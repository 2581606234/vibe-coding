import CryptoKit
import Foundation
import SwiftData
import ZIPFoundation

public struct VibePMExcelWorkbook: Sendable {
    public let projects: [ProjectRecord]
    public let tasks: [TaskRecord]
    private let includesProjectAuditTimestamps: Bool
    private let includesTaskAuditTimestamps: Bool

    public init(projects: [Project], tasks: [ProjectTask]) {
        self.projects = projects.map(ProjectRecord.init)
        self.tasks = tasks.map(TaskRecord.init)
        includesProjectAuditTimestamps = true
        includesTaskAuditTimestamps = true
    }

    private init(
        projects: [ProjectRecord],
        tasks: [TaskRecord],
        includesProjectAuditTimestamps: Bool,
        includesTaskAuditTimestamps: Bool
    ) {
        self.projects = projects
        self.tasks = tasks
        self.includesProjectAuditTimestamps = includesProjectAuditTimestamps
        self.includesTaskAuditTimestamps = includesTaskAuditTimestamps
    }

    public func encoded() throws -> Data {
        return try ExcelArchive.make(
            projectRows: projects.map(Self.projectRow),
            taskRows: tasks.map(Self.taskRow),
            templateLanguage: nil
        )
    }

    public static func templateData(language: AppLanguage = L10n.selectedLanguage()) throws -> Data {
        let language = language.resolved()
        let isChinese = language == .simplifiedChinese
        return try ExcelArchive.make(
            projectRows: [
                [
                    .text(isChinese ? "项目-网站上线" : "project-website-launch"),
                    .text(isChinese ? "网站上线" : "Website launch"),
                    .text(isChinese ? "准备并发布新网站" : "Prepare and publish the new website"),
                    .text(isChinese ? "靛蓝" : "indigo"),
                    .text(isChinese ? "否" : "FALSE"),
                    .blank,
                    .blank
                ],
                [
                    .blank,
                    .text(isChinese ? "未编号项目示例" : "Unnumbered Project example"),
                    .text(isChinese ? "编号留空时，导入会自动生成" : "Import generates an ID when this cell is blank"),
                    .text(isChinese ? "蓝色" : "blue"),
                    .text(isChinese ? "否" : "FALSE"),
                    .blank,
                    .blank
                ]
            ],
            taskRows: [
                [
                    .text(isChinese ? "任务-网站上线" : "task-website-launch"),
                    .text(isChinese ? "发布网站" : "Launch website"),
                    .text(isChinese ? "协调最终上线工作" : "Coordinate the final launch"),
                    .text(isChinese ? "进行中" : "inProgress"),
                    .text(isChinese ? "高" : "high"),
                    .text(isChinese ? "项目-网站上线" : "project-website-launch"),
                    .blank,
                    .date(.now),
                    .date(Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now),
                    .blank,
                    .blank,
                    .blank
                ],
                [
                    .blank,
                    .text(isChinese ? "评审首页文案" : "Review homepage copy"),
                    .text(isChinese ? "确认首页标题、正文和行动按钮文案" : "Confirm the homepage headline, body copy, and call to action"),
                    .text(isChinese ? "待办" : "todo"),
                    .text(isChinese ? "中" : "medium"),
                    .text(isChinese ? "项目-网站上线" : "project-website-launch"),
                    .text(isChinese ? "任务-网站上线" : "task-website-launch"),
                    .date(.now),
                    .date(Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now),
                    .blank,
                    .blank,
                    .blank
                ]
            ],
            templateLanguage: language
        )
    }

