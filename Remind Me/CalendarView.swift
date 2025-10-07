import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: [SortDescriptor(\Item.timestamp, order: .forward)]) private var items: [Item]
    @State private var selectedItem: Item?
    @State private var searchText: String = ""
    @State private var scrollTarget: Date? = Calendar.current.startOfDay(for: Date())

    private var filteredItems: [Item] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }

    private var groupedByDay: [(day: Date, items: [Item])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: filteredItems) { item in
            cal.startOfDay(for: item.timestamp)
        }
        return groups
            .map { ($0.key, $0.value.sorted { $0.timestamp < $1.timestamp }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic animated background similar to other views
                CrossingRadialBackground(
                    colorsA: [
                        Color.teal.opacity(0.16),
                        Color.blue.opacity(0.12),
                        Color.clear
                    ],
                    colorsB: [
                        Color.blue.opacity(0.14),
                        Color.teal.opacity(0.1),
                        Color.clear
                    ],
                    startCenterA: .topLeading,
                    endCenterA: .bottomTrailing,
                    startCenterB: .bottomTrailing,
                    endCenterB: .topLeading,
                    startRadius: 40,
                    endRadius: 360,
                    duration: 10,
                    autoreverses: true
                )

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            // Search field
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                TextField("Search reminders", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .disableAutocorrection(true)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.regularMaterial)
                                    .stroke(.secondary.opacity(0.25), lineWidth: 1)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 24)

                            if groupedByDay.isEmpty {
                                EmptyCalendarState()
                                    .padding(.horizontal, 32)
                                    .padding(.top, 40)
                            } else {
                                LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                                    ForEach(groupedByDay, id: \.day) { section in
                                        Section(header: CalendarSectionHeader(day: section.day)) {
                                            ForEach(section.items) { item in
                                                CalendarItemRow(item: item, selectedItem: $selectedItem, modelContext: modelContext)
                                            }
                                        }
                                        .id(section.day)
                                    }
                                    Color.clear.frame(height: 100)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                            }
                        }
                    }
                    .onAppear {
                        // Scroll to today if present
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            let today = Calendar.current.startOfDay(for: Date())
                            if groupedByDay.contains(where: { $0.day == today }) {
                                withAnimation(.easeInOut) {
                                    proxy.scrollTo(today, anchor: .top)
                                }
                            }
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
                    title: "Calendar View",
                    iconSystemName: "calendar",
                    gradientColors: [.teal, .blue],
                    topPadding: 32
                )
            }
        }
        .sheet(item: $selectedItem) { selected in
            NavigationStack {
                EditReminderView(item: selected)
                    .presentationDetents([.fraction(0.9)])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

private struct CalendarSectionHeader: View {
    let day: Date

    var body: some View {
        HStack {
            Text(display(for: day))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(headerGradient(for: day))
                    .opacity(0.28)
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.secondary.opacity(0.25), lineWidth: 1)
            }
        )
    }

    private func display(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let df = DateFormatter()
        df.dateStyle = .full
        df.timeStyle = .none
        return df.string(from: date)
    }

    private func headerGradient(for date: Date) -> LinearGradient {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return LinearGradient(colors: [.teal, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if cal.isDateInYesterday(date) {
            return LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if cal.isDateInTomorrow(date) || date > cal.startOfDay(for: Date()) {
            return LinearGradient(colors: [.green, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            // Past dates other than yesterday: keep a subtle neutral material tint
            return LinearGradient(colors: [.gray.opacity(0.25), .gray.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

private struct CalendarItemRow: View {
    let item: Item
    @Binding var selectedItem: Item?
    let modelContext: ModelContext
    @State private var isRemoving = false
    @State private var offsetX: CGFloat = 0
    @State private var startOffsetX: CGFloat = 0
    private let revealWidth: CGFloat = 88

    var body: some View {
        ZStack(alignment: .trailing) {
            // Trailing delete
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

            HStack(spacing: 16) {
                Button {
                    toggleCompletion(for: item)
                    Haptics.selectionChanged()
                } label: {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(item.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)

                Button {
                    selectedItem = item
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .strikethrough(item.isCompleted)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(timeString(item.timestamp))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

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
                            .background { Circle().fill(Color.red) }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.secondary.opacity(0.25), lineWidth: 1)
                }
            )
            .contentShape(Rectangle())
            .offset(x: isRemoving ? -40 : offsetX)
            .highPriorityGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let t = value.translation
                        guard abs(t.width) > abs(t.height) else { return }
                        let proposed = startOffsetX + t.width
                        if proposed < -revealWidth {
                            let extra = proposed + revealWidth
                            offsetX = -revealWidth + extra / 6
                        } else if proposed > 0 {
                            offsetX = proposed / 6
                        } else {
                            offsetX = proposed
                        }
                    }
                    .onEnded { value in
                        let predicted = startOffsetX + value.predictedEndTranslation.width
                        let willOpen = -predicted > revealWidth * 0.4
                        let target: CGFloat = willOpen ? -revealWidth : 0
                        let overshoot: CGFloat = willOpen ? (target - 3) : (target + 3)
                        withAnimation(.spring(response: 0.16, dampingFraction: 0.7, blendDuration: 0.08)) {
                            offsetX = overshoot
                        }
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.9, blendDuration: 0.1).delay(0.02)) {
                            offsetX = target
                        }
                        startOffsetX = target
                    }
            )
            .opacity(isRemoving ? 0 : 1)
            .animation(.easeInOut(duration: 0.2), value: isRemoving)
        }
    }

    private func timeString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .none
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

private struct EmptyCalendarState: View {
    @State private var floatIcon = false
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.teal, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(floatIcon ? 1.05 : 0.95)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                        floatIcon.toggle()
                    }
                }
            Text("No reminders to show")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            Text("Create a reminder to see it here, grouped by day.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    NavigationStack { CalendarView() }
        .modelContainer(for: Item.self, inMemory: true)
}
