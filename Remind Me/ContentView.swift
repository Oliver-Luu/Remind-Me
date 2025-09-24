//
//  ContentView.swift
//  Remind Me
//
//  Created by Oliver Luu on 9/22/25.
//

import SwiftUI
import SwiftData
import Combine

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var currentTime = Date()
    @State private var isTicking = true
        
    // Timer that fires every second
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Remind Me")
                    .font(.system(size: 56, weight: .bold, design: .monospaced))
                    .padding(.top, 46)

                Text(formattedTime)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .padding(.top, 4)
                
                Spacer()

                VStack(spacing: 16) {
                    NavigationLink("My Reminders") {
                        RemindersListView()
                    }
                    .buttonStyle(.bordered)
                    .frame(minWidth: 240)

                    NavigationLink("Add Reminder") {
                        AddReminderView()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(minWidth: 240)
                    
                }
                .font(.title2)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Update the state every time the timer fires
            .onReceive(timer) { input in
                if isTicking {
                    currentTime = input
                }
            }
        }
    }

    // Computed property to format time
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss" // 24-hour format
        return formatter.string(from: currentTime)
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
