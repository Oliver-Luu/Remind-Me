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
    
    var allCompleted: Bool { items.allSatisfy { $0.isCompleted } }
}

struct SeriesID: Identifiable { let id: String }

struct RemindersListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: [SortDescriptor(\Item.timestamp, order: .forward)]) private var items: [Item]
    @State private var isPresentingAddReminder = false
    @State private var selectedItem: Item?
    @State private var editingSeries: SeriesID?

    private var repeatingSeries: [ReminderSeries] {
        let repeatingItems = items.filter { $0.parentReminderID != nil }
        let grouped = Dictionary(grouping: repeatingItems, by: { $0.parentReminderID! })
        let series = grouped.map { (parentID, groupItems) in
            // Sort items in a series deterministically by timestamp, then by id
            let sortedItems = groupItems.sorted { lhs, rhs in
                if lhs.timestamp != rhs.timestamp {
                    return lhs.timestamp < rhs.timestamp
                } else {
                    return lhs.id < rhs.id
                }
            }
            return ReminderSeries(
                id: parentID,
                title: sortedItems.first?.title ?? "Repeating Reminder",
                repeatFrequency: sortedItems.first?.repeatFrequency ?? .daily,
                items: sortedItems
            )
        }
        // Deterministic sort for series: next upcoming, then title, then first item timestamp, then id
        return series.sorted { a, b in
            let ad = a.nextUpcoming?.timestamp ?? a.items.first?.timestamp ?? .distantFuture
            let bd = b.nextUpcoming?.timestamp ?? b.items.first?.timestamp ?? .distantFuture
            if ad != bd { return ad < bd }
            let titleCompare = a.title.localizedCaseInsensitiveCompare(b.title)
            if titleCompare != .orderedSame { return titleCompare == .orderedAscending }
            let aFirst = a.items.first?.timestamp ?? .distantFuture
            let bFirst = b.items.first?.timestamp ?? .distantFuture
            if aFirst != bFirst { return aFirst < bFirst }
            return a.id < b.id
        }
    }

    private var singleItems: [Item] {
        items.filter { $0.parentReminderID == nil }
            .sorted { first, second in
                // First, prioritize upcoming reminders over past ones
                let now = Date()
                let firstIsFuture = first.timestamp >= now
                let secondIsFuture = second.timestamp >= now
                
                if firstIsFuture && !secondIsFuture {
                    return true // first is future, second is past - first comes first
                } else if !firstIsFuture && secondIsFuture {
                    return false // first is past, second is future - second comes first
                } else if firstIsFuture && secondIsFuture {
                    // Both are future - sort by timestamp (earliest first)
                    return first.timestamp < second.timestamp
                } else {
                    // Both are past - sort by timestamp (most recent first)
                    return first.timestamp > second.timestamp
                }
            }
    }
    
    private var hasCompletedReminders: Bool {
        let completedSingles = singleItems.filter { $0.isCompleted }
        let completedSeries = repeatingSeries.filter { $0.allCompleted }
        return !completedSingles.isEmpty || !completedSeries.isEmpty
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic animated background
                CrossingRadialBackground(
                    colorsA: [
                        Color.orange.opacity(0.15),
                        Color.pink.opacity(0.1),
                        Color.clear
                    ],
                    colorsB: [
                        Color.pink.opacity(0.13),
                        Color.orange.opacity(0.08),
                        Color.clear
                    ],
                    startCenterA: .topTrailing,
                    endCenterA: .bottomLeading,
                    startCenterB: .bottomLeading,
                    endCenterB: .topTrailing,
                    startRadius: 40,
                    endRadius: 350,
                    duration: 12,
                    autoreverses: true
                )
                
                Group {
                    if items.isEmpty {
                        EmptyStateView(isPresentingAddReminder: $isPresentingAddReminder)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                // Removed header block (icon only to avoid redundant title)
                                
                                // Repeating reminders
                                if !repeatingSeries.isEmpty {
                                    RemindersSection(
                                        title: "Repeating Reminders",
                                        showClearButton: repeatingSeries.contains { $0.allCompleted },
                                        onClearTapped: { deleteAllCompletedSeries() }
                                    ) {
                                        ForEach(repeatingSeries) { series in
                                            ReminderSeriesCard(
                                                series: series,
                                                editingSeries: $editingSeries,
                                                modelContext: modelContext
                                            )
                                        }
                                    }
                                }

                                // One-time reminders
                                if !singleItems.isEmpty {
                                    RemindersSection(
                                        title: "One-time Reminders",
                                        showClearButton: singleItems.contains { $0.isCompleted },
                                        onClearTapped: { deleteAllCompletedSingleReminders() }
                                    ) {
                                        ForEach(singleItems) { item in
                                            ReminderItemCard(
                                                item: item,
                                                selectedItem: $selectedItem,
                                                modelContext: modelContext
                                            )
                                        }
                                    }
                                }
                                
                                // Add some bottom padding for better scrolling experience
                                Color.clear.frame(height: 100)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 32)
                        }
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TitleBarView(
                    title: "My Reminders",
                    iconSystemName: "list.bullet.clipboard.fill",
                    gradientColors: [.orange, .pink],
                    topPadding: 32
                )
                .simultaneousGesture(TapGesture().onEnded {
                    Haptics.selectionChanged()
                })
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Haptics.impact(.medium)
                    isPresentingAddReminder = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .buttonBorderShape(.circle)
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

    private func conciseDateTime(_ date: Date) -> String {
        let calendar = Calendar.current

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        let time = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return "Today \(time)"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow \(time)"
        } else {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            return df.string(from: date)
        }
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
    
    private func deleteAllCompletedSingleReminders() {
        withAnimation {
            // Delete only completed single reminders
            let completedSingles = singleItems.filter { $0.isCompleted }
            Task {
                await NotificationManager.shared.cancelNotifications(for: completedSingles)
            }
            for item in completedSingles {
                modelContext.delete(item)
            }
            
            // Save changes
            try? modelContext.save()
        }
    }
    
    private func deleteAllCompletedSeries() {
        withAnimation {
            // Delete only completed occurrences from repeating reminders
            let completedRepeatingItems = items.filter { $0.parentReminderID != nil && $0.isCompleted }
            Task {
                await NotificationManager.shared.cancelNotifications(for: completedRepeatingItems)
            }
            for item in completedRepeatingItems {
                modelContext.delete(item)
            }
            // Save changes
            try? modelContext.save()
        }
    }
}

