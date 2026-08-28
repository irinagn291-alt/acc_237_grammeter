import Foundation

enum CatalogFault: Equatable, Sendable {
    case transport
    case notFound
    case malformed
}

enum CatalogOutcome<Value: Equatable & Sendable>: Equatable, Sendable {
    case value(Value)
    case fault(CatalogFault)
}

/// One client for both Open Food Facts endpoints. Maps DTO → domain.
actor CatalogClient {
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 15
            configuration.httpAdditionalHeaders = ["User-Agent": GaugeLinks.userAgent]
            self.session = URLSession(configuration: configuration)
        }
    }

    func search(terms: String) async -> CatalogOutcome<[MassSpecimen]> {
        var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/search")
        components?.queryItems = [
            URLQueryItem(name: "search_terms", value: terms),
            URLQueryItem(name: "fields", value: "code,product_name,generic_name,brands,image_front_small_url,nutriments"),
            URLQueryItem(name: "page_size", value: "20")
        ]
        guard let url = components?.url else { return .fault(.malformed) }
        return await fetch(url, retry: true) { data in
            let payload = try JSONDecoder().decode(SearchDTO.self, from: data)
            return payload.products.compactMap { $0.specimen() }.filter(\.hasUsableName)
        }
    }

    func resolve(code: String) async -> CatalogOutcome<MassSpecimen> {
        let candidates = BarcodeNormalizer.candidates(from: code)
        guard !candidates.isEmpty else { return .fault(.notFound) }
        var lastFault: CatalogFault = .notFound
        for candidate in candidates {
            if let shelf = DemoShelf.specimen(barcode: candidate) {
                return .value(shelf)
            }
            let urlString = "https://world.openfoodfacts.org/api/v2/product/\(candidate).json"
            guard let url = URL(string: urlString) else { continue }
            let outcome: CatalogOutcome<MassSpecimen> = await fetch(url, retry: true) { data in
                let payload = try JSONDecoder().decode(ProductDTO.self, from: data)
                if payload.status == 0 { throw DecodeMark.notFound }
                guard let specimen = payload.product?.specimen(fallbackCode: candidate), specimen.hasUsableName else {
                    throw DecodeMark.malformed
                }
                return specimen
            }
            switch outcome {
            case .value(let specimen):
                return .value(specimen)
            case .fault(let fault):
                lastFault = fault
                if fault == .notFound { continue }
            }
        }
        return .fault(lastFault)
    }

    private enum DecodeMark: Error {
        case notFound
        case malformed
    }

    private func fetch<T: Equatable & Sendable>(
        _ url: URL,
        retry: Bool,
        map: (Data) throws -> T
    ) async -> CatalogOutcome<T> {
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                return .fault(.notFound)
            }
            do {
                return .value(try map(data))
            } catch DecodeMark.notFound {
                return .fault(.notFound)
            } catch {
                return .fault(.malformed)
            }
        } catch is CancellationError {
            return .fault(.transport)
        } catch {
            if retry, !Task.isCancelled {
                return await fetch(url, retry: false, map: map)
            }
            return .fault(.transport)
        }
    }
}

struct FlexibleNumber: Decodable, Sendable {
    var value: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
        } else if let number = try? container.decode(Double.self) {
            value = number
        } else if let number = try? container.decode(Int.self) {
            value = Double(number)
        } else if let text = try? container.decode(String.self) {
            value = Double(text)
        } else {
            value = nil
        }
    }
}

struct NutrimentDTO: Decodable, Sendable {
    var energyKcal: FlexibleNumber?
    var energyKj: FlexibleNumber?
    var proteins: FlexibleNumber?
    var carbs: FlexibleNumber?
    var fat: FlexibleNumber?

    enum CodingKeys: String, CodingKey {
        case energyKcal = "energy-kcal_100g"
        case energyKj = "energy_100g"
        case proteins = "proteins_100g"
        case carbs = "carbohydrates_100g"
        case fat = "fat_100g"
    }
}

struct ProductBodyDTO: Decodable, Sendable {
    var code: String?
    var productName: String?
    var genericName: String?
    var brands: String?
    var image: String?
    var nutriments: NutrimentDTO?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case genericName = "generic_name"
        case brands
        case image = "image_front_small_url"
        case nutriments
    }

    func specimen(fallbackCode: String? = nil) -> MassSpecimen? {
        let resolvedName = firstName()
        guard let resolvedName, !resolvedName.isEmpty else { return nil }
        let barcode = (code?.isEmpty == false ? code : fallbackCode) ?? ""
        guard !barcode.isEmpty else { return nil }
        let kcal = PortionMath.kcalPer100g(
            energyKcal: nutriments?.energyKcal?.value,
            energyKj: nutriments?.energyKj?.value
        )
        return MassSpecimen(
            barcode: barcode,
            name: resolvedName,
            brand: brands ?? "",
            kcalPer100g: kcal,
            proteinPer100g: nutriments?.proteins?.value,
            carbsPer100g: nutriments?.carbs?.value,
            fatPer100g: nutriments?.fat?.value,
            imageURL: image,
            shelfAsset: nil,
            lastRefresh: Date()
        )
    }

    private func firstName() -> String? {
        if let productName, !productName.isEmpty { return productName }
        if let genericName, !genericName.isEmpty { return genericName }
        if let brands, !brands.isEmpty { return brands }
        return nil
    }
}

struct SearchDTO: Decodable, Sendable {
    var products: [ProductBodyDTO]
}

struct ProductDTO: Decodable, Sendable {
    var status: Int?
    var product: ProductBodyDTO?
}

enum CatalogDecode {
    static func search(_ data: Data) throws -> [MassSpecimen] {
        let payload = try JSONDecoder().decode(SearchDTO.self, from: data)
        return payload.products.compactMap { $0.specimen() }.filter(\.hasUsableName)
    }

    static func product(_ data: Data, fallbackCode: String) throws -> CatalogOutcome<MassSpecimen> {
        let payload = try JSONDecoder().decode(ProductDTO.self, from: data)
        if payload.status == 0 { return .fault(.notFound) }
        guard let specimen = payload.product?.specimen(fallbackCode: fallbackCode), specimen.hasUsableName else {
            return .fault(.malformed)
        }
        return .value(specimen)
    }
}