    public static func decoded(from data: Data) throws -> Self {
        let archive = try Archive(data: data, accessMode: .read)
        let sharedStrings = try archive.sharedStrings()
        let projectTable = try archive.table(at: "xl/worksheets/sheet1.xml", sharedStrings: sharedStrings)
        let taskTable = try archive.table(at: "xl/worksheets/sheet2.xml", sharedStrings: sharedStrings)
        let projectHeaders = projectTable.canonicalHeaders
        let taskHeaders = taskTable.canonicalHeaders

        let projectRows = try projectTable.records(
            sheet: "Projects",
            requiredHeaders: ExcelArchive.projectRequiredHeaders
        )
        let taskRows = try taskTable.records(
            sheet: "Tasks",
            requiredHeaders: ExcelArchive.taskRequiredHeaders
        )

        var projectIDs: [String: UUID] = [:]
        var projectRecords: [ProjectRecord] = []
        for (index, row) in projectRows.enumerated() {
            let rowNumber = index + 2
            let key = row["project_key"].flatMap(Self.nonEmpty)
            if let key {
                guard projectIDs[key] == nil else {
                    throw ExcelWorkbookError.duplicateKey(sheet: "Projects", key: key)
                }
            }
            let id = key.map { stableID(namespace: "project", key: $0) } ?? UUID()
            if let key { projectIDs[key] = id }
            let now = Date.now
            projectRecords.append(ProjectRecord(
                id: id,
                name: try row.required("name", sheet: "Projects", row: rowNumber),
                projectDescription: row["description"] ?? "",
                createdAt: try parseDate(row["created_at"], sheet: "Projects", row: rowNumber, column: "created_at") ?? now,
                updatedAt: try parseDate(row["updated_at"], sheet: "Projects", row: rowNumber, column: "updated_at") ?? now,
                isArchived: try parseBool(row["archived"], sheet: "Projects", row: rowNumber, column: "archived"),
                accent: try parseAccent(row["accent"], row: rowNumber),
                deletedAt: nil,
                deletionBatchID: nil
            ))
        }

        var taskIDs: [String: UUID] = [:]
        var taskRowIDs: [UUID] = []
        for row in taskRows {
            let key = row["task_key"].flatMap(Self.nonEmpty)
            if let key {
                guard taskIDs[key] == nil else {
                    throw ExcelWorkbookError.duplicateKey(sheet: "Tasks", key: key)
                }
            }
            let id = key.map { stableID(namespace: "task", key: $0) } ?? UUID()
            taskRowIDs.append(id)
            if let key { taskIDs[key] = id }
        }

        var taskRecords: [TaskRecord] = []
        for (index, row) in taskRows.enumerated() {
            let rowNumber = index + 2
            let projectKey = row["project_key"].flatMap(Self.nonEmpty)
            let parentKey = row["parent_task_key"].flatMap(Self.nonEmpty)

            if let projectKey, projectIDs[projectKey] == nil {
                throw ExcelWorkbookError.unknownReference(
                    sheet: "Tasks", row: rowNumber, column: "project_key", key: projectKey
                )
            }
            if let parentKey, taskIDs[parentKey] == nil {
                throw ExcelWorkbookError.unknownReference(
                    sheet: "Tasks", row: rowNumber, column: "parent_task_key", key: parentKey
                )
            }

            let now = Date.now
            let status = try parseStatus(row["status"], row: rowNumber)
            taskRecords.append(TaskRecord(
                id: taskRowIDs[index],
                title: try row.required("title", sheet: "Tasks", row: rowNumber),
                taskDescription: row["description"] ?? "",
                status: status,
                priority: try parsePriority(row["priority"], row: rowNumber),
                projectID: projectKey.flatMap { projectIDs[$0] },
                parentTaskID: parentKey.flatMap { taskIDs[$0] },
                scheduledFor: try parseDate(row["scheduled_for"], row: rowNumber, column: "scheduled_for"),
                dueAt: try parseDate(row["due_at"], row: rowNumber, column: "due_at"),
                completedAt: try parseDate(row["completed_at"], sheet: "Tasks", row: rowNumber, column: "completed_at") ?? (status == .done ? now : nil),
                createdAt: try parseDate(row["created_at"], sheet: "Tasks", row: rowNumber, column: "created_at") ?? now,
                updatedAt: try parseDate(row["updated_at"], sheet: "Tasks", row: rowNumber, column: "updated_at") ?? now,
                deletedAt: nil,
                deletionBatchID: nil
            ))
        }

        return Self(
            projects: projectRecords,
            tasks: taskRecords,
            includesProjectAuditTimestamps: projectHeaders.contains("created_at") && projectHeaders.contains("updated_at"),
            includesTaskAuditTimestamps: taskHeaders.contains("created_at") && taskHeaders.contains("updated_at")
        )
    }

    @MainActor
    public func restore(into context: ModelContext) throws {
        let existingProjects = try context.fetch(FetchDescriptor<Project>())
        let existingTasks = try context.fetch(FetchDescriptor<ProjectTask>())
        let projectsByID = Dictionary(uniqueKeysWithValues: existingProjects.map { ($0.id, $0) })
        let tasksByID = Dictionary(uniqueKeysWithValues: existingTasks.map { ($0.id, $0) })
        let importedAt = Date.now
        let normalizedProjects = projects.map { record in
            guard !includesProjectAuditTimestamps else { return record }
            return ProjectRecord(
                id: record.id,
                name: record.name,
                projectDescription: record.projectDescription,
                createdAt: projectsByID[record.id]?.createdAt ?? importedAt,
                updatedAt: importedAt,
                isArchived: record.isArchived,
                accent: record.accent,
                deletedAt: record.deletedAt,
                deletionBatchID: record.deletionBatchID
            )
        }
        let normalizedTasks = tasks.map { record in
            guard !includesTaskAuditTimestamps else { return record }
            return TaskRecord(
                id: record.id,
                title: record.title,
                taskDescription: record.taskDescription,
                status: record.status,
                priority: record.priority,
                projectID: record.projectID,
                parentTaskID: record.parentTaskID,
                scheduledFor: record.scheduledFor,
                dueAt: record.dueAt,
                completedAt: record.completedAt,
                createdAt: tasksByID[record.id]?.createdAt ?? importedAt,
                updatedAt: importedAt,
                deletedAt: record.deletedAt,
                deletionBatchID: record.deletionBatchID
            )
        }
        let backup = VibePMBackup(
            schemaVersion: VibePMBackup.currentSchemaVersion,
            exportedAt: .now,
            projects: normalizedProjects,
            tasks: normalizedTasks
        )
        try backup.restore(into: context)
    }

