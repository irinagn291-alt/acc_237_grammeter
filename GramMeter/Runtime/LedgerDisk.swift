import Foundation

/// Actor seam between domain archive and the binary file. UI never touches this type.
actor LedgerDisk {
    private let fileURL: URL
    private let backupURL: URL

    init(directory: URL? = nil) {
        let folder = directory ?? LedgerDisk.defaultDirectory()
        fileURL = folder.appendingPathComponent("ledger.gmt")
        backupURL = folder.appendingPathComponent("ledger.gmt.backup")
    }

    func load() -> (ScaleArchive, String?) {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            return (.empty, "The archive folder could not be prepared.")
        }
        if fileManager.fileExists(atPath: fileURL.path) {
            if let data = try? Data(contentsOf: fileURL), let archive = try? BinaryArchiveCodec.decode(data) {
                return (archive, nil)
            }
            if fileManager.fileExists(atPath: backupURL.path),
               let backup = try? Data(contentsOf: backupURL),
               let archive = try? BinaryArchiveCodec.decode(backup) {
                return (archive, "The last good archive was restored.")
            }
            return (.empty, "The archive was unreadable. Starting from an empty scale.")
        }
        return (.empty, nil)
    }

    func save(_ archive: ScaleArchive) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: fileURL.path) {
            if fileManager.fileExists(atPath: backupURL.path) {
                try fileManager.removeItem(at: backupURL)
            }
            try fileManager.copyItem(at: fileURL, to: backupURL)
        }
        let data = BinaryArchiveCodec.encode(archive)
        try data.write(to: fileURL, options: .atomic)
        if !fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.copyItem(at: fileURL, to: backupURL)
        }
    }

    func resetAllData() throws {
        try save(.empty)
    }

    private static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("GramMeter", isDirectory: true)
    }
}
