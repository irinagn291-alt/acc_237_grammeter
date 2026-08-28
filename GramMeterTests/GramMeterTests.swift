import XCTest
@testable import GramMeter

final class PortionMathTests: XCTestCase {
    func testDirectKilocalories() {
        XCTAssertEqual(PortionMath.kcalPer100g(energyKcal: 144, energyKj: 600), 144)
        XCTAssertEqual(PortionMath.scale(144, grams: 150), 216)
    }

    func testKilojouleFallback() {
        let kcal = PortionMath.kcalPer100g(energyKcal: nil, energyKj: 418.4)
        XCTAssertEqual(kcal ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(PortionMath.scale(kcal, grams: 50) ?? 0, 50, accuracy: 0.001)
    }
}

final class BarcodeNormalizerTests: XCTestCase {
    func testEAN8() {
        XCTAssertEqual(BarcodeNormalizer.candidates(from: "12345678").first, "12345678")
    }

    func testEAN13() {
        XCTAssertEqual(BarcodeNormalizer.candidates(from: "0018627103257").first, "0018627103257")
    }

    func testUPCAPadding() {
        XCTAssertEqual(BarcodeNormalizer.candidates(from: "012345678905").first, "0012345678905")
    }

    func testURLInput() {
        let url = "https://world.openfoodfacts.org/product/0025484000107/tofu"
        XCTAssertEqual(BarcodeNormalizer.primary(from: url), "0025484000107")
    }

    func testNoValidRun() {
        XCTAssertTrue(BarcodeNormalizer.candidates(from: "abc-12-xyz").isEmpty)
    }
}

final class MissingMacroTests: XCTestCase {
    func testUnknownStaysUnknown() {
        XCTAssertNil(PortionMath.scale(nil, grams: 80))
        let specimen = MassSpecimen(
            barcode: "1",
            name: "Blank",
            brand: "",
            kcalPer100g: 10,
            proteinPer100g: nil,
            carbsPer100g: nil,
            fatPer100g: nil,
            imageURL: nil,
            shelfAsset: nil,
            lastRefresh: Date(timeIntervalSince1970: 0)
        )
        XCTAssertNil(PortionMath.scale(specimen.proteinPer100g, grams: 100))
        XCTAssertEqual(PortionMath.energy(specimen: specimen, grams: 100), 10)
    }
}

final class DayTotalTests: XCTestCase {
    func testAggregationAcrossSlots() {
        var archive = ScaleArchive.empty
        let specimen = MassSpecimen(
            barcode: "x",
            name: "Charge",
            brand: "",
            kcalPer100g: 100,
            proteinPer100g: 10,
            carbsPer100g: 20,
            fatPer100g: 5,
            imageURL: nil,
            shelfAsset: nil,
            lastRefresh: Date(timeIntervalSince1970: 0)
        )
        archive.upsert(specimen)
        let day = DayKey(year: 2026, month: 8, day: 25)
        archive.records = WeighSlot.allCases.map { slot in
            WeighRecord(id: UUID(), barcode: "x", grams: 50, slot: slot, day: day, isEaten: true)
        }
        let eaten = archive.eaten(on: day)
        XCTAssertEqual(eaten.count, 4)
        XCTAssertEqual(DayTotals.energy(records: eaten, archive: archive), 200, accuracy: 0.001)
        XCTAssertEqual(DayTotals.protein(records: eaten, archive: archive) ?? 0, 20, accuracy: 0.001)
        XCTAssertEqual(DayTotals.carbs(records: eaten, archive: archive) ?? 0, 40, accuracy: 0.001)
        XCTAssertEqual(DayTotals.fat(records: eaten, archive: archive) ?? 0, 10, accuracy: 0.001)
    }
}

final class WishUniquenessTests: XCTestCase {
    func testDuplicateUpdatesExisting() {
        var archive = ScaleArchive.empty
        let first = Date(timeIntervalSince1970: 100)
        let second = Date(timeIntervalSince1970: 200)
        archive.upsertWish("0722252100450", added: first)
        archive.upsertWish("0722252100450", added: second)
        XCTAssertEqual(archive.wishes.count, 1)
        XCTAssertEqual(archive.wishes[0].added, second)
        XCTAssertTrue(archive.isWished("0722252100450"))
    }
}

final class DayBoundaryTests: XCTestCase {
    func testDaylightSavingSpringForward() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        let before = calendar.date(from: DateComponents(year: 2024, month: 3, day: 10, hour: 1, minute: 30))
        let after = calendar.date(from: DateComponents(year: 2024, month: 3, day: 10, hour: 3, minute: 30))
        guard let before, let after else {
            XCTFail("dates")
            return
        }
        XCTAssertEqual(DayKey(from: before, calendar: calendar), DayKey(year: 2024, month: 3, day: 10))
        XCTAssertEqual(DayKey(from: after, calendar: calendar), DayKey(year: 2024, month: 3, day: 10))
        let next = DayKey(from: before, calendar: calendar).adding(days: 1, calendar: calendar)
        XCTAssertEqual(next, DayKey(year: 2024, month: 3, day: 11))
    }
}

