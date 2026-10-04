# Answers(UPI) (Phone App) — Guide

Look, I didn't want to write this, but here we are. This is the Android phone app for **Answers**. It takes photos of MBBS question papers, parses the messy handwriting or printed text with vision AI, generates comprehensive answers with clinical flowcharts, and beams them to your smartwatch or other phones so you don't have to keep squinting at paper.

Here is what every single button and screen does. Don't make me explain it twice.

---

## 1. Home Screen (Where You Start)

### Top Bar
* **AI Provider Pill** (`Gemini` / `OpenRouter`): Tap it to swap AI backends. When Gemini rate-limits you or you want another model, tap this instead of crying.
* **Pipeline Mode Pill** (`Standard` vs `Honours`): 
  * `Standard`: Normal, sane, concise medical answers.
  * `Honours`: Painfully detailed textbook-grade answers with exhaustive differentials and full Reddit-style Mermaid flowchart algorithms.
* **Cloud Fetch** (Cloud with down arrow): Pulls whatever paper was uploaded to your active Cloudflare relay channel (default: `answers`). Useful if someone else solved the paper for you.
* **Settings** (Gear icon): Where you put your API keys and channel key so the app actually works instead of throwing errors.
* **Incomplete Sessions Button** (Refresh icon next to *RECENT PAPERS*):
  * Opens the recovery screen showing papers that were abandoned, interrupted, or crashed halfway through extraction.
  * Lets you tap **Resume** to pick up where it choked, or **Delete** to nuke the corrupted state off your storage.

### The Big Three Input Buttons
* **Take Photo** (Camera): Opens camera. Snap your physical exam paper. Try to hold the phone still.
* **Pick Image** (Gallery): For when you took a photo earlier, sent it to yourself on WhatsApp, and now want to process it.
* **Load Sample** (Paper icon): Injects a pre-canned *MBBS Final Professional - General Medicine* paper so you can test features without looking for real papers.

### Recent Papers List
* Shows previously saved papers with total marks, question counts, answered ratios, and date.
* Tap any card to open the paper view.
* When inside a paper, the top-right trash icon deletes it forever.

---

## 2. Extraction Screen (Turning Pixels into Structured Questions)

Once you pick an image, you land here.

* **Cropped Preview**: Shows what the vision model is about to inspect.
* **Extraction Prompt Dropdown**: Tap the header to expand/collapse the prompt sent to the model. You can edit the text right there if you need to tell the model to ignore watermarks or hospital stamps.
* **Live Terminal Log**: A dark box that streams stdout/stderr from the pipeline in real-time. If it hangs, look here first.
* **Peer Devices Radar**: Automatically scans local Wi-Fi / Hotspot for Wear OS watches, Apple Watches, or other phones listening on port `42424`.
* **Progress Bar**: Shows which step it's on (Image upload -> OCR -> Schema validation -> Question extraction).
* **Start Extraction**: Actually runs the pipeline.
* **Stop**: The emergency brake. Kills the network request immediately if the AI starts hallucinating.
* **Reset**: Throws everything away and sends you back to Home.

---

## 3. Paper View (The Question List & Batch Solver)

Once extracted, you see the full exam breakdown.

### Actions
* **Generate All Answers**: The "I want to go eat dinner" button. Iterates through every unanswered question sequentially, streams answers from AI, saves them to SQLite, and updates progress.
* **Broadcast Paper**: Sends the entire paper and all its answers over local Wi-Fi / Hotspot directly to connected smartwatches.
* **Stop Generation**: Pauses the batch solver after the current question finishes.

### Questions List
* **Badges**:
  * `10M` / `15M` (Amber): Long essay questions.
  * `3M` / `5M` (Cyan): Short notes.
  * `MCQs` (Purple): Consolidated multiple-choice section.
* **Status**: A green checkmark means the answer is already generated and cached locally. Tap any question to read it.

---

## 4. Answer Reader (Reading What the AI Wrote)

This is the main reading viewport.

### Header & Generation
* **Question Number & Marks**: Shows what question you're reading.
* **Generate / Regenerate**: Tap to fetch or rewrite the answer for just this single question.
* **Prompt Dropdown**: Tap to review the exact clinical prompt used to generate this answer.

### Content Rendering
* **Clinical Markdown**: Sub-headings, bullet lists, bolded high-yield points, drug dosages, and callout boxes.
* **Reddit-Style Mermaid Flowcharts**: 
  * Renders native decision trees directly on AMOLED black.
  * **Left Threadlines**: Decision forks and `[IF: ...]` branch conditions hook off the left line.
  * **Right Rails**: Converging paths route exclusively along the right margin into target nodes. No criss-crossing spaghetti.

### Auto-Scroll Floating Controls
* **Speed Pill** (Bottom-left, e.g. `1x`): Tap to toggle auto-scroll play/pause.
* **Controls Button** (Slider icon): Opens the Auto-Scroll dialog:
  * **Scroll Toggle**: Turn auto-scrolling on or off.
  * **Speed Slider**: 11 discrete steps from super slow (`0.05x`) to speedrun (`5x`).
  * **Text Size Slider**: 9sp to 17sp.
  * **Edge Clearance**: Adjust side padding so text isn't cut off by curved phone screens.
  * **Quick Presets**: `0.2x`, `0.5x`, `1x`, `2x`.

### Exporting & Sharing
* **Export Markdown**: Dumps the pure `.md` file to your Downloads folder.
* **Share Current Paper**: Packs the paper into a `.qaset` archive (or JSON) and opens the Android system share sheet.

---

## 5. Sync & Communication (Getting Data Out)

You don't just use this on the phone. It's meant to sync everywhere without you thinking about it.

### Cloud Relay Sync
* Powered by Cloudflare Workers (`answers-relay.ishikawaadachi.workers.dev`).
* **Channel Key**: Default is `'answers'`. If you and your friend both set channel `'answers'`, you share the same live cloud paper stream.
* Tap the cloud download icon on Home to pull the newest paper from the channel.

### Local Wi-Fi / Hotspot Broadcast (Port 42424)
* No cloud? No problem.
* The phone spins up a lightweight TCP server on port `42424`.
* Any Wear OS watch or Apple Watch running Answers on the same Wi-Fi or phone hotspot auto-receives the full `.qaset` package instantly.

### Quick Settings Tile
* Pull down your Android notification shade.
* Add the **Answers Receive** tile to quickly toggle background listening mode on or off without opening the app.

---

## 6. Prompt Library (Tuning the Brains)

Inside **Settings -> Prompt Library**:
* **Built-in System Prompts**: Contains default clinical templates for standard MBBS extraction, honours answers, and MCQ solvers.
* **Custom Prompts**: Add your own prompts if you have specific exam format requirements.
* **Cloud Sync Prompts**: Downloads updated prompts from the Cloudflare relay. When we patch prompt templates on the server, you tap this to get them without downloading a new APK.

---

## 7. Settings Summary

* **AI Provider**: Gemini / OpenRouter / Custom.
* **API Keys**: Stored in encrypted SharedPreferences.
* **Sync Channel**: Set to `answers`. Don't misspell it.
* **Autoscroll Defaults**: Set your favorite starting speed and font size so you don't have to adjust it every single time you open a question.

Now stop asking questions and go pass your exams.
