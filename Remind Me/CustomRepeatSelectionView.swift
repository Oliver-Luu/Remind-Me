import SwiftUI

struct CustomRepeatSelectionView: View {
    @Binding var selectedDates: Set<DateComponents>
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private var dynamicTitleSize: CGFloat {
        40 * dynamicTypeSize.scaleFactor
    }
    
    private var dynamicIconSize: CGFloat {
        16 * dynamicTypeSize.scaleFactor
    }
    
    private var dynamicSubheadlineSize: CGFloat {
        UIFont.preferredFont(forTextStyle: .subheadline).pointSize * dynamicTypeSize.scaleFactor
    }
    
    private var dynamicSpacing: CGFloat {
        max(4, 4 * dynamicTypeSize.scaleFactor)
    }
    
    private var dynamicSectionSpacing: CGFloat {
        16 * dynamicTypeSize.scaleFactor
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: dynamicSectionSpacing) {
                MultiDatePicker("Select Dates", selection: $selectedDates)
                    .frame(maxHeight: .infinity)
                    .padding()
                
                Text(summaryText)
                    .font(.system(size: dynamicSubheadlineSize))
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: dynamicSpacing) {
                        Text("Select Dates")
                            .font(.system(size: dynamicTitleSize, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Image(systemName: "calendar")
                            .font(.system(size: dynamicIconSize, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 32)
                }
            }
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
