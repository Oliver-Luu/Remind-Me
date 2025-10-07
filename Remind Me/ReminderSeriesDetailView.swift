import SwiftUI
import SwiftData

struct ReminderSeriesDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var items: [Item] = []
    @State private var selectedItem: Item?
    @State private var showingAddOccurrenceSheet = false
    @State private var customDate = Date()

    let parentID: String

    var body: some View {
        ZStack {
            // Dynamic animated background
            CrossingRadialBackground(
                colorsA: [
                    Color.teal.opacity(0.15),
                    Color.blue.opacity(0.1),
                    Color.clear
                ],
                colorsB: [
                    Color.blue.opacity(0.12),
                    Color.teal.opacity(0.08),
                    Color.clear
                ],
                startCenterA: .topLeading,
                endCenterA: .bottomTrailing,
                startCenterB: .bottomTrailing,
                endCenterB: .topLeading,
                startRadius: 40,
                endRadius: 350,
                duration: 11,
                autoreverses: true
            )
            
            if upcomingItems.isEmpty && pastItems.isEmpty {
                // Empty state
                VStack(spacing: 24) {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        Image(systemName: "bell.slash.circle")
                            .font(.system(size: 80, weight: .ultraLight))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.teal, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(spacing: 8) {
                            Text("No reminders in this series")
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("Add a new occurrence to get started")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 32)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Upcoming reminders
                        if !upcomingItems.isEmpty {
                            RemindersSectionDetail(title: "Upcoming") {
                                ForEach(upcomingItems) { item in
                                    ReminderDetailCard(
                                        item: item,
                                        selectedItem: $selectedItem,
                                        modelContext: modelContext,
                                        onUpdate: { load() }
                                    )
                                }
                            }
                        }
                        
                        // Past reminders
                        if !pastItems.isEmpty {
                            RemindersSectionDetail(title: "Past") {
                                ForEach(pastItems) { item in
                                    ReminderDetailCard(
                                        item: item,
                                        selectedItem: $selectedItem,
                                        modelContext: modelContext,
                                        onUpdate: { load() }
                                    )
                                }
                            }
                        }
                        
                        // Add some bottom padding for safe scrolling
                        Color.clear.frame(height: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 32) // Small top padding to ensure content isn't clipped
                }
                .scrollIndicators(.visible) // Make sure scroll indicators are visible
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddOccurrenceSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.teal, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .teal.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    EditReminderSeriesView(parentID: parentID)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            ToolbarItem(placement: .principal) {
                TitleBarView(
                    title: seriesTitle,
                    iconSystemName: "repeat.circle.fill",
                    gradientColors: [.teal, .blue],
                    topPadding: 32,
                    fontScale: seriesTitleScale
                )
            }
        }
        .onAppear {
            load()
            // Initialize custom date for adding new occurrences
            if let template = items.first {
                let calendar = Calendar.current
                let templateTime = calendar.dateComponents([.hour, .minute], from: template.timestamp)
                customDate = calendar.date(bySettingHour: templateTime.hour ?? 9,
                                         minute: templateTime.minute ?? 0,
                                         second: 0,
                                         of: Date()) ?? Date()
            }
        }
        .sheet(item: $selectedItem) { selected in
            NavigationStack {
                EditReminderView(item: selected)
                    .presentationDetents([.fraction(0.9)])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingAddOccurrenceSheet) {
            NavigationStack {
                AddCustomOccurrenceView(
                    parentID: parentID,
                    templateItem: items.first,
                    customDate: $customDate
                ) { newItem in
                    modelContext.insert(newItem)
                    try? modelContext.save()
                    load()
                    showingAddOccurrenceSheet = false
                }
                .presentationDetents([.fraction(0.75), .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var seriesTitle: String {
        if let first = items.first { return first.title }
        return "Repeating Reminder"
    }
    private var seriesTitleScale: CGFloat {
        let width = UIScreen.main.bounds.width
        let limit: Int
        switch width {
        case ..<340: limit = 12
        case ..<390: limit = 16
        case ..<430: limit = 18
        case ..<600: limit = 22
        default: limit = 26
        }
        let over = max(0, seriesTitle.count - limit)
        if over == 0 { return 1.0 }
        else if over <= 6 { return 0.92 }
        else { return 0.86 }
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

// MARK: - Supporting Views for Series Detail

struct RemindersSectionDetail<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 4)
            
            LazyVStack(spacing: 12) {
                content
            }
        }
    }
}

struct ReminderDetailCard: View {
    let item: Item
    @Binding var selectedItem: Item?
    let modelContext: ModelContext
    let onUpdate: () -> Void
    @State private var cardScale = 1.0
    @State private var offsetX: CGFloat = 0
    @State private var startOffsetX: CGFloat = 0
    private let revealWidth: CGFloat = 88

    private func dynamicDetailTitleSize(for width: CGFloat) -> CGFloat {
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
            // Trailing red delete background (small button style)
            HStack(spacing: 0) {
                Spacer()
                Button(role: .destructive) {
                    Task { await NotificationManager.shared.handleReminderDeleted(item) }
                    modelContext.delete(item)
                    try? modelContext.save()
                    onUpdate()
                    offsetX = 0
                    startOffsetX = 0
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
                // Completion toggle
                Button {
                    toggleCompletion(for: item)
                } label: {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(item.isCompleted ? .green : .secondary)
                }
                
                // Content area (tappable for edit across the whole card)
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.system(size: dynamicDetailTitleSize(for: UIScreen.main.bounds.width), weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .strikethrough(item.isCompleted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                    
                    HStack(spacing: 8) {
                        Label {
                            Text(formatted(date: item.timestamp))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        } icon: {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if item.timestamp < Date() {
                            Label {
                                Text("Past")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } icon: {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        } else if Calendar.current.isDateInToday(item.timestamp) {
                            Label {
                                Text("Today")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            } icon: {
                                Image(systemName: "today")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Options menu
                if item.isCompleted {
                    Button(role: .destructive) {
                        Task { await NotificationManager.shared.handleReminderDeleted(item) }
                        modelContext.delete(item)
                        try? modelContext.save()
                        onUpdate()
                        offsetX = 0
                        startOffsetX = 0
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
            .offset(x: offsetX)
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        let t = value.translation
                        // Only respond to clearly horizontal drags
                        guard abs(t.width) > max(abs(t.height) * 2, 20) else { return }
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
                        let t = value.translation
                        // Only respond to clearly horizontal drags
                        guard abs(t.width) > max(abs(t.height) * 2, 20) else { 
                            // Reset to start position if this wasn't a clear horizontal drag
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                                offsetX = startOffsetX
                            }
                            return 
                        }
                        
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
        }
        .scaleEffect(cardScale)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) { cardScale = 0.95 }
            withAnimation(.easeInOut(duration: 0.1).delay(0.1)) { cardScale = 1.0 }
            selectedItem = item
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
            try? modelContext.save()
            onUpdate()
        }
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
