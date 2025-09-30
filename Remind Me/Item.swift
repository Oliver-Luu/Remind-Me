//
//  Item.swift
//  Remind Me
//
//  Created by Oliver Luu on 9/22/25.
//

import Foundation
import SwiftData

enum RepeatFrequency: String, CaseIterable, Codable {
    case none = "None"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    
    var displayName: String {
        return self.rawValue
    }
}

@Model
final class Item {
    var timestamp: Date
    var title: String
    var repeatFrequency: RepeatFrequency
    var notificationIntervalMinutes: Int
    var notificationRepeatCount: Int
    var isCompleted: Bool
    var parentReminderID: String? // For tracking related repeating reminders
    var id: String // Unique identifier for notifications
    
    init(
        timestamp: Date,
        title: String = "Reminder",
        repeatFrequency: RepeatFrequency = .none,
        parentReminderID: String? = nil,
        notificationIntervalMinutes: Int = 1,
        notificationRepeatCount: Int = 10
    ) {
        self.timestamp = timestamp
        self.title = title
        self.repeatFrequency = repeatFrequency
        self.notificationIntervalMinutes = notificationIntervalMinutes
        self.notificationRepeatCount = notificationRepeatCount
        self.isCompleted = false
        self.parentReminderID = parentReminderID
        self.id = UUID().uuidString
    }
}
