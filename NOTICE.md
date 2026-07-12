# Third-Party Components

Download It relies on two external command-line tools. It downloads them automatically on
first launch (into `~/Library/Application Support/MediaDownloader/bin`) so you don't need to
install anything yourself.

## yt-dlp

- Purpose: downloads media from supported websites.
- License: The Unlicense (public domain).
- Project & source: https://github.com/yt-dlp/yt-dlp
- Fetched at runtime from the project's official GitHub releases.

## ffmpeg

- Purpose: merges, converts, and trims video/audio.
- License: GPL / LGPL. See https://ffmpeg.org/legal.html
- Project & source: https://ffmpeg.org — source: https://ffmpeg.org/download.html
- Download It uses unmodified static builds as a runtime helper only. They are hosted for
  convenient download on this repository's `runtime-tools` release:
  - Apple Silicon (arm64) build originally from https://www.osxexperts.net
  - Intel (x86_64) build originally from https://evermeet.cx/ffmpeg/
  The corresponding ffmpeg source code is available at the ffmpeg.org link above.

These tools are the property of their respective authors and are used in accordance with
their licenses. Download It itself does not modify them.