    private static func projectRow(_ project: ProjectRecord) -> [ExcelCell] {
        [
            .text(project.id.uuidString),
            .text(project.name),
            .text(project.projectDescription),
            .text(project.accent.rawValue),
            .bool(project.isArchived),
            .dateTime(project.createdAt),
            .dateTime(project.updatedAt)
        ]
    }

    private static func taskRow(_ task: TaskRecord) -> [ExcelCell] {
        [
            .text(task.id.uuidString),
            .text(task.title),
            .text(task.taskDescription),
            .text(task.status.rawValue),
            .text(task.priority.title.lowercased()),
            task.projectID.map { .text($0.uuidString) } ?? .blank,
            task.parentTaskID.map { .text($0.uuidString) } ?? .blank,
            task.scheduledFor.map(ExcelCell.date) ?? .blank,
            task.dueAt.map(ExcelCell.date) ?? .blank,
            task.completedAt.map(ExcelCell.dateTime) ?? .blank,
            .dateTime(task.createdAt),
            .dateTime(task.updatedAt)
        ]
    }

    private static func stableID(namespace: String, key: String) -> UUID {
        if let id = UUID(uuidString: key) { return id }
        let digest = SHA256.hash(data: Data("vibepm:\(namespace):\(key)".utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func nonEmpty(_ value: String) -> String? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func parseBool(
        _ value: String?, sheet: String, row: Int, column: String
    ) throws -> Bool {
        let normalized = (value ?? "false").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "true", "yes", "1", "是": return true
        case "false", "no", "0", "否", "": return false
        default: throw ExcelWorkbookError.invalidValue(sheet: sheet, row: row, column: column, value: value ?? "")
        }
    }

    private static func parseAccent(_ value: String?, row: Int) throws -> ProjectAccent {
        let aliases: [String: ProjectAccent] = [
            "indigo": .indigo, "靛蓝": .indigo, "blue": .blue, "蓝色": .blue,
            "mint": .mint, "薄荷绿": .mint, "orange": .orange, "橙色": .orange,
            "rose": .rose, "玫红": .rose, "purple": .purple, "紫色": .purple
        ]
        let normalized = (value ?? "indigo").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let accent = aliases[normalized] else {
            throw ExcelWorkbookError.invalidValue(sheet: "Projects", row: row, column: "accent", value: value ?? "")
        }
        return accent
    }

    private static func parseStatus(_ value: String?, row: Int) throws -> TaskStatus {
        let aliases: [String: TaskStatus] = [
            "todo": .todo, "to do": .todo, "待办": .todo,
            "inprogress": .inProgress, "in progress": .inProgress, "进行中": .inProgress,
            "done": .done, "已完成": .done
        ]
        let normalized = (value ?? "todo").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let status = aliases[normalized] else {
            throw ExcelWorkbookError.invalidValue(sheet: "Tasks", row: row, column: "status", value: value ?? "")
        }
        return status
    }

    private static func parsePriority(_ value: String?, row: Int) throws -> TaskPriority {
        let aliases: [String: TaskPriority] = [
            "none": .none, "无": .none, "low": .low, "低": .low,
            "medium": .medium, "中": .medium, "high": .high, "高": .high
        ]
        let normalized = (value ?? "none").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let priority = aliases[normalized] else {
            throw ExcelWorkbookError.invalidValue(sheet: "Tasks", row: row, column: "priority", value: value ?? "")
        }
        return priority
    }

    private static func parseDate(
        _ value: String?,
        sheet: String = "Tasks",
        row: Int,
        column: String
    ) throws -> Date? {
        guard let value = value.flatMap(nonEmpty) else { return nil }
        if let serial = Double(value) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let epoch = calendar.date(from: DateComponents(year: 1899, month: 12, day: 30))!
            return calendar.date(byAdding: .second, value: Int(serial * 86_400), to: epoch)
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: value) { return date }
        if let date = ISO8601DateFormatter().date(from: value) { return date }
        throw ExcelWorkbookError.invalidValue(sheet: sheet, row: row, column: column, value: value)
    }
}

public enum ExcelWorkbookError: LocalizedError, Equatable {
    case missingWorksheet(String)
    case emptyWorksheet(String)
    case missingColumn(sheet: String, column: String)
    case missingValue(sheet: String, row: Int, column: String)
    case duplicateKey(sheet: String, key: String)
    case unknownReference(sheet: String, row: Int, column: String, key: String)
    case invalidValue(sheet: String, row: Int, column: String, value: String)
    case malformedWorkbook

