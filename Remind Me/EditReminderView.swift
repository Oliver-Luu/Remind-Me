import SwiftUI
import SwiftData

struct EditReminderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var inAppNotificationManager: InAppNotificationManager

    let item: Item
    @State private var date: Date
    @State private var title: String
    @State private var repeatFrequency: RepeatFrequency
    @State private var repeatInterval: Int
    @State private var isCompleted: Bool
    @State private var notificationIntervalMinutes: Int
    @State private var notificationRepeatCount: Int
    @State private var futureCount: Int = 7
    @State private var showingEditOptionsAlert = false
    @State private var animateGradient = false
    
    @State private var showCustomDatePicker = false
    @State private var customSelectedDates: Set<DateComponents> = []
    
    @State private var showInvalidDateAlert = false
    @State private var invalidDateMessage = ""
    
    init(item: Item) {
        self.item = item
        self._date = State(initialValue: item.timestamp)
        self._title = State(initialValue: item.title)
        self._repeatFrequency = State(initialValue: item.repeatFrequency)
        self._repeatInterval = State(initialValue: item.repeatInterval)
        self._isCompleted = State(initialValue: item.isCompleted)
        self._notificationIntervalMinutes = State(initialValue: item.notificationIntervalMinutes)
        self._notificationRepeatCount = State(initialValue: item.notificationRepeatCount)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dynamic animated background
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.purple.opacity(0.2),
                        Color.blue.opacity(0.15),
                        Color.clear
                    ]),
                    center: animateGradient ? .topTrailing : .bottomLeading,
                    startRadius: 30,
                    endRadius: 300
                )
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 9)
                        .repeatForever(autoreverses: true)
                    ) {
                        animateGradient.toggle()
                    }
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header Section
                        VStack(spacing: 8) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 40, weight: .light))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("Edit Reminder")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .padding(.top, 8)
                        
                        // Form sections with glass effect
                        VStack(spacing: 20) {
                            // Reminder Details Section
                            ModernFormSection(title: "Reminder Details") {
                                VStack(spacing: 16) {
                                    ModernTextField(title: "Reminder Title", text: $title)
                                    
                                    if repeatFrequency == .custom {
                                        ModernDatePicker(
                                            title: "Select Time",
                                            selection: $date,
                                            displayedComponents: [.hourAndMinute]
                                        )
                                    } else {
                                        ModernDatePicker(
                                            title: "Select Date and Time",
                                            selection: $date,
                                            displayedComponents: [.date, .hourAndMinute]
                                        )
                                    }
                                }
                            }
                            
                            // Status Section
                            ModernFormSection(title: "Status") {
                                ModernToggleRow(
                                    title: "Mark as Completed",
                                    isOn: $isCompleted,
                                    icon: isCompleted ? "checkmark.circle.fill" : "circle"
                                )
                            }
                            
                            // Repeat Options Section
                            ModernFormSection(title: "Repeat Options") {
                                VStack(spacing: 16) {
                                    if item.parentReminderID == nil {
                                        ModernPicker(
                                            title: "Repeat",
                                            selection: $repeatFrequency,
                                            options: RepeatFrequency.allCases
                                        ) { frequency in
                                            Text(frequency.displayName).tag(frequency)
                                        }
                                        
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
                                        }
                                        
                                        if repeatFrequency != .none && repeatFrequency != .custom {
                                            ModernStepper(
                                                title: "Interval",
                                                value: $repeatInterval,
                                                range: 1...52,
                                                suffix: repeatFrequency.unitName(for: repeatInterval)
                                            )
                                            
                                            ModernStepper(
                                                title: "Future occurrences",
                                                value: $futureCount,
                                                range: 0...200,
                                                suffix: "occurrence\(futureCount == 1 ? "" : "s")"
                                            )
                                            
                                            ModernStatusRow(
                                                icon: "info.circle",
                                                iconColor: .blue,
                                                text: "Will create \(futureCount) additional reminders"
                                            )
                                        }
                                        
                                        if repeatFrequency == .none {
                                            ModernStatusRow(
                                                icon: "info.circle",
                                                iconColor: .gray,
                                                text: "This will be a one-time reminder"
                                            )
                                        }
                                    } else {
                                        ModernInfoRow(
                                            title: "Repeats",
                                            value: item.repeatFrequency.displayName
                                        )
                                        
                                        ModernStatusRow(
                                            icon: "info.circle",
                                            iconColor: .blue,
                                            text: "Repeat options are managed by the series and can't be changed on a single occurrence."
                                        )
                                    }
                                }
                            }
                            
                            // Notification Options Section
                            ModernFormSection(title: "Notification Options") {
                                VStack(spacing: 16) {
                                    ModernPicker(
                                        title: "Follow-up interval",
                                        selection: $notificationIntervalMinutes,
                                        options: [1, 2, 5, 10, 15, 30]
                                    ) { minutes in
                                        Text("\(minutes) min").tag(minutes)
                                    }
                                    
                                    ModernStepper(
                                        title: "Follow-up count",
                                        value: $notificationRepeatCount,
                                        range: 0...30,
                                        suffix: "follow-up\(notificationRepeatCount == 1 ? "" : "s")"
                                    )
                                    
                                    if notificationRepeatCount == 0 {
                                        ModernStatusRow(
                                            icon: "info.circle",
                                            iconColor: .blue,
                                            text: "Only the initial notification will be sent"
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                    .frame(minHeight: geometry.size.height - 100)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.secondary)
            }
            
            if hasChanges {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                    .foregroundColor(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .purple)
                }
            }
            
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) {
                    Task {
                        await NotificationManager.shared.handleReminderDeleted(item)
                    }
                    modelContext.delete(item)
                    try? modelContext.save()
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                }
            }
        }
        .alert("Edit Repeating Reminder", isPresented: $showingEditOptionsAlert) {
            Button("Edit This Only") {
                saveChangesThisOnly()
            }
            Button("Edit All in Series") {
                saveChangesAllInSeries()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Do you want to edit only this reminder or all reminders in the series?")
        }
        .sheet(isPresented: $showCustomDatePicker) {
            CustomRepeatSelectionView(selectedDates: $customSelectedDates)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert("Invalid Date/Time", isPresented: $showInvalidDateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(invalidDateMessage)
        }
    }
    
    private var hasChanges: Bool {
        return item.timestamp != date ||
               item.title != title.trimmingCharacters(in: .whitespacesAndNewlines) ||
               item.repeatFrequency != repeatFrequency ||
               item.repeatInterval != repeatInterval ||
               item.isCompleted != isCompleted ||
               item.notificationIntervalMinutes != notificationIntervalMinutes ||
               item.notificationRepeatCount != notificationRepeatCount
    }
    
    private func saveChanges() {
        // If this is part of a repeating series and we're changing repeat frequency,
        // ask the user what they want to do
        if item.parentReminderID != nil && item.repeatFrequency != repeatFrequency {
            showingEditOptionsAlert = true
        } else {
            saveChangesThisOnly()
        }
    }
    
    private func saveChangesThisOnly() {
        Task {
            let now = Date()
            let normalizedDate = floorToMinute(date)

            if item.parentReminderID == nil {
                // One-time reminder being edited
                if normalizedDate < now {
                    invalidDateMessage = "The selected date/time is in the past. Please choose a future time."
                    showInvalidDateAlert = true
                    return
                }
            } else {
                // Part of a series: allow editing this occurrence only if not moving it into the past relative to now
                if normalizedDate < now {
                    invalidDateMessage = "You can't set this occurrence in the past. Pick a future time."
                    showInvalidDateAlert = true
                    return
                }
            }
            
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let wasOneTime = (item.parentReminderID == nil && item.repeatFrequency == .none)
            let willBeRepeating = (repeatFrequency != .none)
            
            if wasOneTime && repeatFrequency == .custom {
                let parentID = UUID().uuidString
                item.timestamp = normalizedDate
                item.title = trimmedTitle
                item.repeatFrequency = .custom
                item.repeatInterval = 1
                item.notificationIntervalMinutes = notificationIntervalMinutes
                item.notificationRepeatCount = notificationRepeatCount
                item.parentReminderID = parentID
                item.isCompleted = isCompleted

                var toSchedule: [Item] = []
                if !item.isCompleted { toSchedule.append(item) }

                let calendar = Calendar.current
                let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: normalizedDate)
                let sortedDates = customSelectedDates.sorted { lhs, rhs in
                    let l = calendar.date(from: lhs) ?? Date.distantPast
                    let r = calendar.date(from: rhs) ?? Date.distantPast
                    return l < r
                }

                for dayComponents in sortedDates {
                    var comps = dayComponents
                    comps.hour = timeComponents.hour
                    comps.minute = timeComponents.minute
                    comps.second = timeComponents.second
                    if let scheduledDate = calendar.date(from: comps) {
                        if scheduledDate == item.timestamp { continue }
                        let normalized = floorToMinute(scheduledDate)
                        let newItem = Item(
                            timestamp: normalized,
                            title: trimmedTitle,
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

                try? modelContext.save()
                // Schedule precise in-app triggers for newly created items
                for it in toSchedule { inAppNotificationManager.scheduleInAppTrigger(for: it) }
                await NotificationManager.shared.scheduleNotifications(for: toSchedule)
            } else if wasOneTime && willBeRepeating {
                // Convert to a repeating series: assign a parent ID to this item and create future occurrences
                let parentID = UUID().uuidString

                // Update the current item to be the first in the series
                item.timestamp = normalizedDate
                item.title = trimmedTitle
                item.repeatFrequency = repeatFrequency
                item.repeatInterval = repeatInterval
                item.notificationIntervalMinutes = notificationIntervalMinutes
                item.notificationRepeatCount = notificationRepeatCount
                item.parentReminderID = parentID
                item.isCompleted = isCompleted

                var toSchedule: [Item] = []
                if !item.isCompleted { toSchedule.append(item) }

                // Create future occurrences based on chosen count
                var lastDate = normalizedDate
                let calendar = Calendar.current
                for _ in 0..<futureCount {
                    let nextDate: Date
                    switch repeatFrequency {
                    case .daily:
                        nextDate = calendar.date(byAdding: .day, value: repeatInterval, to: lastDate) ?? lastDate
                    case .weekly:
                        nextDate = calendar.date(byAdding: .weekOfYear, value: repeatInterval, to: lastDate) ?? lastDate
                    case .monthly:
                        nextDate = calendar.date(byAdding: .month, value: repeatInterval, to: lastDate) ?? lastDate
                    case .yearly:
                        nextDate = calendar.date(byAdding: .year, value: repeatInterval, to: lastDate) ?? lastDate
                    case .none, .custom:
                        nextDate = lastDate
                    }

                    let normalizedNextDate = floorToMinute(nextDate)
                    let newItem = Item(
                        timestamp: normalizedNextDate,
                        title: trimmedTitle,
                        repeatFrequency: repeatFrequency,
                        parentReminderID: parentID,
                        notificationIntervalMinutes: notificationIntervalMinutes,
                        notificationRepeatCount: notificationRepeatCount,
                        repeatInterval: repeatInterval
                    )
                    modelContext.insert(newItem)
                    if !newItem.isCompleted { toSchedule.append(newItem) }
                    lastDate = nextDate
                }

                try? modelContext.save()
                // Schedule precise in-app triggers for the first and all new items
                for it in toSchedule { inAppNotificationManager.scheduleInAppTrigger(for: it) }
                // Schedule notifications for all items in the new series
                await NotificationManager.shared.scheduleNotifications(for: toSchedule)
            } else {
                // Update the item without series conversion
                item.timestamp = normalizedDate
                item.title = trimmedTitle
                if item.parentReminderID == nil { item.repeatFrequency = repeatFrequency }
                item.notificationIntervalMinutes = notificationIntervalMinutes
                item.notificationRepeatCount = notificationRepeatCount
                item.repeatInterval = repeatInterval

                // Handle completion status change
                if item.isCompleted != isCompleted {
                    item.isCompleted = isCompleted
                    if isCompleted {
                        await NotificationManager.shared.handleReminderCompleted(item)
                    }
                }

                // If not completed, reschedule notifications
                if !item.isCompleted {
                    await NotificationManager.shared.scheduleNotification(for: item)
                    inAppNotificationManager.scheduleInAppTrigger(for: item)
                }

                try? modelContext.save()
            }

            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func saveChangesAllInSeries() {
        Task {
            let now = Date()
            let normalizedDate = floorToMinute(date)
            if normalizedDate < now {
                invalidDateMessage = "The selected date/time is in the past for the series. Please choose a future time."
                showInvalidDateAlert = true
                return
            }
            
            // Get all related reminders
            let relatedReminders = getRelatedReminders(for: item, modelContext: modelContext)
            
            // Cancel notifications for all related reminders
            await NotificationManager.shared.cancelNotifications(for: relatedReminders)
            
            let timeDifference = normalizedDate.timeIntervalSince(item.timestamp)
            let titleChange = title.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Update all related reminders
            for reminder in relatedReminders {
                reminder.title = titleChange
                let shifted = reminder.timestamp.addingTimeInterval(timeDifference)
                reminder.timestamp = floorToMinute(shifted)
                // reminder.repeatFrequency = repeatFrequency  // Removed as per instructions
                reminder.repeatInterval = repeatInterval
                reminder.notificationIntervalMinutes = notificationIntervalMinutes
                reminder.notificationRepeatCount = notificationRepeatCount
                
                // Don't change completion status for other reminders in the series
                if reminder.id == item.id {
                    reminder.isCompleted = isCompleted
                }
                
                // Reschedule if not completed
                if !reminder.isCompleted {
                    await NotificationManager.shared.scheduleNotification(for: reminder)
                    inAppNotificationManager.scheduleInAppTrigger(for: reminder)
                }
            }
            
            try? modelContext.save()
            
            await MainActor.run {
                dismiss()
            }
        }
    }
}

// MARK: - Additional Modern Components for EditReminderView

struct ModernToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isOn ? .green : .secondary)
                .frame(width: 24, height: 24)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .stroke(.secondary.opacity(0.3), lineWidth: 1)
        }
    }
}

struct ModernInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .stroke(.secondary.opacity(0.3), lineWidth: 1)
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: Item.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let sampleItem = Item(
        timestamp: Date().addingTimeInterval(3600),
        title: "Take medication",
        repeatFrequency: .daily
    )
    
    return NavigationStack {
        EditReminderView(item: sampleItem)
    }
    .modelContainer(container)
}
