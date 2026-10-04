# Answers(UPI) (Phone App) — Guide

Android phone app for **Answers**. Captures exam question papers, extracts questions via vision AI, generates structured clinical answers with flowcharts, and syncs them to smartwatches and peer devices.

---

## 1. Home Screen

### Top Bar
* **AI Provider Pill** (`Gemini` / `OpenRouter`): Toggles the active AI model backend.
* **Pipeline Mode Pill** (`Standard` / `Honours`):
  * `Standard`: Concise, high-yield answers tailored to base marks.
  * `Honours`: In-depth textbook answers with full differentials and Mermaid flowcharts.
* **Cloud Fetch** (Cloud icon): Downloads the latest paper uploaded to the active Cloudflare relay channel (`answers`).
* **Settings** (Gear icon): Configure API keys, provider endpoints, autoscroll defaults, and sync channels.
* **Incomplete Sessions** (Refresh icon next to *RECENT PAPERS*):
  * Lists papers interrupted or partially solved.
  * **Resume**: Continues answer generation where it stopped.
  * **Delete**: Removes the partial session.

### Paper Input
* **Take Photo**: Captures a physical exam paper using the camera.
* **Pick Image**: Selects an existing photo from device storage.
* **Load Sample**: Loads a bundled *MBBS Final Professional - General Medicine* sample paper.

### Recent Papers
* Displays saved papers with total marks, question count, answered count, and timestamp.
* Tap any card to open the paper view.
* Inside a paper, tap the trash icon in the toolbar to delete it.

---

## 2. Extraction Screen

Shown after capturing or selecting a paper image.

* **Image Preview**: Displays the cropped paper image sent to the vision model.
* **Extraction Prompt Dropdown**: Expandable panel to inspect or edit the OCR extraction prompt before running.
* **Terminal Log**: Real-time console log showing pipeline progress and errors.
* **Peer Devices Radar**: Scans the local network/hotspot for active watches and phones listening on port `42424`.
* **Progress Bar**: Visual status across OCR, JSON schema validation, and question extraction.
* **Start Extraction**: Initiates the extraction pipeline.
* **Stop**: Cancels the running extraction request.
* **Reset**: Clears the current session and returns to Home.

---

## 3. Paper View

Displays extracted questions and handles batch solving.

### Actions
* **Generate All Answers**: Sequentially generates answers for all remaining questions, saving each to the local database.
* **Broadcast Paper**: Sends the full paper and generated answers over local Wi-Fi / hotspot to connected watches.
* **Stop Generation**: Pauses the batch solver after the active question completes.

### Question Items
* **Marks Badges**:
  * `10M` / `15M` (Amber): Long essay questions.
  * `3M` / `5M` (Cyan): Short notes.
  * `MCQs` (Purple): Multiple-choice section.
* **Status**: A green checkmark indicates an answer is cached locally. Tap any item to open the answer reader.

---

## 4. Answer Reader

Main reading interface for individual answers.

### Header & Actions
* **Question Title & Marks**: Displays question number and assigned marks.
* **Generate / Regenerate**: Generates or rewrites the answer for the current question.
* **Prompt Dropdown**: Displays the clinical prompt template used for the answer.

### Content Rendering
* **Markdown**: Structured headings, bullet lists, high-yield bold highlights, tables, and drug dosages.
* **Mermaid Flowcharts**: Native clinical flowcharts rendered on black background.
  * **Left Threadline**: Branch forks and `[IF: ...]` decision conditions.
  * **Right Rail**: Converging paths route down the right side into target nodes.

### Auto-Scroll Controls
* **Speed Pill** (Bottom-left): Tap to toggle auto-scroll between play and pause.
* **Settings Dialog** (Slider icon):
  * **Toggle**: Enable or disable continuous scrolling.
  * **Speed**: Discrete steps from `0.05x` to `5x`.
  * **Text Size**: `9sp` to `17sp`.
  * **Edge Clearance**: Adjust horizontal margins for curved or bezel-less displays.
  * **Presets**: Quick-select buttons for `0.2x`, `0.5x`, `1x`, and `2x`.

### Export & Share
* **Export Markdown**: Saves the raw `.md` file to the device Downloads directory.
* **Share Current Paper**: Exports the paper as a `.qaset` bundle or JSON to the Android share sheet.

---

## 5. Sync & Data Transfer

### Cloud Relay Sync
* Backend: Cloudflare Workers (`answers-relay.ishikawaadachi.workers.dev`).
* **Channel Key**: Default is `'answers'`. Devices configured with the same channel name sync papers automatically.
* Tap Cloud Download on Home to fetch the latest paper uploaded to the active channel.

### Local Network Broadcast (Port 42424)
* Starts a local TCP server on port `42424`.
* Wear OS and Apple Watch clients on the same Wi-Fi or hotspot receive papers directly without an internet connection.

### Quick Settings Tile
* Android Quick Settings tile: **Answers Receive**.
* Toggles the background P2P receive listener on or off from the notification shade.

---

## 6. Prompt Library

Accessible via **Settings -> Prompt Library**.

* **Built-in Templates**: Factory prompts for question extraction, MCQ solving, 1.5x candidate drafting, 1.0x distillation, and flowchart summary addons.
* **Custom Prompts**: Create, edit, and assign custom prompt templates per operation.
* **Cloud Sync Prompts**: Fetch published prompt updates from the relay server.

---

## 7. Configuration Reference

* **AI Provider**: Gemini, OpenRouter, or Custom API endpoint.
* **API Keys**: Stored securely in encrypted SharedPreferences.
* **Sync Channel**: Cloud relay channel key (default: `answers`).
* **Default Auto-Scroll**: Sets initial speed and text size preferences across sessions.
