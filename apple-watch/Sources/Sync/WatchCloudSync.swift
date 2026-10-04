import Foundation
import Combine

public class WatchCloudSync: ObservableObject {
    public static let shared = WatchCloudSync()

    public static let defaultEndpoint = "https://answers-relay.ishikawaadachi.workers.dev"
    public static let defaultChannel = "answers"

    private let keyEndpoint = "watch_cloud_endpoint"
    private let keyChannel = "watch_cloud_channel"

    @Published public var isSyncing: Bool = false
    @Published public var statusMessage: String = "Standby"
    @Published public var isOnline: Bool = false
    @Published public var lastLatencyMs: Int = 0
    @Published public var latestPaperTitle: String = ""

    public var endpoint: String {
        get {
            UserDefaults.standard.string(forKey: keyEndpoint) ?? Self.defaultEndpoint
        }
        set {
            var val = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if val.hasSuffix("/") { val = String(val.dropLast()) }
            if val.isEmpty { val = Self.defaultEndpoint }
            UserDefaults.standard.set(val, forKey: keyEndpoint)
            objectWillChange.send()
        }
    }

    public var channel: String {
        get {
            UserDefaults.standard.string(forKey: keyChannel) ?? Self.defaultChannel
        }
        set {
            let val = newValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            UserDefaults.standard.set(val.isEmpty ? Self.defaultChannel : val, forKey: keyChannel)
            objectWillChange.send()
        }
    }

    private init() {
        let ch = UserDefaults.standard.string(forKey: keyChannel) ?? ""
        if ch.isEmpty || ch == "mbbs_prep_default" || ch == "upi_live_channel" || ch == "current_answers_channel" || ch == "paediatrics" || ch == "opthalmalogy123" || ch == "opthalmology" || ch == "ophthalmology123" || ch == "ophthalmology" {
            UserDefaults.standard.set(Self.defaultChannel, forKey: keyChannel)
        }
        checkStatus()
    }

    public func checkStatus() {
        guard let encodedChannel = channel.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(endpoint)/api/v1/sync/status?channel=\(encodedChannel)") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8.0
        request.setValue(channel, forHTTPHeaderField: "X-Channel-Key")

        let startTime = Date()

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)

            DispatchQueue.main.async {
                self.lastLatencyMs = latency
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let data = data {
                    self.isOnline = true
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let hasPaper = json["hasPaper"] as? Bool ?? false
                        if hasPaper, let meta = json["latestPaper"] as? [String: Any], let title = meta["paperTitle"] as? String {
                            self.latestPaperTitle = title
                            self.statusMessage = "● Online (\(latency)ms) | \(title.prefix(12))…"
                        } else {
                            self.statusMessage = "● Online (\(latency)ms) | Empty"
                        }
                    } else {
                        self.statusMessage = "● Online (\(latency)ms)"
                    }
                } else {
                    self.isOnline = false
                    self.statusMessage = "○ Offline"
                }
            }
        }.resume()
    }

    public func fetchLatestPaper(completion: @escaping (Result<ExamPaper, Error>) -> Void) {
        guard let encodedChannel = channel.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(endpoint)/api/v1/sync/download?channel=\(encodedChannel)") else {
            completion(.failure(NSError(domain: "WatchCloudSync", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        DispatchQueue.main.async {
            self.isSyncing = true
            self.statusMessage = "Fetching..."
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15.0
        request.setValue(channel, forHTTPHeaderField: "X-Channel-Key")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isSyncing = false
            }

            if let error = error {
                DispatchQueue.main.async {
                    self.statusMessage = "Sync Failed"
                    completion(.failure(error))
                }
                return
            }

            guard let data = data, !data.isEmpty else {
                let err = NSError(domain: "WatchCloudSync", code: -2, userInfo: [NSLocalizedDescriptionKey: "Empty payload"])
                DispatchQueue.main.async {
                    self.statusMessage = "Empty Response"
                    completion(.failure(err))
                }
                return
            }

            // 1. Attempt .qaset binary unpack
            if QASetUnpacker.isQASet(data: data) {
                do {
                    let paper = try QASetUnpacker.unpackToExamPaper(data: data)
                    WatchPaperStore.shared.savePaper(paper)
                    DispatchQueue.main.async {
                        self.statusMessage = "● Synced: \(paper.title.prefix(12))…"
                        completion(.success(paper))
                    }
                    return
                } catch {
                    print("QASet unpack error: \(error)")
                }
            }

            // 2. Attempt direct JSON decoding
            let decoder = JSONDecoder()
            if let paper = try? decoder.decode(ExamPaper.self, from: data) {
                WatchPaperStore.shared.savePaper(paper)
                DispatchQueue.main.async {
                    self.statusMessage = "● Synced: \(paper.title.prefix(12))…"
                    completion(.success(paper))
                }
                return
            }

            // 3. Fallback attempt for raw GZIP or raw Java serialization stream
            do {
                let paper = try QASetUnpacker.unpackToExamPaper(data: data)
                WatchPaperStore.shared.savePaper(paper)
                DispatchQueue.main.async {
                    self.statusMessage = "● Synced: \(paper.title.prefix(12))…"
                    completion(.success(paper))
                }
                return
            } catch {
                let parseErr = NSError(domain: "WatchCloudSync", code: -3, userInfo: [NSLocalizedDescriptionKey: "Decode failed: \(error.localizedDescription)"])
                DispatchQueue.main.async {
                    self.statusMessage = "Decode Error"
                    completion(.failure(parseErr))
                }
            }
        }.resume()
    }
}
