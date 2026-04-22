#!/usr/bin/env python3
"""Generate procedural SFX WAV files for SpaceWheat quantum game events.

All sounds are shaped with Gaussian packet envelopes — onset and tail are
both smooth Gaussian curves, consistent with the game's continuous-field
aesthetic. No sharp clicks or abrupt cutoffs.
"""

import wave
import math
import struct
import random
import os

SAMPLE_RATE = 44100
CHANNELS = 1
SAMPLE_WIDTH = 2  # 16-bit

def write_wav(filename, samples):
    """Write a list of float samples [-1,1] to a 16-bit mono WAV file."""
    with wave.open(filename, 'w') as f:
        f.setnchannels(CHANNELS)
        f.setsampwidth(SAMPLE_WIDTH)
        f.setframerate(SAMPLE_RATE)
        data = struct.pack('<' + 'h' * len(samples),
                          *[int(max(-32767, min(32767, s * 32767))) for s in samples])
        f.writeframes(data)

def sine(t, freq, amp=1.0):
    return amp * math.sin(2.0 * math.pi * freq * t)

ONSET_RAMP_S = 0.004  # 4 ms linear zero-ramp — guarantees first sample is 0.0

def env_gaussian(t, dur, center_frac=0.32, sigma_frac=0.30):
    """Gaussian packet envelope with zero-ramp onset to prevent clicks.
    center_frac: peak position as fraction of duration — 0.30+ gives a gentle
                 slope at t=0 so the sound fades in softly before peaking.
    sigma_frac:  spread; larger = wider / longer tail.
    The 4 ms linear ramp multiplier guarantees the very first sample is silent
    regardless of where the Gaussian center sits.
    """
    ramp = min(1.0, t / ONSET_RAMP_S)
    center = dur * center_frac
    sigma = dur * sigma_frac
    return ramp * math.exp(-0.5 * ((t - center) / sigma) ** 2)

def make_samples(dur, func):
    n = int(SAMPLE_RATE * dur)
    return [func(i / SAMPLE_RATE, dur) for i in range(n)]


# ── explore_success ──────────────────────────────────────────────────────────
# Rising sci-fi arpeggio: C4→E4→G4→C5. Each note shaped by its own Gaussian
# packet so onset and release are both smooth.
def gen_explore_success():
    notes = [261.63, 329.63, 392.00, 523.25]
    note_dur = 0.09
    gap = 0.008
    samples = []
    for freq in notes:
        n = int(SAMPLE_RATE * note_dur)
        for i in range(n):
            t = i / SAMPLE_RATE
            env = env_gaussian(t, note_dur, center_frac=0.32, sigma_frac=0.30)
            s = sine(t, freq) * 0.18 + sine(t, freq * 2) * 0.07 + sine(t, freq * 3) * 0.02
            samples.append(s * env)
        samples.extend([0.0] * int(SAMPLE_RATE * gap))
    return samples


# ── measure_success ──────────────────────────────────────────────────────────
# Clean quantum ping: 880 Hz, fast Gaussian onset, long smooth tail.
def gen_measure_success():
    dur = 0.30
    def f(t, d):
        env = env_gaussian(t, d, center_frac=0.30, sigma_frac=0.28)
        return (sine(t, 880) * 0.18 + sine(t, 1320) * 0.09 + sine(t, 2200) * 0.03) * env
    return make_samples(dur, f)


# ── pop_success ──────────────────────────────────────────────────────────────
# Bubble pop: frequency sweeps down through Gaussian envelope.
def gen_pop_success():
    dur = 0.20
    def f(t, d):
        freq = 600 * math.exp(-10 * t)
        env = env_gaussian(t, d, center_frac=0.30, sigma_frac=0.26)
        return sine(t, max(freq, 55)) * 0.22 * env
    return make_samples(dur, f)


# ── gate_success ──────────────────────────────────────────────────────────────
# Quick electronic blip: short high-pitched Gaussian burst.
def gen_gate_success():
    dur = 0.14
    def f(t, d):
        env = env_gaussian(t, d, center_frac=0.32, sigma_frac=0.30)
        return (sine(t, 1200) * 0.14 + sine(t, 1800) * 0.07 + sine(t, 2400) * 0.03) * env
    return make_samples(dur, f)


