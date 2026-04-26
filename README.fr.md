# whisper-npu-dictation

Dictée vocale globale sur Windows, Whisper tournant **entièrement sur le NPU AMD Ryzen AI** (XDNA 2). Le GPU reste libre pour ce que tu faisais déjà.

> Construit avec [Lemonade Server](https://lemonade-server.ai) · propulsé par [Whisper](https://github.com/openai/whisper) via [whisper.cpp](https://github.com/ggerganov/whisper.cpp)

---

## Pourquoi ça existe

Toutes les applis de dictée que j'ai trouvées font tourner Whisper sur le CPU (lent) ou s'accaparent le GPU (gênant quand on joue ou qu'on fait tourner un LLM local). Le NPU AMD Ryzen AI reste inutilisé dans la plupart des configs. Ce projet lui fait gagner sa place : l'inférence Whisper tourne sur le NPU XDNA 2 avec ~1,4 s de latence pour 3 secondes d'audio, GPU intact.

---

## Démo

> **TODO** — ajouter un GIF montrant : maintenir Ctrl+Maj → parler → relâcher → le texte apparaît dans le Bloc-notes.  
> Une capture de Task Manager / `xrt-smi` montrant le NPU actif pendant la transcription serait utile aussi.

---

## Matériel requis

| Composant | Testé | Notes |
|-----------|-------|-------|
| CPU / NPU | AMD Ryzen AI 9 HX 370 (Strix Point, **XDNA 2**) | Les autres puces Ryzen AI 300 avec XDNA 2 devraient fonctionner |
| Driver NPU | `IpuMcdmDriver` ≥ 32.0.203.329 | Vérifier dans Gestionnaire de périphériques → Accélérateur de calcul |
| RAM | 32 Go DDR5 | 16 Go suffisent probablement |
| OS | Windows 11 (build 26200+) | Sans WSL, entièrement natif |
| GPU | AMD Radeon RX 6800 XT (16 Go) | **Non utilisé pour la dictée** — reste libre pour Ollama, les jeux, etc. |

**Non testé sur :** Intel NPU, Qualcomm NPU, XDNA 1 (Phoenix/Hawk Point). Pull requests bienvenus.

---

## Comment ça marche

```
Maintenir Ctrl+Maj
      │
      ▼
dictee.ahk (AutoHotkey v2)
  └─ lance record.py
        └─ sounddevice capture le micro à 44 100 Hz
        └─ rééchantillonne vers 16 000 Hz WAV (numpy)
              │
              ▼ (au relâchement de la touche)
  POST /v1/audio/transcriptions
  → Lemonade Server :13305
        └─ processus whisper-server
              └─ Whisper Large-v3-Turbo sur le NPU XDNA 2
                    │
                    ▼
              {"text": "tes mots"}
                    │
              SendInput → curseur de la fenêtre active
```

---

## Installation rapide

```powershell
git clone https://github.com/bastienbrasseur/whisper-npu-dictation C:\scripts\dictee
cd C:\scripts\dictee
.\install.ps1
```

Le script vérifie les prérequis, installe Lemonade Server (une invite UAC), AutoHotkey v2, les paquets Python, télécharge le modèle Whisper (~1,5 Go) et lance le raccourci. Idempotent — safe à relancer si quelque chose échoue à mi-chemin.

---

## Installation manuelle (étape par étape)

Si tu préfères contrôler chaque étape, ou si `install.ps1` échoue à une étape précise, suis les sections ci-dessous.

---

## Prérequis

- [Lemonade Server](https://lemonade-server.ai) ≥ 10.2.0 — installer le MSI complet (pas minimal)
- [AutoHotkey v2](https://www.autohotkey.com/) (`winget install AutoHotkey.AutoHotkey`)
- [Python 3.10+](https://www.python.org/) avec pip
- [ffmpeg](https://ffmpeg.org/) n'est **pas requis** — la capture audio utilise Python

---

## Installation

**1 — Installer Lemonade Server**

Télécharger `lemonade.msi` depuis la [page des releases](https://github.com/lemonade-sdk/lemonade/releases/latest) et l'exécuter.

**2 — Installer le backend whispercpp NPU et le modèle**

```powershell
$lem = "$env:LOCALAPPDATA\lemonade_server\bin\lemonade.exe"
& $lem backends install whispercpp:npu
& $lem pull Whisper-Large-v3-Turbo
& $lem config set whispercpp.backend=npu
& $lem load Whisper-Large-v3-Turbo
```

**3 — Cloner ce repo et installer les dépendances Python**

```powershell
git clone https://github.com/bastienbrasseur/whisper-npu-dictation C:\scripts\dictee
cd C:\scripts\dictee
pip install sounddevice soundfile numpy
```

**4 — Installer AutoHotkey v2 et lancer le script**

```powershell
winget install AutoHotkey.AutoHotkey
# Puis double-cliquer sur dictee.ahk, ou :
Start-Process "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" '"C:\scripts\dictee\dictee.ahk"'
```

**5 — (Optionnel) Démarrage automatique**

```powershell
$startup = [Environment]::GetFolderPath('Startup')
$ws  = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut("$startup\dictee_vocale.lnk")
$lnk.TargetPath  = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$lnk.Arguments   = '"C:\scripts\dictee\dictee.ahk"'
$lnk.Save()
```

---

## Utilisation

| Action | Geste |
|--------|-------|
| Commencer à dicter | Maintenir **Ctrl gauche + Maj gauche** |
| Envoyer et coller | Relâcher l'une ou l'autre touche |
| Activer / Désactiver | Clic droit icône AHK → Activer / Désactiver |
| Quitter | Clic droit icône AHK → Quitter |

Bip haut (880 Hz) = enregistrement démarré  
Bip bas (440 Hz) = enregistrement arrêté, envoi au NPU

---

## Configuration

### Changer le raccourci clavier

Éditer `dictee.ahk`, remplacer les deux derniers blocs :

```ahk
; Actuel : Ctrl gauche + Maj gauche
LCtrl & LShift:: { StartRec()  KeyWait("LShift")  StopRec() }
LShift & LCtrl:: { StartRec()  KeyWait("LCtrl")   StopRec() }

; Exemple : F8 maintenu
F8:: { StartRec()  KeyWait("F8")  StopRec() }
```

Recharger : clic droit icône → Quitter, puis relancer `dictee.ahk`.

### Changer le modèle Whisper

Modèles plus petits = plus rapides, moins précis. Plus grands = plus lents, meilleurs.

```powershell
$lem = "$env:LOCALAPPDATA\lemonade_server\bin\lemonade.exe"
& $lem unload
& $lem pull Whisper-Small        # ~460 Mo, ~600 ms
& $lem load Whisper-Small
```

| Modèle | Taille | Latence approx. (3 s audio, warm) |
|--------|--------|-----------------------------------|
| Whisper-Tiny | ~75 Mo | < 300 ms |
| Whisper-Base | ~140 Mo | ~400 ms |
| Whisper-Small | ~460 Mo | ~600 ms |
| **Whisper-Large-v3-Turbo** | 1,5 Go | **~1,4 s** ← défaut |

### Changer de microphone

`record.py` détecte automatiquement le micro par son nom (priorité WASAPI > MME > WDM-KS). Aucune configuration nécessaire si tu branches un autre micro.

Pour lister les périphériques disponibles :

```python
python -c "import sounddevice as sd; print(sd.query_devices())"
```

---

## Limitations

- **Chargement manuel du modèle après redémarrage.** Lemonade Server démarre automatiquement, mais ne charge pas le modèle Whisper. Il faut lancer `lemonade load Whisper-Large-v3-Turbo` une fois après chaque redémarrage (ou l'ajouter à un script de démarrage).
- **XDNA 2 uniquement (non testé sur d'autres NPUs).** Construit et testé exclusivement sur un Ryzen AI 9 HX 370. XDNA 1 (Ryzen 7040/8040) pourrait fonctionner — si tu essaies, ouvre une issue avec tes résultats.
- **Windows uniquement.** Le backend NPU de Lemonade pour whisper.cpp est Windows-only au moment d'écrire ces lignes.
- **La qualité de transcription, c'est Whisper.** Les accents, le bruit de fond et les courtes phrases sont le problème de Whisper, pas de ce projet. Large-v3-Turbo gère bien le français ; les modèles plus petits peuvent buter sur les noms propres.
- **Pas de streaming.** Whisper traite le clip audio complet après le relâchement de la touche. Pas de transcription mot par mot.

---

## Vérifier que le NPU est utilisé

Pendant une transcription active :

```powershell
C:\Windows\System32\AMD\xrt-smi.exe examine -d 00ca:00:01.1 -r all
# Chercher Status=Active dans la ligne whisper-server
```

Via l'API Lemonade :
```powershell
(Invoke-RestMethod http://localhost:13305/api/v1/system-info).devices.amd_npu
# utilization > 0 pendant l'inférence
```

---

## Crédits

- **[Lemonade Server](https://lemonade-server.ai)** (AMD / lemonade-sdk) — le runtime IA local NPU-aware qui rend tout ça possible. Apache 2.0.
- **[Whisper](https://github.com/openai/whisper)** (OpenAI) — le modèle de reconnaissance vocale. MIT.
- **[whisper.cpp](https://github.com/ggerganov/whisper.cpp)** (ggerganov) — le moteur d'inférence C++ avec support NPU. MIT.
- **[sounddevice](https://python-sounddevice.readthedocs.io/)** — I/O audio Python. MIT.

---

## Licence

MIT — voir [LICENSE](LICENSE).  
Compatible avec Lemonade (Apache 2.0) et whisper.cpp (MIT).

---

## Contribuer

Issues et PRs bienvenus. Si tu testes sur une autre puce Ryzen AI, ouvre une issue avec tes résultats — même "ça ne fonctionne pas" est une donnée utile.

Voir [SETUP.md](SETUP.md) pour le walkthrough technique complet.

---

## Idées de forks et améliorations

Ce projet est volontairement petit — deux fichiers, une idée. Voici ce qu'il ne fait pas encore :

**Matériel / plateforme**
- **Support XDNA 1 (Ryzen 7040/8040 — Phoenix, Hawk Point).** Le même stack Lemonade + whisper.cpp pourrait fonctionner avec des performances dégradées.
- **Port Linux.** Lemonade Server tourne sur Linux ; le recorder Python est déjà cross-platform. Il manque un remplaçant à AutoHotkey — `python-xlib` ou `evdev` pour les raccourcis globaux sur X11/Wayland.
- **NPU Qualcomm Snapdragon X.** Lemonade le supporte expérimentalement.

**Audio plus intelligent**
- **Détection d'activité vocale (VAD).** Remplacer le push-to-talk par une détection automatique du silence. [silero-vad](https://github.com/snakers4/silero-vad) tourne sur CPU.
- **Transcription en streaming.** Envoyer des chunks audio toutes les 2-3 s au lieu d'attendre le relâchement de la touche.
- **Meilleur rééchantillonnage.** L'interpolation linéaire numpy est suffisante mais pas audiophile. `scipy.signal.resample_poly` ou `soxr` pour plus de qualité.

**Sortie texte**
- **Commandes vocales.** Intercepter des phrases comme "nouvelle ligne", "efface ça", "tout sélectionner" avant de coller.
- **Mode presse-papiers.** `SendInput` casse dans certaines applis (terminaux, jeux, bureau à distance). Un fallback presse-papiers + Ctrl+V serait plus robuste.
- **Bascule de langue.** Raccourci ou commande vocale pour alterner entre `language=fr` et `language=en` à la volée.

**Intégrations**
- **Extension VS Code.** Appelle le même endpoint Lemonade et insère le texte au curseur via l'API d'extension.
- **Plugin Obsidian.** Même idée, utile pour la prise de notes vocale.
- **Extension navigateur.** Un WebExtension qui écoute un raccourci, enregistre via `getUserMedia`, POST vers `localhost:13305` et remplit le champ actif.
- **Réécriture de la barre système en Python.** Remplacer la dépendance AHK par une app tray pure Python avec `pystray` + `pynput`.

**Qualité de vie**
- **Chargement automatique de Whisper au démarrage.** Envelopper `lemonade load` dans une tâche planifiée.
- **Indicateur visuel d'enregistrement.** Un petit overlay toujours visible (point rouge) pendant l'enregistrement.
- **Profils de langue par appli.** Utiliser `WinGetTitle` dans AHK pour détecter la fenêtre active et basculer la langue Whisper automatiquement.
