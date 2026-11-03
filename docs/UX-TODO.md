# Download It — preview checklist

Branch: `codex/menu-bar-activity`. Preview: `dist/Download It Preview.app`.
Shipping is explicitly held until the user reviews and approves the preview. No merge, release, or installed-app replacement has been performed.

## Activity and progress

- [x] Native menu bar icon, measured progress, batch counts, elapsed time, and activity panel.
- [x] Last result/error survives toast dismissal and app relaunch; recent-file Copy and Finder actions.
- [x] Cancel owned download/conversion processes and network tasks; check cancellation between PDF pages and batch items.
- [x] Stage single-video downloads in owned temporary directories; clean cancelled encoder/zip output and collection staging.
- [x] Retry with the chosen inputs/options within the current app session.
- [x] Display engine-reported transfer speed/ETA for single-video downloads. Conversion stages remain indeterminate when no estimate is available.
- [x] Optional completion/error notifications; off by default, macOS permission required.
- [x] Prevent quitting during an active task through the panel or application menu.
- [ ] Verify cancellation of real multi-process yt-dlp/FFmpeg jobs and network transfers end to end.
- [ ] Add per-item failure details and Retry Failed (current Retry Task repeats the selected batch and may save additional copies of completed items).
- [ ] Notification delivery and permission-denied behavior on the packaged app need live verification.

## Download controls

- [x] Always-visible Settings, visible destination folder, Open/Change folder controls.
- [x] Image previews and video thumbnails when supplied by the extractor.
- [x] Choose options first, then explicitly Download/Convert.
- [x] Remember single-video quality and image output format/quality.
- [x] Select individual images, PDF pages, playlist videos, and collection items; Select All/Clear.
- [x] Disclose playlist/profile extraction caps.
- [ ] Estimated output sizes and remembered collection save mode remain future refinements.

## Library

- [x] Separate resizable Library window with search and All/Videos/Images/Archives filters.
- [x] Format, size, resolution when readable, and creation date.
- [x] Open/Copy/Show in Finder/Open Source/Remove actions and context menu.
- [x] Undo the latest history removal, including Remove All; original files stay on disk.
- [x] Missing-file labels and disabled file actions in Library and the activity panel.

## Accessibility and polish

- [x] Native controls, semantic colors, labels for new icon actions and input.
- [x] Remove the Tab interception so native focus navigation can work.
- [x] Add application-menu shortcuts: Library Command-L, Activity Command-Shift-A, Settings Command-comma.
- [x] Scroll the main content vertically when cards exceed the window height; resizable Library.
- [x] Respect Reduce Motion for popover and main entrance/trim transitions.
- [x] Inspect the launched main screen and accessibility tree; correct destination-row contrast after the first visual pass.
- [ ] Complete live keyboard/VoiceOver, contrast in both appearances, small-display, and all-state visual checks. UI automation was interrupted/timed out during Library interaction; this is not visual sign-off.

## Validation and shipping

- [x] Compatible SDK build and separate ad-hoc-signed preview package.
- [x] Direct checks: real process cancellation before/during launch; PDF success and temporary cleanup; error retention beyond toast timeout; result persistence; retry/dismiss; isolated history remove/clear/Undo and original-file preservation.
- [x] Attempt full `swift test`.
- [ ] Full XCTest pass: blocked because installed Command Line Tools cannot resolve XCTest. A complete Xcode toolchain is required.
- [ ] User review of the preview.
- [ ] After approval and outstanding validation: merge, publish a versioned release, verify update flow, and update the installed app.

## Review notes

The preview has a separate bundle identifier and release updates are disabled inside it. It still uses the existing shared history/tools directory; history changes in the preview are real, with Undo available for the latest removal. Results persist across launches, but retry closures are session-only. Completed batch files remain on disk if a later item fails or the task is cancelled. A persistent queue, pause/resume, and Retry Failed are not included.

Direct integration checks are reproducible with `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk python3 scripts/verification/run-ux-checks.py`. The default SDK 27 currently has a SwiftUI macro/toolchain mismatch on this machine; SDK 26.5 compiles successfully. Logs from this session are in `/private/tmp/downloader-speed/ux-build.log`, `ux-tests.log`, and `ux-check.log`.
