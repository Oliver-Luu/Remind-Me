import SwiftUI
import SwiftData

struct EditReminderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let item: Item
    @State private var date: Date
    @State private var title: String
    @State private var repeatFrequency: RepeatFrequency
    @State private var isCompleted: Bool
    @State private var notificationIntervalMinutes: Int
    @State private var notificationRepeatCount: Int
    @State private var showingEditOptionsAlert = false
    
    init(item: Item) {
        self.item = item
        self._date = State(initialValue: item.timestamp)
        self._title = State(initialValue: item.title)
        self._repeatFrequency = State(initialValue: item.repeatFrequency)
        self._isCompleted = State(initialValue: item.isCompleted)
        self._notificationIntervalMinutes = State(initialValue: item.notificationIntervalMinutes)
        self._notificationRepeatCount = State(initialValue: item.notificationRepeatCount)
    }

    var body: some View {
        Form {
            Section("Reminder Details") {
                TextField("Reminder Title", text: $title)
                DatePicker("Select Date and Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
            }
            
            Section("Status") {
                Toggle("Completed", isOn: $isCompleted)
            }
            
            Section("Repeat Options") {
                Picker("Repeat", selection: $repeatFrequency) {
                    ForEach(RepeatFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.displayName).tag(frequency)
                    }
                }
                .pickerStyle(.menu)
                
                if item.repeatFrequency != .none && item.parentReminderID != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This is part of a repeating reminder series")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Edit All in Series") {
                            showingEditOptionsAlert = true
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
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
            
            if hasChanges {
                Section {
                    Button("Save Changes") {
                        saveChanges()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
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
    }
    
    private var hasChanges: Bool {
        return item.timestamp != date ||
               item.title != title.trimmingCharacters(in: .whitespacesAndNewlines) ||
               item.repeatFrequency != repeatFrequency ||
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
            // Cancel existing notifications for this item
            await NotificationManager.shared.handleReminderDeleted(item)
            
            // Update the item
            item.timestamp = date
            item.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            item.repeatFrequency = repeatFrequency
            item.notificationIntervalMinutes = notificationIntervalMinutes
            item.notificationRepeatCount = notificationRepeatCount
            
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
            }
            
            try? modelContext.save()
            
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
            
            // Calculate the time difference to apply to all reminders
            let timeDifference = date.timeIntervalSince(item.timestamp)
            let titleChange = title.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Update all related reminders
            for reminder in relatedReminders {
                reminder.title = titleChange
                reminder.timestamp = reminder.timestamp.addingTimeInterval(timeDifference)
                reminder.repeatFrequency = repeatFrequency
                reminder.notificationIntervalMinutes = notificationIntervalMinutes
                reminder.notificationRepeatCount = notificationRepeatCount
                
                // Don't change completion status for other reminders in the series
                if reminder.id == item.id {
                    reminder.isCompleted = isCompleted
                }
                
                // Reschedule if not completed
                if !reminder.isCompleted {
                    await NotificationManager.shared.scheduleNotification(for: reminder)
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