    public var errorDescription: String? {
        switch self {
        case let .missingWorksheet(sheet): "缺少 \(sheet) 工作表 / Missing \(sheet) worksheet."
        case let .emptyWorksheet(sheet): "\(sheet) 工作表为空 / \(sheet) worksheet is empty."
        case let .missingColumn(sheet, column): "\(sheet) 缺少列 \(column) / Missing column \(column) in \(sheet)."
        case let .missingValue(sheet, row, column): "\(sheet) 第 \(row) 行缺少 \(column) / Missing \(column) in \(sheet) row \(row)."
        case let .duplicateKey(sheet, key): "\(sheet) 中键值重复：\(key) / Duplicate key in \(sheet): \(key)."
        case let .unknownReference(sheet, row, column, key): "\(sheet) 第 \(row) 行的 \(column) 引用了不存在的键：\(key) / Unknown reference in \(sheet) row \(row): \(key)."
        case let .invalidValue(sheet, row, column, value): "\(sheet) 第 \(row) 行的 \(column) 值无效：\(value) / Invalid value in \(sheet) row \(row)."
        case .malformedWorkbook: "Excel 文件结构无效 / The Excel workbook is malformed."
        }
    }
}

private enum ExcelCell {
    case text(String)
    case bool(Bool)
    case date(Date)
    case dateTime(Date)
    case blank
}

private enum ExcelArchive {
    static let projectHeaders = [
        "project_key", "name", "description", "accent", "archived", "created_at", "updated_at"
    ]
    static let projectRequiredHeaders = [
        "project_key", "name", "description", "accent", "archived"
    ]
    static let taskHeaders = [
        "task_key", "title", "description", "status", "priority",
        "project_key", "parent_task_key", "scheduled_for", "due_at",
        "completed_at", "created_at", "updated_at"
    ]
    static let taskRequiredHeaders = [
        "task_key", "title", "description", "status", "priority",
        "project_key", "parent_task_key", "scheduled_for", "due_at", "completed_at"
    ]

    private struct ExcelValidation {
        enum Source {
            case values([String])
            case namedRange(String)
        }

        let range: String
        let source: Source
        let promptTitle: String
        let prompt: String
        let errorTitle: String
        let error: String
    }

    private struct TemplateLayout {
        let isTemplate: Bool
        let isChinese: Bool

        init(language: AppLanguage?) {
            isTemplate = language != nil
            isChinese = language?.resolved() == .simplifiedChinese
        }

        var projectSheet: String { isChinese ? "项目" : "Projects" }
        var taskSheet: String { isChinese ? "任务" : "Tasks" }
        var instructionSheet: String { isChinese ? "填写说明" : "Instructions" }
        var guideTitle: String { isChinese ? "VibePM Excel 导入模板说明" : "VibePM Excel Import Guide" }

        var projectHeaders: [String] {
            guard isTemplate else { return ExcelArchive.projectHeaders }
            if isChinese {
                return ["项目编号（新建可留空）", "项目名称", "项目描述", "主题色", "是否归档"]
            }
            return ["Project ID (optional for new)", "Project name", "Project description", "Accent", "Archived"]
        }

        var taskHeaders: [String] {
            guard isTemplate else { return ExcelArchive.taskHeaders }
            if isChinese {
                return [
                    "任务编号（新建可留空）", "任务标题", "任务描述", "状态", "优先级", "所属项目", "父任务",
                    "安排日期", "截止日期", "完成时间"
                ]
            }
            return [
                "Task ID (optional for new)", "Task title", "Task description", "Status", "Priority",
                "Project ID", "Parent Task ID", "Scheduled date", "Due date", "Completed at"
            ]
        }

        var projectValidations: [ExcelValidation] {
            guard isTemplate else { return [] }
            let title = isChinese ? "请选择" : "Choose a value"
            let prompt = isChinese ? "请从下拉列表中选择。" : "Choose from the drop-down list."
            let errorTitle = isChinese ? "值无效" : "Invalid value"
            let error = isChinese ? "请选择列表中的值。" : "Choose a value from the list."
            return [
                ExcelValidation(
                    range: "D2:D1001",
                    source: .values(isChinese
                        ? ["靛蓝", "蓝色", "薄荷绿", "橙色", "玫红", "紫色"]
                        : ["indigo", "blue", "mint", "orange", "rose", "purple"]),
                    promptTitle: title, prompt: prompt, errorTitle: errorTitle, error: error
                ),
                ExcelValidation(
                    range: "E2:E1001",
                    source: .values(isChinese ? ["是", "否"] : ["TRUE", "FALSE"]),
                    promptTitle: title, prompt: prompt, errorTitle: errorTitle, error: error
                )
            ]
        }

        var taskValidations: [ExcelValidation] {
            guard isTemplate else { return [] }
            let title = isChinese ? "请选择" : "Choose a value"
            let prompt = isChinese ? "请从下拉列表中选择。" : "Choose from the drop-down list."
            let referencePrompt = isChinese
                ? "请从已填写的键中选择；留空表示不关联。"
                : "Choose an existing key; leave blank for no relationship."
            let errorTitle = isChinese ? "值无效" : "Invalid value"
            let error = isChinese ? "请选择列表中的值。" : "Choose a value from the list."
            return [
                ExcelValidation(
                    range: "D2:D2001",
                    source: .values(isChinese ? ["待办", "进行中", "已完成"] : ["todo", "inProgress", "done"]),
                    promptTitle: title, prompt: prompt, errorTitle: errorTitle, error: error
                ),
                ExcelValidation(
                    range: "E2:E2001",
                    source: .values(isChinese ? ["无", "低", "中", "高"] : ["none", "low", "medium", "high"]),
                    promptTitle: title, prompt: prompt, errorTitle: errorTitle, error: error
                ),
                ExcelValidation(
                    range: "F2:F2001",
                    source: .namedRange("ProjectKeys"),
                    promptTitle: isChinese ? "选择项目" : "Choose a Project",
                    prompt: referencePrompt, errorTitle: errorTitle, error: error
                ),
                ExcelValidation(
                    range: "G2:G2001",
                    source: .namedRange("TaskKeys"),
                    promptTitle: isChinese ? "选择父任务" : "Choose a Parent Task",
                    prompt: referencePrompt, errorTitle: errorTitle, error: error
                )
            ]
        }

