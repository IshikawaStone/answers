import SwiftUI
import Combine

#if canImport(WatchKit)
import WatchKit
#endif

public struct WatchMainView: View {
    public enum Screen {
        case papers
        case questions
        case answer
    }

    @ObservedObject private var store = WatchPaperStore.shared
    @ObservedObject private var cloudSync = WatchCloudSync.shared

    @State private var currentScreen: Screen = .papers
    @State private var selectedPaper: ExamPaper?
    @State private var selectedQuestion: ExamQuestion?

    @State private var clockText: String = ""
    @State private var isWifiHighPerf: Bool = false
    @State private var showControlsDialog: Bool = false
    @State private var showSettingsDialog: Bool = false
    @State private var cloudBounceOffset: CGFloat = 0

    // Auto-Scroll State
    @AppStorage("watch_autoscroll_enabled") private var autoScrollEnabled: Bool = true
    @AppStorage("watch_autoscroll_speed_index") private var speedIndex: Int = 6 // Default 1x
    @AppStorage("watch_reader_font_size") private var answerTextSizeSp: Double = 12.0
    @AppStorage("watch_reader_side_padding") private var answerSidePaddingDp: Double = 14.0
    @AppStorage("watch_edge_squeeze") private var edgeSqueezePercent: Double = 25.0

    @State private var isAutoScrollRunning: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var crownScrollOffset: CGFloat = 0
    @State private var maxAnswerHeight: CGFloat = 1000
    @State private var timer: Timer?

