//
//  ContentView.swift
//  Remind Me
//
//  Created by Oliver Luu on 9/22/25.
//

import SwiftUI
import SwiftData
internal import Combine

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var currentTime = Date()
        
        // Timer that fires every second
        private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

        var body: some View {
            //Displays "Hello, World!" message
            Text("Hello, World!")
                .font(.largeTitle)
                .padding()
            
            VStack {
                Text(formattedTime)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .padding()
            }
            // Update the state every time the timer fires
            .onReceive(timer) { input in
                currentTime = input
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

