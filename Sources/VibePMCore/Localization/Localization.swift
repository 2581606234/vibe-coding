import Foundation

public enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case simplifiedChinese
    case english

    public static let userDefaultsKey = "appLanguage"

    public var id: String { rawValue }

    public func resolved(systemLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        return systemLanguages.first?.lowercased().hasPrefix("zh") == true
            ? .simplifiedChinese
            : .english
    }

    public func locale(systemLanguages: [String] = Locale.preferredLanguages) -> Locale {
        Locale(identifier: resolved(systemLanguages: systemLanguages) == .simplifiedChinese ? "zh-Hans" : "en")
    }
}

public enum L10n {
    private static let simplifiedChinese: [String: String] = [
        "Follow System": "跟随系统",
        "Simplified Chinese": "简体中文",
        "English": "English",
        "General": "通用",
        "Language": "语言",
        "App language": "应用语言",
        "Language changes apply immediately.": "语言切换会立即生效。",
        "Search Tasks": "搜索任务",
        "Focus": "聚焦",
        "Inbox": "收件箱",
        "Today": "今天",
        "Projects": "项目",
        "Project": "项目",
        "New Project": "新建项目",
        "Edit Project": "编辑项目",
        "Delete Project": "删除项目",
        "Move to Trash": "移到废纸篓",
        "Trash": "废纸篓",
        "Empty Trash": "清空废纸篓",
        "Empty Trash?": "清空废纸篓？",
        "All Projects and Tasks in Trash will be permanently deleted. This cannot be undone.": "废纸篓中的所有项目和任务将被永久删除，且无法撤销。",
        "Undo": "撤销",
        "Moved \"%@\" to Trash.": "已将“%@”移到废纸篓。",
        "Moved %d Tasks to Trash.": "已将 %d 个任务移到废纸篓。",
        "Moved to Trash: %@": "进入废纸篓：%@",
        "Move \"%@\" to Trash?": "将“%@”移到废纸篓？",
        "Move %d Tasks to Trash?": "将 %d 个任务移到废纸篓？",
        "Move %d Tasks to Trash": "将 %d 个任务移到废纸篓",
        "The Project and its Tasks can be restored from Trash for 30 days.": "项目及其任务可在 30 天内从废纸篓恢复。",
        "This Task and its Subtasks can be restored from Trash for 30 days.": "此任务及其子任务可在 30 天内从废纸篓恢复。",
        "The selected Tasks and their Subtasks can be restored from Trash for 30 days.": "所选任务及其子任务可在 30 天内从废纸篓恢复。",
        "Trash is Empty": "废纸篓为空",
        "Deleted Projects and Tasks stay here for 30 days.": "已删除的项目和任务会在这里保留 30 天。",
        "Project · %d Tasks": "项目 · %d 个任务",
        "Delete Permanently": "永久删除",
        "Delete Permanently?": "永久删除？",
        "This data will be permanently deleted and cannot be restored.": "这些数据将被永久删除且无法恢复。",
        "Unable to save changes.": "无法保存更改。",
        "Unable to save changes: %@": "无法保存更改：%@",
        "Unable to create a recovery point: %@": "无法创建恢复点：%@",
        "Archive": "归档",
        "Capture now. Organize when you are ready.": "先快速记录，稍后再整理。",
        "A calm view of what needs your attention.": "从容查看今天需要关注的事项。",
        "Move this Project toward its outcome.": "推动项目一步步达成目标。",
        "New Task": "新建任务",
        "Edit Task": "编辑任务",
        "Delete Task": "删除任务",
        "Select Task": "选择任务",
        "Deselect Task": "取消选择任务",
        "Select Tasks": "选择任务",
        "Done Selecting": "完成选择",
        "Select All": "全选",
        "Deselect All": "取消全选",
        "%d selected": "已选择 %d 个任务",
        "Delete": "删除",
        "Delete %d Tasks": "删除 %d 个任务",
        "Delete \"%@\"?": "删除“%@”？",
        "Delete %d Tasks?": "删除 %d 个任务？",
        "This Task and all of its Subtasks will be permanently deleted. This cannot be undone.": "此任务及其所有子任务将被永久删除，且无法撤销。",
        "The selected Tasks and all of their Subtasks will be permanently deleted. This cannot be undone.": "所选任务及其所有子任务将被永久删除，且无法撤销。",
        "Make progress feel lighter": "让推进工作更轻松",
        "Archive Project": "归档项目",
        "Project actions": "项目操作",
        "Archive \"%@\"?": "归档“%@”？",
        "The Project and its Tasks will move to Archive. You can restore them later.": "项目及其任务将移入归档，之后仍可恢复。",
        "The Project and all of its Tasks and Subtasks will be permanently deleted. This cannot be undone.": "项目及其全部任务和子任务将被永久删除，且无法撤销。",
        "View": "视图",
        "List": "列表",
        "Board": "看板",
        "Gantt": "甘特图",
        "Task": "任务",
        "No dates": "未安排日期",
        "Not set": "未设置",
        "Clear Filters": "清除筛选",
        "Priority": "优先级",
        "Any Priority": "全部优先级",
        "Status": "状态",
        "Any Status": "全部状态",
        "Filter": "筛选",
        "Filtered": "已筛选",
        "Sort Tasks": "任务排序",
        "Created: Newest First": "创建时间：最新优先",
        "Created: Oldest First": "创建时间：最早优先",
        "Priority: High to Low": "优先级：从高到低",
        "Priority: Low to High": "优先级：从低到高",
        "Schedule: Earliest First": "安排日期：从早到晚",
        "Schedule: Latest First": "安排日期：从晚到早",
        "Due: Earliest First": "截止日期：从早到晚",
        "Due: Latest First": "截止日期：从晚到早",
        "Nothing here yet": "这里还没有内容",
        "Capture the next concrete action when you are ready.": "准备好后，记录下一项明确行动。",
        "Create a Task": "创建任务",
        "Subtask": "子任务",
        "Reopen Task": "重新打开任务",
        "Complete Task": "完成任务",
        "No Tasks": "暂无任务",
        "To Do": "待办",
        "In Progress": "进行中",
        "Done": "已完成",
        "None": "无",
        "Low": "低",
        "Medium": "中",
        "High": "高",
        "Task details": "任务详情",
        "Title": "标题",
        "Description": "描述",
        "Organization": "组织",
        "Parent Task": "父任务",
        "Planning": "计划",
        "Schedule": "安排日期",
        "Due date": "截止日期",
        "Make the next action clear and achievable.": "让下一步行动清晰且可执行。",
        "Cancel": "取消",
        "Save": "保存",
        "Project details": "项目详情",
        "Name": "名称",
        "Accent": "主题色",
        "Give this Project a clear outcome.": "为这个项目设定清晰成果。",
        "Indigo": "靛蓝",
        "Blue": "蓝色",
        "Mint": "薄荷绿",
        "Orange": "橙色",
        "Rose": "玫红",
        "Purple": "紫色",
        "Projects stay here with their Tasks until you restore them.": "已归档项目及其任务会保留在这里，直到你恢复它们。",
        "No Archived Projects": "暂无归档项目",
        "Projects you archive will appear here.": "你归档的项目会显示在这里。",
        "Restore": "恢复",
        "%d Tasks": "%d 个任务",
        "Data": "数据",
        "Reminders": "提醒",
        "OK": "好",
        "Your data": "你的数据",
        "Tasks": "任务",
        "Backup": "备份",
        "Excel import and export": "Excel 导入与导出",
        "Export Excel workbook": "导出 Excel 工作簿",
        "Exports Projects and Tasks as editable Excel worksheets.": "将项目和任务导出为可编辑的 Excel 工作表。",
        "Import Excel workbook": "导入 Excel 工作簿",
        "Use the template for field names, allowed values, and examples.": "可先下载模板，查看字段名称、可用值和填写示例。",
        "Template…": "下载模板…",
        "Excel workbook exported successfully.": "Excel 工作簿导出成功。",
        "Excel import template saved successfully.": "Excel 导入模板保存成功。",
        "Recovery points": "恢复点",
        "Last automatic recovery point": "最近自动恢复点",
        "Not yet created": "尚未创建",
        "Protect and restore local data": "保护和恢复本地数据",
        "VibePM creates one local recovery point per day and keeps the latest 14.": "VibePM 每天创建一个本地恢复点，并保留最近 14 个。",
        "Create Now": "立即创建",
        "Restore…": "恢复…",
        "Recovery point created successfully.": "恢复点创建成功。",
        "Recovery point exported successfully.": "恢复点导出成功。",
        "Recovery point restored successfully.": "恢复点恢复成功。",
        "Restore failed: %@": "恢复失败：%@",
        "Import Preview": "导入预览",
        "Review changes before writing them to VibePM.": "写入 VibePM 前，请先确认本次变更。",
        "Create": "新增",
        "Update": "更新",
        "A recovery point will be created automatically before import.": "导入前会自动创建一个恢复点。",
        "Import": "导入",
        "Export JSON backup": "导出 JSON 备份",
        "Includes every Project, Task, Subtask, Status, and date.": "包含所有项目、任务、子任务、状态和日期。",
        "Export…": "导出…",
        "Import JSON backup": "导入 JSON 备份",
        "Matching records are updated; other local data is preserved.": "匹配记录会被更新，其他本地数据保持不变。",
        "Import…": "导入…",
        "Due dates": "截止日期",
        "Local Task reminders": "本地任务提醒",
        "VibePM schedules a native notification for incomplete Tasks with a future due date. No Task data leaves this Mac.": "VibePM 会为尚未完成且设置了未来截止日期的任务安排系统通知。任务数据不会离开这台 Mac。",
        "Refresh scheduled reminders": "刷新已安排的提醒",
        "Backup exported successfully.": "备份导出成功。",
        "Export failed: %@": "导出失败：%@",
        "Reminders refreshed.": "提醒已刷新。",
        "Unable to schedule reminders: %@": "无法安排提醒：%@",
        "Notification permission was not granted.": "未获得通知权限。",
        "Unable to enable reminders: %@": "无法启用提醒：%@",
        "Imported %d Projects and %d Tasks.": "已导入 %d 个项目和 %d 个任务。",
        "Import failed: %@": "导入失败：%@",
        "Task due": "任务到期",
        "Set date": "设置日期",
        "Clear date": "清除日期",
        "Choose date": "选择日期",
        "Previous month": "上个月",
        "Next month": "下个月",
        "Close": "关闭"
    ]

    public static func selectedLanguage(defaults: UserDefaults = .standard) -> AppLanguage {
        AppLanguage(rawValue: defaults.string(forKey: AppLanguage.userDefaultsKey) ?? "") ?? .system
    }

    public static func text(
        _ key: String,
        language: AppLanguage? = nil,
        systemLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        let language = (language ?? selectedLanguage()).resolved(systemLanguages: systemLanguages)
        guard language == .simplifiedChinese else { return key }
        return simplifiedChinese[key] ?? key
    }

    public static func format(
        _ key: String,
        language: AppLanguage? = nil,
        systemLanguages: [String] = Locale.preferredLanguages,
        arguments: [CVarArg]
    ) -> String {
        let selected = language ?? selectedLanguage()
        return String(
            format: text(key, language: selected, systemLanguages: systemLanguages),
            locale: selected.locale(systemLanguages: systemLanguages),
            arguments: arguments
        )
    }
}
