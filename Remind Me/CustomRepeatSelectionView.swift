import SwiftUI

struct CustomRepeatSelectionView: View {
    @Binding var selectedDates: Set<DateComponents>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                MultiDatePicker("Select Dates", selection: $selectedDates)
                    .frame(maxHeight: .infinity)
                    .padding()
                
                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }
            .navigationTitle("Select Dates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { selectedDates.removeAll() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Normalize to day-only components before passing back
                        let normalized: Set<DateComponents> = Set(selectedDates.map { comps in
                            DateComponents(year: comps.year, month: comps.month, day: comps.day)
                        })
                        if normalized != selectedDates {
                            selectedDates = normalized
                        }
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Ensure all components are day-only and share the same calendar/time zone for proper equality
            let normalized: Set<DateComponents> = Set(selectedDates.map { comps in
                var c = DateComponents()
                c.calendar = Calendar.current
                c.timeZone = TimeZone.current
                c.year = comps.year
                c.month = comps.month
                c.day = comps.day
                return c
            })
            if normalized != selectedDates {
                selectedDates = normalized
            }
        }
    }
    
    private var summaryText: String {
        let count = selectedDates.count
        if count == 0 { return "No dates selected" }
        if count == 1 { return "1 date selected" }
        return "\(count) dates selected"
    }
}

#Preview {
    @Previewable @State var dates: Set<DateComponents> = []
    CustomRepeatSelectionView(selectedDates: $dates)
}
