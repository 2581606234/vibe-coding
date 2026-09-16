import Foundation
import SwiftData

public enum ProjectAccent: String, Codable, CaseIterable, Sendable {
    case indigo
    case blue
    case mint
    case orange
    case rose
    case purple

    public var title: String {
        rawValue.capitalized
    }
}

@Model
public final class Project {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var projectDescription: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isArchived: Bool
    public var accentRawValue: String = ProjectAccent.indigo.rawValue

    public var accent: ProjectAccent {
        get { ProjectAccent(rawValue: accentRawValue) ?? .indigo }
        set { accentRawValue = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        projectDescription: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isArchived: Bool = false,
        accent: ProjectAccent = .indigo
    ) {
        self.id = id
        self.name = name
        self.projectDescription = projectDescription
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.accentRawValue = accent.rawValue
    }

    public func archive(at date: Date = .now) {
        isArchived = true
        updatedAt = date
    }

    public func restore(at date: Date = .now) {
        isArchived = false
        updatedAt = date
    }
}