        var instructionRows: [[ExcelCell]] {
            if isChinese {
                return [
                    [.text("工作表"), .text("字段"), .text("说明"), .text("可用值或填写方式")],
                    [.text("开始填写"), .text("任务"), .text("任务工作表与手动新建任务字段一致，包含描述、安排日期、截止日期、状态、优先级、所属项目和父任务"), .text("模板已默认打开任务工作表")],
                    [.text("更新规则"), .text("编号"), .text("新建时编号可以留空，系统会自动生成；现有数据导出会带出编号，保留编号再导入将更新原记录"), .text("编号不为空时必须唯一")],
                    [.text("项目"), .text("project_key"), .text("项目编号；新建可留空，如需被任务引用则必须填写"), .text("可使用易识别文本；导出数据使用 UUID")],
                    [.text("项目"), .text("name"), .text("项目名称；必填"), .text("文本")],
                    [.text("项目"), .text("description"), .text("项目描述"), .text("文本，可留空")],
                    [.text("项目"), .text("accent"), .text("项目主题色；单元格提供下拉选择"), .text("靛蓝、蓝色、薄荷绿、橙色、玫红、紫色")],
                    [.text("项目"), .text("archived"), .text("是否归档；单元格提供下拉选择"), .text("是、否")],
                    [.text("任务"), .text("task_key"), .text("任务编号；新建可留空，如需被子任务引用则必须填写"), .text("可使用易识别文本；导出数据使用 UUID")],
                    [.text("任务"), .text("title"), .text("任务标题；必填"), .text("文本")],
                    [.text("任务"), .text("description"), .text("任务描述"), .text("文本，可留空")],
                    [.text("任务"), .text("status"), .text("任务状态；单元格提供下拉选择"), .text("待办、进行中、已完成")],
                    [.text("任务"), .text("priority"), .text("任务优先级；单元格提供下拉选择"), .text("无、低、中、高")],
                    [.text("任务"), .text("project_key"), .text("所属项目；从项目键下拉列表选择，留空表示收件箱"), .text("项目工作表中的 project_key")],
                    [.text("任务"), .text("parent_task_key"), .text("父任务；从任务键下拉列表选择，留空表示顶级任务"), .text("任务工作表中的 task_key")],
                    [.text("任务"), .text("scheduled_for"), .text("安排日期"), .text("Excel 日期或 yyyy-MM-dd")],
                    [.text("任务"), .text("due_at"), .text("截止日期"), .text("Excel 日期或 yyyy-MM-dd")],
                    [.text("任务"), .text("completed_at"), .text("完成时间；通常可留空，已完成任务会自动补全"), .text("日期时间，可留空")],
                    [.text("说明"), .text("导入规则"), .text("相同键更新现有记录，其他本地数据不会被删除"), .text("模板已经包含父任务和子任务示例")]
                ]
            }
            return [
                [.text("Sheet"), .text("Field"), .text("Description"), .text("Allowed values or input")],
                [.text("Start here"), .text("Tasks"), .text("The Tasks sheet matches manual Task creation, including description, scheduled date, due date, status, priority, Project, and Parent Task"), .text("The template opens on the Tasks sheet")],
                [.text("Update rule"), .text("ID"), .text("Leave the ID blank to create a record automatically. Exports include IDs; keep an exported ID to update that record on import"), .text("Every nonblank ID must be unique")],
                [.text("Projects"), .text("project_key"), .text("Project ID; optional for a new row, but required when a Task references it"), .text("Readable text or an exported UUID")],
                [.text("Projects"), .text("name"), .text("Project name; required"), .text("Text")],
                [.text("Projects"), .text("description"), .text("Project description"), .text("Text; optional")],
                [.text("Projects"), .text("accent"), .text("Project color; use the cell drop-down"), .text("indigo, blue, mint, orange, rose, purple")],
                [.text("Projects"), .text("archived"), .text("Archive state; use the cell drop-down"), .text("TRUE, FALSE")],
                [.text("Tasks"), .text("task_key"), .text("Task ID; optional for a new row, but required when a Subtask references it"), .text("Readable text or an exported UUID")],
                [.text("Tasks"), .text("title"), .text("Task title; required"), .text("Text")],
                [.text("Tasks"), .text("description"), .text("Task description"), .text("Text; optional")],
                [.text("Tasks"), .text("status"), .text("Task status; use the cell drop-down"), .text("todo, inProgress, done")],
                [.text("Tasks"), .text("priority"), .text("Task priority; use the cell drop-down"), .text("none, low, medium, high")],
                [.text("Tasks"), .text("project_key"), .text("Project relationship; choose a Project key or leave blank for Inbox"), .text("project_key from Projects")],
                [.text("Tasks"), .text("parent_task_key"), .text("Parent Task relationship; choose a Task key or leave blank for a root Task"), .text("task_key from Tasks")],
                [.text("Tasks"), .text("scheduled_for"), .text("Scheduled date"), .text("Excel date or yyyy-MM-dd")],
                [.text("Tasks"), .text("due_at"), .text("Due date"), .text("Excel date or yyyy-MM-dd")],
                [.text("Tasks"), .text("completed_at"), .text("Completion timestamp; usually blank and filled for done Tasks"), .text("Date and time; optional")],
                [.text("Note"), .text("Import behavior"), .text("Matching keys update records; other local data is kept"), .text("Parent and Subtask examples are included")]
            ]
        }
    }

