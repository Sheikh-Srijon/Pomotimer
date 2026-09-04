import SwiftUI

private let utilityGreen = Color(red: 0.25, green: 0.72, blue: 0.31)

struct PanelView: View {
    @ObservedObject var model: TimekeepingModel
    @ObservedObject var presentation: PanelPresentation
    @State private var isEditingTimer = false
    @State private var timerDraft = ""
    @FocusState private var timerFieldFocused: Bool

    var body: some View {
        ZStack(alignment: .trailing) {
            Color.clear
            if presentation.isExpanded {
                expandedPanel
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if model.hideCountdownWhenIdle {
                collapsedIconTab
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                collapsedTab
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.16), value: presentation.isExpanded)
        .tint(utilityGreen)
        .onHover(perform: presentation.setHovered)
        .onChange(of: timerFieldFocused) { _, isFocused in
            if !isFocused, isEditingTimer {
                commitTimerEdit(refocusOnFailure: false)
            }
        }
    }

    private var expandedPanel: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                primaryDisplay
                controls
                Divider().overlay(Color.white.opacity(0.09)).padding(.vertical, 14)
                sectionPicker
                if model.section == .timer { durationEditor.padding(.top, 13) }
                Spacer(minLength: 10)
                behaviorPicker
                Divider().overlay(Color.white.opacity(0.09)).padding(.vertical, 7)
                hideCountdownToggle
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(width: 250, height: 420)
            .background(PanelBackground())
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.white.opacity(0.09), lineWidth: 0.7)
            }

            EdgePointer()
                .fill(Color(red: 0.075, green: 0.085, blue: 0.08).opacity(0.96))
                .frame(width: 8, height: 22)
        }
        .frame(width: 258, height: 428)
    }

    private var header: some View {
        HStack {
            Button {
                presentation.setExpanded(false)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(model.behavior == .alwaysOnTop)
            .accessibilityLabel("Collapse panel")

            Spacer()
            Text(model.section == .stopwatch ? "STOPWATCH" : "TIMER")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(0.3)
            Spacer()

            Circle()
                .fill(utilityGreen)
                .frame(width: 8, height: 8)
                .shadow(color: utilityGreen.opacity(0.55), radius: 4)
                .accessibilityHidden(true)
            Color.clear.frame(width: 16, height: 1)
        }
        .frame(height: 26)
    }

    private var primaryDisplay: some View {
        VStack(spacing: 2) {
            if model.section == .timer, isEditingTimer, !model.isTimerRunning {
                TextField("MM:SS", text: $timerDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 32, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .focused($timerFieldFocused)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(model.timerError == nil ? utilityGreen.opacity(0.65) : Color.red, lineWidth: 1)
                    }
                    .onSubmit { commitTimerEdit(refocusOnFailure: true) }
                    .onExitCommand(perform: cancelTimerEdit)
                    .accessibilityLabel("Countdown duration")
                    .accessibilityHint("Enter minutes and seconds, or hours, minutes and seconds")
            } else {
                ZStack(alignment: .trailing) {
                    Text(displayedTime)
                        .font(.system(size: model.section == .stopwatch ? 31 : 34, weight: .regular, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.75)
                    if model.section == .timer, !model.isTimerRunning {
                        Image(systemName: "pencil")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .offset(x: 16)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: beginTimerEdit)
                .accessibilityAddTraits(model.section == .timer && !model.isTimerRunning ? .isButton : [])
                .accessibilityHint(model.section == .timer && !model.isTimerRunning ? "Click to edit the countdown duration" : "")
            }

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(subtitleColor)
        }
        .frame(height: 70)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button(action: toggleCurrent) {
                Text(isCurrentRunning ? "Pause" : "Start")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GreenButtonStyle())
            .keyboardShortcut(.space, modifiers: [])

            Button("Reset", action: resetCurrent)
                .frame(maxWidth: .infinity)
                .buttonStyle(DarkButtonStyle())
        }
        .frame(height: 32)
    }

    private var sectionPicker: some View {
        HStack(spacing: 0) {
            SectionButton(title: "Stopwatch", selected: model.section == .stopwatch) {
                model.section = .stopwatch
            }
            SectionButton(title: "Timer", selected: model.section == .timer) {
                model.section = .timer
            }
        }
        .frame(height: 36)
        .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 7))
    }

    private var durationEditor: some View {
        HStack(spacing: 5) {
            ForEach([5, 15, 30, 45, 60], id: \.self) { minutes in
                TimerPresetButton(
                    minutes: minutes,
                    selected: Int(model.displayedTimerRemaining) == minutes * 60,
                    model: model
                )
            }
        }
        .disabled(model.isTimerRunning)
        .opacity(model.isTimerRunning ? 0.45 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Countdown presets")
    }

    private var behaviorPicker: some View {
        VStack(spacing: 2) {
            ForEach(PanelBehavior.allCases) { behavior in
                Button {
                    model.behavior = behavior
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: behavior.symbol)
                            .font(.system(size: 13))
                            .frame(width: 17)
                        Text(behavior.title)
                            .font(.system(size: 13))
                        Spacer()
                        Image(systemName: model.behavior == behavior ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(model.behavior == behavior ? utilityGreen : Color.secondary)
                    }
                    .contentShape(Rectangle())
                    .frame(height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(model.behavior == behavior ? .isSelected : [])
            }
        }
    }

    private var hideCountdownToggle: some View {
        Toggle(isOn: $model.hideCountdownWhenIdle) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.compress.vertical")
                    .font(.system(size: 13))
                    .frame(width: 17)
                Text("Hide countdown when idle")
                    .font(.system(size: 12))
            }
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .accessibilityHint("Shows only the stopwatch icon when the panel is collapsed")
    }

    private var collapsedIconTab: some View {
        Image(systemName: "stopwatch")
            .font(.system(size: 25, weight: .light))
            .foregroundStyle(.white)
            .frame(width: 52, height: 92)
            .background(PanelBackground())
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 12))
            .overlay {
                UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 12)
                    .stroke(Color.white.opacity(0.09), lineWidth: 0.7)
            }
            .contentShape(Rectangle())
            .onTapGesture { presentation.setExpanded(true) }
            .accessibilityLabel("Open stopwatch utility")
            .accessibilityHint("Expands the panel")
            .accessibilityAddTraits(.isButton)
    }

    private var collapsedTab: some View {
        VStack(spacing: 10) {
            Image(systemName: model.section == .stopwatch ? "stopwatch" : "timer")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(model.section == .timer && model.isTimerRunning ? utilityGreen : Color.white)
            Text(collapsedTime)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .rotationEffect(.degrees(90))
                .fixedSize()
                .frame(width: 22, height: 64)
        }
        .frame(width: 52, height: 148)
        .background(PanelBackground())
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 12))
        .overlay(alignment: .leading) {
            Rectangle().fill(utilityGreen.opacity(isCurrentRunning ? 0.9 : 0)).frame(width: 2).padding(.vertical, 14)
        }
        .contentShape(Rectangle())
        .onTapGesture { presentation.setExpanded(true) }
        .accessibilityLabel("Open stopwatch panel, \(collapsedTime)")
    }

    private var displayedTime: String {
        switch model.section {
        case .stopwatch: formatStopwatch(model.stopwatchElapsed)
        case .timer: formatTimer(model.displayedTimerRemaining)
        }
    }

    private var collapsedTime: String {
        switch model.section {
        case .stopwatch: formatCompact(model.stopwatchElapsed)
        case .timer: formatCompact(model.displayedTimerRemaining)
        }
    }

    private var subtitle: String {
        if model.section == .timer, let timerError = model.timerError { return timerError }
        if let completionMessage = model.completionMessage, model.section == .timer { return completionMessage }
        if model.section == .timer { return model.isTimerRunning ? "Focus" : "Click time to edit" }
        return model.isStopwatchRunning ? "Running" : "Ready"
    }

    private var subtitleColor: Color {
        if model.timerError != nil, model.section == .timer { return .red }
        if model.completionMessage != nil, model.section == .timer { return utilityGreen }
        return .secondary
    }

    private var isCurrentRunning: Bool {
        model.section == .stopwatch ? model.isStopwatchRunning : model.isTimerRunning
    }

    private func toggleCurrent() {
        if isEditingTimer { commitTimerEdit(refocusOnFailure: true) }
        guard !isEditingTimer else { return }
        model.section == .stopwatch ? model.toggleStopwatch() : model.toggleTimer()
    }

    private func resetCurrent() {
        model.section == .stopwatch ? model.resetStopwatch() : model.resetTimer()
    }

    private func beginTimerEdit() {
        guard model.section == .timer, !model.isTimerRunning else { return }
        timerDraft = formatTimer(model.displayedTimerRemaining)
        model.clearTimerError()
        isEditingTimer = true
        DispatchQueue.main.async { timerFieldFocused = true }
    }

    private func commitTimerEdit(refocusOnFailure: Bool) {
        guard isEditingTimer else { return }
        guard model.setTimerDuration(from: timerDraft) else {
            if refocusOnFailure {
                DispatchQueue.main.async { timerFieldFocused = true }
            } else {
                isEditingTimer = false
            }
            return
        }
        isEditingTimer = false
        timerFieldFocused = false
    }

    private func cancelTimerEdit() {
        model.clearTimerError()
        isEditingTimer = false
        timerFieldFocused = false
    }

    private func formatStopwatch(_ interval: TimeInterval) -> String {
        let centiseconds = Int(max(0, interval) * 100)
        return String(format: "%02d:%02d.%02d", centiseconds / 6_000, (centiseconds / 100) % 60, centiseconds % 100)
    }

    private func formatTimer(_ interval: TimeInterval) -> String {
        let total = Int(ceil(max(0, interval)))
        if total >= 3_600 {
            return String(format: "%02d:%02d:%02d", total / 3_600, (total / 60) % 60, total % 60)
        }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func formatCompact(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        if total >= 3_600 { return String(format: "%d:%02d:%02d", total / 3_600, (total / 60) % 60, total % 60) }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private struct SectionButton: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: selected ? .medium : .regular))
                    .foregroundStyle(selected ? .primary : .secondary)
                Rectangle()
                    .fill(selected ? utilityGreen : Color.clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct TimerPresetButton: View {
    let minutes: Int
    let selected: Bool
    @ObservedObject var model: TimekeepingModel

    var body: some View {
        Button {
            model.setTimerPreset(minutes: minutes)
        } label: {
            Text("\(minutes)m")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(selected ? utilityGreen.opacity(0.9) : Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set timer to \(minutes) minutes")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct GreenButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.vertical, 7)
            .background(utilityGreen.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(.white)
    }
}

private struct DarkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(configuration.isPressed ? 0.07 : 0.11), in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(.white)
    }
}

private struct PanelBackground: View {
    var body: some View {
        ZStack {
            PanelMaterial()
            Color(red: 0.045, green: 0.052, blue: 0.048).opacity(0.9)
        }
    }
}

private struct PanelMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private struct EdgePointer: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: 0, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
