import Foundation

/// Bundled local shelf. Nutrition values and barcodes match SPEC §14 exactly.
enum DemoShelf {
    static let specimens: [MassSpecimen] = [
        item(
            barcode: "0722252100450",
            name: "Calibrated Protein Bar",
            brand: "Shelf",
            kcal: 383, protein: 30.0, carbs: 40.0, fat: 12.0
        ),
        item(
            barcode: "0029000016613",
            name: "Mixed Nut Charge",
            brand: "Shelf",
            kcal: 607, protein: 20.0, carbs: 21.0, fat: 54.0
        ),
        item(
            barcode: "8410054000129",
            name: "Chickpea Tin",
            brand: "Shelf",
            kcal: 119, protein: 7.1, carbs: 16.2, fat: 2.6
        ),
        item(
            barcode: "0033383401003",
            name: "Sweet Potato Mass",
            brand: "Shelf",
            kcal: 86, protein: 1.6, carbs: 20.1, fat: 0.1
        ),
        item(
            barcode: "8076809513388",
            name: "Brown Rice Charge",
            brand: "Shelf",
            kcal: 362, protein: 7.5, carbs: 76.0, fat: 2.7
        ),
        item(
            barcode: "0027815995026",
            name: "Salmon Fillet Slab",
            brand: "Shelf",
            kcal: 208, protein: 20.4, carbs: 0.0, fat: 13.4
        )
    ]

    static func specimen(barcode: String) -> MassSpecimen? {
        specimens.first { $0.barcode == barcode }
    }

    static func matches(query: String) -> [MassSpecimen] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return [] }
        return specimens.filter {
            $0.name.lowercased().contains(needle)
                || $0.brand.lowercased().contains(needle)
                || $0.barcode.contains(needle)
        }
    }

    static func seedDay(into archive: ScaleArchive, day: DayKey) -> ScaleArchive {
        var next = archive
        for specimen in specimens {
            next.upsert(specimen)
        }
        if next.eaten(on: day).isEmpty {
            let seeded: [(String, Double, WeighSlot)] = [
                ("0722252100450", 60, .weighInOne),
                ("0029000016613", 30, .tare),
                ("8410054000129", 150, .weighInTwo),
                ("0027815995026", 120, .weighInThree)
            ]
            for (barcode, grams, slot) in seeded {
                next.records.append(
                    WeighRecord(id: UUID(), barcode: barcode, grams: grams, slot: slot, day: day, isEaten: true)
                )
            }
        }
        if next.planned(from: day.adding(days: 1), through: day.adding(days: 14)).isEmpty {
            next.records.append(
                WeighRecord(
                    id: UUID(),
                    barcode: "8076809513388",
                    grams: 80,
                    slot: .weighInTwo,
                    day: day.adding(days: 1),
                    isEaten: false
                )
            )
        }
        if next.wishes.isEmpty {
            next.upsertWish("0033383401003", added: Date())
            next.upsertWish("0027815995026", added: Date())
        }
        return next
    }

    private static func item(
        barcode: String,
        name: String,
        brand: String,
        kcal: Double,
        protein: Double,
        carbs: Double,
        fat: Double
    ) -> MassSpecimen {
        MassSpecimen(
            barcode: barcode,
            name: name,
            brand: brand,
            kcalPer100g: kcal,
            proteinPer100g: protein,
            carbsPer100g: carbs,
            fatPer100g: fat,
            imageURL: nil,
            shelfAsset: "gmt_ProductPlaceholder",
            lastRefresh: Date(timeIntervalSince1970: 0)
        )
    }
}
