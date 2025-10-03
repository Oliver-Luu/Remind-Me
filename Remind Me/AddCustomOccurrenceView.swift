import SwiftUI
import SwiftData

struct AddCustomOccurrenceView: View {
    let parentID: String
    let templateItem: Item?
    @Binding var customDate: Date
    let onSave: (Item) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTime = Date()
    @State private var showingDuplicateAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header section
                VStack(spacing: 6) {
                    Text("Add Custom Occurrence")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    if let template = templateItem {
                        Text("for \"\(template.title)\"")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal)
                
                // Date selection section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Date & Time")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // Quick selection buttons
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            Button("Today") {
                                setDateToToday()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button("Tomorrow") {
                                setDateToTomorrow()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button("Next Week") {
                                setDateToNextWeek()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Date picker with custom styling
                    DatePicker(
                        "",
                        selection: $customDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding(.horizontal)
                }
                
                // Bottom button section
                VStack(spacing: 12) {
                    Button("Add Reminder") {
                        addCustomOccurrence()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .controlSize(.large)
                    .disabled(templateItem == nil)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .controlSize(.large)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 4) {
                    Text("Add Occurrence")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 16, weight: .medium))
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

