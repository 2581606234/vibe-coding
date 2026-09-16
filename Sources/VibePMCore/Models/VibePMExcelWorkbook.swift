import CryptoKit
import Foundation
import SwiftData
import ZIPFoundation

public struct VibePMExcelWorkbook: Sendable {
    public let projects: [ProjectRecord]
    public let tasks: [TaskRecord]

    public init(projects: [Project], tasks: [ProjectTask]) {
        self.projects = projects.map(ProjectRecord.init)
        self.tasks = tasks.map(TaskRecord.init)
    }

    private init(projects: [ProjectRecord], tasks: [TaskRecord]) {
        self.projects = projects
        self.tasks = tasks
    }

    public func encoded() throws -> Data {
        try ExcelArchive.make(
            projectRows: projects.map(Self.projectRow),
            taskRows: tasks.map(Self.taskRow),
            includeExamples: false
        )
    }

    public static func templateData() throws -> Data {
        try ExcelArchive.make(
            projectRows: [[
                .text("project-example"),
                .text("Website launch"),
                .text("Prepare and publish the new website"),
                .text("indigo"),
                .bool(false),
                .blank,
                .blank
            ]],
            taskRows: [
                [
                    .text("task-parent-example"),
                    .text("Launch website"),
                    .text("Coordinate the final launch"),
                    .text("inProgress"),
                    .text("high"),
                    .text("project-example"),
                    .blank,
                    .date(.now),
                    .date(Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now),
                    .blank,
                    .blank,
                    .blank
                ],
                [
                    .text("task-child-example"),
                    .text("Review homepage copy"),
                    .text(""),
                    .text("todo"),
                    .text("medium"),
                    .text("project-example"),
                    .text("task-parent-example"),
                    .date(.now),
                    .date(Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now),
                    .blank,
                    .blank,
                    .blank
                ]
            ],
            includeExamples: true
        )
    }

