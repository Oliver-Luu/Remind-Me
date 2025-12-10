import SwiftUI
import SwiftData

struct EditReminderSeriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let parentID: String

    @State private var title: String = ""
    @State private var repeatFrequency: RepeatFrequency = .daily
    @State private var repeatInterval: Int = 1
    @State private var startDate: Date = Date()
    @State private var notificationIntervalMinutes: Int = 1
    @State private var notificationRepeatCount: Int = 10
    @State private var futureCount: Int = 0

    @State private var items: [Item] = []
    @State private var showCustomDatePicker = false
    @State private var customSelectedDates: Set<DateComponents> = []
    @State private var selectionModified = false
    @State private var didInitializeCustomDates = false

    @State private var showRepeatDialog = false
    @State private var showFollowupDialog = false

    @State private var isDeletingSeries = false
    @State private var showDeleteSeriesError = false
    @State private var deleteSeriesErrorMessage = ""
    
    // Dynamic Type scaling properties
    private var dynamicSectionSpacing: CGFloat {
        20 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicTopPadding: CGFloat {
        32 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicBottomPadding: CGFloat {
        40 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicHorizontalPadding: CGFloat {
        20 * min(dynamicTypeSize.scaleFactor, 1.3)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic animated background
                CrossingRadialBackground(
                    colorsA: [
                        Color.indigo.opacity(0.2),
                        Color.purple.opacity(0.15),
                        Color.clear
                    ],
                    colorsB: [
                        Color.purple.opacity(0.18),
                        Color.indigo.opacity(0.12),
                        Color.clear
                    ],
                    startCenterA: .topTrailing,
                    endCenterA: .bottomLeading,
                    startCenterB: .bottomLeading,
                    endCenterB: .topTrailing,
                    startRadius: 30,
                    endRadius: 300,
                    duration: 8,
                    autoreverses: true
                )
                
                ScrollView {
                    // Form sections with glass effect
                    VStack(spacing: dynamicSectionSpacing) {
                        // Series Details Section
                        ModernFormSection(title: "Series Details") {
                            VStack(spacing: 16 * dynamicTypeSize.scaleFactor) {
                                ModernTextField(title: "Reminder Title", text: $title, centered: true)
                                
                                if repeatFrequency == .custom {
                                    ModernDatePicker(
                                        title: "Time for all dates",
                                        selection: $startDate,
                                        displayedComponents: [.hourAndMinute]
                                    )
                                    
                                    ModernStatusRow(
                                        icon: "info.circle",
                                        iconColor: .blue,
                                        text: "This time will apply to all selected dates"
                                    )
                                } else {
                                    ModernDatePicker(
                                        title: "Series start date",
                                        selection: $startDate,
                                        displayedComponents: [.date, .hourAndMinute],
                                        centered: true
                                    )
                                }
                            }
                        }

                        // Repeat Options Section
                        ModernFormSection(title: "Repeat Options") {
                            VStack(spacing: 16 * dynamicTypeSize.scaleFactor) {
                                ModernSelectionRow(
                                    title: "Repeat",
                                    value: repeatFrequency.displayName,
                                    action: { showRepeatDialog = true }
                                )

                                if repeatFrequency == .custom {
                                    ModernActionRow(
                                        title: "Choose dates",
                                        icon: "calendar",
                                        action: { showCustomDatePicker = true }
                                    )
                                    
                                    ModernStatusRow(
                                        icon: customSelectedDates.isEmpty ? "exclamationmark.circle" : "checkmark.circle.fill",
                                        iconColor: customSelectedDates.isEmpty ? .orange : .green,
                                        text: customSelectedDates.isEmpty ?
                                            "No dates selected yet" :
                                            "Selected \(customSelectedDates.count) date\(customSelectedDates.count == 1 ? "" : "s")"
                                    )
                                } else {
                                    ModernStepper(
                                        title: "Interval",
                                        value: $repeatInterval,
                                        range: 1...52,
                                        suffix: repeatFrequency.unitName(for: repeatInterval),
                                    )
                                    
                                    ModernStepper(
                                        title: "Future reminders",
                                        value: $futureCount,
                                        range: 0...200,
                                        suffix: "reminder\(futureCount == 1 ? "" : "s")"
                                    )
                                    
                                    ModernStatusRow(
                                        icon: "info.circle",
                                        iconColor: .blue,
                                        text: "Series must be repeating. To stop repeating, delete future occurrences."
                                    )
                                }
                            }
                        }

                        // Notification Options Section
                        ModernFormSection(title: "Notification Options") {
                            VStack(spacing: 16 * dynamicTypeSize.scaleFactor) {
                                ModernSelectionRow(
                                    title: "Follow-up interval",
                                    value: "\(notificationIntervalMinutes) min",
                                    action: { showFollowupDialog = true }
                                )

                                ModernStepper(
                                    title: "Follow-up count",
                                    value: $notificationRepeatCount,
                                    range: 0...30,
                                    suffix: "follow-up\(notificationRepeatCount == 1 ? "" : "s")"
                                )
                            }
                        }
                    }
                    .padding(.top, dynamicTopPadding)
                    .padding(.bottom, dynamicBottomPadding)
                }
                .padding(.horizontal, dynamicHorizontalPadding)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { 
                    Haptics.selectionChanged()
                    dismiss() 
                }
                .foregroundColor(.secondary)
                .font(.system(size: UIFont.preferredFont(forTextStyle: .body).pointSize * min(dynamicTypeSize.scaleFactor, 1.2)))
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { 
                    Haptics.impact(.medium)
                    save() 
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (!hasChanges && !selectionModified))
                .fontWeight(.semibold)
                .foregroundColor(
                    (title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (!hasChanges && !selectionModified)) ? 
                    .secondary : .indigo
                )
                .font(.system(size: UIFont.preferredFont(forTextStyle: .body).pointSize * min(dynamicTypeSize.scaleFactor, 1.2)))
            }
            ToolbarItem(placement: .principal) {
                TitleBarView(
                    title: "Edit Series",
                    iconSystemName: "repeat.circle.fill",
                    gradientColors: [.indigo, .purple],
                    topPadding: 32,
                    fontScale: 0.8
                )
            }
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    Haptics.warning()
                    Task { await deleteSeries() }
                } label: {
                    HStack(spacing: 6 * min(dynamicTypeSize.scaleFactor, 1.2)) {
                        Image(systemName: "trash")
                            .font(.system(size: UIFont.preferredFont(forTextStyle: .body).pointSize * min(dynamicTypeSize.scaleFactor, 1.2)))
                        Text("Delete Series")
                            .font(.system(size: UIFont.preferredFont(forTextStyle: .body).pointSize * min(dynamicTypeSize.scaleFactor, 1.2)))
                    }
                }
                .disabled(isDeletingSeries)
            }
        }
        .onAppear(perform: load)
        .sheet(isPresented: $showCustomDatePicker) {
            // Wrap the binding to normalize day-only components consistently for the picker
            let normalizedBinding = Binding<Set<DateComponents>>(
                get: {
                    let cal = Calendar.current
                    let tz = TimeZone.current
                    return Set(customSelectedDates.map { comps in
                        var c = DateComponents()
                        c.calendar = cal
                        c.timeZone = tz
                        c.year = comps.year
                        c.month = comps.month
                        c.day = comps.day
                        return c
                    })
                },
                set: { newValue in
                    let cal = Calendar.current
                    let tz = TimeZone.current
                    let normalized = Set(newValue.map { comps in
                        var c = DateComponents()
                        c.calendar = cal
                        c.timeZone = tz
                        c.year = comps.year
                        c.month = comps.month
                        c.day = comps.day
                        return c
                    })
                    customSelectedDates = normalized
                }
            )
            CustomRepeatSelectionView(selectedDates: normalizedBinding)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: showCustomDatePicker) { _, isPresented in
            // When the sheet is dismissed, normalize to day-only and mark modified
            if !isPresented {
                let normalized = Set(customSelectedDates.map { dayOnly($0) })
                if normalized != customSelectedDates {
                    customSelectedDates = normalized
                }
                selectionModified = true
                Haptics.selectionChanged()
            }
        }
        .confirmationDialog("Repeat", isPresented: $showRepeatDialog, titleVisibility: .visible) {
            ForEach(RepeatFrequency.allCases.filter { $0 != .none }, id: \.self) { frequency in
                Button(frequency.displayName) { 
                    Haptics.selectionChanged()
                    repeatFrequency = frequency 
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Follow-up interval", isPresented: $showFollowupDialog, titleVisibility: .visible) {
            Button("1 min") { Haptics.selectionChanged(); notificationIntervalMinutes = 1 }
            Button("2 min") { Haptics.selectionChanged(); notificationIntervalMinutes = 2 }
            Button("5 min") { Haptics.selectionChanged(); notificationIntervalMinutes = 5 }
            Button("10 min") { Haptics.selectionChanged(); notificationIntervalMinutes = 10 }
            Button("15 min") { Haptics.selectionChanged(); notificationIntervalMinutes = 15 }
            Button("30 min") { Haptics.selectionChanged(); notificationIntervalMinutes = 30 }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Delete Series", isPresented: $showDeleteSeriesError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteSeriesErrorMessage)
        }
    }

    private func dayOnly(_ comps: DateComponents) -> DateComponents {
        DateComponents(year: comps.year, month: comps.month, day: comps.day)
    }

    private func dayKey(from comps: DateComponents, calendar: Calendar) -> Date? {
        let justDay = DateComponents(year: comps.year, month: comps.month, day: comps.day)
        guard let date = calendar.date(from: justDay) else { return nil }
        return calendar.startOfDay(for: date)
    }

    private var hasChanges: Bool {
        guard let first = items.sorted(by: { $0.timestamp < $1.timestamp }).first else { return false }
        if repeatFrequency == .custom {
            let cal = Calendar.current
            let existingDays = Set(items.map { dayOnly(cal.dateComponents([.year, .month, .day], from: $0.timestamp)) })
            let selectedDays = Set(customSelectedDates.map { dayOnly($0) })
            let sameDates = existingDays == selectedDays
            let firstTime = cal.dateComponents([.hour, .minute, .second], from: floorToMinute(first.timestamp))
            let selectedTime = cal.dateComponents([.hour, .minute, .second], from: floorToMinute(startDate))
            let sameTime = firstTime == selectedTime
            let sameTitle = first.title == title
            let sameNotifs = first.notificationIntervalMinutes == notificationIntervalMinutes && first.notificationRepeatCount == notificationRepeatCount
            return !(sameDates && sameTime && sameTitle && sameNotifs)
        } else {
            return first.title == title && first.repeatFrequency == repeatFrequency && first.notificationIntervalMinutes == notificationIntervalMinutes && first.notificationRepeatCount == notificationRepeatCount && first.timestamp == startDate && first.repeatInterval == repeatInterval && max(0, items.count - 1) == futureCount ? false : true
        }
    }

    private func load() {
        let descriptor = FetchDescriptor<Item>(
            predicate: #Predicate<Item> { it in it.parentReminderID == parentID },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        do {
            items = try modelContext.fetch(descriptor)
            if let first = items.first {
                title = first.title
                repeatFrequency = first.repeatFrequency
                repeatInterval = max(1, first.repeatInterval)
                startDate = first.timestamp
                notificationIntervalMinutes = first.notificationIntervalMinutes
                notificationRepeatCount = first.notificationRepeatCount
                futureCount = max(0, items.count - 1)
                if repeatFrequency == .custom {
                    let cal = Calendar.current
                    if !didInitializeCustomDates {
                        customSelectedDates = Set(items.map { cal.dateComponents([.year, .month, .day], from: $0.timestamp) })
                        didInitializeCustomDates = true
                    }
                } else {
                    customSelectedDates = []
                    didInitializeCustomDates = false
                }
            }
        } catch {
            print("Error loading series: \(error)")
            items = []
        }
    }

    private func save() {
        // Load current items and ensure we have something to edit
        guard !items.isEmpty else { return }

        let normalizedStart = floorToMinute(startDate)

        // Cancel notifications for all current items first
        Task { await NotificationManager.shared.cancelNotifications(for: items) }

        if repeatFrequency == .custom {
            let cal = Calendar.current
            let now = Date()

            // Compute selected day keys (start of day)
            let selectedKeys: Set<Date> = Set(customSelectedDates.compactMap { dayKey(from: $0, calendar: cal) })

            // Fetch a fresh snapshot of series items
            var currentItems: [Item] = []
            do {
                let descriptor = FetchDescriptor<Item>(
                    predicate: #Predicate<Item> { it in it.parentReminderID == parentID }
                )
                currentItems = try modelContext.fetch(descriptor)
            } catch {
                currentItems = items
            }

            // Identify future items (>= now)
            let futureItems = currentItems.filter { $0.timestamp >= now }

            // Cancel notifications for all future items (they will be replaced)
            Task { await NotificationManager.shared.cancelNotifications(for: futureItems) }

            // Delete all future items
            for it in futureItems { modelContext.delete(it) }

            // Recreate future items exactly matching the selected day keys
            let time = cal.dateComponents([.hour, .minute], from: normalizedStart)
            let newFutureKeys = selectedKeys.filter { $0 >= cal.startOfDay(for: now) }.sorted()

            var toSchedule: [Item] = []
            for key in newFutureKeys {
                var comps = cal.dateComponents([.year, .month, .day], from: key)
                comps.hour = time.hour
                comps.minute = time.minute
                comps.second = 0
                if let scheduled = cal.date(from: comps) {
                    let normalized = floorToMinute(scheduled, calendar: cal)
                    let newItem = Item(
                        timestamp: normalized,
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        repeatFrequency: .custom,
                        parentReminderID: parentID,
                        notificationIntervalMinutes: notificationIntervalMinutes,
                        notificationRepeatCount: notificationRepeatCount,
                        repeatInterval: 1
                    )
                    modelContext.insert(newItem)
                    if !newItem.isCompleted { toSchedule.append(newItem) }
                }
            }

            // Persist changes
            try? modelContext.save()

            // Schedule notifications for new future items
            Task { await NotificationManager.shared.scheduleNotifications(for: toSchedule) }

            dismiss()
            return
        }

        // Sort items by timestamp to maintain order
        var sortedItems = items.sorted { $0.timestamp < $1.timestamp }

        // Determine desired total occurrences (first + future)
        let desiredTotal = futureCount + 1

        // Add or remove items to match desired count
        if sortedItems.count < desiredTotal {
            let toAdd = desiredTotal - sortedItems.count
            for _ in 0..<toAdd {
                let newItem = Item(
                    timestamp: normalizedStart, // placeholder, will set below
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    repeatFrequency: repeatFrequency,
                    parentReminderID: parentID,
                    notificationIntervalMinutes: notificationIntervalMinutes,
                    notificationRepeatCount: notificationRepeatCount,
                    repeatInterval: repeatInterval
                )
                modelContext.insert(newItem)
                sortedItems.append(newItem)
                items.append(newItem)
            }
        } else if sortedItems.count > desiredTotal {
            let excess = sortedItems.count - desiredTotal
            let toDelete = Array(sortedItems.suffix(excess))
            for it in toDelete {
                modelContext.delete(it)
                items.removeAll { $0.id == it.id }
            }
            sortedItems.removeLast(excess)
        }

        // Recompute timestamps for entire series using new start date and interval
        let calendar = Calendar.current
        var currentDate = normalizedStart
        for index in 0..<sortedItems.count {
            let item = sortedItems[index]
            item.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            item.repeatFrequency = repeatFrequency
            item.repeatInterval = repeatInterval
            item.notificationIntervalMinutes = notificationIntervalMinutes
            item.notificationRepeatCount = notificationRepeatCount

            let normalized = floorToMinute(currentDate)
            item.timestamp = normalized

            // Compute next date for next iteration
            if index < sortedItems.count - 1 {
                switch repeatFrequency {
                case .daily:
                    currentDate = calendar.date(byAdding: .day, value: repeatInterval, to: currentDate) ?? currentDate
                case .weekly:
                    currentDate = calendar.date(byAdding: .weekOfYear, value: repeatInterval, to: currentDate) ?? currentDate
                case .monthly:
                    currentDate = calendar.date(byAdding: .month, value: repeatInterval, to: currentDate) ?? currentDate
                case .yearly:
                    currentDate = calendar.date(byAdding: .year, value: repeatInterval, to: currentDate) ?? currentDate
                case .none, .custom:
                    break
                }
            }
        }

        // Reschedule notifications for all non-completed items
        Task {
            let toSchedule = sortedItems.filter { !$0.isCompleted }
            await NotificationManager.shared.scheduleNotifications(for: toSchedule)
        }

        // Persist changes
        try? modelContext.save()
        dismiss()
    }

    @MainActor
    private func deleteSeries() async {
        guard !isDeletingSeries else { return }
        isDeletingSeries = true
        defer { isDeletingSeries = false }

        // Fetch all items in this series
        let descriptor = FetchDescriptor<Item>(
            predicate: #Predicate<Item> { it in it.parentReminderID == parentID }
        )
        var seriesItems: [Item] = []
        do {
            seriesItems = try modelContext.fetch(descriptor)
        } catch {
            seriesItems = items
        }

        // Cancel notifications for all items BEFORE deleting
        await NotificationManager.shared.cancelNotifications(for: seriesItems)

        // Delete all items
        for it in seriesItems {
            modelContext.delete(it)
        }

        // Persist and dismiss
        do {
            try modelContext.save()
            dismiss()
        } catch {
            deleteSeriesErrorMessage = "Failed to delete the series. Please try again."
            showDeleteSeriesError = true
        }
    }
}

