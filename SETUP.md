# Technical reference — NPU dictation

Whisper runs on the NPU via Lemonade Server. The GPU (for Ollama, games, etc.) is untouched.

## Architecture

```
Microphone  →  record.py (sounddevice/Python)  →  WAV 16 kHz mono
                                                         ↓
                         Lemonade Server :13305  →  whisper-server (NPU XDNA2)
                                                         ↓
                         dictee.ahk (AHK v2)  →  SendInput → active window cursor
```

## Hotkey

| Action | Gesture |
|--------|---------|
| Start dictating | Hold **Left Ctrl + Left Shift** |
| Send & paste | Release either key |
| Enable / Disable | Right-click tray icon → Enable / Disable |
| Quit | Right-click tray icon → Quit |

High beep (880 Hz) = recording started  
Low beep (440 Hz) = recording stopped, sending to NPU

## Files

```
whisper-npu-dictation\
├── dictee.ahk      AutoHotkey v2 — hotkey + HTTP send
├── record.py       Python 3.10+ — mic capture + 16 kHz WAV
├── install.ps1     Idempotent installer
└── README.md / SETUP.md / LICENSE

Auto-start: %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\dictee_vocale.lnk
```

## Start / stop Lemonade Server

```powershell
$lem = "$env:LOCALAPPDATA\lemonade_server\bin\lemonade.exe"

# Status
& $lem status

# Start manually (if closed)
Start-Process "$env:LOCALAPPDATA\lemonade_server\app\lemonade-app.exe"

# Server logs
& $lem logs
```

Lemonade starts automatically with Windows. The Whisper model must be loaded before dictating (NPU backend is set as default):

```powershell
& "$env:LOCALAPPDATA\lemonade_server\bin\lemonade.exe" load Whisper-Large-v3-Turbo
```

The NPU backend is pinned in global config (`whispercpp.backend = npu`) — no need to pass `--whispercpp npu` manually.

## Change the Whisper model

```powershell
$lem = "$env:LOCALAPPDATA\lemonade_server\bin\lemonade.exe"

# Unload current model
& $lem unload

# List available Whisper models
& $lem list | Select-String Whisper

# Pull a different model
& $lem pull Whisper-Small
& $lem pull Whisper-Base

# Load on NPU
& $lem load Whisper-Small
& $lem load Whisper-Large-v3-Turbo   # default
```

| Model | Size | Estimated latency |
|-------|------|-------------------|
| Whisper-Tiny | ~75 MB | < 300 ms |
| Whisper-Base | ~140 MB | ~400 ms |
| Whisper-Small | ~460 MB | ~600 ms |
| Whisper-Large-v3-Turbo | 1.5 GB | ~1.4 s (warm) |

## Change the hotkey

Edit `dictee.ahk`, modify the two hotkey blocks at the bottom:

```ahk
; Current: Left Ctrl + Left Shift
LCtrl & LShift:: {
    StartRec()
    KeyWait("LShift")
    StopRec()
}
LShift & LCtrl:: {
    StartRec()
    KeyWait("LCtrl")
    StopRec()
}
```

Other examples:

```ahk
; F8 held
F8:: { StartRec()  KeyWait("F8")  StopRec() }

; CapsLock held
CapsLock:: { StartRec()  KeyWait("CapsLock")  StopRec() }
```

After editing: right-click tray → Quit, then relaunch:
```powershell
Start-Process "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" '"<path-to>\dictee.ahk"'
```

## Change the microphone

`record.py` auto-detects the best available input device (WASAPI > MME > other). No manual configuration needed when switching microphones.

To list available devices:

```python
python -c "import sounddevice as sd; print(sd.query_devices())"
```

## Verify the NPU is being used

During an active transcription:

```powershell
C:\Windows\System32\AMD\xrt-smi.exe examine -d 00ca:00:01.1 -r all
# Look for Status=Active in the whisper-server row
```

Via the API:
```powershell
(Invoke-RestMethod http://localhost:13305/api/v1/system-info).devices.amd_npu
# utilization > 0 during inference
```

## NPU Turbo mode

Enabled by default after initial setup. To reapply after a reboot:

```powershell
# Requires admin (UAC prompt)
Start-Process "C:\Windows\System32\AMD\xrt-smi.exe" -ArgumentList "configure --pmode turbo" -Verb RunAs
```

Available modes: `default`, `powersaver`, `balanced`, `performance`, `turbo`

## Versions tested

| Component | Version |
|-----------|---------|
| Lemonade Server | 10.2.0 |
| AutoHotkey | v2.0.24 |
| Python | 3.10+ |
| sounddevice | 0.5.5 |
| whisper-server | whisper.cpp v1.8.2 NPU |
| XRT / NPU driver | 2.19.0 / 32.0.203.329 |
| NPU | AMD XDNA2 (Strix Point) — Turbo |
