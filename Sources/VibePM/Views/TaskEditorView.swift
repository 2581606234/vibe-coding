import SwiftUI
import VibePMCore

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let heading: String
    let projects: [Project]
    let parentTasks: [ProjectTask]
    let onSave: (TaskDraft) -> Void

    @State private var draft: TaskDraft

    init(
        heading: String,
        draft: TaskDraft,
        projects: [Project],
        parentTasks: [ProjectTask],
        onSave: @escaping (TaskDraft) -> Void
    ) {
        self.heading = heading
        self.projects = projects
        self.parentTasks = parentTasks
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader
            Divider()

            Form {
                Section(L10n.text("Task details")) {
                    TextField(L10n.text("Title"), text: $draft.title)
                        .textFieldStyle(.roundedBorder)

                    TextField(L10n.text("Description"), text: $draft.taskDescription, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section(L10n.text("Planning")) {
                    OptionalDateField(
                        title: L10n.text("Schedule"),
                        date: $draft.scheduledFor
                    )

                    OptionalDateField(
                        title: L10n.text("Due date"),
                        date: $draft.dueAt,
                        minimumDate: draft.scheduledFor
                    )
                }

                Section(L10n.text("Organization")) {
                    Picker(L10n.text("Status"), selection: $draft.status) {
                        ForEach(TaskStatus.allCases, id: \.self) { status in
                            Text(L10n.text(status.title)).tag(status)
                        }
                    }

                    Picker(L10n.text("Priority"), selection: $draft.priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Label(L10n.text(priority.title), systemImage: "flag.fill")
                                .foregroundStyle(priority.color)
                                .tag(priority)
                        }
                    }

                    Picker(L10n.text("Project"), selection: $draft.projectID) {
                        Label(L10n.text("Inbox"), systemImage: "tray").tag(UUID?.none)
                        ForEach(projects) { project in
                            Label(project.name, systemImage: "folder.fill")
                                .tag(Optional(project.id))
                        }
                    }

                    Picker(L10n.text("Parent Task"), selection: $draft.parentTaskID) {
                        Text(L10n.text("None")).tag(UUID?.none)
                        ForEach(eligibleParentTasks) { task in
                            Text(task.title).tag(Optional(task.id))
                        }
                    }
                }

            }
            .formStyle(.grouped)

            Divider()
            editorActions
        }
        .frame(width: 580, height: 560)
        .onChange(of: draft.projectID) {
            if let parentTaskID = draft.parentTaskID,
               !eligibleParentTasks.contains(where: { $0.id == parentTaskID }) {
                draft.parentTaskID = nil
            }
        }
        .onChange(of: draft.scheduledFor) {
            if let scheduledFor = draft.scheduledFor,
               let dueAt = draft.dueAt,
               dueAt < scheduledFor {
                draft.dueAt = scheduledFor
            }
        }
    }

    private var eligibleParentTasks: [ProjectTask] {
        parentTasks.filter { $0.projectID == draft.projectID }
    }

    private var editorHeader: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(VibeTheme.brandGradient)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.body.bold())
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(heading)
                    .font(.title2.weight(.semibold))
                Text(L10n.text("Make the next action clear and achievable."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    private var editorActions: some View {
        HStack {
            Spacer()
            Button(L10n.text("Cancel"), role: .cancel) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button(L10n.text("Save")) {
                onSave(draft)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(VibeTheme.accent)
            .keyboardShortcut(.defaultAction)
            .disabled(!draft.canSave)
        }
        .padding()
    }
}

private struct OptionalDateField: View {
    let title: String
    @Binding var date: Date?
    var minimumDate: Date?
    @State private var showsCalendar = false

    init(title: String, date: Binding<Date?>, minimumDate: Date? = nil) {
        self.title = title
        _date = date
        self.minimumDate = minimumDate
    }

    private var selectedDate: Binding<Date> {
        Binding(
            get: {
                guard let minimumDate else { return date ?? .now }
                return max(date ?? minimumDate, minimumDate)
            },
            set: { date = $0 }
        )
    }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                Button {
                    if date == nil {
                        date = minimumDate ?? .now
                    }
                    showsCalendar = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(VibeTheme.accent)

                        if let date {
                            Text(date.formatted(
                                Date.FormatStyle.dateTime
                                    .year()
                                    .month(.wide)
                                    .day()
                                    .locale(L10n.selectedLanguage().locale())
                            ))
                                .foregroundStyle(.primary)
                        } else {
                            Text(L10n.text("Set date"))
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 10)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .frame(width: 250, height: 40)
                    .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(.primary.opacity(0.10), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showsCalendar) {
                    LargeDatePicker(
                        title: title,
                        date: selectedDate,
                        minimumDate: minimumDate,
                        onClose: { showsCalendar = false }
                    )
                }

                if date != nil {
                    Button {
                        date = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.text("Clear date"))
                    .accessibilityLabel(L10n.text("Clear date"))
                } else {
                    Color.clear.frame(width: 20, height: 20)
                }
            }
        }
    }
}