    static func make(
        projectRows: [[ExcelCell]],
        taskRows: [[ExcelCell]],
        templateLanguage: AppLanguage?
    ) throws -> Data {
        let layout = TemplateLayout(language: templateLanguage)
        let archive = try Archive(accessMode: .create)
        let files: [(String, String)] = [
            ("[Content_Types].xml", contentTypes),
            ("_rels/.rels", rootRelationships),
            ("docProps/app.xml", appProperties),
            ("docProps/core.xml", coreProperties),
            ("xl/workbook.xml", workbook(layout: layout)),
            ("xl/_rels/workbook.xml.rels", workbookRelationships),
            ("xl/styles.xml", styles),
            ("xl/worksheets/sheet1.xml", worksheet(
                headers: layout.projectHeaders,
                rows: projectRows,
                widths: Array([30, 26, 42, 18, 20, 22, 22].prefix(layout.projectHeaders.count)),
                validations: layout.projectValidations,
                isSelected: false
            )),
            ("xl/worksheets/sheet2.xml", worksheet(
                headers: layout.taskHeaders,
                rows: taskRows,
                widths: Array([32, 30, 42, 18, 18, 28, 30, 24, 20, 24, 22, 22].prefix(layout.taskHeaders.count)),
                validations: layout.taskValidations,
                isSelected: layout.isTemplate
            )),
            ("xl/worksheets/sheet3.xml", instructions(layout: layout))
        ]

        for (path, contents) in files {
            let data = Data(contents.utf8)
            try archive.addEntry(
                with: path,
                type: .file,
                uncompressedSize: Int64(data.count),
                compressionMethod: .deflate
            ) { position, size in
                let start = Int(position)
                return data.subdata(in: start..<(start + size))
            }
        }
        guard let data = archive.data else { throw ExcelWorkbookError.malformedWorkbook }
        return data
    }

    private static func worksheet(
        headers: [String],
        rows: [[ExcelCell]],
        widths: [Double],
        validations: [ExcelValidation] = [],
        isSelected: Bool = false
    ) -> String {
        let columnXML = widths.enumerated().map { index, width in
            "<col min=\"\(index + 1)\" max=\"\(index + 1)\" width=\"\(width)\" customWidth=\"1\"/>"
        }.joined()
        let headerXML = headers.enumerated().map { index, header in
            cellXML(.text(header), column: index, row: 1, style: 1)
        }.joined()
        let bodyXML = rows.enumerated().map { rowIndex, row in
            let cells = headers.indices.map { column in
                cellXML(column < row.count ? row[column] : .blank, column: column, row: rowIndex + 2, style: nil)
            }.joined()
            return "<row r=\"\(rowIndex + 2)\" ht=\"22\" customHeight=\"1\">\(cells)</row>"
        }.joined()
        let lastColumn = columnName(headers.count - 1)
        let validationXML = dataValidationsXML(validations)
        let selectedAttribute = isSelected ? " tabSelected=\"1\"" : ""

        return xmlHeader + """
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetViews><sheetView\(selectedAttribute) workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>
          <sheetFormatPr defaultRowHeight="20"/>
          <cols>\(columnXML)</cols>
          <sheetData><row r="1" ht="26" customHeight="1">\(headerXML)</row>\(bodyXML)</sheetData>
          <autoFilter ref="A1:\(lastColumn)\(max(rows.count + 1, 1))"/>
          \(validationXML)
        </worksheet>
        """
    }

    private static func instructions(layout: TemplateLayout) -> String {
        worksheet(
            headers: [layout.guideTitle, "", "", ""],
            rows: layout.instructionRows,
            widths: [20, 24, 66, 38]
        )
    }

    private static func dataValidationsXML(_ validations: [ExcelValidation]) -> String {
        guard !validations.isEmpty else { return "" }
        let entries = validations.map { validation in
            let formula: String
            switch validation.source {
            case let .values(values): formula = escape("\"\(values.joined(separator: ","))\"")
            case let .namedRange(name): formula = escape(name)
            }
            return """
            <dataValidation type="list" allowBlank="1" showInputMessage="1" showErrorMessage="1" errorStyle="stop" sqref="\(validation.range)" promptTitle="\(escape(validation.promptTitle))" prompt="\(escape(validation.prompt))" errorTitle="\(escape(validation.errorTitle))" error="\(escape(validation.error))"><formula1>\(formula)</formula1></dataValidation>
            """
        }.joined()
        return "<dataValidations count=\"\(validations.count)\">\(entries)</dataValidations>"
    }

