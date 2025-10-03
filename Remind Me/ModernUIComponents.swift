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
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 12) {
                content
            }
            .padding(20)
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
    
    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
            
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(centered ? .center : .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
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
    
    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
            
            HStack {
                Spacer()
                DatePicker("", selection: $selection, displayedComponents: displayedComponents)
                    .datePickerStyle(.compact)
                    .fixedSize()
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
    
    init(title: String, selection: Binding<T>, options: [T], @ViewBuilder content: @escaping (T) -> Content) {
        self.title = title
        self._selection = selection
        self.options = options
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Picker("", selection: $selection) {
                ForEach(options, id: \ .self) { option in
                    content(option)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
    
    init(title: String, selection: Binding<T>, options: [T], @ViewBuilder content: @escaping (T) -> Content) {
        self.title = title
        self._selection = selection
        self.options = options
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Picker("", selection: $selection) {
                ForEach(options, id: \ .self) { option in
                    content(option)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
    
    init(title: String, value: Binding<Int>, range: ClosedRange<Int>, suffix: String? = nil) {
        self.title = title
        self._value = value
        self.range = range
        self.suffix = suffix
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack {
                Button {
                    if value > range.lowerBound {
                        value -= 1
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background {
                            Circle()
                                .fill(value > range.lowerBound ? .blue : .secondary)
                        }
                }
                .disabled(value <= range.lowerBound)
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("\(value)")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    if let suffix = suffix {
                        Text(suffix)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    if value < range.upperBound {
                        value += 1
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background {
                            Circle()
                                .fill(value < range.upperBound ? .blue : .secondary)
                        }
                }
                .disabled(value >= range.upperBound)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .stroke(.secondary.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

struct ModernStatusRow: View {
    let icon: String
    let iconColor: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
    
    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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

