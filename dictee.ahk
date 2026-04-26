#Requires AutoHotkey v2.0
#SingleInstance Force

; ── Configuration ────────────────────────────────────────────────────────────
PYTHON := "pythonw"
RECPY  := A_ScriptDir . "\record.py"
FLAG   := A_Temp . "\dictee_flag.lock"
WAV    := A_Temp . "\dictee_audio.wav"
CURL   := "C:\Windows\System32\curl.exe"
URL    := "http://localhost:13305/v1/audio/transcriptions"

isRecording := false
recPID      := 0

; ── Icone barre des taches ────────────────────────────────────────────────────
A_IconTip := "Dictee NPU  |  Ctrl+Maj pour dicter"
A_TrayMenu.Delete()
A_TrayMenu.Add("Dictee vocale NPU", (*) => 0)
A_TrayMenu.Disable("Dictee vocale NPU")
A_TrayMenu.Add()
A_TrayMenu.Add("Activer / Desactiver", (*) => ToggleSuspend())
A_TrayMenu.Add("Quitter", (*) => ExitApp())

ToggleSuspend() {
    Suspend(-1)
    A_IconTip := A_IsSuspended
        ? "Dictee NPU  |  SUSPENDU"
        : "Dictee NPU  |  Ctrl+Maj pour dicter"
}

; ── Fonctions internes ────────────────────────────────────────────────────────
StartRec() {
    global isRecording, recPID, PYTHON, RECPY, FLAG
    if isRecording
        return
    isRecording := true
    SoundBeep(880, 80)                          ; bip haut = debut enregistrement
    recPID := Run('"' PYTHON '" "' RECPY '"',, "Hide")
    loop 100 {                                  ; attendre que record.py soit pret (max 2s)
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
    try FileDelete(FLAG)                        ; signal d'arret pour record.py
    ProcessWaitClose(recPID, 4)                 ; attendre la fin de l'enregistrement
    SoundBeep(440, 80)                          ; bip bas = fin enregistrement
    if !FileExist(WAV)
        return
    ; ── Envoi au NPU via Lemonade ─────────────────────────────────────────────
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
    ; ── Extraction du texte JSON et collage ───────────────────────────────────
    if RegExMatch(raw, '"text"\s*:\s*"((?:[^"\\]|\\.)*)"', &m) {
        text := StrReplace(m[1], "\n", "")
        text := Trim(text)
        if text != ""
            SendInput(text)
    }
}

; ── Raccourci push-to-talk : Ctrl gauche + Maj gauche ────────────────────────
; Cas 1 : Ctrl appuye en premier, puis Maj
LCtrl & LShift:: {
    StartRec()
    KeyWait("LShift")
    StopRec()
}

; Cas 2 : Maj appuyee en premier, puis Ctrl
LShift & LCtrl:: {
    StartRec()
    KeyWait("LCtrl")
    StopRec()
}
