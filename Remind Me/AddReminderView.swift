import SwiftUI
import SwiftData

struct AddReminderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()

    var body: some View {
        Form {
            Section("Reminder Time") {
                DatePicker("Select Date and Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
            }
        }
        .navigationTitle("Add Reminder")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
    }

    private func save() {
        let newItem = Item(timestamp: date)
        modelContext.insert(newItem)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        AddReminderView()
    }
    .modelContainer(for: Item.self, inMemory: true)
}