private struct LargeDatePicker: View {
    let title: String
    @Binding var date: Date
    let minimumDate: Date?
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(date.formatted(
                        Date.FormatStyle.dateTime
                            .year()
                            .month(.wide)
                            .day()
                            .locale(L10n.selectedLanguage().locale())
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(L10n.text("Today")) {
                    date = max(Date.now, minimumDate ?? .distantPast)
                }
                .buttonStyle(.bordered)
            }

            LargeCalendar(date: $date, minimumDate: minimumDate)

            Divider()

            HStack {
                Spacer()
                Button(L10n.text("Close"), action: onClose)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 430, height: 460)
    }
}

private struct LargeCalendar: View {
    @Binding var date: Date
    let minimumDate: Date?
    @State private var displayedMonth: Date

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    init(date: Binding<Date>, minimumDate: Date?) {
        _date = date
        self.minimumDate = minimumDate
        _displayedMonth = State(initialValue: Self.monthStart(for: date.wrappedValue))
    }

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = L10n.selectedLanguage().locale()
        return calendar
    }

    private var monthDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return Array(repeating: nil, count: 42)
        }
        let weekday = calendar.component(.weekday, from: displayedMonth)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var days = Array<Date?>(repeating: nil, count: leading)
        days += range.compactMap { day in
            calendar.date(bySetting: .day, value: day, of: displayedMonth)
        }
        days += Array(repeating: nil, count: max(0, 42 - days.count))
        return Array(days.prefix(42))
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[offset...] + symbols[..<offset])
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 34, height: 30)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(L10n.text("Previous month"))

                Spacer()
                Text(monthTitle)
                    .font(.title3.weight(.semibold))
                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 34, height: 30)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(L10n.text("Next month"))
            }

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 24)
                }

                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayButton(day)
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
        }
        .frame(width: 376)
        .onChange(of: date) {
            displayedMonth = Self.monthStart(for: date)
        }
    }

    private func dayButton(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: date)
        let isToday = calendar.isDateInToday(day)
        let isEnabled = minimumDate.map {
            calendar.startOfDay(for: day) >= calendar.startOfDay(for: $0)
        } ?? true

        return Button {
            guard isEnabled else { return }
            date = calendar.startOfDay(for: day)
        } label: {
            Text(day.formatted(.dateTime.day()))
                .font(.body.weight(isSelected ? .bold : .medium))
                .foregroundStyle(
                    isSelected ? Color.white : isEnabled ? Color.primary : Color.secondary.opacity(0.45)
                )
                .frame(maxWidth: .infinity, minHeight: 36)
                .background {
                    if isSelected {
                        Circle().fill(VibeTheme.accent)
                    } else if isToday {
                        Circle().stroke(VibeTheme.accent.opacity(0.7), lineWidth: 1.5)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(day.formatted(
            Date.FormatStyle.dateTime
                .year()
                .month(.wide)
                .day()
                .locale(L10n.selectedLanguage().locale())
        ))
    }

    private var monthTitle: String {
        displayedMonth.formatted(
            Date.FormatStyle.dateTime
                .year()
                .month(.wide)
                .locale(L10n.selectedLanguage().locale())
        )
    }

    private func changeMonth(by value: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
    }

    private static func monthStart(for date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }
}
