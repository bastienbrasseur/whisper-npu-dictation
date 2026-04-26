# whisper-npu-dictation

> 🇫🇷 [Lire en français](README.fr.md)

Global push-to-talk dictation on Windows, running Whisper **entirely on the AMD Ryzen AI NPU** (XDNA 2). Your GPU stays free for whatever you were already running.

> Built with [Lemonade Server](https://lemonade-server.ai) · powered by [Whisper](https://github.com/openai/whisper) via [whisper.cpp](https://github.com/ggerganov/whisper.cpp)

---

## Why this exists

Every dictation app I found either runs Whisper on the CPU (slow) or grabs the GPU (annoying when you're gaming or running a local LLM). The AMD Ryzen AI NPU sits there doing nothing in most setups. This project makes it earn its place: Whisper inference runs on the XDNA 2 NPU at ~1.4 s latency for a 3-second utterance, GPU untouched.

---

## Demo

> **TODO** — add a GIF here showing: hold Ctrl+Shift → speak → release → text appears in Notepad.  
> A screenshot of Task Manager / `xrt-smi` showing the NPU active during transcription would also help.

---

## Hardware requirements

| Component | Tested | Notes |
|-----------|--------|-------|
| CPU / NPU | AMD Ryzen AI 9 HX 370 (Strix Point, **XDNA 2**) | Other Ryzen AI 300-series chips with XDNA 2 should work |
| NPU driver | `IpuMcdmDriver` ≥ 32.0.203.329 | Check in Device Manager → Compute Accelerator |
| RAM | 32 GB DDR5 | 16 GB is likely fine |
| OS | Windows 11 (build 26200+) | No WSL, fully native |
| GPU | AMD Radeon RX 6800 XT (16 GB) | **Not used for dictation** — stays free for Ollama, games, etc. |

**Not tested on:** Intel NPU, Qualcomm NPU, XDNA 1 (Phoenix/Hawk Point). Pull requests welcome.

---

## How it works

```
Hold Ctrl+Shift
      │
      ▼
dictee.ahk (AutoHotkey v2)
  └─ launches record.py
        └─ sounddevice captures mic at 44 100 Hz
        └─ resamples to 16 000 Hz WAV (numpy)
              │
              ▼ (on key release)
  POST /v1/audio/transcriptions
  → Lemonade Server :13305
        └─ whisper-server process
              └─ Whisper Large-v3-Turbo on XDNA 2 NPU
                    │
                    ▼
              {"text": "your words"}
                    │
              SendInput → active window cursor
```

---

## Quick install

```powershell
git clone https://github.com/bastienbrasseur/whisper-npu-dictation
cd whisper-npu-dictation
.\install.ps1
```

The script checks prerequisites, installs Lemonade Server (one UAC prompt), AutoHotkey v2, Python packages, downloads the Whisper model (~1.5 GB), and launches the hotkey. Idempotent — safe to re-run if something fails halfway.

---

## Manual install (step by step)

If you prefer to control each step, or if `install.ps1` fails at a specific stage, follow the sections below.

---

## Prerequisites

- [Lemonade Server](https://lemonade-server.ai) ≥ 10.2.0 — install the full MSI (not minimal)
- [AutoHotkey v2](https://www.autohotkey.com/) (`winget install AutoHotkey.AutoHotkey`)
- [Python 3.10+](https://www.python.org/) with pip
- [ffmpeg](https://ffmpeg.org/) is **not required** — audio capture uses Python

---

## Installation

**1 — Install Lemonade Server**

Download `lemonade.msi` from the [releases page](https://github.com/lemonade-sdk/lemonade/releases/latest) and run it.

**2 — Install the whispercpp NPU backend and model**

```powershell
$lem = "$env:LOCALAPPDATA\lemonade_server\bin\lemonade.exe"
& $lem backends install whispercpp:npu
& $lem pull Whisper-Large-v3-Turbo
& $lem config set whispercpp.backend=npu
& $lem load Whisper-Large-v3-Turbo
```

**3 — Clone this repo and install Python deps**

```powershell
git clone https://github.com/bastienbrasseur/whisper-npu-dictation
cd whisper-npu-dictation
pip install sounddevice soundfile numpy
```

**4 — Install AutoHotkey v2 and launch the script**

```powershell
winget install AutoHotkey.AutoHotkey
# Then double-click dictee.ahk, or:
Start-Process "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" '"<path-to>\dictee.ahk"'
```

**5 — (Optional) Auto-start on boot**

```powershell
$startup = [Environment]::GetFolderPath('Startup')
$ws  = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut("$startup\dictee_vocale.lnk")
$lnk.TargetPath  = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$lnk.Arguments   = '"<path-to>\dictee.ahk"'
$lnk.Save()
```

---

## Usage

| Action | Gesture |
|--------|---------|
| Start dictating | Hold **Left Ctrl + Left Shift** |
| Send & paste | Release either key |
| Enable / disable | Right-click the tray icon → Enable / Disable |
| Quit | Right-click the tray icon → Quit |

High beep (880 Hz) = recording started  
Low beep (440 Hz) = recording stopped, sending to NPU

---

## Configuration

### Change the hotkey

Edit `dictee.ahk`, replace the two hotkey blocks at the bottom:

```ahk
; Current: Left Ctrl + Left Shift
LCtrl & LShift:: { StartRec()  KeyWait("LShift")  StopRec() }
LShift & LCtrl:: { StartRec()  KeyWait("LCtrl")   StopRec() }

; Example: F8 held
F8:: { StartRec()  KeyWait("F8")  StopRec() }
```

Reload: right-click tray → Quitter, then relaunch `dictee.ahk`.

### Change the Whisper model

Smaller models = faster, less accurate. Larger = slower, better.

```powershell
$lem = "$env:LOCALAPPDATA\lemonade_server\bin\lemonade.exe"
& $lem unload
& $lem pull Whisper-Small        # ~460 MB, ~600 ms
& $lem load Whisper-Small
```

| Model | Size | Approx. latency (3 s audio, warm) |
|-------|------|-----------------------------------|
| Whisper-Tiny | ~75 MB | < 300 ms |
| Whisper-Base | ~140 MB | ~400 ms |
| Whisper-Small | ~460 MB | ~600 ms |
| **Whisper-Large-v3-Turbo** | 1.5 GB | **~1.4 s** ← default |

### Change the microphone

`record.py` auto-detects your microphone by name (prefers WASAPI > MME > WDM-KS). No manual configuration needed when you plug in a different mic.

To list available devices:

```python
python -c "import sounddevice as sd; print(sd.query_devices())"
```

---

## Limitations

- **Manual model load after reboot.** Lemonade Server auto-starts, but does not auto-load the Whisper model. You need to run `lemonade load Whisper-Large-v3-Turbo` once after each reboot (or add it to a startup script).
- **XDNA 2 only (untested on other NPUs).** This was built and tested exclusively on a Ryzen AI 9 HX 370. XDNA 1 (Ryzen 7040/8040 series) may or may not work with the same backend — if you try it, open an issue and let us know.
- **Windows only.** Lemonade's NPU backend for whisper.cpp is Windows-only at the time of writing.
- **Transcription quality is Whisper's.** Accents, background noise, and short utterances are Whisper's problem, not this project's. Large-v3-Turbo handles French well; smaller models can struggle with proper nouns.
- **The Z key** was an early hotkey candidate and is no longer used. The default is Left Ctrl + Left Shift.
- **No streaming.** Whisper processes the full audio clip after you release the key. There is no word-by-word streaming.

---

## Verify NPU is being used

Run this while a transcription is in progress:

```powershell
C:\Windows\System32\AMD\xrt-smi.exe examine -d 00ca:00:01.1 -r all
# Look for Status=Active in the whisper-server row
```

Or via the Lemonade API:
```powershell
(Invoke-RestMethod http://localhost:13305/api/v1/system-info).devices.amd_npu
# utilization > 0 during inference
```

---

## Credits

- **[Lemonade Server](https://lemonade-server.ai)** (AMD / lemonade-sdk) — the NPU-aware local AI runtime that makes this possible. Apache 2.0.
- **[Whisper](https://github.com/openai/whisper)** (OpenAI) — the speech recognition model. MIT.
- **[whisper.cpp](https://github.com/ggerganov/whisper.cpp)** (ggerganov) — the C++ inference engine with NPU support. MIT.
- **[sounddevice](https://python-sounddevice.readthedocs.io/)** — Python audio I/O. MIT.

---

## License

MIT — see [LICENSE](LICENSE).  
Compatible with Lemonade (Apache 2.0) and whisper.cpp (MIT).

---

## Contributing

Issues and PRs welcome. If you test this on a different Ryzen AI chip, please open an issue with your results — even "it doesn't work" is useful data.

See [SETUP.md](SETUP.md) for the full technical walkthrough of how this was built.

---

## Fork ideas & improvements

This project is intentionally small — two files, one idea. Here's what it doesn't do yet, in case you want to take it somewhere:

**Hardware / platform**
- **XDNA 1 support (Ryzen 7040/8040 — Phoenix, Hawk Point).** The same Lemonade + whisper.cpp stack might work with degraded performance. Worth a try and a comparison table.
- **Linux port.** Lemonade Server runs on Linux; the Python recorder already works cross-platform. The missing piece is replacing AutoHotkey — `python-xlib` or `evdev` could handle global hotkeys on X11/Wayland.
- **Qualcomm Snapdragon X NPU.** Lemonade supports it experimentally. Someone with a Copilot+ PC could swap the backend and test.

**Smarter audio**
- **Voice activity detection (VAD).** Replace push-to-talk with automatic silence detection — start recording when you speak, stop when you stop. [silero-vad](https://github.com/snakers4/silero-vad) runs on CPU and is fast enough.
- **Streaming transcription.** Send audio chunks every 2–3 s instead of waiting for key release. Reduces perceived latency at the cost of accuracy on sentence boundaries.
- **Better resampling.** The current numpy linear interpolation is good enough but not audiophile-grade. Drop in `scipy.signal.resample_poly` or `soxr` for higher quality (matters more for accents and quiet speakers).

**Text output**
- **Voice commands on top of dictation.** Intercept recognized phrases like "new line", "delete that", "select all" before pasting. A small lookup table in `dictee.ahk` covers 80% of use cases.
- **Clipboard mode vs. SendInput mode.** `SendInput` breaks in some apps (terminals, games, remote desktop). A fallback that writes to clipboard + Ctrl+V would be more robust.
- **Language toggle.** Hotkey or voice command to switch between `language=fr` and `language=en` on the fly.

**Integrations**
- **VS Code extension.** A VS Code extension that calls the same Lemonade endpoint and inserts text at cursor via the extension API — no AHK needed, works cross-platform.
- **Obsidian plugin.** Same idea, Obsidian has a clean plugin API. Useful for voice-driven note-taking.
- **Browser extension.** A WebExtension that listens for a keyboard shortcut, records via `getUserMedia`, POSTs to `localhost:13305`, and fills the focused input. Works in any browser, any OS.
- **System tray rewrite in Python.** Replace the AHK dependency with a pure Python tray app using `pystray` + `pynput`. One fewer dependency, easier to package as an `.exe` with PyInstaller.

**Quality of life**
- **Auto-load Whisper on boot.** Wrap `lemonade load` in a scheduled task or startup script so the model is ready before you need it.
- **Visual recording indicator.** A small always-on-top overlay (red dot) during recording, dismissible and semi-transparent. AHK v2 can draw GUI elements.
- **Per-app language profiles.** Use `WinGetTitle` in AHK to detect the active window and switch Whisper language automatically — French in your browser, English in your IDE.