// MARK: - Supporting Views

struct EmptyStateView: View {
    @Binding var isPresentingAddReminder: Bool
    @State private var floatIcon = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "bell.slash.circle")
                    .font(.system(size: 80, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(floatIcon ? 1.05 : 0.95)
                    .onAppear {
                        withAnimation(
                            .easeInOut(duration: 2.5)
                            .repeatForever(autoreverses: true)
                        ) {
                            floatIcon.toggle()
                        }
                    }
                
                VStack(spacing: 8) {
                    Text("No reminders yet")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Create your first reminder to get started!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Button {
                    Haptics.impact(.light)
                    isPresentingAddReminder = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                        
                        Text("Create Reminder")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .orange.opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

struct RemindersSection<Content: View>: View {
    let title: String
    let content: Content
    let showClearButton: Bool
    let onClearTapped: (() -> Void)?
    
    init(title: String, showClearButton: Bool = false, onClearTapped: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
        self.showClearButton = showClearButton
        self.onClearTapped = onClearTapped
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if showClearButton {
                    Button {
                        onClearTapped?()
                    } label: {
                        Text("Clear Completed")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.red.opacity(0.1))
                                    .stroke(.red.opacity(0.3), lineWidth: 1)
                            }
                    }
                }
            }
            .padding(.horizontal, 4)
            
            LazyVStack(spacing: 12) {
                content
            }
        }
    }
}

struct ReminderSeriesCard: View {
    let series: ReminderSeries
    @Binding var editingSeries: SeriesID?
    let modelContext: ModelContext
    @State private var cardScale = 1.0
    @State private var isRemoving = false
    @State private var offsetX: CGFloat = 0
    @State private var startOffsetX: CGFloat = 0
    private let revealWidth: CGFloat = 88

    private func dynamicTitleSize(for width: CGFloat) -> CGFloat {
        switch width {
        case ..<340: return 16
        case ..<390: return 17
        case ..<430: return 18
        case ..<600: return 19
        default: return 20
        }
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Trailing red delete background (small button style)
            HStack(spacing: 0) {
                Spacer()
                Button(role: .destructive) {
                    Haptics.warning()
                    withAnimation(.easeInOut(duration: 0.2)) { isRemoving = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        Task {
                            await NotificationManager.shared.cancelNotifications(for: series.items)
                            for it in series.items { modelContext.delete(it) }
                            try? modelContext.save()
                        }
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: revealWidth)
                        .frame(maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.red)
                        )
                        .contentShape(Rectangle())
                }
                .tint(.red)
            }
            .clipShape(RoundedCorners(radius: 16, corners: [.topRight, .bottomRight]))
            .opacity(offsetX < 0 ? 1 : 0)
            .allowsHitTesting(offsetX < 0)
            .animation(.easeInOut(duration: 0.2), value: offsetX)

