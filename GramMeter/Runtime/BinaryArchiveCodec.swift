import Foundation

enum ArchiveCodecError: Error, Equatable, Sendable {
    case magic
    case checksum
    case truncated
    case unsupportedVersion
}

/// Compact versioned binary document: magic, schema, payload, CRC32 footer.
enum BinaryArchiveCodec {
    static let magic = Data([0x47, 0x4D, 0x54, 0x42]) // GMTB
    static let currentVersion: UInt16 = 1

    static func encode(_ archive: ScaleArchive) -> Data {
        var payload = Data()
        writeU16(&payload, archive.schemaVersion)
        writeU16(&payload, UInt16(archive.products.count))
        for key in archive.products.keys.sorted() {
            if let specimen = archive.products[key] {
                writeSpecimen(&payload, specimen)
            }
        }
        writeU16(&payload, UInt16(archive.records.count))
        for record in archive.records {
            writeRecord(&payload, record)
        }
        writeU16(&payload, UInt16(archive.wishes.count))
        for wish in archive.wishes {
            writeString(&payload, wish.barcode)
            writeDouble(&payload, wish.added.timeIntervalSince1970)
        }
        writeU16(&payload, UInt16(archive.presets.count))
        for preset in archive.presets {
            writeString(&payload, preset.barcode)
            payload.append(preset.kind.rawValue)
            writeDouble(&payload, preset.grams)
        }
        writeDouble(&payload, archive.targets.kcal)
        writeDouble(&payload, archive.targets.proteinGrams)
        writeDouble(&payload, archive.targets.carbsGrams)
        writeDouble(&payload, archive.targets.fatGrams)
        payload.append(archive.onboardingComplete ? 1 : 0)

        var document = Data()
        document.append(magic)
        writeU16(&document, archive.schemaVersion)
        writeU32(&document, UInt32(payload.count))
        document.append(payload)
        writeU32(&document, crc32(payload))
        return document
    }

    static func decode(_ data: Data) throws -> ScaleArchive {
        guard data.count >= 14 else { throw ArchiveCodecError.truncated }
        guard data.prefix(4) == magic else { throw ArchiveCodecError.magic }
        let version = readU16(data, 4)
        guard version == 1 else { throw ArchiveCodecError.unsupportedVersion }
        let payloadSize = Int(readU32(data, 6))
        let payloadStart = 10
        let payloadEnd = payloadStart + payloadSize
        guard data.count >= payloadEnd + 4 else { throw ArchiveCodecError.truncated }
        let payload = data.subdata(in: payloadStart..<payloadEnd)
        let checksum = readU32(data, payloadEnd)
        guard checksum == crc32(payload) else { throw ArchiveCodecError.checksum }
        return try decodePayload(payload, version: version)
    }

