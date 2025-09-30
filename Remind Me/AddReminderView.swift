import SwiftUI
import SwiftData

struct AddReminderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var title = ""
    @State private var repeatFrequency = RepeatFrequency.none
    @State private var repeatInterval: Int = 1
    @State private var numberOfOccurrences = 7 // Default number of future reminders to create
    @State private var notificationIntervalMinutes: Int = 1
    @State private var notificationRepeatCount: Int = 10

    @State private var showCustomDatePicker = false
    @State private var customSelectedDates: Set<DateComponents> = []

    var body: some View {
        Form {
            Section("Reminder Details") {
                TextField("Reminder Title", text: $title)
                if repeatFrequency == .custom {
                    DatePicker("Select Time", selection: $date, displayedComponents: [.hourAndMinute])
                    Text("This time will apply to all selected dates.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    DatePicker("Select Date and Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
            }
            
            Section("Repeat Options") {
                Picker("Repeat", selection: $repeatFrequency) {
                    ForEach(RepeatFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.displayName).tag(frequency)
                    }
                }
                .pickerStyle(.menu)
                
                if repeatFrequency != .none && repeatFrequency != .custom {
                    Stepper("Every " + "\(repeatInterval)" + " " + "\(repeatFrequency.unitName(for: repeatInterval))", value: $repeatInterval, in: 1...52)
                }
                
                if repeatFrequency != .none && repeatFrequency != .custom {
                    Stepper("Create \(numberOfOccurrences) future reminders", value: $numberOfOccurrences, in: 1...50)
                        .help("Number of future repeating reminders to create")
                }

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
        .navigationTitle("Add Reminder")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .sheet(isPresented: $showCustomDatePicker) {
            CustomRepeatSelectionView(selectedDates: $customSelectedDates)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if repeatFrequency == .custom {
            // Create a parent ID for the custom series
            let parentID = UUID().uuidString
            var remindersToSchedule: [Item] = []
            let calendar = Calendar.current
            // Keep the time components from `date`
            let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: date)
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
                    let item = Item(
                        timestamp: scheduledDate,
                        title: trimmedTitle,
                        repeatFrequency: .custom,
                        parentReminderID: parentID,
                        notificationIntervalMinutes: notificationIntervalMinutes,
                        notificationRepeatCount: notificationRepeatCount,
                        repeatInterval: 1
                    )
                    modelContext.insert(item)
                    remindersToSchedule.append(item)
                }
            }
            Task { await NotificationManager.shared.scheduleNotifications(for: remindersToSchedule) }
            dismiss()
            return
        }
        addRepeatingReminders(
            title: trimmedTitle,
            startDate: date,
            repeatFrequency: repeatFrequency,
            repeatInterval: repeatInterval,
            numberOfOccurrences: numberOfOccurrences,
            modelContext: modelContext,
            notificationIntervalMinutes: notificationIntervalMinutes,
            notificationRepeatCount: notificationRepeatCount
        )
        dismiss()
    }
}

#Preview {
    NavigationStack {
        AddReminderView()
    }
    .modelContainer(for: Item.self, inMemory: true)
}

