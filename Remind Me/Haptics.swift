import SwiftUI
import UIKit

enum HapticLevel: String, CaseIterable {
    case system
    case light
    case medium
    case heavy
    case off
}

enum Haptics {
    private static var currentLevel: HapticLevel {
        let raw = UserDefaults.standard.string(forKey: "settings.hapticsLevel") ?? HapticLevel.system.rawValue
        return HapticLevel(rawValue: raw) ?? .system
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let level = currentLevel
        if level == .off { return }
        let effectiveStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch level {
        case .system:
            effectiveStyle = style
        case .light:
            effectiveStyle = .light
        case .medium:
            effectiveStyle = .medium
        case .heavy:
            effectiveStyle = .heavy
        case .off:
            return
        }
        let generator = UIImpactFeedbackGenerator(style: effectiveStyle)
        generator.prepare()
        generator.impactOccurred()
    }
    
    static func selectionChanged() {
        if currentLevel == .off { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    static func success() {
        if currentLevel == .off { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    static func warning() {
        if currentLevel == .off { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
    
    static func error() {
        if currentLevel == .off { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}

struct HapticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HapticButton(configuration: configuration)
    }
    
    private struct HapticButton: View {
        let configuration: Configuration
        
        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .onChange(of: configuration.isPressed) { oldValue, newValue in
                    if newValue && !oldValue {
                        Haptics.impact(.light)
                    }
                }
        }
    }
}
