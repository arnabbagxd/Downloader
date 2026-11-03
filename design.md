# Activity panel redesign brief

Status: **Approved as the direction for a design board** on 2026-11-03. This document defines the direction for the menu bar activity popover; the board and SwiftUI implementation remain separate review steps.

## Scope and source of truth

Redesign the activity popover rendered by `MenuBarActivityView.swift` and presented by `MenuBarController.swift`. Keep its existing capabilities: task progress and result, Cancel and Retry, error copying, Paste Link, Open App, three recent files with Copy and Finder actions, history removal and Undo, Library and download folder access, completion notifications, Settings, and Quit. The app is a native macOS utility; this is a focused refinement of that interface, not a new product surface.

The current UI is a 360-point-wide material popover with a 20-point inset. It mixes SF Symbols in this panel with Lucide icons elsewhere, uses several rounded glass treatments, and places task status, two prominent actions, recent files, a settings toggle, and utility controls in one vertical stack. The status card's controls and metrics can become scattered when a task is running or fails. There is no explicit height strategy for a long title, four lines of detail, progress, transfer data, three files, and the footer on a smaller display.

## Direction

- **Product:** Download It helps a Mac user collect and prepare media from links and local files without managing command-line tools.
- **Character:** Quiet, precise, reassuring.
- **World:** A compact Mac utility beside the system menu bar, with the downloaded file itself as the useful artifact.
- **Moments:** The live progress indicator and a real recent-file thumbnail carry the visual detail. Other chrome stays subdued.
- **Signature:** A small, consistently placed progress circle ties the menu bar indicator to the task row in the popover.

The existing app icon and blue accent are established brand cues. Keep system typography, semantic macOS colors, and native control behavior. Use the accent for progress, selection, and the primary action; use semantic red only for failure. Material remains the outer popover surface, while content groups use a restrained surface step rather than multiple glass layers.

## Information hierarchy

1. **Current activity:** What is happening, its measured progress when available, and the one next action that matters.
2. **Open the app:** A clear route to the full task flow. Paste Link is the nearby secondary action.
3. **Recent files:** Up to three completed files, with direct Copy and Finder actions, then Show All Files.
4. **Preferences and utility:** Notifications, Settings, destination folder, and Quit remain available with lower visual weight.

## Proposed composition

Keep the popover at approximately 360 points wide. Use a 20-point outer inset, a 4-point spacing rhythm, and 16 to 20 points between major groups. Give each group one clear alignment line. Avoid adding a navigation sidebar or another window.

| Area | Proposed treatment |
| --- | --- |
| Header | App name at the leading edge; Settings as one trailing icon button with a clear focus and hover state. The app mark or a single system symbol can sit beside the name, but it should not compete with task status. |
| Activity | One surface with a status icon/progress circle, short title, secondary detail, and a right-aligned percentage when measurable. Put transfer speed, ETA, and elapsed time on a compact secondary line. Place Cancel or Retry in a consistent action row inside this surface. Keep Dismiss as a labeled accessibility action. |
| Primary actions | Open App is the primary button. Paste Link is secondary and disabled while busy or while tools are unavailable, matching current behavior. |
| Recent files | A section heading with Undo and folder access as small utility actions. Three equal-height rows use a 38-point thumbnail, one-line title, one-line source or missing-file message, and aligned Copy/Finder buttons. Show All Files is a plain full-width row with a chevron. |
| Footer | Completion notifications and the privacy/working message sit below the files with a quiet divider. Quit stays visible and is disabled while busy. |

The panel should fit on smaller displays by making the content area scroll when needed, while keeping the header and main task summary easy to find. Do not clip long task details or file names without a tooltip, selection, or accessibility text that exposes the full value.

## State behavior

| State | Status content | Available next action |
| --- | --- | --- |
| Idle, no prior task | “Ready when you are” with one sentence about links and files | Open App; Paste Link when usable |
| Probing or refining | Current probe message and an indeterminate indicator | Open App; cancellation only if the model supports it |
| Running with measured progress | Task title, percentage, progress track, transfer detail when supplied, elapsed time | Cancel Task |
| Running without measured progress | Task title, indeterminate indicator, elapsed time | Cancel Task |
| Succeeded | “Finished” and the retained result detail | Dismiss result; recent-file actions when present |
| Failed | “Needs attention” and selectable error summary | Retry Task when supported; Copy Error Details; Dismiss |
| Cancelled | “Cancelled” and retained detail | Retry Task when supported; Dismiss |

State changes should not reorder unrelated sections. Never imply an ETA when the engine has not supplied one. Keep the latest result visible until dismissed or replaced, as the current model does. Copy and Finder actions must remain disabled for missing files, with the missing-file message visible.

## Visual and interaction rules

- **Type:** Use the macOS system font. Limit the panel to a compact title, body text, and caption/meta role; use semibold only for section and task titles. Use tabular digits for percentages, elapsed time, speed, and counts.
- **Color:** Use semantic primary, secondary, and tertiary text. Keep the existing `#0A84FF` accent for active progress and the main action. Ensure contrast in light and dark appearances and with Reduce Transparency enabled.
- **Shape:** Preserve the native popover silhouette. Use one moderate radius for the activity surface and smaller radii for rows and icon buttons. Avoid extra pills around every element.
- **Icons:** Use one consistent icon family within this panel. Match the current system menu bar icon and macOS controls; do not mix icon styles in adjacent actions.
- **Motion:** Use short state transitions only where they clarify a change. Respect Reduce Motion; avoid scale effects or looping decoration. The indeterminate indicator may animate only while work is active.
- **Keyboard and accessibility:** Keep a logical top-to-bottom focus order, visible focus rings, native button semantics, meaningful labels for icon-only controls, and a spoken progress value. Enter should continue to open the app unless focus is on another control. Preserve the existing menu bar status text and tooltip.
- **Copy:** Use direct labels such as “Cancel Task,” “Retry Task,” “Copy Error Details,” and “Show All Files.” Keep technical error details selectable and copyable; avoid celebratory or marketing copy.

## Review criteria for the later design board

The board should show light and dark appearances and these states: idle, probing, measured download, indeterminate conversion, success, failure, and a recent file whose original has moved. It should show the complete popover at its intended width, including the lower controls, plus a constrained-height version. The board should annotate spacing, type roles, color roles, focus order, and state-specific actions. Use plausible file names and real product terminology, without invented performance claims or fake progress data.

## Approval boundary

The user approved proceeding from this brief to a design board. Review the board to settle the final layout and component details before implementing the SwiftUI view. The approved brief may be added to GitHub; the board and implementation remain local until reviewed.

Methodology credit: informed by *unslop* by Damir Sokolovsky (CC BY 4.0); the proposed visual language remains specific to Download It and native macOS.