final class CatalogDecodeTests: XCTestCase {
    func testMissingAndStringNutriments() throws {
        let json = """
        {
          "status": 1,
          "product": {
            "code": "12345678",
            "product_name": "Gauge Oats",
            "brands": "Shelf",
            "nutriments": {
              "energy-kcal_100g": "120",
              "proteins_100g": 4.5,
              "carbohydrates_100g": "20",
              "fat_100g": null
            }
          }
        }
        """.data(using: .utf8) ?? Data()
        let outcome = try CatalogDecode.product(json, fallbackCode: "12345678")
        guard case .value(let specimen) = outcome else {
            XCTFail("expected value")
            return
        }
        XCTAssertEqual(specimen.name, "Gauge Oats")
        XCTAssertEqual(specimen.kcalPer100g ?? 0, 120, accuracy: 0.001)
        XCTAssertEqual(specimen.proteinPer100g ?? 0, 4.5, accuracy: 0.001)
        XCTAssertEqual(specimen.carbsPer100g ?? 0, 20, accuracy: 0.001)
        XCTAssertNil(specimen.fatPer100g)
    }

    func testStatusZeroIsNotFound() throws {
        let json = """
        {"status": 0, "status_verbose": "product not found"}
        """.data(using: .utf8) ?? Data()
        let outcome = try CatalogDecode.product(json, fallbackCode: "000")
        XCTAssertEqual(outcome, .fault(.notFound))
    }
}

final class PrecisionWeighTests: XCTestCase {
    func testTareNetAndUnits() {
        XCTAssertEqual(MassConvert.netGrams(tare: 50, gross: 180), 130, accuracy: 0.0001)
        XCTAssertEqual(MassConvert.toGrams(1, unit: .ounce), MassConvert.gramsPerOunce, accuracy: 0.0001)
        XCTAssertEqual(MassConvert.toGrams(100, unit: .millilitre, density: 1.03), 103, accuracy: 0.0001)
        let net = MassConvert.netGrams(tareDisplay: 2, grossDisplay: 6, unit: .ounce, density: 1)
        XCTAssertEqual(net, 4 * MassConvert.gramsPerOunce, accuracy: 0.0001)
        var model = ScaleModel.blank
        model.tareText = "40"
        model.grossText = "140"
        XCTAssertEqual(model.netGrams ?? 0, 100, accuracy: 0.001)
    }
}

final class ElmUpdatePurityTests: XCTestCase {
    func testScaleUpdateIsPure() {
        let start = ScaleModel.blank
        let (first, cmdA) = ScaleUpdate.update(msg: .setGrams("100"), model: start)
        let (second, cmdB) = ScaleUpdate.update(msg: .setGrams("100"), model: start)
        XCTAssertEqual(first, second)
        XCTAssertEqual(cmdA, cmdB)
        XCTAssertEqual(start.gramsText, "")
        XCTAssertEqual(first.gramsText, "100")
    }

    func testTareRemapsWhenPlanning() {
        var model = ScaleModel.blank
        model.slot = .tare
        let (next, _) = ScaleUpdate.update(msg: .setEaten(false), model: model)
        XCTAssertEqual(next.slot, .weighInThree)
    }
}

final class BinaryArchiveRoundTripTests: XCTestCase {
    func testWriteReload() throws {
        var archive = ScaleArchive.empty
        archive.onboardingComplete = true
        archive.targets = GaugeTargets(kcal: 2100, proteinGrams: 130, carbsGrams: 240, fatGrams: 60)
        let specimen = DemoShelf.specimens[0]
        archive.upsert(specimen)
        archive.records.append(
            WeighRecord(
                id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE") ?? UUID(),
                barcode: specimen.barcode,
                grams: 55.5,
                slot: .weighInTwo,
                day: DayKey(year: 2026, month: 8, day: 27),
                isEaten: true
            )
        )
        archive.upsertWish(specimen.barcode, added: Date(timeIntervalSince1970: 50))
        archive.upsertPreset(PortionPreset(barcode: specimen.barcode, kind: .slice, grams: 28))
        let data = BinaryArchiveCodec.encode(archive)
        let restored = try BinaryArchiveCodec.decode(data)
        XCTAssertEqual(restored.targets, archive.targets)
        XCTAssertEqual(restored.records.count, 1)
        XCTAssertEqual(restored.records[0].grams, 55.5, accuracy: 0.0001)
        XCTAssertEqual(restored.records[0].day, DayKey(year: 2026, month: 8, day: 27))
        XCTAssertEqual(restored.wishes.count, 1)
        XCTAssertEqual(restored.presets.first?.grams, 28)
        XCTAssertEqual(restored.products[specimen.barcode]?.name, specimen.name)
        XCTAssertTrue(restored.onboardingComplete)
    }

    func testCorruptFallsBackInDisk() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let disk = LedgerDisk(directory: folder)
        var archive = ScaleArchive.empty
        archive.targets.kcal = 1999
        try await disk.save(archive)
        let url = folder.appendingPathComponent("ledger.gmt")
        try Data([0x00, 0x01, 0x02]).write(to: url)
        let (loaded, notice) = await disk.load()
        XCTAssertEqual(loaded.targets.kcal, 1999)
        XCTAssertNotNil(notice)
    }
}
