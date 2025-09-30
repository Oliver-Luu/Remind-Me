import SwiftUI
import SwiftData

struct RemindersListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Item.timestamp, order: .forward)]) private var items: [Item]
    @State private var isPresentingAddReminder = false
    @State private var selectedItem: Item?
    @State private var isPresentingEditReminder = false

    var body: some View {
        List {
            ForEach(items) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "bell")
                        .foregroundStyle(item.isCompleted ? .green : .blue)
                        .onTapGesture {
                            toggleCompletion(for: item)
                        }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(item.title)
                                .font(.headline)
                                .strikethrough(item.isCompleted)
                            
                            Spacer()
                            
                            if item.repeatFrequency != .none {
                                Image(systemName: "repeat")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        HStack {
                            Text(formatted(date: item.timestamp))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            if item.repeatFrequency != .none {
                                Text("• \(item.repeatFrequency.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedItem = item
                    isPresentingEditReminder = true
                }
                .contextMenu {
                    Button("Edit") {
                        selectedItem = item
                        isPresentingEditReminder = true
                    }
                    
                    Divider()
                    
                    if item.repeatFrequency != .none {
                        Button("Add Next Occurrence") {
                            addNextOccurrence(for: item, modelContext: modelContext)
                        }
                        
                        Button("Remove Future Occurrences", role: .destructive) {
                            Task {
                                await removeAllFutureOccurrences(for: item, modelContext: modelContext)
                            }
                        }
                        
                        Divider()
                    }
                    
                    Button("Delete", role: .destructive) {
                        Task {
                            await NotificationManager.shared.handleReminderDeleted(item)
                        }
                        modelContext.delete(item)
                    }
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("My Reminders")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingAddReminder = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingAddReminder) {
            NavigationStack {
                AddReminderView()
                    .presentationDetents([.fraction(0.8)])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $isPresentingEditReminder) {
            NavigationStack {
                if let selectedItem = selectedItem {
                    EditReminderView(item: selectedItem)
                        .presentationDetents([.fraction(0.8)])
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }

    private func formatted(date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }

    private func toggleCompletion(for item: Item) {
        withAnimation {
            item.isCompleted.toggle()
            
            // Cancel notifications when marking as complete
            if item.isCompleted {
                Task {
                    await NotificationManager.shared.handleReminderCompleted(item)
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        withAnimation {
            let itemsToDelete = offsets.map { items[$0] }
            
            // Cancel notifications for deleted reminders
            Task {
                await NotificationManager.shared.cancelNotifications(for: itemsToDelete)
            }
            
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    NavigationStack {
        RemindersListView()
    }
    .modelContainer(for: Item.self, inMemory: true)
}

