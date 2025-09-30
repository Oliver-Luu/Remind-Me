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
    case custom = "Custom"
    
    var displayName: String {
        return self.rawValue
    }

    func unitName(for count: Int) -> String {
        switch self {
        case .none: return count == 1 ? "time" : "times"
        case .daily: return count == 1 ? "day" : "days"
        case .weekly: return count == 1 ? "week" : "weeks"
        case .monthly: return count == 1 ? "month" : "months"
        case .yearly: return count == 1 ? "year" : "years"
        case .custom: return count == 1 ? "date" : "dates"
        }
    }
    
    func display(interval: Int) -> String {
        switch self {
        case .custom:
            return "Custom"
        default:
            if interval <= 1 { return self.displayName }
            return "Every \(interval) \(unitName(for: interval))"
        }
    }
}

@Model
final class Item {
    var timestamp: Date
    var title: String
    var repeatFrequency: RepeatFrequency
    var repeatInterval: Int
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
        notificationRepeatCount: Int = 10,
        repeatInterval: Int = 1
    ) {
        self.timestamp = timestamp
        self.title = title
        self.repeatFrequency = repeatFrequency
        self.repeatInterval = repeatInterval
        self.notificationIntervalMinutes = notificationIntervalMinutes
        self.notificationRepeatCount = notificationRepeatCount
        self.isCompleted = false
        self.parentReminderID = parentReminderID
        self.id = UUID().uuidString
    }
}
