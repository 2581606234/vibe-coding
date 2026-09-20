import Foundation

public enum RecoveryPointKind: String, Sendable {
    case automatic
    case preImport = "pre-import"
    case manual
}

public struct RecoveryPointDescriptor: Equatable, Sendable {
    public let url: URL
    public let kind: RecoveryPointKind
    public let createdAt: Date
}

public struct RecoveryPointStore: Sendable {
    public static let automaticRetentionCount = 14
    public static let automaticInterval: TimeInterval = 24 * 60 * 60

    public let directoryURL: URL

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    public static func applicationSupport() throws -> RecoveryPointStore {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return RecoveryPointStore(
            directoryURL: baseURL
                .appendingPathComponent("VibePM", isDirectory: true)
                .appendingPathComponent("Recovery Points", isDirectory: true)
        )
    }

    @discardableResult
    public func create(
        backup: VibePMBackup,
        kind: RecoveryPointKind,
        now: Date = .now
    ) throws -> RecoveryPointDescriptor {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let url = directoryURL.appendingPathComponent(Self.filename(kind: kind, date: now))
        try backup.encoded().write(to: url, options: .atomic)
        let descriptor = RecoveryPointDescriptor(url: url, kind: kind, createdAt: now)
        if kind == .automatic {
            try pruneAutomaticRecoveryPoints()
        }
        return descriptor
    }

    public func createAutomaticIfNeeded(
        backup: VibePMBackup,
        now: Date = .now
    ) throws -> RecoveryPointDescriptor? {
        if let latest = try descriptors().first(where: { $0.kind == .automatic }),
           now.timeIntervalSince(latest.createdAt) < Self.automaticInterval {
            return nil
        }
        return try create(backup: backup, kind: .automatic, now: now)
    }

    public func descriptors() throws -> [RecoveryPointDescriptor] {
        guard FileManager.default.fileExists(atPath: directoryURL.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .compactMap(Self.descriptor)
        .sorted { $0.createdAt > $1.createdAt }
    }

    private func pruneAutomaticRecoveryPoints() throws {
        let automatic = try descriptors().filter { $0.kind == .automatic }
        for descriptor in automatic.dropFirst(Self.automaticRetentionCount) {
            try FileManager.default.removeItem(at: descriptor.url)
        }
    }

    private static func filename(kind: RecoveryPointKind, date: Date) -> String {
        "\(kind.rawValue)-\(timestampFormatter.string(from: date)).json"
    }

    private static func descriptor(from url: URL) -> RecoveryPointDescriptor? {
        let name = url.deletingPathExtension().lastPathComponent
        guard let separator = name.lastIndex(of: "-") else { return nil }
        let timestamp = String(name[name.index(after: separator)...])
        let prefix = String(name[..<separator])
        guard let kind = RecoveryPointKind(rawValue: prefix),
              let date = timestampFormatter.date(from: timestamp) else { return nil }
        return RecoveryPointDescriptor(url: url, kind: kind, createdAt: date)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmssSSS'Z'"
        return formatter
    }()
}
