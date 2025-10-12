import SwiftUI

public struct AnimatedRadialBackground: View {
    public var colors: [Color]
    public var startCenter: UnitPoint = .topLeading
    public var endCenter: UnitPoint = .bottomTrailing
    public var startRadius: CGFloat = 40
    public var endRadius: CGFloat = 350
    public var duration: Double = 10
    public var autoreverses: Bool = true

    @State private var animate = false

    public init(
        colors: [Color],
        startCenter: UnitPoint = .topLeading,
        endCenter: UnitPoint = .bottomTrailing,
        startRadius: CGFloat = 40,
        endRadius: CGFloat = 350,
        duration: Double = 10,
        autoreverses: Bool = true
    ) {
        self.colors = colors
        self.startCenter = startCenter
        self.endCenter = endCenter
        self.startRadius = startRadius
        self.endRadius = endRadius
        self.duration = duration
        self.autoreverses = autoreverses
    }

    public var body: some View {
        RadialGradient(
            gradient: Gradient(colors: colors),
            center: animate ? endCenter : startCenter,
            startRadius: startRadius,
            endRadius: endRadius
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: autoreverses)
            ) {
                animate.toggle()
            }
        }
    }
}

public struct CrossingRadialBackground: View {
    public var colorsA: [Color]
    public var colorsB: [Color]
    public var startCenterA: UnitPoint
    public var endCenterA: UnitPoint
    public var startCenterB: UnitPoint
    public var endCenterB: UnitPoint
    public var startRadius: CGFloat
    public var endRadius: CGFloat
    public var duration: Double
    public var autoreverses: Bool

    @State private var animate = false

    public init(
        colorsA: [Color],
        colorsB: [Color],
        startCenterA: UnitPoint,
        endCenterA: UnitPoint,
        startCenterB: UnitPoint,
        endCenterB: UnitPoint,
        startRadius: CGFloat,
        endRadius: CGFloat,
        duration: Double = 10,
        autoreverses: Bool = true
    ) {
        self.colorsA = colorsA
        self.colorsB = colorsB
        self.startCenterA = startCenterA
        self.endCenterA = endCenterA
        self.startCenterB = startCenterB
        self.endCenterB = endCenterB
        self.startRadius = startRadius
        self.endRadius = endRadius
        self.duration = duration
        self.autoreverses = autoreverses
    }

    public var body: some View {
        ZStack {
            RadialGradient(
                gradient: Gradient(colors: colorsA),
                center: animate ? endCenterA : startCenterA,
                startRadius: startRadius,
                endRadius: endRadius
            )
            RadialGradient(
                gradient: Gradient(colors: colorsB),
                center: animate ? endCenterB : startCenterB,
                startRadius: startRadius,
                endRadius: endRadius
            )
            .blendMode(.plusLighter)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: autoreverses)
            ) {
                animate.toggle()
            }
        }
    }
}

public extension View {
    func modernGlassCard(
        cornerRadius: CGFloat = 16,
        material: Material = .regularMaterial,
        shadowColor: Color = .black.opacity(0.05),
        shadowRadius: CGFloat = 8,
        shadowX: CGFloat = 0,
        shadowY: CGFloat = 4,
        strokeColor: Color = .white,
        strokeOpacity: Double = 0.0,
        strokeWidth: CGFloat = 1
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(material)
                    .shadow(color: shadowColor, radius: shadowRadius, x: shadowX, y: shadowY)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(strokeColor.opacity(strokeOpacity), lineWidth: strokeWidth)
                    )
            )
    }
}

public struct GradientButton: View {
    public var title: String
    public var systemImage: String?
    public var colors: [Color]
    public var cornerRadius: CGFloat
    public var shadow: Color?
    public var symbolSize: CGFloat?
    public var action: () -> Void

    @State private var isPressed = false

    public init(
        title: String,
        systemImage: String? = nil,
        colors: [Color],
        cornerRadius: CGFloat = 16,
        shadow: Color? = nil,
        symbolSize: CGFloat? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.colors = colors
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.symbolSize = symbolSize
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .ifLet(symbolSize) { view, size in
                            view.font(.system(size: size, weight: .semibold))
                        }
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .shadow(color: shadow ?? .clear, radius: shadow == nil ? 0 : 12, x: 0, y: 6)
        }
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeInOut(duration: 0.08)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.08)) {
                        isPressed = false
                    }
                }
        )
        .buttonStyle(HapticButtonStyle())
    }
}

public struct GradientIcon: View {
    public var systemName: String
    public var size: CGFloat = 32
    public var colors: [Color]

    public init(systemName: String, size: CGFloat = 32, colors: [Color]) {
        self.systemName = systemName
        self.size = size
        self.colors = colors
    }