    private static func cellXML(_ cell: ExcelCell, column: Int, row: Int, style: Int?) -> String {
        let reference = "\(columnName(column))\(row)"
        let styleAttribute: String
        switch cell {
        case .date: styleAttribute = " s=\"2\""
        case .dateTime: styleAttribute = " s=\"3\""
        default: styleAttribute = style.map { " s=\"\($0)\"" } ?? ""
        }

        switch cell {
        case let .text(value):
            return "<c r=\"\(reference)\" t=\"inlineStr\"\(styleAttribute)><is><t xml:space=\"preserve\">\(escape(value))</t></is></c>"
        case let .bool(value):
            return "<c r=\"\(reference)\" t=\"b\"\(styleAttribute)><v>\(value ? 1 : 0)</v></c>"
        case let .date(date):
            return "<c r=\"\(reference)\"\(styleAttribute)><v>\(excelSerial(for: date))</v></c>"
        case let .dateTime(date):
            return "<c r=\"\(reference)\"\(styleAttribute)><v>\(excelSerial(for: date))</v></c>"
        case .blank:
            return "<c r=\"\(reference)\"\(styleAttribute)/>"
        }
    }

    private static func excelSerial(for date: Date) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let epoch = calendar.date(from: DateComponents(year: 1899, month: 12, day: 30))!
        return date.timeIntervalSince(epoch) / 86_400
    }

    private static func columnName(_ zeroBasedIndex: Int) -> String {
        var index = zeroBasedIndex + 1
        var name = ""
        while index > 0 {
            index -= 1
            name = String(UnicodeScalar(65 + index % 26)!) + name
            index /= 26
        }
        return name
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static let xmlHeader = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
    private static let contentTypes = xmlHeader + """
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
      <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
      <Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
      <Override PartName="/xl/worksheets/sheet3.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
      <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
      <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
      <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
    </Types>
    """
    private static let rootRelationships = xmlHeader + """
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
      <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
      <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
    </Relationships>
    """
    private static func workbook(layout: TemplateLayout) -> String {
        let definedNames: String
        if layout.isTemplate {
            let projectSheet = layout.projectSheet.replacingOccurrences(of: "'", with: "''")
            let taskSheet = layout.taskSheet.replacingOccurrences(of: "'", with: "''")
            definedNames = """
              <definedNames>
                <definedName name="ProjectKeys">OFFSET('\(escape(projectSheet))'!$A$2,0,0,MAX(1,COUNTA('\(escape(projectSheet))'!$A:$A)-1),1)</definedName>
                <definedName name="TaskKeys">OFFSET('\(escape(taskSheet))'!$A$2,0,0,MAX(1,COUNTA('\(escape(taskSheet))'!$A:$A)-1),1)</definedName>
              </definedNames>
            """
        } else {
            definedNames = ""
        }

        let sheets: String
        if layout.isTemplate {
            // Keep the physical worksheet paths stable for backward-compatible decoding,
            // while presenting the complete Task input sheet first to the user.
            sheets = """
                <sheet name="\(escape(layout.taskSheet))" sheetId="2" r:id="rId2"/>
                <sheet name="\(escape(layout.projectSheet))" sheetId="1" r:id="rId1"/>
                <sheet name="\(escape(layout.instructionSheet))" sheetId="3" r:id="rId3"/>
            """
        } else {
            sheets = """
                <sheet name="\(escape(layout.projectSheet))" sheetId="1" r:id="rId1"/>
                <sheet name="\(escape(layout.taskSheet))" sheetId="2" r:id="rId2"/>
                <sheet name="\(escape(layout.instructionSheet))" sheetId="3" r:id="rId3"/>
            """
        }

        return xmlHeader + """
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <bookViews><workbookView activeTab="0"/></bookViews>
          <sheets>\(sheets)</sheets>
          \(definedNames)
        </workbook>
        """
    }
    private static let workbookRelationships = xmlHeader + """
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
      <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
      <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet3.xml"/>
      <Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
    </Relationships>
    """
    private static let styles = xmlHeader + """
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <numFmts count="2"><numFmt numFmtId="164" formatCode="yyyy-mm-dd"/><numFmt numFmtId="165" formatCode="yyyy-mm-dd hh:mm"/></numFmts>
      <fonts count="2"><font><sz val="11"/><name val="Aptos"/></font><font><b/><color rgb="FFFFFFFF"/><sz val="11"/><name val="Aptos"/></font></fonts>
      <fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF4F46E5"/><bgColor indexed="64"/></patternFill></fill></fills>
      <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
      <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
      <cellXfs count="4"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/><xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/><xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></cellXfs>
      <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
    </styleSheet>
    """
    private static let appProperties = xmlHeader + """
    <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"><Application>VibePM</Application></Properties>
    """
    private static let coreProperties = xmlHeader + """
    <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:creator>VibePM</dc:creator><dc:title>VibePM Data</dc:title></cp:coreProperties>
    """
}

private extension Archive {
    func entryData(at path: String) throws -> Data {
        guard let entry = self[path] else {
            let sheet = path.contains("sheet1") ? "Projects" : "Tasks"
            throw ExcelWorkbookError.missingWorksheet(sheet)
        }
        var data = Data()
        _ = try extract(entry) { data.append($0) }
        return data
    }

