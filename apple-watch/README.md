# Answers for Apple Watch — Lazy Dev Notes

Yeah, this is the watchOS port. Because someone insisted on reading full 10-mark medical exam answers and clinical algorithms on a 40mm wrist screen.

It talks to the same Cloudflare relay worker, receives local Wi-Fi broadcasts from the phone app, draws Mermaid flowcharts on a tiny Canvas, and auto-scrolls so you don't wear out your finger.

---

## What's In Here

* **Cloud Sync**: Grabs papers from Cloudflare relay (`answers` channel). Tap cloud icon, wait 2 seconds.
* **Flowcharts**: Native Canvas renderer for Mermaid graphs. Decision branches hang off the left line, merges collect on the right rail. No crossed lines.
* **Auto-Scroll**: 11 speeds (`0.05x` to `5x`). Tap the screen to pause/resume. Turn the Digital Crown to scroll manually. Long-press to open speed/font controls.
* **Offline Storage**: Saves papers as JSON in sandboxed `Documents/papers/`. If there's nothing saved, it drops in a sample DKA paper so the screen isn't pitch black.

---

## How to Run It

### The Easy Way
```bash
./apple-watch/run_simulator.sh
```
Builds it, boots the simulator if it's sleeping, installs it, launches it. Done.

### In Xcode
1. Open `apple-watch/AnswersWatch.xcodeproj` (do NOT open `Package.swift`, SPM executable targets don't run as watch apps).
2. Scheme: `AnswersWatch`.
3. Pick any watch simulator.
4. Hit `Cmd + R`.

---

## Controls Quick Ref
* **Single Tap**: Pause / resume auto-scroll.
* **Long Press**: Open speed & text size controls.
* **Crown**: Manual scroll (automatically pauses auto-scroll so it doesn't fight you).
* **Left-to-Right Swipe**: Back to questions list.
