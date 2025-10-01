import SwiftUI
import SwiftData

struct EditReminderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var inAppNotificationManager: InAppNotificationManager

    let item: Item
    @State private var date: Date
    @State private var title: String
    @State private var repeatFrequency: RepeatFrequency
    @State private var repeatInterval: Int
    @State private var isCompleted: Bool
    @State private var notificationIntervalMinutes: Int
    @State private var notificationRepeatCount: Int
    @State private var futureCount: Int = 7
    @State private var showingEditOptionsAlert = false
    
    @State private var showCustomDatePicker = false
    @State private var customSelectedDates: Set<DateComponents> = []
    
    init(item: Item) {
        self.item = item
        self._date = State(initialValue: item.timestamp)
        self._title = State(initialValue: item.title)
        self._repeatFrequency = State(initialValue: item.repeatFrequency)
        self._repeatInterval = State(initialValue: item.repeatInterval)
        self._isCompleted = State(initialValue: item.isCompleted)
        self._notificationIntervalMinutes = State(initialValue: item.notificationIntervalMinutes)
        self._notificationRepeatCount = State(initialValue: item.notificationRepeatCount)
    }

    var body: some View {
        Form {
            Section("Reminder Details") {
                TextField("Reminder Title", text: $title)
                if repeatFrequency == .custom {
                    DatePicker("Select Time", selection: $date, displayedComponents: [.hourAndMinute])
                } else {
                    DatePicker("Select Date and Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
            }
            
            Section("Status") {
                Toggle("Completed", isOn: $isCompleted)
            }
            
            Section("Repeat Options") {
                if item.parentReminderID == nil {
                    Picker("Repeat", selection: $repeatFrequency) {
                        ForEach(RepeatFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                    .pickerStyle(.menu)
                    
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
                    }
                    
                    if repeatFrequency != .none && repeatFrequency != .custom {
                        Stepper("Every \(repeatInterval) \(repeatFrequency.unitName(for: repeatInterval))", value: $repeatInterval, in: 1...52)
                        Stepper("Create \(futureCount) future reminders", value: $futureCount, in: 0...200)
                    }
                } else {
                    HStack {
                        Text("Repeats")
                        Spacer()
                        Text(item.repeatFrequency.displayName)
                            .foregroundStyle(.secondary)
                    }
                    Text("Repeat options are managed by the series and can't be changed on a single occurrence.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Notification Options") {
                Picker("Follow-up interval", selection: $notificationIntervalMinutes) {
                    Text("1 min").tag(1)
                    Text("2 min").tag(2)
                    Text("5 min").tag(5)
                    Text("10 min").tag(10)
                    Text("15 min").tag(15)
                    Text("30 min").tag(30)
                }
                .pickerStyle(.menu)

                Stepper("Send follow-ups: \(notificationRepeatCount) times", value: $notificationRepeatCount, in: 0...30)
                    .help("How many additional notifications to send after the first one. Set to 0 to disable follow-ups.")
            }
        }
        .navigationTitle("Edit Reminder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            if hasChanges {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .alert("Edit Repeating Reminder", isPresented: $showingEditOptionsAlert) {
            Button("Edit This Only") {
                saveChangesThisOnly()
            }
            Button("Edit All in Series") {
                saveChangesAllInSeries()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Do you want to edit only this reminder or all reminders in the series?")
        }
        .sheet(isPresented: $showCustomDatePicker) {
            CustomRepeatSelectionView(selectedDates: $customSelectedDates)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private var hasChanges: Bool {
        return item.timestamp != date ||
               item.title != title.trimmingCharacters(in: .whitespacesAndNewlines) ||
               item.repeatFrequency != repeatFrequency ||
               item.repeatInterval != repeatInterval ||
               item.isCompleted != isCompleted ||
               item.notificationIntervalMinutes != notificationIntervalMinutes ||
               item.notificationRepeatCount != notificationRepeatCount
    }
    
    private func saveChanges() {
        // If this is part of a repeating series and we're changing repeat frequency,
        // ask the user what they want to do
        if item.parentReminderID != nil && item.repeatFrequency != repeatFrequency {
            showingEditOptionsAlert = true
        } else {
            saveChangesThisOnly()
        }
    }
    
    private func saveChangesThisOnly() {
        Task {
            let normalizedDate = floorToMinute(date)
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let wasOneTime = (item.parentReminderID == nil && item.repeatFrequency == .none)
            let willBeRepeating = (repeatFrequency != .none)
            
            if wasOneTime && repeatFrequency == .custom {
                let parentID = UUID().uuidString
                item.timestamp = normalizedDate
                item.title = trimmedTitle
                item.repeatFrequency = .custom
                item.repeatInterval = 1
                item.notificationIntervalMinutes = notificationIntervalMinutes
                item.notificationRepeatCount = notificationRepeatCount
                item.parentReminderID = parentID
                item.isCompleted = isCompleted

                var toSchedule: [Item] = []
                if !item.isCompleted { toSchedule.append(item) }

                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: normalizedDate)
                let sortedDates = customSelectedDates.sorted { lhs, rhs in
                    let l = calendar.date(from: lhs) ?? Date.distantPast
                    let r = calendar.date(from: rhs) ?? Date.distantPast
                    return l < r
                }

                for dayComponents in sortedDates {
                    var comps = dayComponents
                    comps.hour = timeComponents.hour
                    comps.minute = timeComponents.minute
                    comps.second = timeComponents.second
                    if let scheduledDate = calendar.date(from: comps) {
                        if scheduledDate == item.timestamp { continue }
                        let normalized = floorToMinute(scheduledDate)
                        let newItem = Item(
                            timestamp: normalized,
                            title: trimmedTitle,
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

                try? modelContext.save()
                // Schedule precise in-app triggers for newly created items
                for it in toSchedule { inAppNotificationManager.scheduleInAppTrigger(for: it) }
                await NotificationManager.shared.scheduleNotifications(for: toSchedule)
            } else if wasOneTime && willBeRepeating {
                // Convert to a repeating series: assign a parent ID to this item and create future occurrences
                let parentID = UUID().uuidString

                // Update the current item to be the first in the series
                item.timestamp = normalizedDate
                item.title = trimmedTitle
                item.repeatFrequency = repeatFrequency
                item.repeatInterval = repeatInterval
                item.notificationIntervalMinutes = notificationIntervalMinutes
                item.notificationRepeatCount = notificationRepeatCount
                item.parentReminderID = parentID
                item.isCompleted = isCompleted

                var toSchedule: [Item] = []
                if !item.isCompleted { toSchedule.append(item) }

                // Create future occurrences based on chosen count
                var lastDate = normalizedDate
                let calendar = Calendar.current
                for _ in 0..<futureCount {
                    let nextDate: Date
                    switch repeatFrequency {
                    case .daily:
                        nextDate = calendar.date(byAdding: .day, value: repeatInterval, to: lastDate) ?? lastDate
                    case .weekly:
                        nextDate = calendar.date(byAdding: .weekOfYear, value: repeatInterval, to: lastDate) ?? lastDate
                    case .monthly:
                        nextDate = calendar.date(byAdding: .month, value: repeatInterval, to: lastDate) ?? lastDate
                    case .yearly:
                        nextDate = calendar.date(byAdding: .year, value: repeatInterval, to: lastDate) ?? lastDate
                    case .none, .custom:
                        nextDate = lastDate
                    }

                    let normalizedNextDate = floorToMinute(nextDate)
                    let newItem = Item(
                        timestamp: normalizedNextDate,
                        title: trimmedTitle,
                        repeatFrequency: repeatFrequency,
                        parentReminderID: parentID,
                        notificationIntervalMinutes: notificationIntervalMinutes,
                        notificationRepeatCount: notificationRepeatCount,
                        repeatInterval: repeatInterval
                    )
                    modelContext.insert(newItem)
                    if !newItem.isCompleted { toSchedule.append(newItem) }
                    lastDate = nextDate
                }

                try? modelContext.save()
                // Schedule precise in-app triggers for the first and all new items
                for it in toSchedule { inAppNotificationManager.scheduleInAppTrigger(for: it) }
                // Schedule notifications for all items in the new series
                await NotificationManager.shared.scheduleNotifications(for: toSchedule)
            } else {
                // Update the item without series conversion
                item.timestamp = normalizedDate
                item.title = trimmedTitle
                if item.parentReminderID == nil { item.repeatFrequency = repeatFrequency }
                item.notificationIntervalMinutes = notificationIntervalMinutes
                item.notificationRepeatCount = notificationRepeatCount
                item.repeatInterval = repeatInterval

                // Handle completion status change
                if item.isCompleted != isCompleted {
                    item.isCompleted = isCompleted
                    if isCompleted {
                        await NotificationManager.shared.handleReminderCompleted(item)
                    }
                }

                // If not completed, reschedule notifications
                if !item.isCompleted {
                    await NotificationManager.shared.scheduleNotification(for: item)
                    inAppNotificationManager.scheduleInAppTrigger(for: item)
                }

                try? modelContext.save()
            }

            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func saveChangesAllInSeries() {
        Task {
            // Get all related reminders
            let relatedReminders = getRelatedReminders(for: item, modelContext: modelContext)
            
            // Cancel notifications for all related reminders
            await NotificationManager.shared.cancelNotifications(for: relatedReminders)
            
            let normalizedDate = floorToMinute(date)
            let timeDifference = normalizedDate.timeIntervalSince(item.timestamp)
            let titleChange = title.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Update all related reminders
            for reminder in relatedReminders {
                reminder.title = titleChange
                let shifted = reminder.timestamp.addingTimeInterval(timeDifference)
                reminder.timestamp = floorToMinute(shifted)
                // reminder.repeatFrequency = repeatFrequency  // Removed as per instructions
                reminder.repeatInterval = repeatInterval
                reminder.notificationIntervalMinutes = notificationIntervalMinutes
                reminder.notificationRepeatCount = notificationRepeatCount
                
                // Don't change completion status for other reminders in the series
                if reminder.id == item.id {
                    reminder.isCompleted = isCompleted
                }
                
                // Reschedule if not completed
                if !reminder.isCompleted {
                    await NotificationManager.shared.scheduleNotification(for: reminder)
                    inAppNotificationManager.scheduleInAppTrigger(for: reminder)
                }
            }
            
            try? modelContext.save()
            
            await MainActor.run {
                dismiss()
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: Item.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let sampleItem = Item(
        timestamp: Date().addingTimeInterval(3600),
        title: "Take medication",
        repeatFrequency: .daily
    )
    
    return NavigationStack {
        EditReminderView(item: sampleItem)
    }
    .modelContainer(container)
}
