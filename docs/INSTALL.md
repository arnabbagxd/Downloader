# Installing Download It

Download It is free and safe, but it isn't yet notarized by Apple (that requires a paid
Apple Developer account, which we'll add later). Because of that, macOS shows a one-time
warning the **first** time you open it. Here's how to get past it — it takes about 10 seconds,
and you only do it **once**.

## Step 1 — Install the app

1. Download **`DownloadIt-macos-arm64.dmg`**.
2. Double-click it to open, then **drag the Download It icon onto the Applications folder**.
3. Eject the disk image (drag it to the Trash / click the ⏏ next to it in Finder).

## Step 2 — Open it the first time

1. Open your **Applications** folder and double-click **Download It**.
2. You'll see a message like *"Apple could not verify 'Download It' is free of malware."*
   Click **Done** (do **not** click "Move to Trash").
3. Open  → **System Settings** → **Privacy & Security**.
4. Scroll down to the **Security** section. You'll see:
   *"Download It was blocked to protect your Mac."* → click **Open Anyway**.
5. Confirm with **Open Anyway** and enter your Mac password / Touch ID if asked.

That's it — Download It opens normally, and every time after this it opens with a simple
double-click, no warnings.

> **Older macOS (Monterey / Ventura)?** You can instead **right-click (or Control-click)
> the app → Open → Open** in the dialog. On the newest macOS, use the System Settings steps above.

## Also install the two helpers

Download It uses two free, widely-used tools to do the actual downloading and video trimming.
Install them once with [Homebrew](https://brew.sh):

```sh
brew install yt-dlp ffmpeg
```

The app will also prompt you and show this command if the tools are missing.

## Is this safe?

Yes. The warning appears for **every** app that isn't signed with a paid Apple Developer
account — it is not specific to Download It and does not mean anything is wrong. The app is
open source; you can read every line of the code at
<https://github.com/arnabbagxd/Downloader>.

---

### Landing-page snippet (copy/paste)

> **First time opening?** macOS shows a one-time security prompt for apps not yet notarized
> by Apple. Just go to **System Settings → Privacy & Security → Open Anyway**. You only do
> this once. [Full instructions →](https://github.com/arnabbagxd/Downloader/blob/main/docs/INSTALL.md)
