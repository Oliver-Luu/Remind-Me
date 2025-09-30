import SwiftUI
import SwiftData

struct AddReminderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var title = ""
    @State private var repeatFrequency = RepeatFrequency.none
    @State private var numberOfOccurrences = 7 // Default number of future reminders to create
    @State private var notificationIntervalMinutes: Int = 1
    @State private var notificationRepeatCount: Int = 10

    var body: some View {
        Form {
            Section("Reminder Details") {
                TextField("Reminder Title", text: $title)
                DatePicker("Select Date and Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
            }
            
            Section("Repeat Options") {
                Picker("Repeat", selection: $repeatFrequency) {
                    ForEach(RepeatFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.displayName).tag(frequency)
                    }
                }
                .pickerStyle(.menu)
                
                if repeatFrequency != .none {
                    Stepper("Create \(numberOfOccurrences) future reminders", value: $numberOfOccurrences, in: 1...50)
                        .help("Number of future repeating reminders to create")
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
    }

    private func save() {
        addRepeatingReminders(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: date,
            repeatFrequency: repeatFrequency,
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

