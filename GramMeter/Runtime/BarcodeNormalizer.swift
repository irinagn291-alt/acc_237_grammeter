import Foundation

/// Extracts digit runs and produces every plausible Open Food Facts candidate.
enum BarcodeNormalizer {
    static func candidates(from raw: String) -> [String] {
        let runs = digitRuns(in: raw).filter { (8...14).contains($0.count) }
        var ordered: [String] = []
        var seen = Set<String>()
        for run in runs {
            for candidate in expand(run) where seen.insert(candidate).inserted {
                ordered.append(candidate)
            }
        }
        return ordered
    }

    static func primary(from raw: String) -> String? {
        candidates(from: raw).first
    }

    private static func digitRuns(in raw: String) -> [String] {
        var runs: [String] = []
        var current = ""
        for character in raw {
            if character.isNumber {
                current.append(character)
            } else if !current.isEmpty {
                runs.append(current)
                current = ""
            }
        }
        if !current.isEmpty { runs.append(current) }
        return runs
    }

    private static func expand(_ run: String) -> [String] {
        var list: [String] = []
        if run.count == 12 {
            list.append("0" + run)
        }
        list.append(run)
        if run.count == 13, run.first == "0" {
            list.append(String(run.dropFirst()))
        }
        return list
    }
}
