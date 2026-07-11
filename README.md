<h1 align="center">Download It</h1>
<p align="center">A beautiful, native macOS video downloader.</p>
<p align="center"><a href="https://github.com/arnabbagxd/Downloader/releases/latest">Download for macOS</a></p>

Download It lets you download, quickly copy, reveal, and trim videos from social media and video platforms in one focused, Spotlight-style app. Paste a URL from services such as YouTube, Instagram, X, TikTok, Vimeo, Reddit, and [thousands of other sites](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md) supported by [`yt-dlp`](https://github.com/yt-dlp/yt-dlp); the app detects the available resolutions, downloads an MP4 at the quality you pick, copies the finished file to the clipboard, saves it to your chosen folder, and keeps a local history for fast access.

## Features

- Download videos from thousands of `yt-dlp`-supported websites.
- Paste (or drag-and-drop) a URL into a clean, Spotlight-style window.
- **Pick the resolution per video** — the app probes the link and shows the actual available qualities (up to 4K/8K), as selectable boxes.
- Live **download progress** with a percentage ring.
- Convert and merge downloads to broadly compatible MP4 (H.264/AAC when possible).
- Automatically copy the downloaded file after completion.
- Keep a local download history with thumbnails; **swipe a row left to delete**.
- Copy files again, reveal them in Finder, or open the original source URL from history.
- Trim downloaded videos and either save the trimmed MP4 or copy the trimmed clip.
- Choose and persist a custom download folder.
- Check GitHub Releases for app updates from the settings menu.

## Local Development Requirements

These are only needed to build or run the app from source:

- macOS 14 or newer
- Xcode Command Line Tools or Xcode with Swift 5.9+
- [`yt-dlp`](https://github.com/yt-dlp/yt-dlp)
- [`ffmpeg`](https://ffmpeg.org/)

Install the toolchain and runtime dependencies:

```sh
xcode-select --install
brew install yt-dlp ffmpeg
```

Verify the tools are available:

```sh
yt-dlp --version
ffmpeg -version
```

## Build and Run (Local Development)

From the repository root:

```sh
./script/build_and_run.sh
```

The script runs `swift build`, creates a local development app bundle at `dist/Download It.app`, and launches it.

You can also use SwiftPM directly:

```sh
swift build
swift test   # requires full Xcode (XCTest); Command Line Tools alone cannot run tests
```

Useful development script modes:

```sh
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
./script/build_and_run.sh --debug
./script/build_and_run.sh --setup
```

## Release: Signing and Notarization

For a download that opens without Gatekeeper warnings, the app **must** be signed with a
"Developer ID Application" certificate and **notarized** by Apple. This requires an
[Apple Developer Program](https://developer.apple.com/programs/) membership.

1. Copy `.env.example` to `.env` and fill in your signing identity and App Store Connect API key.
   Never commit `.env`, `.p8`, `.p12`, certificates, or private keys — the repo ignores them.
2. Create signed, notarized artifacts and publish a GitHub release:

   ```sh
   ./script/release_macos.sh v1.0.0
   ```

   This runs tests, builds a release `Download It.app`, signs it with a hardened runtime,
   submits it to Apple notarization, staples the ticket, creates
   `dist/release/DownloadIt-macos-<arch>.zip` and `DownloadIt-macos-<arch>.dmg`, and uploads
   both to the matching GitHub release.

3. To build signed, notarized artifacts locally **without** publishing:

   ```sh
   ./script/package_macos.sh
   ```

The in-app updater checks `https://api.github.com/repos/arnabbagxd/Downloader/releases/latest`
and compares the latest release tag (e.g. `v1.0.0`) against `CFBundleShortVersionString`.

## How It Works

Download It uses `yt-dlp` to fetch media and `ffmpeg` to merge, convert, trim, and export
video files. Downloads are saved to the selected local folder. App preferences are stored in
`UserDefaults`, while history and generated thumbnails are stored under the app's Application
Support directory.

## Project Structure

- `Package.swift` — Swift Package Manager manifest.
- `Sources/MediaDownloader` — macOS app source code.
- `Tests/MediaDownloaderTests` — unit tests.
- `script/build_and_run.sh` — local build, bundle, launch, debug, and logging helper.
- `script/package_macos.sh` — signed, notarized local artifacts.
- `script/release_macos.sh` — signed, notarized artifacts published to a GitHub release.
- `script/create_dmg.sh` — creates the drag-to-Applications DMG from a built app bundle.
- `dist/` — generated local app bundle output.

## Notes

Site support depends on the installed `yt-dlp` version. If a site stops working, update
`yt-dlp` first:

```sh
brew upgrade yt-dlp
```

## Credits

Built on the excellent [`yt-dlp`](https://github.com/yt-dlp/yt-dlp) and
[`ffmpeg`](https://ffmpeg.org/) projects. Icons by [Lucide](https://lucide.dev).