            // Foreground card content with navigation
            NavigationLink {
                ReminderSeriesDetailView(parentID: series.id)
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack(spacing: 12) {
                        Image(systemName: series.allCompleted ? "checkmark.circle.fill" : "repeat.circle.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(series.allCompleted ? .green : .blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(series.title)
                                .font(.system(size: dynamicTitleSize(for: UIScreen.main.bounds.width), weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                                .strikethrough(series.allCompleted)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.85)
                                .allowsTightening(true)
                            
                            Text(series.repeatFrequency.display(interval: series.items.first?.repeatInterval ?? 1))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    // Details
                    HStack(spacing: 16) {
                        if let next = series.nextUpcoming {
                            Label {
                                Text(conciseDateTime(next.timestamp))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } icon: {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Label {
                            Text("\(series.totalCount) total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } icon: {
                            Image(systemName: "number.circle")
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                    }
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                }
            }
            .contentShape(Rectangle())
            .offset(x: isRemoving ? -40 : offsetX)
            .highPriorityGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let t = value.translation
                        guard abs(t.width) > abs(t.height) else { return }
                        let proposed = startOffsetX + t.width
                        if proposed < -revealWidth {
                            let extra = proposed + revealWidth // negative when over-dragging left
                            offsetX = -revealWidth + extra / 6 // rubber-band beyond limit
                        } else if proposed > 0 {
                            offsetX = proposed / 6 // rubber-band when pulling right past 0
                        } else {
                            offsetX = proposed
                        }
                    }
                    .onEnded { value in
                        let predicted = startOffsetX + value.predictedEndTranslation.width
                        let willOpen = -predicted > revealWidth * 0.4
                        let target: CGFloat = willOpen ? -revealWidth : 0
                        let overshoot: CGFloat = willOpen ? (target - 3) : (target + 3)
                        
                        // Phase 1: quick overshoot
                        withAnimation(.spring(response: 0.16, dampingFraction: 0.7, blendDuration: 0.08)) {
                            offsetX = overshoot
                        }
                        // Phase 2: settle to target
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.9, blendDuration: 0.1).delay(0.02)) {
                            offsetX = target
                        }
                        startOffsetX = target
                    }
            )
            .opacity(isRemoving ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: isRemoving)
        }
        .scaleEffect(cardScale)
        .contextMenu {
            Button("Edit Series") {
                Haptics.selectionChanged()
                editingSeries = SeriesID(id: series.id)
            }

            Button("Add Next Occurrence") {
                Haptics.selectionChanged()
                if let last = series.items.sorted(by: { $0.timestamp < $1.timestamp }).last {
                    addNextOccurrence(for: last, modelContext: modelContext)
                }
            }

            Button("Remove Future Occurrences", role: .destructive) {
                Haptics.warning()
                Task {
                    if let pivot = series.nextUpcoming ?? series.items.sorted(by: { $0.timestamp < $1.timestamp }).last {
                        await removeAllFutureOccurrences(for: pivot, modelContext: modelContext)
                    }
                }
            }

            Divider()

            Button("Delete Series", role: .destructive) {
                Haptics.warning()
                withAnimation(.easeInOut(duration: 0.2)) { isRemoving = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    Task {
                        await NotificationManager.shared.cancelNotifications(for: series.items)
                        for it in series.items { modelContext.delete(it) }
                        try? modelContext.save()
                    }
                }
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                cardScale = 0.95
            }
            withAnimation(.easeInOut(duration: 0.1).delay(0.1)) {
                cardScale = 1.0
            }
        }
    }
    
    private func conciseDateTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        let time = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return "Today \(time)"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow \(time)"
        } else {
            let df = DateFormatter()
            df.dateStyle = .short
            df.timeStyle = .short
            return df.string(from: date)
        }
    }
}

struct ReminderItemCard: View {
    let item: Item
    @Binding var selectedItem: Item?
    let modelContext: ModelContext
    @State private var cardScale = 1.0
    @State private var isRemoving = false
    @State private var offsetX: CGFloat = 0
    @State private var startOffsetX: CGFloat = 0
    private let revealWidth: CGFloat = 88

