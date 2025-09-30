// Global constants for notification management compatibility
// This keeps existing code working while we migrate to per-reminder settings.

import Foundation

// Used by NotificationManager.stopAllPersistentNotifications() legacy implementation
let maxPersistentNotifications: Int = 10