    private static func decodePayload(_ data: Data, version: UInt16) throws -> ScaleArchive {
        var offset = 0
        _ = try takeU16(data, &offset)
        let productCount = try takeU16(data, &offset)
        var products: [String: MassSpecimen] = [:]
        for _ in 0..<productCount {
            let specimen = try takeSpecimen(data, &offset)
            products[specimen.barcode] = specimen
        }
        let recordCount = try takeU16(data, &offset)
        var records: [WeighRecord] = []
        records.reserveCapacity(Int(recordCount))
        for _ in 0..<recordCount {
            records.append(try takeRecord(data, &offset))
        }
        let wishCount = try takeU16(data, &offset)
        var wishes: [ReservedSpecimen] = []
        for _ in 0..<wishCount {
            let barcode = try takeString(data, &offset)
            let added = Date(timeIntervalSince1970: try takeDouble(data, &offset))
            wishes.append(ReservedSpecimen(barcode: barcode, added: added))
        }
        let presetCount = try takeU16(data, &offset)
        var presets: [PortionPreset] = []
        for _ in 0..<presetCount {
            let barcode = try takeString(data, &offset)
            let kindRaw = try takeU8(data, &offset)
            let kind = PortionKind(rawValue: kindRaw) ?? .slice
            let grams = try takeDouble(data, &offset)
            presets.append(PortionPreset(barcode: barcode, kind: kind, grams: grams))
        }
        let targets = GaugeTargets(
            kcal: try takeDouble(data, &offset),
            proteinGrams: try takeDouble(data, &offset),
            carbsGrams: try takeDouble(data, &offset),
            fatGrams: try takeDouble(data, &offset)
        )
        let onboarded = try takeU8(data, &offset) != 0
        return ScaleArchive(
            schemaVersion: version,
            products: products,
            records: records,
            wishes: wishes,
            presets: presets,
            targets: targets,
            onboardingComplete: onboarded
        )
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                let mask = UInt32(0) &- (crc & 1)
                crc = (crc >> 1) ^ (0xEDB88320 & mask)
            }
        }
        return crc ^ 0xFFFFFFFF
    }

    private static func writeSpecimen(_ data: inout Data, _ specimen: MassSpecimen) {
        writeString(&data, specimen.barcode)
        writeString(&data, specimen.name)
        writeString(&data, specimen.brand)
        writeOptionalDouble(&data, specimen.kcalPer100g)
        writeOptionalDouble(&data, specimen.proteinPer100g)
        writeOptionalDouble(&data, specimen.carbsPer100g)
        writeOptionalDouble(&data, specimen.fatPer100g)
        writeString(&data, specimen.imageURL ?? "")
        writeString(&data, specimen.shelfAsset ?? "")
        writeDouble(&data, specimen.lastRefresh.timeIntervalSince1970)
    }

    private static func takeSpecimen(_ data: Data, _ offset: inout Int) throws -> MassSpecimen {
        MassSpecimen(
            barcode: try takeString(data, &offset),
            name: try takeString(data, &offset),
            brand: try takeString(data, &offset),
            kcalPer100g: try takeOptionalDouble(data, &offset),
            proteinPer100g: try takeOptionalDouble(data, &offset),
            carbsPer100g: try takeOptionalDouble(data, &offset),
            fatPer100g: try takeOptionalDouble(data, &offset),
            imageURL: emptyToNil(try takeString(data, &offset)),
            shelfAsset: emptyToNil(try takeString(data, &offset)),
            lastRefresh: Date(timeIntervalSince1970: try takeDouble(data, &offset))
        )
    }

    private static func writeRecord(_ data: inout Data, _ record: WeighRecord) {
        writeUUID(&data, record.id)
        writeString(&data, record.barcode)
        writeDouble(&data, record.grams)
        data.append(record.slot.rawValue)
        writeI32(&data, Int32(record.day.year))
        data.append(UInt8(clamping: record.day.month))
        data.append(UInt8(clamping: record.day.day))
        data.append(record.isEaten ? 1 : 0)
    }

    private static func takeRecord(_ data: Data, _ offset: inout Int) throws -> WeighRecord {
        WeighRecord(
            id: try takeUUID(data, &offset),
            barcode: try takeString(data, &offset),
            grams: try takeDouble(data, &offset),
            slot: WeighSlot(rawValue: try takeU8(data, &offset)) ?? .weighInOne,
            day: DayKey(
                year: Int(try takeI32(data, &offset)),
                month: Int(try takeU8(data, &offset)),
                day: Int(try takeU8(data, &offset))
            ),
            isEaten: try takeU8(data, &offset) != 0
        )
    }

    private static func emptyToNil(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }

    private static func writeString(_ data: inout Data, _ value: String) {
        let utf8 = Data(value.utf8)
        writeU16(&data, UInt16(clamping: utf8.count))
        data.append(utf8)
    }

    private static func takeString(_ data: Data, _ offset: inout Int) throws -> String {
        let count = Int(try takeU16(data, &offset))
        guard offset + count <= data.count else { throw ArchiveCodecError.truncated }
        let slice = data.subdata(in: offset..<(offset + count))
        offset += count
        return String(data: slice, encoding: .utf8) ?? ""
    }

    private static func writeOptionalDouble(_ data: inout Data, _ value: Double?) {
        if let value {
            data.append(1)
            writeDouble(&data, value)
        } else {
            data.append(0)
        }
    }

    private static func takeOptionalDouble(_ data: Data, _ offset: inout Int) throws -> Double? {
        let flag = try takeU8(data, &offset)
        if flag == 0 { return nil }
        return try takeDouble(data, &offset)
    }

    private static func writeDouble(_ data: inout Data, _ value: Double) {
        var bitPattern = value.bitPattern.littleEndian
        Swift.withUnsafeBytes(of: &bitPattern) { data.append(contentsOf: $0) }
    }

    private static func takeDouble(_ data: Data, _ offset: inout Int) throws -> Double {
        guard offset + 8 <= data.count else { throw ArchiveCodecError.truncated }
        let bits = data.subdata(in: offset..<(offset + 8)).withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }.littleEndian
        offset += 8
        return Double(bitPattern: bits)
    }

    private static func writeUUID(_ data: inout Data, _ value: UUID) {
        data.append(contentsOf: uuidBytes(value))
    }

    private static func takeUUID(_ data: Data, _ offset: inout Int) throws -> UUID {
        guard offset + 16 <= data.count else { throw ArchiveCodecError.truncated }
        let bytes = [UInt8](data.subdata(in: offset..<(offset + 16)))
        offset += 16
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func uuidBytes(_ value: UUID) -> [UInt8] {
        let u = value.uuid
        return [u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7, u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15]
    }

    private static func writeU16(_ data: inout Data, _ value: UInt16) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }

    private static func writeU32(_ data: inout Data, _ value: UInt32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }

    private static func writeI32(_ data: inout Data, _ value: Int32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }

    private static func readU16(_ data: Data, _ offset: Int) -> UInt16 {
        data.subdata(in: offset..<(offset + 2)).withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }.littleEndian
    }

    private static func readU32(_ data: Data, _ offset: Int) -> UInt32 {
        data.subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian
    }

    private static func takeU8(_ data: Data, _ offset: inout Int) throws -> UInt8 {
        guard offset < data.count else { throw ArchiveCodecError.truncated }
        let value = data[offset]
        offset += 1
        return value
    }

    private static func takeU16(_ data: Data, _ offset: inout Int) throws -> UInt16 {
        guard offset + 2 <= data.count else { throw ArchiveCodecError.truncated }
        let value = readU16(data, offset)
        offset += 2
        return value
    }

    private static func takeI32(_ data: Data, _ offset: inout Int) throws -> Int32 {
        guard offset + 4 <= data.count else { throw ArchiveCodecError.truncated }
        let value = data.subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }.littleEndian
        offset += 4
        return value
    }
}
