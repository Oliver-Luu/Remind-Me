import SwiftUI

public struct TitleBarView: View {
    public let title: String
    public let iconSystemName: String
    public let gradientColors: [Color]
    public let topPadding: CGFloat
    public let iconScale: CGFloat
    public let fontScale: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(title: String,
                iconSystemName: String,
                gradientColors: [Color],
                topPadding: CGFloat = 32,
                fontScale: CGFloat = 1.0,
                iconScale: CGFloat = 1.5) {
        self.title = title
        self.iconSystemName = iconSystemName
        self.gradientColors = gradientColors
        self.topPadding = topPadding
        self.fontScale = fontScale
        self.iconScale = iconScale
    }

    private var baseFontSize: CGFloat {
        let width = UIScreen.main.bounds.width
        switch width {
        case ..<340:
            return 24
        case ..<390:
            return 28
        case ..<430:
            return 32
        case ..<600:
            return 36
        default:
            return 40
        }
    }
    
    private var autoScale: CGFloat {
        let width = UIScreen.main.bounds.width
        let limit: Int
        switch width {
        case ..<340: limit = 12
        case ..<390: limit = 16
        case ..<430: limit = 18
        case ..<600: limit = 22
        default: limit = 26
        }
        let over = max(0, title.count - limit)
        if over == 0 { return 1.0 }
        else if over <= 6 { return 0.96 }
        else { return 0.92 }
    }
    
    private var dynamicTitleSize: CGFloat {
        baseFontSize * fontScale * autoScale * dynamicTypeSize.scaleFactor
    }
    
    private var dynamicIconSize: CGFloat {
        max(14, dynamicTitleSize * 0.4 * iconScale)
    }
    
    private var dynamicSpacing: CGFloat {
        4 * dynamicTypeSize.scaleFactor
    }

    public var body: some View {
        VStack(spacing: dynamicSpacing) {
            Text(title)
                .font(.system(size: dynamicTitleSize, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .truncationMode(.tail)
                .allowsTightening(true)
            Image(systemName: iconSystemName)
                .font(.system(size: dynamicIconSize, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .padding(.top, topPadding)
    }
}

