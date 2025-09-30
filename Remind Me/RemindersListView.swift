import SwiftUI
import SwiftData

struct ReminderSeries: Identifiable {
    let id: String
    let title: String
    let repeatFrequency: RepeatFrequency
    let items: [Item]

    var nextUpcoming: Item? {
        let upcoming = items.filter { !$0.isCompleted && $0.timestamp >= Date() }.sorted { $0.timestamp < $1.timestamp }
        return upcoming.first ?? items.sorted { $0.timestamp < $1.timestamp }.first
    }

    var totalCount: Int { items.count }
}

struct SeriesID: Identifiable { let id: String }

struct RemindersListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Item.timestamp, order: .forward)]) private var items: [Item]
    @State private var isPresentingAddReminder = false
    @State private var selectedItem: Item?
    @State private var editingSeries: SeriesID?

    private var repeatingSeries: [ReminderSeries] {
        let repeatingItems = items.filter { $0.parentReminderID != nil }
        let grouped = Dictionary(grouping: repeatingItems, by: { $0.parentReminderID! })
        let series = grouped.map { (parentID, items) in
            ReminderSeries(
                id: parentID,
                title: items.first?.title ?? "Repeating Reminder",
                repeatFrequency: items.first?.repeatFrequency ?? .daily,
                items: items.sorted { $0.timestamp < $1.timestamp }
            )
        }
        return series.sorted { (a, b) in
            let ad = a.nextUpcoming?.timestamp ?? a.items.first?.timestamp ?? .distantFuture
            let bd = b.nextUpcoming?.timestamp ?? b.items.first?.timestamp ?? .distantFuture
            return ad < bd
        }
    }

    private var singleItems: [Item] {
        items.filter { $0.parentReminderID == nil }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                VStack {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 56))
                            .foregroundStyle(.secondary)
                        Text("No reminders yet")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Button {
                            isPresentingAddReminder = true
                        } label: {
                            Label("Add Reminder", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal, 24)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 80)
            } else {
                List {
                    // Repeating series grouped as a single row
                    if !repeatingSeries.isEmpty {
                        Section("Repeating Reminders") {
                            ForEach(repeatingSeries) { series in
                                NavigationLink {
                                    ReminderSeriesDetailView(parentID: series.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "repeat")
                                            .foregroundStyle(.blue)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(series.title)
                                                .font(.headline)

                                            HStack(spacing: 6) {
                                                if let next = series.nextUpcoming {
                                                    Text(formatted(date: next.timestamp))
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                }
                                                Text("• \(series.repeatFrequency.display(interval: series.items.first?.repeatInterval ?? 1))")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Text("• \(series.totalCount) occurrences")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                                .contextMenu {
                                    Button("Edit Series") {
                                        editingSeries = SeriesID(id: series.id)
                                    }

                                    Button("Add Next Occurrence") {
                                        if let last = series.items.sorted(by: { $0.timestamp < $1.timestamp }).last {
                                            addNextOccurrence(for: last, modelContext: modelContext)
                                        }
                                    }

                                    Button("Remove Future Occurrences", role: .destructive) {
                                        Task {
                                            if let pivot = series.nextUpcoming ?? series.items.sorted(by: { $0.timestamp < $1.timestamp }).last {
                                                await removeAllFutureOccurrences(for: pivot, modelContext: modelContext)
                                            }
                                        }
                                    }

                                    Divider()

                                    Button("Delete Series", role: .destructive) {
                                        Task {
                                            await NotificationManager.shared.cancelNotifications(for: series.items)
                                        }
                                        for it in series.items {
                                            modelContext.delete(it)
                                        }
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        editingSeries = SeriesID(id: series.id)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)

                                    Button(role: .destructive) {
                                        Task {
                                            await NotificationManager.shared.cancelNotifications(for: series.items)
                                        }
                                        for it in series.items {
                                            modelContext.delete(it)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    // One-time reminders listed individually
                    if !singleItems.isEmpty {
                        Section("One-time Reminders") {
                            ForEach(singleItems) { item in
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
                                    }
                                }
                            }
                            .onDelete(perform: deleteSingles)
                        }
                    }
                }
            }
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
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(item: $selectedItem) { selected in
            NavigationStack {
                EditReminderView(item: selected)
                    .presentationDetents([.fraction(0.9)])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(item: $editingSeries) { series in
            NavigationStack {
                EditReminderSeriesView(parentID: series.id)
                    .presentationDetents([.fraction(0.9)])
                    .presentationDragIndicator(.visible)
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

    private func deleteSingles(_ offsets: IndexSet) {
        withAnimation {
            let singles = singleItems
            let itemsToDelete = offsets.map { singles[$0] }

            Task {
                await NotificationManager.shared.cancelNotifications(for: itemsToDelete)
            }

            for item in itemsToDelete {
                modelContext.delete(item)
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