// MARK: - Additional Modern Components for EditReminderSeriesView

struct ModernSelectionRow: View {
    let title: String
    let value: String
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private var dynamicTitleSize: CGFloat {
        14 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicValueSize: CGFloat {
        16 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicIconSize: CGFloat {
        12 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicSpacing: CGFloat {
        16 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicPadding: CGFloat {
        max(12, 12 * min(dynamicTypeSize.scaleFactor, 1.3))
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: dynamicSpacing) {
                Text(title)
                    .font(.system(size: dynamicTitleSize, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                
                Spacer()
                
                HStack(spacing: 8 * dynamicTypeSize.scaleFactor) {
                    Text(value)
                        .font(.system(size: dynamicValueSize, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .minimumScaleFactor(0.8)
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: dynamicIconSize, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, dynamicPadding + 4)
            .padding(.vertical, dynamicPadding)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .stroke(.secondary.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: Item.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let ctx = ModelContext(container)
    let parent = UUID().uuidString
    let now = Date()
    let items: [Item] = [0,1,2,3].map { i in
        Item(timestamp: Calendar.current.date(byAdding: .day, value: i, to: now)!, title: "Series", repeatFrequency: .daily, parentReminderID: parent)
    }
    items.forEach { ctx.insert($0) }
    try? ctx.save()
    return NavigationStack { EditReminderSeriesView(parentID: parent) }
        .modelContainer(container)
}

