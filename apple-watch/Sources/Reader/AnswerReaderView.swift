import SwiftUI

#if canImport(WatchKit)
import WatchKit
#endif

public struct AnswerReaderView: View {
    public let question: ExamQuestion
    public let paperTitle: String

    @StateObject private var scroller = AutoScrollController()
    @State private var crownOffset: CGFloat = 0
    @State private var showSettings: Bool = false
    @State private var contentHeight: CGFloat = 800

    public init(question: ExamQuestion, paperTitle: String) {
        self.question = question
        self.paperTitle = paperTitle
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 12) {
                    // Header Badge
                    HStack {
                        Text("[\(question.marks) MARKS - HONOURS]")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(question.marksBadgeColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.1, green: 0.1, blue: 0.12))
                            .cornerRadius(4)

                        Spacer()

                        // Auto-scroll Speed & Toggle Pill
                        Button(action: {
                            scroller.toggle()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: scroller.isRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 8))
                                Text(scroller.currentSpeedLabel)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(scroller.isRunning ? .green : .gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                            .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Question Title Text
                    Text(question.text)
                        .font(.system(size: scroller.fontSize + 1, weight: .bold))
                        .foregroundColor(.white)
                        .lineSpacing(2)

                    Divider()
                        .background(Color(red: 0.25, green: 0.25, blue: 0.28))

                    // Answer Content Blocks (Markdown & Mermaid Flowcharts)
                    let blocks = parseAnswerBlocks(question.honoursAnswer)
                    ForEach(0..<blocks.count, id: \.self) { idx in
                        renderBlock(blocks[idx])
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, scroller.sidePadding)
                .padding(.top, 8)
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear {
                            self.scroller.maxContentHeight = geo.size.height
                        }
                        .onChange(of: geo.size.height) { _, newHeight in
                            self.scroller.maxContentHeight = newHeight
                        }
                    }
                )
            }
            .background(Color.black)
            .focusable()
            .digitalCrownRotation($crownOffset, from: 0, through: scroller.maxContentHeight, by: 10, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
            .onChange(of: crownOffset) { _, newOffset in
                scroller.pause()
                scroller.scrollOffset = newOffset
            }
            .onChange(of: scroller.scrollOffset) { _, offset in
                // Keep crownOffset in sync with auto-scroller
                self.crownOffset = offset
            }
            .onAppear {
                scroller.start()
            }
            .onDisappear {
                scroller.stop()
            }
            .navigationTitle(question.number)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        scroller.cycleSpeed()
                    }) {
                        Image(systemName: "gauge.with.dots.needle.50percent")
                            .foregroundColor(Color(red: 0.22, green: 0.74, blue: 0.97))
                    }
                }
            }
        }
    }

    // MARK: - Markdown & Mermaid Block Parsing

    private enum ContentBlock {
        case header(String, Int)
        case paragraph(String)
        case bullet(String)
        case mermaid(String)
        case callout(String)
    }

    private func parseAnswerBlocks(_ markdown: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        let lines = markdown.components(separatedBy: .newlines)
        var isInsideMermaid = false
        var mermaidBuffer = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.starts(with: "```mermaid") {
                isInsideMermaid = true
                mermaidBuffer = ""
                continue
            }

            if isInsideMermaid {
                if trimmed.starts(with: "```") {
                    isInsideMermaid = false
                    blocks.append(.mermaid(mermaidBuffer))
                    mermaidBuffer = ""
                } else {
                    mermaidBuffer += line + "\n"
                }
                continue
            }

            if trimmed.isEmpty { continue }

            if trimmed.starts(with: "# ") {
                blocks.append(.header(String(trimmed.dropFirst(2)), 1))
            } else if trimmed.starts(with: "## ") {
                blocks.append(.header(String(trimmed.dropFirst(3)), 2))
            } else if trimmed.starts(with: "### ") {
                blocks.append(.header(String(trimmed.dropFirst(4)), 3))
            } else if trimmed.starts(with: "- ") || trimmed.starts(with: "* ") {
                blocks.append(.bullet(String(trimmed.dropFirst(2))))
            } else if trimmed.starts(with: "> ") {
                blocks.append(.callout(String(trimmed.dropFirst(2))))
            } else {
                blocks.append(.paragraph(trimmed))
            }
        }

        if isInsideMermaid && !mermaidBuffer.isEmpty {
            blocks.append(.mermaid(mermaidBuffer))
        }

        return blocks
    }

    @ViewBuilder
    private func renderBlock(_ block: ContentBlock) -> some View {
        switch block {
        case .header(let text, let level):
            Text(text)
                .font(.system(size: level == 1 ? scroller.fontSize + 3 : (level == 2 ? scroller.fontSize + 1.5 : scroller.fontSize), weight: .bold))
                .foregroundColor(level == 1 ? Color(red: 1.0, green: 0.83, blue: 0.31) : Color(red: 0.22, green: 0.74, blue: 0.97))
                .padding(.top, 4)

        case .paragraph(let text):
            Text(LocalizedStringKey(text))
                .font(.system(size: scroller.fontSize))
                .foregroundColor(Color(red: 0.9, green: 0.9, blue: 0.9))
                .lineSpacing(2)

        case .bullet(let text):
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .font(.system(size: scroller.fontSize, weight: .bold))
                    .foregroundColor(Color(red: 0.22, green: 0.74, blue: 0.97))
                Text(LocalizedStringKey(text))
                    .font(.system(size: scroller.fontSize))
                    .foregroundColor(Color(red: 0.9, green: 0.9, blue: 0.9))
                    .lineSpacing(2)
            }

        case .callout(let text):
            HStack {
                Rectangle()
                    .fill(Color(red: 0.98, green: 0.62, blue: 0.04))
                    .frame(width: 3)
                Text(LocalizedStringKey(text))
                    .font(.system(size: scroller.fontSize - 1, weight: .medium))
                    .foregroundColor(Color(red: 0.85, green: 0.85, blue: 0.85))
                    .padding(.vertical, 2)
            }
            .padding(.leading, 4)

        case .mermaid(let code):
            VStack(alignment: .leading, spacing: 4) {
                Text("CLINICAL DECISION ALGORITHM")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.96, green: 0.62, blue: 0.04))

                MermaidCanvasView(code: code)
                    .background(Color(red: 0.06, green: 0.06, blue: 0.07))
                    .cornerRadius(6)
            }
            .padding(.vertical, 4)
        }
    }
}
