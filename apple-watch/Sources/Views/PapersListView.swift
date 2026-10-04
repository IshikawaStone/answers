import SwiftUI

public struct PapersListView: View {
    @ObservedObject private var store = WatchPaperStore.shared
    @ObservedObject private var cloudSync = WatchCloudSync.shared

    @State private var showSettings: Bool = false
    @State private var fetchError: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // Top Cloud Relay Status Header
                Section {
                    statusPillView
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4))

                // Papers List or Standby Empty State
                if store.papers.isEmpty {
                    standbyEmptyView
                } else {
                    ForEach(store.papers) { paper in
                        NavigationLink(destination: QuestionsListView(paper: paper)) {
                            paperCardView(paper)
                        }
                        .listRowBackground(Color(red: 0.08, green: 0.08, blue: 0.1))
                    }
                    .onDelete(perform: deletePaper)
                }
            }
            .listStyle(CarouselListStyle())
            .navigationTitle("Answers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        cloudSync.checkStatus()
                        store.loadPapers()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 0.22, green: 0.74, blue: 0.97))
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        Button(action: triggerCloudDownload) {
                            if cloudSync.isSyncing {
                                ProgressView()
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "icloud.and.arrow.down")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(red: 0.96, green: 0.62, blue: 0.04))
                            }
                        }

                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheetView()
            }
        }
    }

    // MARK: - Components

    private var statusPillView: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(cloudSync.isOnline ? Color.green : Color.red)
                .frame(width: 5, height: 5)

            Text(cloudSync.statusMessage)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(cloudSync.isOnline ? .green : .gray)
                .lineLimit(1)

            Spacer()

            Text(cloudSync.channel)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.96, green: 0.62, blue: 0.04))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color(red: 0.14, green: 0.14, blue: 0.16))
                .cornerRadius(3)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color(red: 0.06, green: 0.06, blue: 0.08))
        .cornerRadius(6)
    }

    private func paperCardView(_ paper: ExamPaper) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(paper.title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)

            HStack {
                Text("\(paper.questionCount) Questions · \(paper.totalMarks)M")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)

                Spacer()

                Text(paper.promptSetDisplayTag)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(paper.promptSetColor)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.14))
                    .cornerRadius(3)
            }

            HStack {
                Text("\(paper.answeredCount)/\(paper.questionCount) Answered")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(paper.isFullyAnswered ? Color.green : Color.orange)

                Spacer()

                if !paper.date.isEmpty {
                    Text(paper.date)
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var standbyEmptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(Color(red: 0.22, green: 0.74, blue: 0.97))
                .padding(.top, 8)

            Text("No Exam Papers Loaded")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)

            Text("1-tap fetch from cloud or load sample MBBS paper.")
                .font(.system(size: 9))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)

            Button(action: triggerCloudDownload) {
                HStack(spacing: 4) {
                    Image(systemName: "icloud.and.arrow.down")
                    Text("Fetch Cloud Paper")
                }
                .font(.system(size: 10, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color(red: 0.96, green: 0.62, blue: 0.04))
                .foregroundColor(.black)
                .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                store.savePaper(SampleData.makeSamplePaper())
            }) {
                Text("Load Sample MBBS Paper")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                    .foregroundColor(Color(red: 0.22, green: 0.74, blue: 0.97))
                    .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
    }

    private func triggerCloudDownload() {
        cloudSync.fetchLatestPaper { result in
            switch result {
            case .success(let paper):
                store.savePaper(paper)
            case .failure(let error):
                fetchError = error.localizedDescription
            }
        }
    }

    private func deletePaper(at offsets: IndexSet) {
        for index in offsets {
            let paper = store.papers[index]
            store.deletePaper(id: paper.id)
        }
    }
}
