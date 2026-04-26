# Dictée vocale globale — NPU AMD XDNA 2

Whisper tourne sur le NPU via Lemonade Server. Le GPU (RX 6800 XT / Ollama) n'est pas touché.

## Architecture

```
Micro Fifine  →  record.py (sounddevice/Python)  →  WAV 16 kHz mono
                                                          ↓
                          Lemonade Server :13305  →  whisper-server (NPU XDNA2)
                                                          ↓
                          dictee.ahk (AHK v2)  →  SendInput → curseur actif
```

## Raccourci

| Action | Geste |
|--------|-------|
| Commencer à dicter | Maintenir **Ctrl gauche + Maj gauche** |
| Envoyer / coller | Relâcher les deux touches |
| Activer / Désactiver | Clic droit icône AHK → Activer / Désactiver |
| Quitter | Clic droit icône AHK → Quitter |

Bip haut (880 Hz) = début enregistrement  
Bip bas (440 Hz) = fin, envoi en cours

## Fichiers

```
C:\scripts\dictee\
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

Lemonade démarre automatiquement avec l'app desktop au lancement de Windows.  
Le modèle Whisper doit être chargé avant de dicter (le backend NPU est configuré par défaut) :

```powershell
& "$env:LOCALAPPDATA\lemonade_server\bin\lemonade.exe" load Whisper-Large-v3-Turbo
```

Le backend NPU est fixé en config globale (`whispercpp.backend = npu`) — plus besoin de `--whispercpp npu`.

## Changer de modèle Whisper

```powershell
$lem = "$env:LOCALAPPDATA\lemonade_server\bin\lemonade.exe"

# Décharger le modèle actuel
& $lem unload

# Lister les modèles Whisper disponibles
& $lem list | Select-String Whisper

# Télécharger un autre modèle (ex: plus léger)
& $lem pull Whisper-Small
& $lem pull Whisper-Base

# Charger avec backend NPU
& $lem load Whisper-Small --whispercpp npu
& $lem load Whisper-Large-v3-Turbo --whispercpp npu   # modèle actuel
```

| Modèle | Taille | Latence estimée |
|--------|--------|-----------------|
| Whisper-Tiny | ~75 MB | < 300 ms |
| Whisper-Base | ~140 MB | ~400 ms |
| Whisper-Small | ~460 MB | ~600 ms |
| Whisper-Large-v3-Turbo | 1,5 GB | ~1,4 s (warm) |

## Changer le raccourci clavier

Editer `C:\scripts\dictee\dictee.ahk`, modifier les deux derniers blocs :

```ahk
; Raccourci actuel : Ctrl gauche + Maj gauche
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

Exemples d'autres raccourcis :

```ahk
; F8 maintenu
F8:: { StartRec() ⁠  KeyWait("F8")   StopRec() }

; CapsLock maintenu
CapsLock:: { StartRec()   KeyWait("CapsLock")   StopRec() }
```

Après modification : clic droit icône AHK → Quitter, puis relancer :
```powershell
Start-Process "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" '"C:\scripts\dictee\dictee.ahk"'
```

## Changer de micro

`record.py` détecte automatiquement le micro par son nom (priorité : "fifine" dans le nom, puis WASAPI > MME > WDM-KS). Aucune configuration manuelle n'est nécessaire si tu branches un autre micro.

Pour forcer un micro spécifique, ajoute en haut de `record.py` :

```python
# Lister les micros disponibles :
# python -c "import sounddevice as sd; print(sd.query_devices())"

# Pour forcer un index précis, remplacer _find_input_device() par :
# device_idx, CHANNELS, NATIVE_SR = 7, 2, 44100
```

## Vérifier que le NPU est utilisé

Pendant une transcription active :

```powershell
C:\Windows\System32\AMD\xrt-smi.exe examine -d 00ca:00:01.1 -r all
# Chercher une ligne avec Status=Active dans la colonne whisper-server
```

Via l'API :
```powershell
(Invoke-RestMethod http://localhost:13305/api/v1/system-info).devices.amd_npu
# utilization > 0 pendant l'inférence
```

## Mode Turbo NPU

Activé au démarrage par défaut après la configuration initiale.  
Pour le réappliquer après un redémarrage :

```powershell
# En tant qu'admin (UAC requis)
Start-Process "C:\Windows\System32\AMD\xrt-smi.exe" -ArgumentList "configure --pmode turbo" -Verb RunAs
```

Modes disponibles : `default`, `powersaver`, `balanced`, `performance`, `turbo`

## Créer un repo GitHub

```bash
cd C:\scripts\dictee
git init
git add dictee.ahk record.py install.ps1 README.md SETUP.md LICENSE .gitignore
git commit -m "Initial: dictee vocale NPU AMD XDNA2 via Lemonade + AHK v2"
# Puis sur github.com : New repository → pousser avec :
git remote add origin https://github.com/bastienbrasseur/<nom-repo>.git
git push -u origin main
```

`.gitignore` recommandé :
```
__pycache__/
*.pyc
```

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
| Ollama | 0.21.2 — ROCm / RX 6800 XT (inchangé) |
