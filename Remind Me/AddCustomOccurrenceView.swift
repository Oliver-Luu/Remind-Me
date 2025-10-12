import SwiftUI
import SwiftData

struct AddCustomOccurrenceView: View {
    let parentID: String
    let templateItem: Item?
    @Binding var customDate: Date
    let onSave: (Item) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @State private var selectedTime = Date()
    @State private var showingDuplicateAlert = false
    
    // Dynamic Type scaling properties
    private var dynamicTitleSize: CGFloat {
        UIFont.preferredFont(forTextStyle: .headline).pointSize * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicSpacing: CGFloat {
        max(12, 12 * min(dynamicTypeSize.scaleFactor, 1.3))
    }
    
    private var dynamicSectionSpacing: CGFloat {
        20 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicTopPadding: CGFloat {
        32 * dynamicTypeSize.scaleFactor
    }
    
    private var dynamicHorizontalPadding: CGFloat {
        20 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicToolbarTitleSize: CGFloat {
        40 * min(dynamicTypeSize.scaleFactor, 1.1)
    }
    
    private var dynamicToolbarIconSize: CGFloat {
        16 * min(dynamicTypeSize.scaleFactor, 1.1)
    }
    
    private var dynamicToolbarSpacing: CGFloat {
        max(4, 4 * min(dynamicTypeSize.scaleFactor, 1.3))
    }
    
    private var dynamicButtonPadding: CGFloat {
        max(12, 12 * min(dynamicTypeSize.scaleFactor, 1.3))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: dynamicSectionSpacing) {
                // Date selection section
                VStack(alignment: .leading, spacing: dynamicSpacing) {
                    Text("Select Date & Time")
                        .padding(.top, dynamicTopPadding)
                        .font(.system(size: dynamicTitleSize, weight: .semibold))
                        .padding(.horizontal, dynamicHorizontalPadding)
                    
                    // Quick selection buttons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: dynamicSpacing) {
                    Button("Today") {
                        setDateToToday()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.system(size: UIFont.preferredFont(forTextStyle: .footnote).pointSize * min(dynamicTypeSize.scaleFactor, 1.2)))
                    
                    Button("Tomorrow") {
                        setDateToTomorrow()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.system(size: UIFont.preferredFont(forTextStyle: .footnote).pointSize * min(dynamicTypeSize.scaleFactor, 1.2)))
                    
                    Button("Next Week") {
                        setDateToNextWeek()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .font(.system(size: UIFont.preferredFont(forTextStyle: .footnote).pointSize * min(dynamicTypeSize.scaleFactor, 1.2)))
                        }
                        .padding(.horizontal, dynamicHorizontalPadding)
                    }
                    
                    // Date picker with custom styling
                    DatePicker(
                        "",
                        selection: $customDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding(.horizontal, dynamicHorizontalPadding)
                }
                
                // Bottom button section
                VStack(spacing: dynamicSpacing) {
                    Button("Add Reminder") {
                        addCustomOccurrence()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .controlSize(.large)
                    .disabled(templateItem == nil)
                    .font(.system(size: UIFont.preferredFont(forTextStyle: .body).pointSize * min(dynamicTypeSize.scaleFactor, 1.2)))
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .controlSize(.large)
                    .font(.system(size: UIFont.preferredFont(forTextStyle: .body).pointSize * min(dynamicTypeSize.scaleFactor, 1.2)))
                }
                .padding(.horizontal, dynamicHorizontalPadding)
                .padding(.bottom, dynamicButtonPadding)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: dynamicToolbarSpacing) {
                    Text("Add Occurrence")
                        .font(.system(size: dynamicToolbarTitleSize, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: dynamicToolbarIconSize, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.teal, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(.top, 32)
            }
        }
        .alert("Duplicate Reminder", isPresented: $showingDuplicateAlert) {
            Button("OK") { }
        } message: {
            Text("A reminder already exists at this date and time. Please choose a different time.")
        }
        .onAppear {
            // Initialize with a sensible default time
            if let template = templateItem {
                let calendar = Calendar.current
                let templateTime = calendar.dateComponents([.hour, .minute], from: template.timestamp)
                customDate = calendar.date(bySettingHour: templateTime.hour ?? 9, 
                                         minute: templateTime.minute ?? 0, 
                                         second: 0, 
                                         of: customDate) ?? customDate
            }
        }
    }
    
    private func addCustomOccurrence() {
        guard let template = templateItem else { return }
        
        // Check if an occurrence already exists at this exact date/time
        let existingDescriptor = FetchDescriptor<Item>(
            predicate: #Predicate<Item> { item in
                item.parentReminderID == parentID && item.timestamp == customDate
            }
        )
        
        // Check for existing occurrence
        do {
            let existingItems = try modelContext.fetch(existingDescriptor)
            if !existingItems.isEmpty {
                showingDuplicateAlert = true
                return
            }
        } catch {
            print("Error checking for existing occurrences: \(error)")
        }
        
        // Create new occurrence based on the template
        let newItem = Item(
            timestamp: customDate,
            title: template.title,
            repeatFrequency: template.repeatFrequency,
            parentReminderID: template.parentReminderID,
            notificationIntervalMinutes: template.notificationIntervalMinutes,
            notificationRepeatCount: template.notificationRepeatCount,
            repeatInterval: template.repeatInterval
        )
        
        // Schedule notification for the new reminder
        Task {
            await NotificationManager.shared.scheduleNotification(for: newItem)
        }
        
        onSave(newItem)
    }
    
    private func setDateToToday() {
        guard let template = templateItem else { return }
        let calendar = Calendar.current
        let templateTime = calendar.dateComponents([.hour, .minute], from: template.timestamp)
        customDate = calendar.date(bySettingHour: templateTime.hour ?? 9, 
                                 minute: templateTime.minute ?? 0, 
                                 second: 0, 
                                 of: Date()) ?? Date()
    }
    
    private func setDateToTomorrow() {
        guard let template = templateItem else { return }
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let templateTime = calendar.dateComponents([.hour, .minute], from: template.timestamp)
        customDate = calendar.date(bySettingHour: templateTime.hour ?? 9, 
                                 minute: templateTime.minute ?? 0, 
                                 second: 0, 
                                 of: tomorrow) ?? tomorrow
    }
    
    private func setDateToNextWeek() {
        guard let template = templateItem else { return }
        let calendar = Calendar.current
        let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
        let templateTime = calendar.dateComponents([.hour, .minute], from: template.timestamp)
        customDate = calendar.date(bySettingHour: templateTime.hour ?? 9, 
                                 minute: templateTime.minute ?? 0, 
                                 second: 0, 
                                 of: nextWeek) ?? nextWeek
    }
}

#Preview {
    let container = try! ModelContainer(for: Item.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let ctx = ModelContext(container)
    let template = Item(timestamp: Date(), title: "Take Medicine", repeatFrequency: .daily)
    ctx.insert(template)
    try? ctx.save()
    
    return NavigationStack {
        AddCustomOccurrenceView(
            parentID: "sample-parent-id",
            templateItem: template,
            customDate: .constant(Date())
        ) { _ in }
    }
    .modelContainer(container)
}