    func sharedStrings() throws -> [String] {
        guard let entry = self["xl/sharedStrings.xml"] else { return [] }
        var data = Data()
        _ = try extract(entry) { data.append($0) }
        let delegate = SharedStringsParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { throw ExcelWorkbookError.malformedWorkbook }
        return delegate.strings
    }

    func table(at path: String, sharedStrings: [String]) throws -> [[String]] {
        let delegate = WorksheetParser(sharedStrings: sharedStrings)
        let parser = XMLParser(data: try entryData(at: path))
        parser.delegate = delegate
        guard parser.parse() else { throw ExcelWorkbookError.malformedWorkbook }
        return delegate.rows
    }
}

private extension Array where Element == [String] {
    var canonicalHeaders: [String] {
        guard let headerRow = first else { return [] }
        return headerRow.map(Self.canonicalHeader)
    }

    func records(sheet: String, requiredHeaders: [String]) throws -> [[String: String]] {
        guard let headerRow = first else { throw ExcelWorkbookError.emptyWorksheet(sheet) }
        let headers = headerRow.map(Self.canonicalHeader)
        for requiredHeader in requiredHeaders where !headers.contains(requiredHeader) {
            throw ExcelWorkbookError.missingColumn(sheet: sheet, column: requiredHeader)
        }

        return dropFirst().compactMap { row in
            let values = Dictionary(uniqueKeysWithValues: headers.enumerated().map { index, header in
                (header, index < row.count ? row[index].trimmingCharacters(in: .whitespacesAndNewlines) : "")
            })
            return values.values.allSatisfy(\.isEmpty) ? nil : values
        }
    }

    private static func canonicalHeader(_ header: String) -> String {
        let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let aliases = [
            "项目键": "project_key", "项目编号": "project_key", "项目编号（新建可留空）": "project_key",
            "project id": "project_key", "project id (optional for new)": "project_key",
            "项目名称": "name", "project name": "name",
            "项目描述": "description", "project description": "description",
            "主题色": "accent", "accent": "accent", "是否归档": "archived", "archived": "archived",
            "任务键": "task_key", "任务编号": "task_key", "任务编号（新建可留空）": "task_key",
            "task id": "task_key", "task id (optional for new)": "task_key",
            "任务标题": "title", "task title": "title",
            "任务描述": "description", "task description": "description",
            "状态": "status", "status": "status", "优先级": "priority", "priority": "priority",
            "所属项目": "project_key", "所属项目键": "project_key",
            "父任务": "parent_task_key", "父任务键": "parent_task_key",
            "parent task id": "parent_task_key", "安排日期": "scheduled_for", "scheduled date": "scheduled_for",
            "截止日期": "due_at", "due date": "due_at", "完成时间": "completed_at", "completed at": "completed_at",
            "创建时间": "created_at", "更新时间": "updated_at"
        ]
        if let alias = aliases[trimmed] { return alias }
        return trimmed.split(separator: "/", omittingEmptySubsequences: true).last
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? trimmed
    }
}

private extension Dictionary where Key == String, Value == String {
    func required(_ column: String, sheet: String, row: Int) throws -> String {
        let value = self[column]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else { throw ExcelWorkbookError.missingValue(sheet: sheet, row: row, column: column) }
        return value
    }
}

private final class WorksheetParser: NSObject, XMLParserDelegate {
    let sharedStrings: [String]
    var rows: [[String]] = []
    private var rowValues: [Int: String] = [:]
    private var currentColumn = 0
    private var currentType = ""
    private var currentValue = ""
    private var captureValue = false

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "row": rowValues = [:]
        case "c":
            currentColumn = Self.columnIndex(from: attributeDict["r"] ?? "A1")
            currentType = attributeDict["t"] ?? ""
            currentValue = ""
        case "v", "t": captureValue = true
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if captureValue { currentValue += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "v", "t": captureValue = false
        case "c":
            if currentType == "s", let index = Int(currentValue), sharedStrings.indices.contains(index) {
                rowValues[currentColumn] = sharedStrings[index]
            } else if currentType == "b" {
                rowValues[currentColumn] = currentValue == "1" ? "TRUE" : "FALSE"
            } else {
                rowValues[currentColumn] = currentValue
            }
        case "row":
            let count = (rowValues.keys.max() ?? -1) + 1
            rows.append((0..<count).map { rowValues[$0] ?? "" })
        default: break
        }
    }

    private static func columnIndex(from reference: String) -> Int {
        reference.prefix { $0.isLetter }.reduce(0) { result, character in
            result * 26 + Int(character.asciiValue! - 64)
        } - 1
    }
}

private final class SharedStringsParser: NSObject, XMLParserDelegate {
    var strings: [String] = []
    private var current = ""
    private var captureText = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "si" { current = "" }
        if elementName == "t" { captureText = true }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if captureText { current += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "t" { captureText = false }
        if elementName == "si" { strings.append(current) }
    }
}