    public static func decoded(from data: Data) throws -> Self {
        let archive = try Archive(data: data, accessMode: .read)
        let sharedStrings = try archive.sharedStrings()
        let projectTable = try archive.table(at: "xl/worksheets/sheet1.xml", sharedStrings: sharedStrings)
        let taskTable = try archive.table(at: "xl/worksheets/sheet2.xml", sharedStrings: sharedStrings)

        let projectRows = try projectTable.records(
            sheet: "Projects",
            requiredHeaders: ExcelArchive.projectHeaders
        )
        let taskRows = try taskTable.records(
            sheet: "Tasks",
            requiredHeaders: ExcelArchive.taskHeaders
        )

        var projectIDs: [String: UUID] = [:]
        var projectRecords: [ProjectRecord] = []
        for (index, row) in projectRows.enumerated() {
            let rowNumber = index + 2
            let key = try row.required("project_key", sheet: "Projects", row: rowNumber)
            guard projectIDs[key] == nil else {
                throw ExcelWorkbookError.duplicateKey(sheet: "Projects", key: key)
            }
            let id = stableID(namespace: "project", key: key)
            projectIDs[key] = id
            let now = Date.now
            projectRecords.append(ProjectRecord(
                id: id,
                name: try row.required("name", sheet: "Projects", row: rowNumber),
                projectDescription: row["description"] ?? "",
                createdAt: try parseDate(row["created_at"], sheet: "Projects", row: rowNumber, column: "created_at") ?? now,
                updatedAt: try parseDate(row["updated_at"], sheet: "Projects", row: rowNumber, column: "updated_at") ?? now,
                isArchived: try parseBool(row["archived"], sheet: "Projects", row: rowNumber, column: "archived"),
                accent: try parseAccent(row["accent"], row: rowNumber)
            ))
        }

        var taskIDs: [String: UUID] = [:]
        for (index, row) in taskRows.enumerated() {
            let key = try row.required("task_key", sheet: "Tasks", row: index + 2)
            guard taskIDs[key] == nil else {
                throw ExcelWorkbookError.duplicateKey(sheet: "Tasks", key: key)
            }
            taskIDs[key] = stableID(namespace: "task", key: key)
        }

        var taskRecords: [TaskRecord] = []
        for (index, row) in taskRows.enumerated() {
            let rowNumber = index + 2
            let key = try row.required("task_key", sheet: "Tasks", row: rowNumber)
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
                id: taskIDs[key]!,
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
                updatedAt: try parseDate(row["updated_at"], sheet: "Tasks", row: rowNumber, column: "updated_at") ?? now
            ))
        }

        return Self(projects: projectRecords, tasks: taskRecords)
    }

    @MainActor
    public func restore(into context: ModelContext) throws {
        let backup = VibePMBackup(
            schemaVersion: VibePMBackup.currentSchemaVersion,
            exportedAt: .now,
            projects: projects,
            tasks: tasks
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
    static let taskHeaders = [
        "task_key", "title", "description", "status", "priority",
        "project_key", "parent_task_key", "scheduled_for", "due_at",
        "completed_at", "created_at", "updated_at"
    ]

    static func make(
        projectRows: [[ExcelCell]],
        taskRows: [[ExcelCell]],
        includeExamples: Bool
    ) throws -> Data {
        let archive = try Archive(accessMode: .create)
        let files: [(String, String)] = [
            ("[Content_Types].xml", contentTypes),
            ("_rels/.rels", rootRelationships),
            ("docProps/app.xml", appProperties),
            ("docProps/core.xml", coreProperties),
            ("xl/workbook.xml", workbook),
            ("xl/_rels/workbook.xml.rels", workbookRelationships),
            ("xl/styles.xml", styles),
            ("xl/worksheets/sheet1.xml", worksheet(headers: projectHeaders, rows: projectRows, widths: [24, 24, 42, 14, 12, 20, 20])),
            ("xl/worksheets/sheet2.xml", worksheet(headers: taskHeaders, rows: taskRows, widths: [24, 28, 42, 16, 14, 24, 24, 16, 16, 20, 20, 20])),
            ("xl/worksheets/sheet3.xml", instructions(includeExamples: includeExamples))
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

    private static func worksheet(headers: [String], rows: [[ExcelCell]], widths: [Double]) -> String {
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

        return xmlHeader + """
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>
          <sheetFormatPr defaultRowHeight="20"/>
          <cols>\(columnXML)</cols>
          <sheetData><row r="1" ht="26" customHeight="1">\(headerXML)</row>\(bodyXML)</sheetData>
          <autoFilter ref="A1:\(lastColumn)\(max(rows.count + 1, 1))"/>
        </worksheet>
        """
    }

    private static func instructions(includeExamples: Bool) -> String {
        let rows: [[ExcelCell]] = [
            [.text("Sheet / 工作表"), .text("Field / 字段"), .text("Description / 说明"), .text("Allowed values / 可用值")],
            [.text("Projects"), .text("project_key"), .text("Unique stable key; used by Tasks / 唯一稳定键，供任务引用"), .text("Text; UUID is recommended")],
            [.text("Projects"), .text("accent"), .text("Project color / 项目颜色"), .text("indigo, blue, mint, orange, rose, purple")],
            [.text("Projects"), .text("archived"), .text("Archive state / 是否归档"), .text("TRUE or FALSE")],
            [.text("Tasks"), .text("task_key"), .text("Unique stable key / 唯一稳定键"), .text("Text; UUID is recommended")],
            [.text("Tasks"), .text("status"), .text("Task status / 任务状态"), .text("todo, inProgress, done")],
            [.text("Tasks"), .text("priority"), .text("Task priority / 任务优先级"), .text("none, low, medium, high")],
            [.text("Tasks"), .text("project_key"), .text("Project reference; blank means Inbox / 项目引用，留空表示收件箱"), .text("A key from Projects")],
            [.text("Tasks"), .text("parent_task_key"), .text("Parent Task reference / 父任务引用"), .text("A key from Tasks or blank")],
            [.text("Tasks"), .text("scheduled_for, due_at"), .text("Excel date values / Excel 日期值"), .text("Date or yyyy-MM-dd")],
            [.text("All"), .text("*_at"), .text("Audit timestamps; optional in templates / 审计时间，模板中可留空"), .text("Date and time")],
            [.text("Note"), .text("Import behavior"), .text("Matching keys update; other local data stays / 相同键更新，其他数据保留"), .text(includeExamples ? "Examples included / 已含示例" : "Exported data / 导出数据")]
        ]
        return worksheet(headers: ["VibePM Excel Import Guide", "", "", ""], rows: rows, widths: [20, 24, 66, 38])
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
    private static let workbook = xmlHeader + """
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
      <sheets>
        <sheet name="Projects" sheetId="1" r:id="rId1"/>
        <sheet name="Tasks" sheetId="2" r:id="rId2"/>
        <sheet name="Instructions" sheetId="3" r:id="rId3"/>
      </sheets>
    </workbook>
    """
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
    func records(sheet: String, requiredHeaders: [String]) throws -> [[String: String]] {
        guard let headerRow = first else { throw ExcelWorkbookError.emptyWorksheet(sheet) }
        let headers = headerRow.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
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
