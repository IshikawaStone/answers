import SwiftUI

public struct QuestionsListView: View {
    public let paper: ExamPaper
    @State private var selectedQuestion: ExamQuestion?

    public init(paper: ExamPaper) {
        self.paper = paper
    }

    public var body: some View {
        List {
            Section(header: headerView) {
                ForEach(paper.questions) { question in
                    NavigationLink(destination: AnswerReaderView(question: question, paperTitle: paper.title)) {
                        questionRow(question)
                    }
                    .listRowBackground(Color(red: 0.08, green: 0.08, blue: 0.1))
                }
            }
        }
        .listStyle(CarouselListStyle())
        .navigationTitle(paper.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(paper.answeredCount)/\(paper.questionCount) ANSWERED")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.06, green: 0.73, blue: 0.51)) // Emerald

                Spacer()

                Text(paper.promptSetDisplayTag)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(paper.promptSetColor)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                    .cornerRadius(3)
            }
        }
        .padding(.vertical, 2)
    }

    private func questionRow(_ question: ExamQuestion) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(question.number)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Text(question.marksBadgeText)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(question.marksBadgeColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color(red: 0.14, green: 0.14, blue: 0.16))
                    .cornerRadius(3)

                Spacer()

                if question.isAnswered {
                    Circle()
                        .fill(Color(red: 0.06, green: 0.73, blue: 0.51))
                        .frame(width: 6, height: 6)
                }
            }

            Text(question.text)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Color(red: 0.85, green: 0.85, blue: 0.85))
                .lineLimit(3)
                .lineSpacing(1.5)
        }
        .padding(.vertical, 4)
    }
}
