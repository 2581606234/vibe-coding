import Foundation

public struct ProjectDraft: Equatable, Sendable {
    public var name: String
    public var projectDescription: String
    public var accent: ProjectAccent

    public init(
        name: String = "",
        projectDescription: String = "",
        accent: ProjectAccent = .indigo
    ) {
        self.name = name
        self.projectDescription = projectDescription
        self.accent = accent
    }

    public init(project: Project) {
        self.init(
            name: project.name,
            projectDescription: project.projectDescription,
            accent: project.accent
        )
    }

    public var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var canSave: Bool {
        !normalizedName.isEmpty
    }

    public func makeProject(now: Date = .now) -> Project {
        Project(
            name: normalizedName,
            projectDescription: projectDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: now,
            updatedAt: now,
            accent: accent
        )
    }

    public func apply(to project: Project, now: Date = .now) {
        project.name = normalizedName
        project.projectDescription = projectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        project.accent = accent
        project.updatedAt = now
    }
}

