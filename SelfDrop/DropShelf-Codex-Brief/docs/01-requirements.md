# Product requirements

## Problem and goal
A Mac user currently minimizes maximized apps or visits Finder/Desktop to drag files. DropShelf stages files, images and folders and remains accessible when switching to a destination app, including ordinary maximized windows and supported native full-screen Spaces. It is a wrapper around macOS drag-and-drop, not a replacement for it.

## Confirmed functional requirements
| ID | Requirement |
|---|---|
| R01 | Native Swift/AppKit app; local, lightweight, no server. |
| R02 | Small blue floating drop button on right edge, not center. Compact panel opens inward from right edge. |
| R03 | Drop existing files/folders directly on collapsed button without opening. Brief rounding/expansion and success indication on accepted intake; then return to idle. |
| R04 | Clicking button opens shelf. Drag one or several selected items out to destination; support long-press multi-selection and normal single-item behavior. |
| R05 | Store existing file/folder references only, in memory, never copy contents into shelf. No restore on restart or persistent history. |
| R06 | Retain manually staged references after a successful/cancelled/rejected outgoing drag; manual removal affects references only. Deduplicate. No manual-item TTL explicitly required; session lifetime. |
| R07 | Use latest original file content; attempt to resolve rename/move; mark missing or inaccessible items unavailable; disconnected external volume temporarily unavailable. |
| R08 | Automatically collect newly saved macOS screenshots in selected screenshot folder (Desktop by default when applicable). No custom screen capture. Separate from manual items. |
| R09 | Screenshot queue at most 10 newest references, oldest-first eviction, per-item one-hour expiration, newest-first display. Never delete originals. |
| R10 | Native drag payloads, not string paths. Validate actual attachments in ChatGPT and actual copy to a VS Code Explorer folder; opening folders/files in supported targets. Multi-file drag required. |
| R11 | Low CPU, memory and UI overhead. 100 MB maximum RAM budget for release acceptance, idle CPU near zero. No continuous polling. |
| R12 | Graceful failures, native OS integration, stable daily use. |

## Suggested interactions / scope boundaries
Owner requested a convenient recent-item copy/paste option and ability to handle floating screenshot thumbnails and clipboard screenshots where feasible. These are not permission to store image data indefinitely or simulate keystrokes. Quick Copy (double click) and Quick Drag (drag from collapsed button) were proposed; exact latest-item policy remains open. See docs/07. Clipboard-only images may have no file URL; handle only within approved storage policy. Do not claim every app supports every drop type.

## Non-goals
Persistent shelf, database, cloud sync, background screen recording, screenshot replacement, full clipboard history, global key interception, automatic paste into arbitrary apps, recursive folder enumeration, arbitrary website URL staging, application-specific upload APIs, file manager or original-file cleanup. No broad privileges by default.
