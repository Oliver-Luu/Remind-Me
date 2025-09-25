import SwiftUI
import SwiftData

struct AddReminderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var title = ""
    @State private var repeatFrequency = RepeatFrequency.none
    @State private var numberOfOccurrences = 7 // Default number of future reminders to create

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
            modelContext: modelContext
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
