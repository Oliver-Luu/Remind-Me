import SwiftUI
import SwiftData

struct TrashView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationManager: NotificationManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @Query(
        filter: #Predicate<Item> { $0.isInDeleteBin },
        sort: [SortDescriptor(\Item.timestamp, order: .reverse)]
    ) private var deletedItems: [Item]
    
    private var dynamicTitleSize: CGFloat { 20 * min(dynamicTypeSize.scaleFactor, 1.3) }
    private var dynamicRowSpacing: CGFloat { 12 * min(dynamicTypeSize.scaleFactor, 1.2) }
    private var dynamicPadding: CGFloat { max(16, 16 * min(dynamicTypeSize.scaleFactor, 1.2)) }
    private var dynamicButtonSize: CGFloat { 14 * min(dynamicTypeSize.scaleFactor, 1.2) }
    
    var body: some View {
        ZStack {
            CrossingRadialBackground(
                colorsA: [
                    Color.gray.opacity(0.15),
                    Color.blue.opacity(0.08),
                    Color.clear
                ],
                colorsB: [
                    Color.purple.opacity(0.12),
                    Color.gray.opacity(0.08),
                    Color.clear
                ],
                startCenterA: .topLeading,
                endCenterA: .bottomTrailing,
                startCenterB: .bottomTrailing,
                endCenterB: .topLeading,
                startRadius: 40,
                endRadius: 350,
                duration: 10,
                autoreverses: true
            )
            
            if deletedItems.isEmpty {
                EmptyTrashState()
                    .padding(.horizontal, 32)
            } else {
                ScrollView {
                    LazyVStack(spacing: dynamicRowSpacing) {
                        ForEach(deletedItems) { item in
                            TrashRow(item: item, restoreAction: { restore(item) }, deleteAction: { delete(item) })
                        }
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, dynamicPadding)
                    .padding(.top, 24)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TitleBarView(
                    title: "Recently Deleted",
                    iconSystemName: "trash",
                    gradientColors: [.gray, .purple],
                    topPadding: 32,
                    fontScale: min(dynamicTypeSize.scaleFactor, 1.0)
                )
            }
        }
    }
    
    private func restore(_ item: Item) {
        withAnimation {
            item.isInDeleteBin = false
            // Only schedule for items that are not completed and in the future
            if !item.isCompleted {
                Task { await notificationManager.scheduleNotification(for: item) }
            }
            try? modelContext.save()
        }
    }
    
    private func delete(_ item: Item) {
        withAnimation {
            // Ensure any pending notifications are cancelled before permanent delete
            Task { await notificationManager.cancelNotification(for: item) }
            modelContext.delete(item)
            try? modelContext.save()
        }
    }
}

private struct TrashRow: View {
    let item: Item
    let restoreAction: () -> Void
    let deleteAction: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private var titleSize: CGFloat { 16 * min(dynamicTypeSize.scaleFactor, 1.3) }
    private var subtitleSize: CGFloat { 13 * min(dynamicTypeSize.scaleFactor, 1.3) }
    private var buttonTextSize: CGFloat { 13 * min(dynamicTypeSize.scaleFactor, 1.2) }
    private var rowPadding: CGFloat { max(14, 14 * min(dynamicTypeSize.scaleFactor, 1.2)) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
                Text(item.title)
                    .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                Spacer()
            }
            
            HStack(spacing: 12) {
                Label {
                    Text(item.timestamp, style: .date)
                        .font(.system(size: subtitleSize))
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Label {
                    Text(item.timestamp, style: .time)
                        .font(.system(size: subtitleSize))
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            HStack(spacing: 10) {
                Button {
                    Haptics.selectionChanged()
                    restoreAction()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.left.circle.fill")
                        Text("Restore")
                    }
                    .font(.system(size: buttonTextSize, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [.green, .blue], startPoint: .leading, endPoint: .trailing))
                    }
                }
                
                Button(role: .destructive) {
                    Haptics.warning()
                    deleteAction()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.system(size: buttonTextSize, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.red)
                    }
                }
            }
        }
        .padding(rowPadding)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        }
    }
}

private struct EmptyTrashState: View {
    @State private var floatIcon = false
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "trash")
                .font(.system(size: 80, weight: .ultraLight))
                .foregroundStyle(LinearGradient(colors: [.gray, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .scaleEffect(floatIcon ? 1.05 : 0.95)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                        floatIcon.toggle()
                    }
                }
            
            VStack(spacing: 8) {
                Text("No recently deleted reminders")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Items you delete will appear here for easy restore.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
    }
}

#Preview {
    NavigationStack { TrashView() }
        .environmentObject(NotificationManager.shared)
        .modelContainer(for: Item.self, inMemory: true)
}
