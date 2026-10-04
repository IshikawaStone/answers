import Foundation
import Combine

public class WatchPaperStore: ObservableObject {
    public static let shared = WatchPaperStore()

    @Published public var papers: [ExamPaper] = []

    private let fileManager = FileManager.default
    private let papersDirName = "papers"

    private var papersDirectoryURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent(papersDirName, isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public init() {
        loadPapers()
        if papers.isEmpty {
            let sample = SampleData.makeSamplePaper()
            savePaper(sample)
        }
    }

    public func loadPapers() {
        let dir = papersDirectoryURL
        guard let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else {
            return
        }

        var loaded: [ExamPaper] = []
        let jsonDecoder = JSONDecoder()

        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let paper = try? jsonDecoder.decode(ExamPaper.self, from: data) {
                loaded.append(paper)
            }
        }

        // Sort by date / modification order
        if Thread.isMainThread {
            self.papers = loaded
        } else {
            DispatchQueue.main.async {
                self.papers = loaded
            }
        }
    }

    public func savePaper(_ paper: ExamPaper) {
        let fileURL = papersDirectoryURL.appendingPathComponent("\(paper.id).json")
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted
        do {
            let data = try jsonEncoder.encode(paper)
            try data.write(to: fileURL, options: .atomic)
            loadPapers()
        } catch {
            print("[WatchPaperStore] Failed to save paper: \(error)")
        }
    }

    public func deletePaper(id: String) {
        let fileURL = papersDirectoryURL.appendingPathComponent("\(id).json")
        try? fileManager.removeItem(at: fileURL)
        loadPapers()
    }
}
