import SwiftUI

public struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var cloudSync = WatchCloudSync.shared

    @AppStorage("watch_autoscroll_enabled") private var autoScrollEnabled: Bool = true
    @AppStorage("watch_autoscroll_speed_index") private var speedIndex: Int = 6
    @AppStorage("watch_reader_font_size") private var fontSize: Double = 12.0
    @AppStorage("watch_reader_side_padding") private var sidePadding: Double = 12.0

    @State private var channelInput: String = ""
    @State private var endpointInput: String = ""
    @State private var testResultText: String = ""
    @State private var isTesting: Bool = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack {
                    Text("Watch Settings")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Done") {
                        saveChanges()
                        dismiss()
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 0.22, green: 0.74, blue: 0.97))
                }

                // Section 1: Cloud Sync Relay
                VStack(alignment: .leading, spacing: 6) {
                    Text("CLOUD RELAY (CLOUDFLARE)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.96, green: 0.62, blue: 0.04))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Channel Key")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        TextField("Channel Key", text: $channelInput)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white)
                    }

                    Button(action: testRelayConnection) {
                        HStack {
                            if isTesting {
                                ProgressView().scaleEffect(0.6)
                            }
                            Text(testResultText.isEmpty ? "Test Relay Ping" : testResultText)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.14, green: 0.14, blue: 0.18))
                        .cornerRadius(4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(8)
                .background(Color(red: 0.08, green: 0.08, blue: 0.1))
                .cornerRadius(6)

                // Section 2: Reader & Auto-Scroll
                VStack(alignment: .leading, spacing: 8) {
                    Text("AUTO-SCROLL ENGINE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.22, green: 0.74, blue: 0.97))

                    Toggle("Enable Auto-Scroll", isOn: $autoScrollEnabled)
                        .font(.system(size: 11))

                    HStack {
                        Text("Speed Preset")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Spacer()
                        Picker("", selection: $speedIndex) {
                            ForEach(0..<AutoScrollController.speedLabels.count, id: \.self) { idx in
                                Text(AutoScrollController.speedLabels[idx]).tag(idx)
                            }
                        }
                        .frame(width: 70)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Text Size: \(Int(fontSize)) pt")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        Slider(value: $fontSize, in: 9...18, step: 1)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Edge Padding: \(Int(sidePadding)) pt")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        Slider(value: $sidePadding, in: 4...24, step: 2)
                    }
                }
                .padding(8)
                .background(Color(red: 0.08, green: 0.08, blue: 0.1))
                .cornerRadius(6)

                // Section 3: Reset
                Button(action: resetToDefaults) {
                    Text("Reset All to Defaults")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.15, green: 0.08, blue: 0.08))
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 6)
        }
        .onAppear {
            self.channelInput = cloudSync.channel
            self.endpointInput = cloudSync.endpoint
        }
    }

    private func testRelayConnection() {
        isTesting = true
        testResultText = "Pinging..."
        cloudSync.channel = channelInput
        cloudSync.checkStatus()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isTesting = false
            testResultText = cloudSync.statusMessage
        }
    }

    private func saveChanges() {
        cloudSync.channel = channelInput
        if !endpointInput.isEmpty {
            cloudSync.endpoint = endpointInput
        }
    }

    private func resetToDefaults() {
        cloudSync.channel = WatchCloudSync.defaultChannel
        cloudSync.endpoint = WatchCloudSync.defaultEndpoint
        channelInput = WatchCloudSync.defaultChannel
        endpointInput = WatchCloudSync.defaultEndpoint
        autoScrollEnabled = true
        speedIndex = 6
        fontSize = 12.0
        sidePadding = 12.0
        testResultText = "Reset applied"
    }
}
