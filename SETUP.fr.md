# Référence technique — Dictée vocale NPU

Whisper tourne sur le NPU via Lemonade Server. Le GPU (pour Ollama, les jeux, etc.) n'est pas touché.

## Architecture

```
Microphone  →  record.py (sounddevice/Python)  →  WAV 16 kHz mono
                                                         ↓
                         Lemonade Server :13305  →  whisper-server (NPU XDNA2)
                                                         ↓
                         dictee.ahk (AHK v2)  →  SendInput → curseur fenêtre active
```

## Raccourci

| Action | Geste |
|--------|-------|
| Commencer à dicter | Maintenir **Ctrl gauche + Maj gauche** |
| Envoyer / coller | Relâcher l'une ou l'autre touche |
| Activer / Désactiver | Clic droit icône → Enable / Disable |
| Quitter | Clic droit icône → Quit |

Bip haut (880 Hz) = enregistrement démarré  
Bip bas (440 Hz) = enregistrement arrêté, envoi en cours

## Fichiers

```
whisper-npu-dictation\
├── dictee.ahk      AutoHotkey v2 — raccourci + envoi HTTP
├── record.py       Python 3.10+ — capture micro + WAV 16 kHz
├── install.ps1     Installeur idempotent
└── README.md / SETUP.md / LICENSE

Démarrage auto : %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\dictee_vocale.lnk
```

## Démarrer / arrêter Lemonade Server

```powershell
$lem = "$env:LOCALAPPDATA\lemonade_server\bin\lemonade.exe"

# Statut
& $lem status

# Démarrer manuellement (si fermé)
Start-Process "$env:LOCALAPPDATA\lemonade_server\app\lemonade-app.exe"

# Logs serveur
& $lem logs
```

Lemonade démarre automatiquement avec Windows. Le modèle Whisper doit être chargé avant de dicter :

```powershell
& "$env:LOCALAPPDATA\lemonade_server\bin\lemonade.exe" load Whisper-Large-v3-Turbo
```

Le backend NPU est fixé en config globale (`whispercpp.backend = npu`).

## Changer de modèle Whisper

```powershell
$lem = "$env:LOCALAPPDATA\lemonade_server\bin\lemonade.exe"

& $lem unload
& $lem list | Select-String Whisper
& $lem pull Whisper-Small
& $lem load Whisper-Small
```

| Modèle | Taille | Latence estimée |
|--------|--------|-----------------|
| Whisper-Tiny | ~75 MB | < 300 ms |
| Whisper-Base | ~140 MB | ~400 ms |
| Whisper-Small | ~460 MB | ~600 ms |
| Whisper-Large-v3-Turbo | 1,5 GB | ~1,4 s (warm) |

## Changer le raccourci clavier

Éditer `dictee.ahk`, modifier les deux derniers blocs :

```ahk
; Actuel : Ctrl gauche + Maj gauche
LCtrl & LShift:: { StartRec()  KeyWait("LShift")  StopRec() }
LShift & LCtrl:: { StartRec()  KeyWait("LCtrl")   StopRec() }

; Exemple : F8 maintenu
F8:: { StartRec()  KeyWait("F8")  StopRec() }
```

Après modification : clic droit icône → Quit, puis relancer :
```powershell
Start-Process "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" '"<chemin>\dictee.ahk"'
```

## Changer de microphone

`record.py` détecte automatiquement le meilleur périphérique d'entrée (WASAPI > MME > autre). Aucune configuration nécessaire.

Pour lister les périphériques disponibles :

```python
python -c "import sounddevice as sd; print(sd.query_devices())"
```

## Vérifier que le NPU est utilisé

Pendant une transcription active :

```powershell
C:\Windows\System32\AMD\xrt-smi.exe examine -d 00ca:00:01.1 -r all
# Chercher Status=Active dans la ligne whisper-server
```

Via l'API :
```powershell
(Invoke-RestMethod http://localhost:13305/api/v1/system-info).devices.amd_npu
# utilization > 0 pendant l'inférence
```

## Mode Turbo NPU

```powershell
# En tant qu'admin (UAC requis)
Start-Process "C:\Windows\System32\AMD\xrt-smi.exe" -ArgumentList "configure --pmode turbo" -Verb RunAs
```

Modes disponibles : `default`, `powersaver`, `balanced`, `performance`, `turbo`

## Versions installées

| Composant | Version |
|-----------|---------|
| Lemonade Server | 10.2.0 |
| AutoHotkey | v2.0.24 |
| Python | 3.10+ |
| sounddevice | 0.5.5 |
| whisper-server | whisper.cpp v1.8.2 NPU |
| XRT / NPU driver | 2.19.0 / 32.0.203.329 |
| NPU | AMD XDNA2 (Strix Point) — Turbo |
