import Foundation
import SwiftUI
import Combine

#if canImport(WatchKit)
import WatchKit
#endif

public class AutoScrollController: ObservableObject {
    public static let speedLabels = [
        "0.05x", "0.1x", "0.2x", "0.3x", "0.5x", "0.75x", "1x", "1.5x", "2x", "3x", "5x"
    ]
    public static let speedMultipliers: [CGFloat] = [
        0.05, 0.1, 0.2, 0.3, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 5.0
    ]

    private let keyEnabled = "watch_autoscroll_enabled"
    private let keySpeedIndex = "watch_autoscroll_speed_index"
    private let keyFontSize = "watch_reader_font_size"
    private let keySidePadding = "watch_reader_side_padding"

    @Published public var isRunning: Bool = false
    @Published public var scrollOffset: CGFloat = 0
    @Published public var maxContentHeight: CGFloat = 1000

    public var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: keyEnabled) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: keyEnabled)
            objectWillChange.send()
        }
    }

    public var speedIndex: Int {
        get {
            let idx = UserDefaults.standard.integer(forKey: keySpeedIndex)
            return (idx >= 0 && idx < Self.speedMultipliers.count) ? idx : 6 // Default 1x
        }
        set {
            let clamped = max(0, min(Self.speedMultipliers.count - 1, newValue))
            UserDefaults.standard.set(clamped, forKey: keySpeedIndex)
            objectWillChange.send()
        }
    }

    public var fontSize: CGFloat {
        get {
            let size = CGFloat(UserDefaults.standard.float(forKey: keyFontSize))
            return (size >= 9 && size <= 18) ? size : 12.0
        }
        set {
            let clamped = max(9.0, min(18.0, newValue))
            UserDefaults.standard.set(Float(clamped), forKey: keyFontSize)
            objectWillChange.send()
        }
    }

    public var sidePadding: CGFloat {
        get {
            let pad = CGFloat(UserDefaults.standard.float(forKey: keySidePadding))
            return (pad >= 4 && pad <= 24) ? pad : 12.0
        }
        set {
            let clamped = max(4.0, min(24.0, newValue))
            UserDefaults.standard.set(Float(clamped), forKey: keySidePadding)
            objectWillChange.send()
        }
    }

    public var currentSpeedLabel: String {
        Self.speedLabels[speedIndex]
    }

    public var currentMultiplier: CGFloat {
        Self.speedMultipliers[speedIndex]
    }

    private var timer: Timer?
    private let basePointsPerSecond: CGFloat = 26.0

    #if canImport(WatchKit)
    private var extendedSession: WKExtendedRuntimeSession?
    #endif

    public init() {}

    public func start() {
        guard isEnabled else { return }
        stop()
        isRunning = true

        #if canImport(WatchKit)
        if extendedSession == nil {
            extendedSession = WKExtendedRuntimeSession()
            extendedSession?.start()
        }
        #endif

        let interval: TimeInterval = 1.0 / 30.0 // 30 updates/sec
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, self.isRunning else { return }
            let step = (self.basePointsPerSecond * self.currentMultiplier) * CGFloat(interval)
            DispatchQueue.main.async {
                if self.scrollOffset < self.maxContentHeight {
                    self.scrollOffset += step
                }
            }
        }
    }

    public func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    public func resume() {
        if isEnabled && !isRunning {
            start()
        }
    }

    public func toggle() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    public func cycleSpeed() {
        speedIndex = (speedIndex + 1) % Self.speedMultipliers.count
    }

    public func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil

        #if canImport(WatchKit)
        extendedSession?.invalidate()
        extendedSession = nil
        #endif
    }

    deinit {
        stop()
    }
}