    private func dynamicItemTitleSize(for width: CGFloat) -> CGFloat {
        switch width {
        case ..<340: return 14.5
        case ..<390: return 15.5
        case ..<430: return 16
        case ..<600: return 17
        default: return 18
        }
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Trailing red delete background
            HStack(spacing: 0) {
                Spacer()
                Button(role: .destructive) {
                    Haptics.warning()
                    withAnimation(.easeInOut(duration: 0.2)) { isRemoving = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        Task { await NotificationManager.shared.handleReminderDeleted(item) }
                        modelContext.delete(item)
                        try? modelContext.save()
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: revealWidth)
                        .frame(maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.red)
                        )
                        .contentShape(Rectangle())
                }
                .tint(.red)
            }
            .clipShape(RoundedCorners(radius: 16, corners: [.topRight, .bottomRight]))
            .opacity(offsetX < 0 ? 1 : 0)
            .allowsHitTesting(offsetX < 0)
            .animation(.easeInOut(duration: 0.2), value: offsetX)
            
            // Foreground card content
            HStack(spacing: 16) {
                // Completion button
                Button {
                    toggleCompletion(for: item)
                    Haptics.selectionChanged()
                } label: {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(item.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)
                
                // Content - tappable area for editing
                Button {
                    selectedItem = item
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: dynamicItemTitleSize(for: UIScreen.main.bounds.width), weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .strikethrough(item.isCompleted)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.85)
                            .allowsTightening(true)
                        
                        Text(formatted(date: item.timestamp))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                // Inline delete button (still shown when completed)
                if item.isCompleted {
                    Button(role: .destructive) {
                        Haptics.warning()
                        withAnimation(.easeInOut(duration: 0.2)) { isRemoving = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            Task { await NotificationManager.shared.handleReminderDeleted(item) }
                            modelContext.delete(item)
                            try? modelContext.save()
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background {
                                Circle().fill(Color.red)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            }
            .contentShape(Rectangle())
            .offset(x: isRemoving ? -40 : offsetX)
            .highPriorityGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let t = value.translation
                        guard abs(t.width) > abs(t.height) else { return }
                        let proposed = startOffsetX + t.width
                        if proposed < -revealWidth {
                            let extra = proposed + revealWidth // negative when over-dragging left
                            offsetX = -revealWidth + extra / 6 // rubber-band beyond limit (changed from /4 to /6)
                        } else if proposed > 0 {
                            offsetX = proposed / 6 // rubber-band when pulling right past 0 (changed from /4 to /6)
                        } else {
                            offsetX = proposed
                        }
                    }
                    .onEnded { value in
                        let predicted = startOffsetX + value.predictedEndTranslation.width
                        let willOpen = -predicted > revealWidth * 0.4 // changed from 0.35 to 0.4
                        let target: CGFloat = willOpen ? -revealWidth : 0
                        let overshoot: CGFloat = willOpen ? (target - 3) : (target + 3) // changed from 6 to 3
                        
                        // Phase 1: quick overshoot
                        withAnimation(.spring(response: 0.16, dampingFraction: 0.7, blendDuration: 0.08)) { // changed animation timings
                            offsetX = overshoot
                        }
                        // Phase 2: settle to target
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.9, blendDuration: 0.1).delay(0.02)) { // changed animation timings and delay
                            offsetX = target
                        }
                        startOffsetX = target
                    }
            )
            .opacity(isRemoving ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: isRemoving)
        }
        .scaleEffect(isRemoving ? 0.98 : cardScale)
        .contextMenu {
            Button("Edit") { selectedItem = item }
            Divider()
            Button("Delete", role: .destructive) {
                Haptics.warning()
                withAnimation(.easeInOut(duration: 0.2)) { isRemoving = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    Task { await NotificationManager.shared.handleReminderDeleted(item) }
                    modelContext.delete(item)
                    try? modelContext.save()
                }
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) { cardScale = 0.95 }
            withAnimation(.easeInOut(duration: 0.1).delay(0.1)) { cardScale = 1.0 }
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
            if item.isCompleted {
                Task { await NotificationManager.shared.handleReminderCompleted(item) }
            }
        }
    }
}

struct RoundedCorners: Shape {
    var radius: CGFloat = 16
    var corners: UIRectCorner = [.allCorners]

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    NavigationStack {
        RemindersListView()
    }
    .modelContainer(for: Item.self, inMemory: true)
}

