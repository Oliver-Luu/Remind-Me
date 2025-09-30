import SwiftUI
import SwiftData

struct ReminderSeriesDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var items: [Item] = []
    @State private var selectedItem: Item?

    let parentID: String

    var body: some View {
        List {
            if upcomingItems.isEmpty && pastItems.isEmpty {
                ContentUnavailableView("No reminders in this series", systemImage: "bell.slash")
            } else {
                if !upcomingItems.isEmpty {
                    Section("Upcoming") {
                        ForEach(upcomingItems) { item in
                            row(for: item)
                        }
                        .onDelete { offsets in
                            delete(offsets, from: upcomingItems)
                        }
                    }
                }
                if !pastItems.isEmpty {
                    Section("Past") {
                        ForEach(pastItems) { item in
                            row(for: item)
                        }
                        .onDelete { offsets in
                            delete(offsets, from: pastItems)
                        }
                    }
                }
            }
        }
        .navigationTitle(seriesTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addNextFromSeries()
                } label: {
                    Label("Add Next", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    EditReminderSeriesView(parentID: parentID)
                } label: {
                    Label("Edit Series", systemImage: "pencil")
                }
            }
        }
        .onAppear(perform: load)
        .sheet(item: $selectedItem) { selected in
            NavigationStack {
                EditReminderView(item: selected)
                    .presentationDetents([.fraction(0.9)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func row(for item: Item) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "bell")
                .foregroundStyle(item.isCompleted ? .green : .blue)
                .onTapGesture {
                    toggleCompletion(for: item)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .strikethrough(item.isCompleted)

                Text(formatted(date: item.timestamp))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedItem = item
        }
        .contextMenu {
            Button("Edit") {
                selectedItem = item
            }
            Divider()
            Button("Delete", role: .destructive) {
                Task {
                    await NotificationManager.shared.handleReminderDeleted(item)
                }
                modelContext.delete(item)
                load()
            }
        }
    }

    private var seriesTitle: String {
        if let first = items.first { return first.title }
        return "Repeating Reminder"
    }

    private var upcomingItems: [Item] {
        items.filter { $0.timestamp >= Date() }.sorted { $0.timestamp < $1.timestamp }
    }

    private var pastItems: [Item] {
        items.filter { $0.timestamp < Date() }.sorted { $0.timestamp > $1.timestamp }
    }

    private func load() {
        let descriptor = FetchDescriptor<Item>(
            predicate: #Predicate<Item> { it in
                it.parentReminderID == parentID
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        do {
            self.items = try modelContext.fetch(descriptor)
        } catch {
            print("Error loading series: \(error)")
            self.items = []
        }
    }

    private func toggleCompletion(for item: Item) {
        withAnimation {
            item.isCompleted.toggle()
            if item.isCompleted {
                Task { await NotificationManager.shared.handleReminderCompleted(item) }
            }
            try? modelContext.save()
            load()
        }
    }

    private func addNextFromSeries() {
        guard let last = items.sorted(by: { $0.timestamp < $1.timestamp }).last else { return }
        addNextOccurrence(for: last, modelContext: modelContext)
        load()
    }

    private func delete(_ offsets: IndexSet, from source: [Item]) {
        withAnimation {
            let itemsToDelete = offsets.map { source[$0] }
            Task { await NotificationManager.shared.cancelNotifications(for: itemsToDelete) }
            for it in itemsToDelete { modelContext.delete(it) }
            load()
        }
    }

    private func formatted(date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
}

#Preview {
    let container = try! ModelContainer(for: Item.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let ctx = ModelContext(container)
    let parent = UUID().uuidString
    let now = Date()
    let items: [Item] = [0,1,2,3].map { i in
        Item(timestamp: Calendar.current.date(byAdding: .day, value: i, to: now)!, title: "Medicate", repeatFrequency: .daily, parentReminderID: parent)
    }
    items.forEach { ctx.insert($0) }
    try? ctx.save()
    return NavigationStack { ReminderSeriesDetailView(parentID: parent) }
        .modelContainer(container)
}