    private let timerClock = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        ZStack {
            WatchTheme.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Compact Header Bar (Visible on Papers and Questions; Hidden on Answer)
                if currentScreen != .answer {
                    watchHeaderView
                        .padding(.horizontal, 8)
                        .padding(.top, 0)
                        .padding(.bottom, 3)
                        .background(WatchTheme.black)
                }

                // Main Viewport Container
                ZStack {
                    switch currentScreen {
                    case .papers:
                        papersScreenView
                    case .questions:
                        if let paper = selectedPaper {
                            questionsScreenView(paper: paper)
                        }
                    case .answer:
                        if let question = selectedQuestion {
                            answerScreenView(question: question)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // controls popup
            if showControlsDialog {
                Color.black.opacity(0.65).ignoresSafeArea()
                    .onTapGesture { showControlsDialog = false }

                controlsDialogView
                    .frame(maxWidth: 180)
                    .transition(.scale.combined(with: .opacity))
            }

            // settings popup
            if showSettingsDialog {
                Color.black.opacity(0.65).ignoresSafeArea()
                    .onTapGesture { showSettingsDialog = false }

                settingsDialogView
                    .frame(maxWidth: 185)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            updateClock()
            if store.papers.isEmpty {
                store.savePaper(SampleData.makeSamplePaper())
            }
        }
        .onReceive(timerClock) { _ in
            updateClock()
        }
    }

    // MARK: - Top Header Bar

    private var watchHeaderView: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left: Back Button (Visible when on Questions screen)
            if currentScreen == .questions {
                Button(action: {
                    hapticTap()
                    currentScreen = .papers
                }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(WatchTheme.textPrimary)
                        .frame(width: 28, height: 26)
                        .background(WatchTheme.pillBg)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 6)
            }

            // Center Actions or Title
            HStack(spacing: 8) {
                if currentScreen == .papers {
                    // Button 1: Sets / Refresh
                    Button(action: {
                        hapticTap()
                        store.loadPapers()
                        cloudSync.checkStatus()
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(WatchTheme.pillBg)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(WatchTheme.borderSubtle, lineWidth: 1))
                            Image(systemName: "square.3.layers.3d")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(WatchTheme.accentCyan)
                        }
                        .frame(width: 38, height: 26)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Button 2: Wi-Fi Toggle
                    Button(action: {
                        hapticTap()
                        isWifiHighPerf.toggle()
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(WatchTheme.pillBg)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(WatchTheme.borderSubtle, lineWidth: 1))
                            Image(systemName: "wifi")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isWifiHighPerf ? WatchTheme.accentEmerald : WatchTheme.textPrimary)
                        }
                        .frame(width: 38, height: 26)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Button 3: Cloud Fetch
                    Button(action: {
                        hapticTap()
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                            cloudBounceOffset = 4
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation { cloudBounceOffset = 0 }
                        }
                        cloudSync.fetchLatestPaper { result in
                            if case .success(let p) = result {
                                store.savePaper(p)
                            }
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(WatchTheme.pillBg)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(WatchTheme.borderSubtle, lineWidth: 1))
                            Image(systemName: "icloud.and.arrow.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(WatchTheme.accentAmber)
                                .offset(y: cloudBounceOffset)
                        }
                        .frame(width: 38, height: 26)
                    }
                    .buttonStyle(PlainButtonStyle())

                } else if currentScreen == .questions, let paper = selectedPaper {
                    // Questions Screen Title
                    Text(paper.title.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(WatchTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: currentScreen == .papers ? .center : .leading)
        }
        .frame(height: 30)
    }

    // MARK: - Papers Screen

    private var papersScreenView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 6) {
                if store.papers.isEmpty {
                    // Standby View (0 papers)
                    VStack(spacing: 6) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 28))
                            .foregroundColor(WatchTheme.accentCyan)
                            .padding(.top, 10)

                        Text("NO SAVED SETS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(WatchTheme.textPrimary)

                        HStack(spacing: 4) {
                            // IP & Port Pill
                            HStack(spacing: 4) {
                                Image(systemName: "wifi")
                                    .font(.system(size: 9))
                                    .foregroundColor(WatchTheme.accentEmerald)
                                Text("10.181.224.150:42424")
                                    .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                                    .foregroundColor(WatchTheme.accentEmerald)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(WatchTheme.pillBg)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(WatchTheme.borderSubtle, lineWidth: 1))
                            .cornerRadius(8)

                            // Settings Button
                            Button(action: {
                                hapticTap()
                                showSettingsDialog = true
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(WatchTheme.pillBg)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(WatchTheme.borderSubtle, lineWidth: 1))
                                    Image(systemName: "gearshape")
                                        .font(.system(size: 11))
                                        .foregroundColor(WatchTheme.textPrimary)
                                }
                                .frame(width: 26, height: 24)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.top, 4)

                        Text("Tap header to restart sync\nBroadcast from phone")
                            .font(.system(size: 10))
                            .foregroundColor(WatchTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 16)

                } else {
                    // List of Paper Cards
                    ForEach(store.papers) { paper in
                        paperCardView(paper)
                            .onTapGesture {
                                hapticTap()
                                selectedPaper = paper
                                currentScreen = .questions
                            }
                    }

                    // Bottom Wi-Fi Info Footer & Settings Button
                    HStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "wifi")
                                .font(.system(size: 9))
                                .foregroundColor(WatchTheme.accentCyan)
                            Text("10.181.224.150:42424")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(WatchTheme.accentCyan)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(WatchTheme.pillBg)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(WatchTheme.borderSubtle, lineWidth: 1))
                        .cornerRadius(8)

                        Button(action: {
                            hapticTap()
                            showSettingsDialog = true
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(WatchTheme.pillBg)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(WatchTheme.borderSubtle, lineWidth: 1))
                                Image(systemName: "gearshape")
                                    .font(.system(size: 11))
                                    .foregroundColor(WatchTheme.textPrimary)
                            }
                            .frame(width: 26, height: 24)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 20)
                }
            }
            .padding(.horizontal, 10)
        }
    }

    private func paperCardView(_ paper: ExamPaper) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            // Top Row: Title + Generation Mode Badge
            HStack(alignment: .center, spacing: 6) {
                Text(paper.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WatchTheme.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                let isStd = paper.isStandardMode
                Text(isStd ? "STD" : "HON")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(isStd ? WatchTheme.modeStandard : WatchTheme.modeHonours)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(isStd ? WatchTheme.badgeBgEmerald : WatchTheme.badgeBgAmber)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(isStd ? WatchTheme.modeStandard : WatchTheme.modeHonours, lineWidth: 1))
                    .cornerRadius(4)
            }

            // High-Density Metric Bar
            HStack(alignment: .center, spacing: 0) {
                // Target / Marks
                Image(systemName: "target")
                    .font(.system(size: 10))
                    .foregroundColor(WatchTheme.accentCyan)
                Text(" \(paper.totalMarks > 0 ? paper.totalMarks : 100)")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(WatchTheme.accentCyan)

                Spacer().frame(width: 8)

                // Questions Count
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10))
                    .foregroundColor(WatchTheme.textSecondary)
                Text(" \(paper.questionCount)")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(WatchTheme.textSecondary)

                Spacer().frame(width: 8)

                // Answered Count
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(paper.isFullyAnswered ? WatchTheme.accentEmerald : WatchTheme.accentAmber)
                Text(" \(paper.answeredCount)/\(paper.questionCount)")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(paper.isFullyAnswered ? WatchTheme.accentEmerald : WatchTheme.accentAmber)

                Spacer()

                // Date
                Text(paper.date.count >= 5 ? String(paper.date.suffix(5)) : "06/09")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(WatchTheme.textMuted)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(WatchTheme.surfaceCard)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(WatchTheme.borderCard, lineWidth: 1))
        .cornerRadius(14)
    }

    // MARK: - Questions Screen

    private func questionsScreenView(paper: ExamPaper) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 5) {
                // Subjective Questions
                ForEach(paper.subjectiveQuestions) { q in
                    questionCardView(q)
                        .onTapGesture {
                            hapticTap()
                            selectedQuestion = q
                            currentScreen = .answer
                            startAutoScroll()
                        }
                }

                // Consolidated MCQs Card (if any MCQs exist)
                let mcqs = paper.mcqQuestions
                if !mcqs.isEmpty {
                    let mcqQuestion = ExamQuestion(
                        id: "consolidated_mcqs",
                        number: "MCQs",
                        text: "Multiple Choice Questions (\(mcqs.count))",
                        marks: mcqs.count,
                        isMcq: true,
                        honoursAnswer: mcqs.first?.honoursAnswer ?? "No answers solved yet."
                    )
                    questionCardView(mcqQuestion)
                        .onTapGesture {
                            hapticTap()
                            selectedQuestion = mcqQuestion
                            currentScreen = .answer
                            startAutoScroll()
                        }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 18)
        }
    }

    private func questionCardView(_ q: ExamQuestion) -> some View {
        HStack(alignment: .center, spacing: 7) {
            // Type & Marks Badge Pill
            HStack(spacing: 3) {
                if q.isMcq {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "#A78BFA"))
                } else if q.marks >= 10 {
                    Image(systemName: "pencil")
                        .font(.system(size: 9))
                        .foregroundColor(WatchTheme.accentAmber)
                } else {
                    Image(systemName: "doc.text")
                        .font(.system(size: 9))
                        .foregroundColor(WatchTheme.accentCyan)
                }

                Text(q.isMcq ? "\(q.marks)" : "\(q.marks)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(q.isMcq ? Color(hex: "#A78BFA") : (q.marks >= 10 ? WatchTheme.accentAmber : WatchTheme.accentCyan))
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(WatchTheme.pillBg)
            .cornerRadius(8)

            // Question Text Snippet
            Text(q.isMcq ? q.text : "\(q.number): \(q.text)")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(WatchTheme.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Trailing Answered Indicator
            if q.isAnswered {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(WatchTheme.accentEmerald)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(WatchTheme.surfaceCard)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(WatchTheme.borderCard, lineWidth: 1))
        .cornerRadius(14)
    }

    // MARK: - Answer Reader

    private func answerScreenView(question: ExamQuestion) -> some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    // Header Badge Bar with Back Button + Controls Button
                    HStack {
                        // Back to questions
                        Button(action: {
                            hapticTap()
                            stopAutoScroll()
                            currentScreen = .questions
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 9, weight: .bold))
                                Text(question.isMcq ? "MCQs" : "\(question.number) • \(question.marks)M")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(WatchTheme.accentAmber)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(WatchTheme.pillBg)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(WatchTheme.borderSubtle, lineWidth: 1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Spacer()

                        // Controls Popup Button
                        Button(action: {
                            hapticTap()
                            pauseAutoScroll()
                            showControlsDialog = true
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Controls")
                                    .font(.system(size: 9.5, weight: .bold))
                            }
                            .foregroundColor(WatchTheme.accentEmerald)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(WatchTheme.pillBg)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(WatchTheme.borderSubtle, lineWidth: 1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.bottom, 4)

                    // Answer Body (Markdown + Flowcharts)
                    let blocks = parseAnswerMarkdown(question.honoursAnswer)
                    ForEach(0..<blocks.count, id: \.self) { i in
                        renderAnswerBlock(blocks[i])
                    }

                    Spacer(minLength: 45)
                }
                .padding(.horizontal, CGFloat(answerSidePaddingDp))
                .padding(.top, 4)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { self.maxAnswerHeight = geo.size.height }
                            .onChange(of: geo.size.height) { _, newH in self.maxAnswerHeight = newH }
                    }
                )
            }
            .focusable()
            .digitalCrownRotation($crownScrollOffset, from: 0, through: maxAnswerHeight, by: 8, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
            .onChange(of: crownScrollOffset) { _, newOff in
                pauseAutoScroll()
                self.scrollOffset = newOff
            }
            .onTapGesture {
                // Single Tap: Pause / Resume Auto-scroll
                hapticTap()
                toggleAutoScroll()
            }
            .onLongPressGesture {
                // Long Press: Open Controls Dialog
                hapticLongPress()
                pauseAutoScroll()
                showControlsDialog = true
            }

            // Floating Bottom Auto-Scroll Speed Bar
            HStack {
                Button(action: {
                    hapticTap()
                    toggleAutoScroll()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isAutoScrollRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 8))
                        Text(AutoScrollController.speedLabels[speedIndex])
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(isAutoScrollRunning ? WatchTheme.accentEmerald : WatchTheme.accentAmber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(WatchTheme.dialogBg)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(WatchTheme.dialogBorder, lineWidth: 1))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Button(action: {
                    hapticTap()
                    pauseAutoScroll()
                    showControlsDialog = true
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(WatchTheme.textPrimary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(WatchTheme.dialogBg)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(WatchTheme.dialogBorder, lineWidth: 1))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 2)
        }
        .gesture(
            DragGesture().onEnded { val in
                // Left-to-Right edge swipe returns to Questions
                if val.startLocation.x < 50 && val.translation.width > 40 {
                    hapticTap()
                    stopAutoScroll()
                    currentScreen = .questions
                }
            }
        )
    }

    // MARK: - Markdown & Mermaid Rendering

    private enum RenderSegment {
        case header(String, Int)
        case bullet(String)
        case text(String)
        case mermaid(String)
    }

    private func parseAnswerMarkdown(_ md: String) -> [RenderSegment] {
        var segments: [RenderSegment] = []
        let lines = md.components(separatedBy: .newlines)
        var inMermaid = false
        var mermaidBuf = ""

        for line in lines {
            let tr = line.trimmingCharacters(in: .whitespaces)

            if tr.starts(with: "```mermaid") {
                inMermaid = true
                mermaidBuf = ""
                continue
            }
            if inMermaid {
                if tr.starts(with: "```") {
                    inMermaid = false
                    segments.append(.mermaid(mermaidBuf))
                    mermaidBuf = ""
                } else {
                    mermaidBuf += line + "\n"
                }
                continue
            }

            if tr.isEmpty { continue }

            if tr.starts(with: "# ") {
                segments.append(.header(String(tr.dropFirst(2)).uppercased(), 1))
            } else if tr.starts(with: "## ") {
                segments.append(.header(String(tr.dropFirst(3)).uppercased(), 2))
            } else if tr.starts(with: "### ") {
                segments.append(.header(String(tr.dropFirst(4)).uppercased(), 3))
            } else if tr.starts(with: "- ") || tr.starts(with: "* ") || tr.starts(with: "• ") {
                segments.append(.bullet(String(tr.dropFirst(2))))
            } else {
                segments.append(.text(tr))
            }
        }

        if inMermaid && !mermaidBuf.isEmpty {
            segments.append(.mermaid(mermaidBuf))
        }

        return segments
    }

    @ViewBuilder
    private func renderAnswerBlock(_ segment: RenderSegment) -> some View {
        switch segment {
        case .header(let title, let level):
            let color = level <= 2 ? WatchTheme.accentCyan : (level == 3 ? WatchTheme.accentAmber : WatchTheme.accentEmerald)
            Text(title)
                .font(.system(size: CGFloat(answerTextSizeSp + (level == 1 ? 2 : 1)), weight: .bold))
                .foregroundColor(color)
                .padding(.top, 6)

        case .bullet(let content):
            HStack(alignment: .top, spacing: 5) {
                Text("•")
                    .font(.system(size: CGFloat(answerTextSizeSp), weight: .bold))
                    .foregroundColor(WatchTheme.accentCyan)
                Text(LocalizedStringKey(content))
                    .font(.system(size: CGFloat(answerTextSizeSp), weight: .regular))
                    .foregroundColor(WatchTheme.textPrimary)
                    .lineSpacing(2)
            }

        case .text(let content):
            Text(LocalizedStringKey(content))
                .font(.system(size: CGFloat(answerTextSizeSp), weight: .regular))
                .foregroundColor(WatchTheme.textPrimary)
                .lineSpacing(2)

        case .mermaid(let code):
            MermaidCanvasView(code: code)
                .padding(.vertical, 4)
        }
    }

    // MARK: - Controls Dialog

    private var controlsDialogView: some View {
        VStack(spacing: 8) {
            // Header Row: CONTROLS on Left, SCROLL: ON/OFF Pill on Right
            HStack {
                Text("CONTROLS")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#A1A1AA"))

                Spacer()

                Button(action: {
                    hapticTap()
                    autoScrollEnabled.toggle()
                    if autoScrollEnabled { startAutoScroll() } else { stopAutoScroll() }
                }) {
                    Text(autoScrollEnabled ? "SCROLL: ON" : "SCROLL: OFF")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(autoScrollEnabled ? WatchTheme.accentEmerald : WatchTheme.accentRose)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(WatchTheme.pillBg)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Divider().background(Color(hex: "#2E2E38"))

            // Speed Row
            HStack(spacing: 4) {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .font(.system(size: 11))
                    .foregroundColor(WatchTheme.textSecondary)

                Slider(value: Binding(
                    get: { Double(speedIndex) },
                    set: { speedIndex = Int($0) }
                ), in: 0...10, step: 1)

                Text(AutoScrollController.speedLabels[speedIndex])
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(WatchTheme.textPrimary)
                    .frame(width: 32, alignment: .trailing)
            }

            // Text Size Row
            HStack(spacing: 4) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 11))
                    .foregroundColor(WatchTheme.textSecondary)

                Slider(value: $answerTextSizeSp, in: 9...17, step: 1)

                Text("\(Int(answerTextSizeSp))sp")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(WatchTheme.textPrimary)
                    .frame(width: 32, alignment: .trailing)
            }

            // Quick Presets: 0.2x, 0.5x, 1x, 2x
            HStack(spacing: 4) {
                presetButton(label: "0.2x", idx: 2)
                presetButton(label: "0.5x", idx: 4)
                presetButton(label: "1x", idx: 6)
                presetButton(label: "2x", idx: 8)
            }

            // Done Button
            Button(action: {
                hapticTap()
                showControlsDialog = false
                if autoScrollEnabled { startAutoScroll() }
            }) {
                Text("Done")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#2E2E38"))
                    .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(10)
        .background(WatchTheme.dialogBg)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(WatchTheme.dialogBorder, lineWidth: 1))
        .cornerRadius(18)
    }

    private func presetButton(label: String, idx: Int) -> some View {
        Button(action: {
            hapticTap()
            speedIndex = idx
        }) {
            Text(label)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundColor(speedIndex == idx ? WatchTheme.accentEmerald : WatchTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(WatchTheme.pillBg)
                .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func channelPresetButton(label: String, key: String) -> some View {
        Button(action: {
            hapticTap()
            cloudSync.channel = key
            cloudSync.checkStatus()
        }) {
            Text(label)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundColor(cloudSync.channel == key ? WatchTheme.accentAmber : WatchTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(WatchTheme.pillBg)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(cloudSync.channel == key ? WatchTheme.accentAmber : WatchTheme.borderSubtle, lineWidth: 1))
                .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Settings Dialog

    private var settingsDialogView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text("WATCH SETTINGS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(WatchTheme.textPrimary)
                    Spacer()
                    Button(action: { showSettingsDialog = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(WatchTheme.textMuted)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Divider().background(WatchTheme.dialogBorder)

                // Cloud Relay Section
                Text("CLOUD RELAY")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(WatchTheme.accentAmber)

                HStack {
                    Text("KEY:")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundColor(WatchTheme.textMuted)

                    TextField("Channel", text: Binding(
                        get: { cloudSync.channel },
                        set: {
                            cloudSync.channel = $0
                            cloudSync.checkStatus()
                        }
                    ))
                    .font(.system(size: 9, design: .monospaced))
                    .padding(3)
                    .background(WatchTheme.pillBg)
                    .cornerRadius(4)
                }

                // Channel Quick Presets
                HStack(spacing: 4) {
                    channelPresetButton(label: "Default", key: WatchCloudSync.defaultChannel)
                    channelPresetButton(label: "UPI Live", key: "upi_live_channel")
                }

                Button(action: {
                    hapticTap()
                    cloudSync.checkStatus()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 8))
                        Text(cloudSync.statusMessage)
                            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(WatchTheme.pillBg)
                    .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())

                Divider().background(WatchTheme.dialogBorder)

                // Auto-Scroll Toggle
                Toggle(isOn: $autoScrollEnabled) {
                    Text("Auto-Scroll Enabled")
                        .font(.system(size: 9.5))
                        .foregroundColor(WatchTheme.textPrimary)
                }

                // Reset Button
                Button(action: {
                    hapticTap()
                    autoScrollEnabled = true
                    speedIndex = 6
                    answerTextSizeSp = 12.0
                    showSettingsDialog = false
                }) {
                    Text("Reset to Defaults")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(WatchTheme.accentRose)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#221111"))
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(10)
        }
        .background(WatchTheme.dialogBg)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(WatchTheme.dialogBorder, lineWidth: 1))
        .cornerRadius(18)
    }

    // MARK: - Auto-Scroll Engine

    private func startAutoScroll() {
        guard autoScrollEnabled else { return }
        stopAutoScroll()
        isAutoScrollRunning = true

        let interval: TimeInterval = 1.0 / 30.0
        let multiplier = AutoScrollController.speedMultipliers[speedIndex]
        let step = (26.0 * multiplier) * CGFloat(interval)

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            DispatchQueue.main.async {
                if self.scrollOffset < self.maxAnswerHeight {
                    self.scrollOffset += step
                    self.crownScrollOffset = self.scrollOffset
                }
            }
        }
    }

    private func pauseAutoScroll() {
        isAutoScrollRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func toggleAutoScroll() {
        if isAutoScrollRunning {
            pauseAutoScroll()
        } else {
            startAutoScroll()
        }
    }

    private func stopAutoScroll() {
        isAutoScrollRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func updateClock() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        clockText = formatter.string(from: Date())
    }

    private func hapticTap() {
        #if canImport(WatchKit)
        WKInterfaceDevice.current().play(.click)
        #endif
    }

    private func hapticLongPress() {
        #if canImport(WatchKit)
        WKInterfaceDevice.current().play(.notification)
        #endif
    }
}
