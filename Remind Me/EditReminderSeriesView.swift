import SwiftUI
import SwiftData

struct EditReminderSeriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let parentID: String

    @State private var title: String = ""
    @State private var repeatFrequency: RepeatFrequency = .daily
    @State private var repeatInterval: Int = 1
    @State private var startDate: Date = Date()
    @State private var notificationIntervalMinutes: Int = 1
    @State private var notificationRepeatCount: Int = 10
    @State private var futureCount: Int = 0

    @State private var items: [Item] = []
    @State private var showCustomDatePicker = false
    @State private var customSelectedDates: Set<DateComponents> = []
    @State private var selectionModified = false
    @State private var didInitializeCustomDates = false

    @State private var showRepeatDialog = false
    @State private var showFollowupDialog = false

    var body: some View {
        Form {
            Section("Series Details") {
                TextField("Title", text: $title)
                if repeatFrequency == .custom {
                    DatePicker("Time for all dates", selection: $startDate, displayedComponents: [.hourAndMinute])
                    Text("This time will apply to all selected dates.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    DatePicker("Series start date", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                }
            }

            Section("Repeat Options") {
                HStack {
                    Text("Repeat")
                    Spacer()
                    Text(repeatFrequency.displayName)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { showRepeatDialog = true }

                if repeatFrequency == .custom {
                    Button {
                        showCustomDatePicker = true
                    } label: {
                        Label("Choose dates", systemImage: "calendar")
                    }
                    if !customSelectedDates.isEmpty {
                        Text("Selected: \(customSelectedDates.count) date\(customSelectedDates.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No dates selected yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Stepper("Every " + "\(repeatInterval)" + " " + "\(repeatFrequency.unitName(for: repeatInterval))", value: $repeatInterval, in: 1...52)
                    Stepper("Create \(futureCount) future reminders", value: $futureCount, in: 0...200)
                    Text("Series must be repeating. To stop repeating, delete future occurrences.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Notification Options") {
                HStack {
                    Text("Follow-up interval")
                    Spacer()
                    Text("\(notificationIntervalMinutes) min")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { showFollowupDialog = true }

                Stepper("Send follow-ups: \(notificationRepeatCount) times", value: $notificationRepeatCount, in: 0...30)
            }
        }
        .navigationTitle("Edit Series")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (!hasChanges && !selectionModified))
            }
        }
        .onAppear(perform: load)
        .sheet(isPresented: $showCustomDatePicker) {
            // Wrap the binding to normalize day-only components consistently for the picker
            let normalizedBinding = Binding<Set<DateComponents>>(
                get: {
                    let cal = Calendar.current
                    let tz = TimeZone.current
                    return Set(customSelectedDates.map { comps in
                        var c = DateComponents()
                        c.calendar = cal
                        c.timeZone = tz
                        c.year = comps.year
                        c.month = comps.month
                        c.day = comps.day
                        return c
                    })
                },
                set: { newValue in
                    let cal = Calendar.current
                    let tz = TimeZone.current
                    let normalized = Set(newValue.map { comps in
                        var c = DateComponents()
                        c.calendar = cal
                        c.timeZone = tz
                        c.year = comps.year
                        c.month = comps.month
                        c.day = comps.day
                        return c
                    })
                    customSelectedDates = normalized
                }
            )
            CustomRepeatSelectionView(selectedDates: normalizedBinding)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: showCustomDatePicker) { _, isPresented in
            // When the sheet is dismissed, normalize to day-only and mark modified
            if !isPresented {
                let normalized = Set(customSelectedDates.map { dayOnly($0) })
                if normalized != customSelectedDates {
                    customSelectedDates = normalized
                }
                selectionModified = true
            }
        }
        .confirmationDialog("Repeat", isPresented: $showRepeatDialog, titleVisibility: .visible) {
            ForEach(RepeatFrequency.allCases.filter { $0 != .none }, id: \.self) { frequency in
                Button(frequency.displayName) { repeatFrequency = frequency }
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Follow-up interval", isPresented: $showFollowupDialog, titleVisibility: .visible) {
            Button("1 min") { notificationIntervalMinutes = 1 }
            Button("2 min") { notificationIntervalMinutes = 2 }
            Button("5 min") { notificationIntervalMinutes = 5 }
            Button("10 min") { notificationIntervalMinutes = 10 }
            Button("15 min") { notificationIntervalMinutes = 15 }
            Button("30 min") { notificationIntervalMinutes = 30 }
            Button("Cancel", role: .cancel) { }
        }
    }

    private func dayOnly(_ comps: DateComponents) -> DateComponents {
        DateComponents(year: comps.year, month: comps.month, day: comps.day)
    }

    private func dayKey(from comps: DateComponents, calendar: Calendar) -> Date? {
        let justDay = DateComponents(year: comps.year, month: comps.month, day: comps.day)
        guard let date = calendar.date(from: justDay) else { return nil }
        return calendar.startOfDay(for: date)
    }

    private var hasChanges: Bool {
        guard let first = items.sorted(by: { $0.timestamp < $1.timestamp }).first else { return false }
        if repeatFrequency == .custom {
            let cal = Calendar.current
            let existingDays = Set(items.map { dayOnly(cal.dateComponents([.year, .month, .day], from: $0.timestamp)) })
            let selectedDays = Set(customSelectedDates.map { dayOnly($0) })
            let sameDates = existingDays == selectedDays
            let firstTime = cal.dateComponents([.hour, .minute, .second], from: floorToMinute(first.timestamp))
            let selectedTime = cal.dateComponents([.hour, .minute, .second], from: floorToMinute(startDate))
            let sameTime = firstTime == selectedTime
            let sameTitle = first.title == title
            let sameNotifs = first.notificationIntervalMinutes == notificationIntervalMinutes && first.notificationRepeatCount == notificationRepeatCount
            return !(sameDates && sameTime && sameTitle && sameNotifs)
        } else {
            return first.title == title && first.repeatFrequency == repeatFrequency && first.notificationIntervalMinutes == notificationIntervalMinutes && first.notificationRepeatCount == notificationRepeatCount && first.timestamp == startDate && first.repeatInterval == repeatInterval && max(0, items.count - 1) == futureCount ? false : true
        }
    }

    private func load() {
        let descriptor = FetchDescriptor<Item>(
            predicate: #Predicate<Item> { it in it.parentReminderID == parentID },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        do {
            items = try modelContext.fetch(descriptor)
            if let first = items.first {
                title = first.title
                repeatFrequency = first.repeatFrequency
                repeatInterval = max(1, first.repeatInterval)
                startDate = first.timestamp
                notificationIntervalMinutes = first.notificationIntervalMinutes
                notificationRepeatCount = first.notificationRepeatCount
                futureCount = max(0, items.count - 1)
                if repeatFrequency == .custom {
                    let cal = Calendar.current
                    if !didInitializeCustomDates {
                        customSelectedDates = Set(items.map { cal.dateComponents([.year, .month, .day], from: $0.timestamp) })
                        didInitializeCustomDates = true
                    }
                } else {
                    customSelectedDates = []
                    didInitializeCustomDates = false
                }
            }
        } catch {
            print("Error loading series: \(error)")
            items = []
        }
    }

    private func save() {
        // Load current items and ensure we have something to edit
        guard !items.isEmpty else { return }

        let normalizedStart = floorToMinute(startDate)

        // Cancel notifications for all current items first
        Task { await NotificationManager.shared.cancelNotifications(for: items) }

        if repeatFrequency == .custom {
            let cal = Calendar.current
            let now = Date()

            // Compute selected day keys (start of day)
            let selectedKeys: Set<Date> = Set(customSelectedDates.compactMap { dayKey(from: $0, calendar: cal) })

            // Fetch a fresh snapshot of series items
            var currentItems: [Item] = []
            do {
                let descriptor = FetchDescriptor<Item>(
                    predicate: #Predicate<Item> { it in it.parentReminderID == parentID }
                )
                currentItems = try modelContext.fetch(descriptor)
            } catch {
                currentItems = items
            }

            // Identify future items (>= now)
            let futureItems = currentItems.filter { $0.timestamp >= now }

            // Cancel notifications for all future items (they will be replaced)
            Task { await NotificationManager.shared.cancelNotifications(for: futureItems) }

            // Delete all future items
            for it in futureItems { modelContext.delete(it) }

            // Recreate future items exactly matching the selected day keys
            let time = cal.dateComponents([.hour, .minute], from: normalizedStart)
            let newFutureKeys = selectedKeys.filter { $0 >= cal.startOfDay(for: now) }.sorted()

            var toSchedule: [Item] = []
            for key in newFutureKeys {
                var comps = cal.dateComponents([.year, .month, .day], from: key)
                comps.hour = time.hour
                comps.minute = time.minute
                comps.second = 0
                if let scheduled = cal.date(from: comps) {
                    let normalized = floorToMinute(scheduled, calendar: cal)
                    let newItem = Item(
                        timestamp: normalized,
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        repeatFrequency: .custom,
                        parentReminderID: parentID,
                        notificationIntervalMinutes: notificationIntervalMinutes,
                        notificationRepeatCount: notificationRepeatCount,
                        repeatInterval: 1
                    )
                    modelContext.insert(newItem)
                    if !newItem.isCompleted { toSchedule.append(newItem) }
                }
            }

            // Persist changes
            try? modelContext.save()

            // Schedule notifications for new future items
            Task { await NotificationManager.shared.scheduleNotifications(for: toSchedule) }

            dismiss()
            return
        }

        // Sort items by timestamp to maintain order
        var sortedItems = items.sorted { $0.timestamp < $1.timestamp }

        // Determine desired total occurrences (first + future)
        let desiredTotal = futureCount + 1

        // Add or remove items to match desired count
        if sortedItems.count < desiredTotal {
            let toAdd = desiredTotal - sortedItems.count
            for _ in 0..<toAdd {
                let newItem = Item(
                    timestamp: normalizedStart, // placeholder, will set below
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    repeatFrequency: repeatFrequency,
                    parentReminderID: parentID,
                    notificationIntervalMinutes: notificationIntervalMinutes,
                    notificationRepeatCount: notificationRepeatCount,
                    repeatInterval: repeatInterval
                )
                modelContext.insert(newItem)
                sortedItems.append(newItem)
                items.append(newItem)
            }
        } else if sortedItems.count > desiredTotal {
            let excess = sortedItems.count - desiredTotal
            let toDelete = Array(sortedItems.suffix(excess))
            for it in toDelete {
                modelContext.delete(it)
                items.removeAll { $0.id == it.id }
            }
            sortedItems.removeLast(excess)
        }

        // Recompute timestamps for entire series using new start date and interval
        let calendar = Calendar.current
        var currentDate = normalizedStart
        for index in 0..<sortedItems.count {
            let item = sortedItems[index]
            item.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            item.repeatFrequency = repeatFrequency
            item.repeatInterval = repeatInterval
            item.notificationIntervalMinutes = notificationIntervalMinutes
            item.notificationRepeatCount = notificationRepeatCount

            let normalized = floorToMinute(currentDate)
            item.timestamp = normalized

            // Compute next date for next iteration
            if index < sortedItems.count - 1 {
                switch repeatFrequency {
                case .daily:
                    currentDate = calendar.date(byAdding: .day, value: repeatInterval, to: currentDate) ?? currentDate
                case .weekly:
                    currentDate = calendar.date(byAdding: .weekOfYear, value: repeatInterval, to: currentDate) ?? currentDate
                case .monthly:
                    currentDate = calendar.date(byAdding: .month, value: repeatInterval, to: currentDate) ?? currentDate
                case .yearly:
                    currentDate = calendar.date(byAdding: .year, value: repeatInterval, to: currentDate) ?? currentDate
                case .none, .custom:
                    break
                }
            }
        }

        // Reschedule notifications for all non-completed items
        Task {
            let toSchedule = sortedItems.filter { !$0.isCompleted }
            await NotificationManager.shared.scheduleNotifications(for: toSchedule)
        }

        // Persist changes
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    let container = try! ModelContainer(for: Item.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let ctx = ModelContext(container)
    let parent = UUID().uuidString
    let now = Date()
    let items: [Item] = [0,1,2,3].map { i in
        Item(timestamp: Calendar.current.date(byAdding: .day, value: i, to: now)!, title: "Series", repeatFrequency: .daily, parentReminderID: parent)
    }
    items.forEach { ctx.insert($0) }
    try? ctx.save()
    return NavigationStack { EditReminderSeriesView(parentID: parent) }
        .modelContainer(container)
}
