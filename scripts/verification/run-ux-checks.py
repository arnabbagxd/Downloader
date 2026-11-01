#!/usr/bin/env python3
"""Run isolated integration checks even on a Mac without XCTest."""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
sdk = os.environ.get('SDKROOT') or subprocess.check_output(['xcrun', '--show-sdk-path'], text=True).strip()
with tempfile.TemporaryDirectory(prefix='downloadit-verification-') as scratch:
    executable = str(Path(scratch) / 'ux-checks')
    sources = sorted(str(p) for p in (root / 'Sources/MediaDownloader').rglob('*.swift') if p.name != 'MediaDownloaderApp.swift')
    subprocess.run(['swiftc', '-parse-as-library', '-sdk', sdk, '-module-cache-path', str(Path(scratch) / 'cache'), *sources, str(root / 'scripts/verification/UXChecks.swift'), '-o', executable], check=True)
    subprocess.run([executable], check=True, timeout=45)
