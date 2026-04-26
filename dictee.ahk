#Requires AutoHotkey v2.0
#SingleInstance Force

; ── Settings ─────────────────────────────────────────────────────────────────
PYTHON := "pythonw"
RECPY  := A_ScriptDir . "\record.py"
FLAG   := A_Temp . "\dictee_flag.lock"
WAV    := A_Temp . "\dictee_audio.wav"
CURL   := "C:\Windows\System32\curl.exe"
URL    := "http://localhost:13305/v1/audio/transcriptions"

isRecording := false
recPID      := 0

; ── Tray icon ────────────────────────────────────────────────────────────────
A_IconTip := "NPU Dictation  |  Ctrl+Shift to dictate"
A_TrayMenu.Delete()
A_TrayMenu.Add("NPU Dictation", (*) => 0)
A_TrayMenu.Disable("NPU Dictation")
A_TrayMenu.Add()
A_TrayMenu.Add("Enable / Disable", (*) => ToggleSuspend())
A_TrayMenu.Add("Quit", (*) => ExitApp())

ToggleSuspend() {
    Suspend(-1)
    A_IconTip := A_IsSuspended
        ? "NPU Dictation  |  DISABLED"
        : "NPU Dictation  |  Ctrl+Shift to dictate"
}

; ── Core functions ───────────────────────────────────────────────────────────
StartRec() {
    global isRecording, recPID, PYTHON, RECPY, FLAG, WAV
    if isRecording
        return
    isRecording := true
    try FileDelete(WAV)                         ; remove stale WAV from previous session
    SoundBeep(880, 80)                          ; high beep = recording started
    recPID := Run('"' PYTHON '" "' RECPY '"',, "Hide")
    loop 100 {                                  ; wait for record.py to be ready (max 2 s)
        if FileExist(FLAG)
            break
        Sleep(20)
    }
}

StopRec() {
    global isRecording, recPID, FLAG, WAV, CURL, URL
    if !isRecording
        return
    isRecording := false
    try FileDelete(FLAG)                        ; stop signal for record.py
    ProcessWaitClose(recPID, 4)                 ; wait for recording to finish
    SoundBeep(440, 80)                          ; low beep = recording stopped
    if !FileExist(WAV)
        return
    ; ── Send to NPU via Lemonade ─────────────────────────────────────────────
    tmp := A_Temp . "\dictee_out.txt"
    RunWait('"' CURL '" -s -X POST "' URL '"'
        . ' -F "file=@' WAV '"'
        . ' -F "model=Whisper-Large-v3-Turbo"'
        . ' -F "language=fr"'
        . ' -o "' tmp '"',, "Hide")
    if !FileExist(tmp)
        return
    raw := FileRead(tmp, "UTF-8")
    FileDelete(tmp)
    ; ── Extract text from JSON and paste ─────────────────────────────────────
    if RegExMatch(raw, '"text"\s*:\s*"((?:[^"\\]|\\.)*)"', &m) {
        text := StrReplace(m[1], "\n", "")
        text := Trim(text)
        if text != ""
            SendInput(text)
    }
}

; ── Push-to-talk hotkey: Left Ctrl + Left Shift ──────────────────────────────
; Case 1: Ctrl pressed first, then Shift
LCtrl & LShift:: {
    StartRec()
    KeyWait("LShift")
    StopRec()
}

; Case 2: Shift pressed first, then Ctrl
LShift & LCtrl:: {
    StartRec()
    KeyWait("LCtrl")
    StopRec()
}
