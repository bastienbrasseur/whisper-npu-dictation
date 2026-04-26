"""
record.py — Enregistrement micro pour dictee vocale
Demarre via AutoHotkey, s'arrete quand le flag est supprime.
"""
import sounddevice as sd
import soundfile as sf
import numpy as np
import os

FLAG_FILE   = os.path.join(os.environ["TEMP"], "dictee_flag.lock")
OUTPUT_FILE = os.path.join(os.environ["TEMP"], "dictee_audio.wav")
TARGET_SR   = 16000


def _find_input_device():
    """
    Trouve le micro fifine en privilegiant WASAPI, puis MME, puis tout autre
    hostapi. Retourne (device_index, channels, default_samplerate).
    """
    devices  = sd.query_devices()
    hostapis = sd.query_hostapis()

    def api_name(idx):
        try:
            return hostapis[idx]["name"].lower()
        except Exception:
            return ""

    # score: 100 si "fifine" dans le nom, +10 WASAPI, +5 MME
    best_score, best_idx = -1, None
    for i, d in enumerate(devices):
        if d["max_input_channels"] < 1:
            continue
        score = 0
        if "fifine" in d["name"].lower():
            score += 100
        api = api_name(d["hostapi"])
        if "wasapi" in api:
            score += 10
        elif "mme" in api or "windows multi" in api:
            score += 5
        if score > best_score:
            best_score, best_idx = score, i

    if best_idx is None:
        raise RuntimeError("Aucun peripherique d'entree trouve.")

    dev      = devices[best_idx]
    channels = min(dev["max_input_channels"], 2)
    sr       = int(dev["default_samplerate"])
    return best_idx, channels, sr


device_idx, CHANNELS, NATIVE_SR = _find_input_device()
CHUNK_FRAMES = int(0.1 * NATIVE_SR)

# Creer le flag : signale a AHK que le script est pret
open(FLAG_FILE, "w").close()

frames = []
try:
    with sd.InputStream(samplerate=NATIVE_SR, channels=CHANNELS,
                        dtype="float32", device=device_idx) as stream:
        while os.path.exists(FLAG_FILE):
            chunk, _ = stream.read(CHUNK_FRAMES)
            frames.append(chunk.copy())
finally:
    if os.path.exists(FLAG_FILE):
        os.remove(FLAG_FILE)

if not frames:
    raise SystemExit(0)

# Stereo -> mono si necessaire, puis resampling vers 16000 Hz
audio = np.concatenate(frames)
if audio.ndim > 1:
    audio = np.mean(audio, axis=1)

n = int(len(audio) * TARGET_SR / NATIVE_SR)
audio_16k = np.interp(
    np.linspace(0, len(audio) - 1, n),
    np.arange(len(audio)),
    audio,
).astype("float32")

sf.write(OUTPUT_FILE, audio_16k, TARGET_SR, subtype="PCM_16")