    public var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .light))
            .foregroundStyle(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

public enum ModernDateFormatters {
    public static let mediumDateShortTime: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    public static let fullDate: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .full
        df.timeStyle = .none
        return df
    }()

    public static let timeOnly: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .short
        return df
    }()
}

public func conciseRelativeDateTime(_ date: Date) -> String {
    let calendar = Calendar.current

    if calendar.isDateInToday(date) {
        let time = ModernDateFormatters.timeOnly.string(from: date)
        return "Today \(time)"
    } else if calendar.isDateInTomorrow(date) {
        let time = ModernDateFormatters.timeOnly.string(from: date)
        return "Tomorrow \(time)"
    } else {
        return ModernDateFormatters.mediumDateShortTime.string(from: date)
    }
}

// MARK: - Modern Form Components (Merged)

struct ModernFormSection<Content: View>: View {
    let title: String
    let content: Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    private var dynamicTitleSize: CGFloat {
        20 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicSpacing: CGFloat {
        16 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicPadding: CGFloat {
        20 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: dynamicSpacing) {
            Text(title)
                .font(.system(size: dynamicTitleSize, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 12 * dynamicTypeSize.scaleFactor) {
                content
            }
            .padding(dynamicPadding)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
            }
        }
    }
}

struct ModernTextField: View {
    let title: String
    @Binding var text: String
    var centered: Bool = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private var dynamicTitleSize: CGFloat {
        14 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicTextSize: CGFloat {
        16 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicSpacing: CGFloat {
        8 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicPadding: CGFloat {
        max(12, 12 * min(dynamicTypeSize.scaleFactor, 1.3))
    }
    
    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: dynamicSpacing) {
            Text(title)
                .font(.system(size: dynamicTitleSize, weight: .medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
            
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: dynamicTextSize, weight: .medium))
                .multilineTextAlignment(centered ? .center : .leading)
                .padding(.horizontal, dynamicPadding + 4)
                .padding(.vertical, dynamicPadding)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .stroke(.secondary.opacity(0.3), lineWidth: 1)
                }
        }
    }
}

struct ModernDatePicker: View {
    let title: String
    @Binding var selection: Date
    let displayedComponents: DatePickerComponents
    var centered: Bool = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private var dynamicTitleSize: CGFloat {
        14 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicSpacing: CGFloat {
        8 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicPadding: CGFloat {
        max(12, 12 * min(dynamicTypeSize.scaleFactor, 1.3))
    }
    
    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: dynamicSpacing) {
            Text(title)
                .font(.system(size: dynamicTitleSize, weight: .medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
            
            HStack {
                Spacer()
                DatePicker("", selection: $selection, displayedComponents: displayedComponents)
                    .datePickerStyle(.compact)
                    .onChange(of: selection) { _, _ in
                        Haptics.selectionChanged()
                    }
                    .fixedSize()
                Spacer()
            }
            .padding(.horizontal, dynamicPadding + 4)
            .padding(.vertical, dynamicPadding)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .stroke(.secondary.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

struct ModernPicker<T: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: T
    let options: [T]
    let content: (T) -> Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    init(title: String, selection: Binding<T>, options: [T], @ViewBuilder content: @escaping (T) -> Content) {
        self.title = title
        self._selection = selection
        self.options = options
        self.content = content
    }
    
    private var dynamicTitleSize: CGFloat {
        14 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicSpacing: CGFloat {
        8 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicPadding: CGFloat {
        max(12, 12 * min(dynamicTypeSize.scaleFactor, 1.3))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: dynamicSpacing) {
            Text(title)
                .font(.system(size: dynamicTitleSize, weight: .medium))
                .foregroundColor(.secondary)
            
            Picker("", selection: $selection) {
                ForEach(options, id: \ .self) { option in
                    content(option)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selection) { _, _ in
                Haptics.selectionChanged()
            }
            .padding(.horizontal, dynamicPadding + 4)
            .padding(.vertical, dynamicPadding)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .stroke(.secondary.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

struct ModernCenteredPicker<T: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: T
    let options: [T]
    let content: (T) -> Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    init(title: String, selection: Binding<T>, options: [T], @ViewBuilder content: @escaping (T) -> Content) {
        self.title = title
        self._selection = selection
        self.options = options
        self.content = content
    }
    
    private var dynamicTitleSize: CGFloat {
        14 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicSpacing: CGFloat {
        8 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicPadding: CGFloat {
        max(12, 12 * min(dynamicTypeSize.scaleFactor, 1.3))
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: dynamicSpacing) {
            Text(title)
                .font(.system(size: dynamicTitleSize, weight: .medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Picker("", selection: $selection) {
                ForEach(options, id: \ .self) { option in
                    content(option)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selection) { _, _ in
                Haptics.selectionChanged()
            }
            .padding(.horizontal, dynamicPadding + 4)
            .padding(.vertical, dynamicPadding)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .stroke(.secondary.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

struct ModernStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let suffix: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    init(title: String, value: Binding<Int>, range: ClosedRange<Int>, suffix: String? = nil) {
        self.title = title
        self._value = value
        self.range = range
        self.suffix = suffix
    }
    
    private var dynamicTitleSize: CGFloat {
        14 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicSpacing: CGFloat {
        8 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicPadding: CGFloat {
        max(12, 12 * min(dynamicTypeSize.scaleFactor, 1.3))
    }
    
    private var dynamicButtonSize: CGFloat {
        max(32, 32 * min(dynamicTypeSize.scaleFactor, 1.2)) // Cap scaling for buttons
    }
    
    private var dynamicValueSize: CGFloat {
        18 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicSuffixSize: CGFloat {
        12 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: dynamicSpacing) {
            Text(title)
                .font(.system(size: dynamicTitleSize, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack {
                Button {
                    if value > range.lowerBound {
                        value -= 1
                        Haptics.selectionChanged()
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: min(14, 14 * dynamicTypeSize.scaleFactor), weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: dynamicButtonSize, height: dynamicButtonSize)
                        .background {
                            Circle()
                                .fill(value > range.lowerBound ? .blue : .secondary)
                        }
                }
                .disabled(value <= range.lowerBound)
                
                Spacer()
                
                VStack(spacing: 2 * dynamicTypeSize.scaleFactor) {
                    Text("\(value)")
                        .font(.system(size: dynamicValueSize, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    if let suffix = suffix {
                        Text(suffix)
                            .font(.system(size: dynamicSuffixSize, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.9)
                    }
                }
                
                Spacer()
                
                Button {
                    if value < range.upperBound {
                        value += 1
                        Haptics.selectionChanged()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: min(14, 14 * dynamicTypeSize.scaleFactor), weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: dynamicButtonSize, height: dynamicButtonSize)
                        .background {
                            Circle()
                                .fill(value < range.upperBound ? .blue : .secondary)
                        }
                }
                .disabled(value >= range.upperBound)
            }
            .padding(.horizontal, dynamicPadding + 4)
            .padding(.vertical, dynamicPadding)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .stroke(.secondary.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

struct ModernActionRow: View {
    let title: String
    let icon: String
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private var dynamicTitleSize: CGFloat {
        16 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicIconSize: CGFloat {
        min(16, 16 * dynamicTypeSize.scaleFactor)
    }
    
    private var dynamicSpacing: CGFloat {
        12 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicPadding: CGFloat {
        max(12, 12 * min(dynamicTypeSize.scaleFactor, 1.3))
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: dynamicSpacing) {
                Image(systemName: icon)
                    .font(.system(size: dynamicIconSize, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: dynamicTitleSize, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: min(12, 12 * dynamicTypeSize.scaleFactor), weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, dynamicPadding + 4)
            .padding(.vertical, dynamicPadding)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .stroke(.secondary.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(HapticButtonStyle())
    }
}

struct ModernStatusRow: View {
    let icon: String
    let iconColor: Color
    let text: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private var dynamicIconSize: CGFloat {
        min(14, 14 * dynamicTypeSize.scaleFactor)
    }
    
    private var dynamicTextSize: CGFloat {
        14 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicSpacing: CGFloat {
        12 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicPadding: CGFloat {
        max(10, 10 * min(dynamicTypeSize.scaleFactor, 1.3))
    }
    
    var body: some View {
        HStack(spacing: dynamicSpacing) {
            Image(systemName: icon)
                .font(.system(size: dynamicIconSize, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.system(size: dynamicTextSize, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(.horizontal, dynamicPadding + 6)
        .padding(.vertical, dynamicPadding)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(iconColor.opacity(0.1))
                .stroke(iconColor.opacity(0.2), lineWidth: 1)
        }
    }
}

struct ModernInfoRow: View {
    let title: String
    let value: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private var dynamicTitleSize: CGFloat {
        14 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicValueSize: CGFloat {
        16 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicSpacing: CGFloat {
        16 * min(dynamicTypeSize.scaleFactor, 1.3)
    }
    
    private var dynamicPadding: CGFloat {
        max(12, 12 * min(dynamicTypeSize.scaleFactor, 1.3))
    }
    
    var body: some View {
        HStack(spacing: dynamicSpacing) {
            Text(title)
                .font(.system(size: dynamicTitleSize, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
            
            Spacer()
            
            Text(value)
                .font(.system(size: dynamicValueSize, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, dynamicPadding + 4)
        .padding(.vertical, dynamicPadding)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .stroke(.secondary.opacity(0.3), lineWidth: 1)
        }
    }
}

private extension View {
    @ViewBuilder
    func ifLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let unwrapped = value {
            transform(self, unwrapped)
        } else {
            self
        }
    }
}