# ── action_blocked ────────────────────────────────────────────────────────────
# Low thud: dull impact. Low frequency Gaussian burst.
def gen_action_blocked():
    dur = 0.24
    def f(t, d):
        env = env_gaussian(t, d, center_frac=0.30, sigma_frac=0.28)
        freq = 155 * math.exp(-2.5 * t)
        noise_val = (random.random() * 2 - 1) * 0.05
        return (sine(t, freq) * 0.18 + sine(t, freq * 1.5) * 0.06 + noise_val) * env
    return make_samples(dur, f)


# ── action_error ──────────────────────────────────────────────────────────────
# Descending Gaussian buzz: something went wrong.
def gen_action_error():
    dur = 0.30
    def f(t, d):
        env = env_gaussian(t, d, center_frac=0.32, sigma_frac=0.30)
        freq = 420 * math.exp(-1.8 * t / d)
        s = sine(t, freq) * 0.14 + sine(t, freq * 3) * 0.05 + sine(t, freq * 5) * 0.02
        return s * env
    return make_samples(dur, f)


# ── reap_success ──────────────────────────────────────────────────────────────
# Harvest chime: C5→E5→G5→C6 cascade, each note a Gaussian packet.
def gen_reap_success():
    notes = [523.25, 659.25, 783.99, 1046.50]
    note_dur = 0.14
    overlap = 0.07
    total = note_dur + (len(notes) - 1) * (note_dur - overlap)
    n_total = int(SAMPLE_RATE * (total + 0.18))
    samples = [0.0] * n_total
    for idx, freq in enumerate(notes):
        start = int(idx * (note_dur - overlap) * SAMPLE_RATE)
        for i in range(int(note_dur * SAMPLE_RATE)):
            if start + i >= n_total:
                break
            t = i / SAMPLE_RATE
            env = env_gaussian(t, note_dur, center_frac=0.32, sigma_frac=0.30)
            s = sine(t, freq) * 0.13 + sine(t, freq * 2) * 0.07 + sine(t, freq * 4) * 0.03
            samples[start + i] += s * env
    return samples


# ── biome_switch ──────────────────────────────────────────────────────────────
# Whoosh transition: noise + rising tone through symmetric Gaussian packet.
def gen_biome_switch():
    dur = 0.38
    def f(t, d):
        env = env_gaussian(t, d, center_frac=0.40, sigma_frac=0.32)
        noise_val = (random.random() * 2 - 1) * 0.06
        freq = 180 + 750 * (t / d)
        tone = sine(t, freq) * 0.10
        return (noise_val + tone) * env
    return make_samples(dur, f)


# ── menu_open ────────────────────────────────────────────────────────────────
# Soft upward sweep through Gaussian window.
def gen_menu_open():
    dur = 0.16
    def f(t, d):
        env = env_gaussian(t, d, center_frac=0.35, sigma_frac=0.32)
        freq = 380 + 420 * (t / d)
        return (sine(t, freq) * 0.14 + sine(t, freq * 1.5) * 0.04) * env
    return make_samples(dur, f)


# ── menu_close ───────────────────────────────────────────────────────────────
# Soft downward sweep through Gaussian window.
def gen_menu_close():
    dur = 0.13
    def f(t, d):
        env = env_gaussian(t, d, center_frac=0.25, sigma_frac=0.30)
        freq = 800 - 420 * (t / d)
        return (sine(t, freq) * 0.12 + sine(t, freq * 1.5) * 0.04) * env
    return make_samples(dur, f)


# ─────────────────────────────────────────────────────────────────────────────

GENERATORS = {
    "explore_success": gen_explore_success,
    "measure_success": gen_measure_success,
    "pop_success": gen_pop_success,
    "gate_success": gen_gate_success,
    "action_blocked": gen_action_blocked,
    "action_error": gen_action_error,
    "reap_success": gen_reap_success,
    "biome_switch": gen_biome_switch,
    "menu_open": gen_menu_open,
    "menu_close": gen_menu_close,
}

if __name__ == "__main__":
    out_dir = os.path.dirname(os.path.abspath(__file__))
    random.seed(42)
    for event_id, gen_fn in GENERATORS.items():
        path = os.path.join(out_dir, f"{event_id}.wav")
        samples = gen_fn()
        write_wav(path, samples)
        dur = len(samples) / SAMPLE_RATE
        peak = max(abs(s) for s in samples)
        print(f"  {event_id}: {len(samples)} samples ({dur:.2f}s) peak={peak:.3f} → {path}")
    print(f"\nGenerated {len(GENERATORS)} SFX files.")
