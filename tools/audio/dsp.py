"""Numpy DSP the pinned music_theory tag (v0.1.0) does not carry.

The toolkit gives pitch, scales, chords, a beat grid, ADSR and static
oscillators. A game mix also needs filters, noise, pitch glides, panning and
a room. Filters here work in the frequency domain (one FFT, the biquad's own
response): fast for a 40 s loop, and circular, so a filtered loop still closes
on itself. Everything is float64 at 44.1 kHz, mono (N,) or stereo (N, 2).
"""

from __future__ import annotations

import math

import numpy as np

SR = 44100
FLAT_Q = 1.0 / math.sqrt(2.0)
# Zeros appended before a one-shot is filtered, so the filter's ringing does
# not wrap round to the start of the sound.
PAD = 8192

type Signal = np.ndarray


def frames(seconds: float) -> int:
    return max(round(seconds * SR), 0)


def times(count: int) -> Signal:
    return np.arange(count, dtype=np.float64) / SR


def response(kind: str, cutoff_hz: float, q: float, count: int, rate: int = SR) -> Signal:
    """Complex response of an RBJ cookbook biquad on the rfft bins of `count` frames."""
    w0 = 2.0 * math.pi * min(max(cutoff_hz, 10.0), 0.49 * rate) / rate
    alpha = math.sin(w0) / (2.0 * q)
    cos_w0 = math.cos(w0)
    if kind == "lowpass":
        b = ((1.0 - cos_w0) / 2.0, 1.0 - cos_w0, (1.0 - cos_w0) / 2.0)
    elif kind == "highpass":
        b = ((1.0 + cos_w0) / 2.0, -(1.0 + cos_w0), (1.0 + cos_w0) / 2.0)
    elif kind == "bandpass":
        b = (alpha, 0.0, -alpha)
    else:
        raise ValueError(f"unknown filter {kind!r}")
    a = (1.0 + alpha, -2.0 * cos_w0, 1.0 - alpha)
    z = np.exp(-2j * math.pi * np.fft.rfftfreq(count, d=1.0 / rate) / rate)
    return (b[0] + b[1] * z + b[2] * z * z) / (a[0] + a[1] * z + a[2] * z * z)


def shape(signal: Signal, curve: Signal, wrap: bool = False) -> Signal:
    """Multiplies the spectrum by `curve(bins)`-style gains built by the caller."""
    pad = 0 if wrap else PAD
    count = len(signal) + pad
    body = np.concatenate((signal, np.zeros((pad, *signal.shape[1:])))) if pad else signal
    spectrum = np.fft.rfft(body, axis=0)
    gains = curve if spectrum.ndim == 1 else curve[:, None]
    return np.fft.irfft(spectrum * gains, n=count, axis=0)[: len(signal)]


def filt(signal: Signal, kind: str, cutoff_hz: float, q: float = FLAT_Q, poles: int = 1, wrap: bool = False) -> Signal:
    """One biquad (or `poles` of them in series). `wrap` keeps a loop circular."""
    count = len(signal) + (0 if wrap else PAD)
    return shape(signal, response(kind, cutoff_hz, q, count) ** poles, wrap)


def lowpass(signal: Signal, cutoff_hz: float, poles: int = 1, wrap: bool = False) -> Signal:
    return filt(signal, "lowpass", cutoff_hz, FLAT_Q, poles, wrap)


def highpass(signal: Signal, cutoff_hz: float, poles: int = 1, wrap: bool = False) -> Signal:
    return filt(signal, "highpass", cutoff_hz, FLAT_Q, poles, wrap)


def bandpass(signal: Signal, centre_hz: float, q: float = 2.0, wrap: bool = False) -> Signal:
    return filt(signal, "bandpass", centre_hz, q, 1, wrap)


def sweep_bandpass(signal: Signal, hz_curve: Signal, q: float = 2.0, bands: int = 10) -> Signal:
    """A band-pass whose centre follows `hz_curve`: a bank of fixed bands, cross-faded."""
    low, high = float(np.min(hz_curve)), float(np.max(hz_curve))
    if high <= low * 1.001:
        return bandpass(signal, low, q)
    centres = np.geomspace(low, high, bands)
    place_in_bank = (np.log(hz_curve) - math.log(low)) / (math.log(high) - math.log(low)) * (bands - 1)
    out = np.zeros(len(signal))
    for index, centre in enumerate(centres):
        weight = np.clip(1.0 - np.abs(place_in_bank - index), 0.0, 1.0)
        out += weight * bandpass(signal, float(centre), q)
    return out


def noise(count: int, rng: np.random.Generator) -> Signal:
    return rng.uniform(-1.0, 1.0, max(count, 0))


def decay(count: int, tau_s: float) -> Signal:
    """exp(-t / tau): a resonance dying by a constant ratio per unit time."""
    return np.exp(-times(count) / tau_s)


def ramp(count: int, attack_s: float) -> Signal:
    """0 -> 1 over `attack_s`, then 1: takes the click off a start."""
    rise = max(frames(attack_s), 1)
    return np.clip(np.arange(count) / rise, 0.0, 1.0)


def fade_out(signal: Signal, seconds: float) -> Signal:
    """The last `seconds` fall to exactly zero (no click at the end of a one-shot)."""
    out = signal.copy()
    tail = min(frames(seconds), len(out))
    if tail:
        gain = np.linspace(1.0, 0.0, tail)
        out[-tail:] *= gain if out.ndim == 1 else gain[:, None]
    return out


def glide(points: tuple[float, ...], count: int) -> Signal:
    """A frequency curve through `points`, evenly spaced, straight in log-frequency."""
    if len(points) == 1:
        return np.full(count, float(points[0]))
    anchors = np.linspace(0.0, max(count - 1, 1), len(points))
    return np.exp(np.interp(np.arange(count), anchors, np.log(np.asarray(points, dtype=np.float64))))


def harmonics(hz_curve: Signal, amplitudes: Signal | list[float], top_hz: float = 16000.0) -> Signal:
    """Band-limited tone on a moving pitch: partial k follows k * hz and stops below `top_hz`."""
    phase = np.concatenate(([0.0], np.cumsum(hz_curve[:-1]))) / SR
    out = np.zeros(len(hz_curve))
    for index, amplitude in enumerate(amplitudes):
        if not amplitude:
            continue
        partial = index + 1
        audible = (hz_curve * partial) < top_hz
        if not audible.any():
            break
        out += amplitude * np.sin(2.0 * math.pi * partial * phase) * audible
    return out


def drive(signal: Signal, amount: float) -> Signal:
    """tanh soft clip, level-matched: 1 is gentle warmth, 8 is a fuzz box."""
    return np.tanh(signal * amount) / math.tanh(amount)


def pan(signal: Signal, where: float) -> Signal:
    """Mono -> stereo, constant power. -1 left, 0 centre, 1 right."""
    angle = (min(max(where, -1.0), 1.0) + 1.0) * math.pi / 4.0
    return np.stack((signal * math.cos(angle), signal * math.sin(angle)), axis=1)


def place(total: Signal, start: int, sound: Signal, wrap: bool = False) -> None:
    """Adds `sound` into `total` at `start`. `wrap` folds the tail back to the start (a loop)."""
    size = len(total)
    if not size or not len(sound):
        return
    if not wrap:
        end = min(start + len(sound), size)
        if end > start >= 0:
            total[start:end] += sound[: end - start]
        return
    index = start % size
    offset = 0
    while offset < len(sound):
        chunk = min(size - index, len(sound) - offset)
        total[index : index + chunk] += sound[offset : offset + chunk]
        offset += chunk
        index = 0


def room(signal: Signal, seconds: float, wet: float, seed: int, wrap: bool = False, damp_hz: float = 4200.0) -> Signal:
    """A small hall: stereo convolution with decaying noise. Circular for loops."""
    stereo = signal if signal.ndim == 2 else pan(signal, 0.0)
    rng = np.random.default_rng([seed, 77])
    count = frames(seconds)
    tail = np.stack([noise(count, rng), noise(count, rng)], axis=1) * decay(count, seconds / 6.0)[:, None]
    tail[: frames(0.012)] = 0.0  # pre-delay keeps the dry attack clear
    tail = lowpass(highpass(tail, 180.0), damp_hz)
    tail /= math.sqrt(float(np.sum(tail**2)) / 2.0)
    size = len(stereo) if wrap else len(stereo) + count
    kernel = np.zeros((size, 2))
    kernel[: min(count, size)] = tail[: min(count, size)]
    body = stereo if wrap else np.concatenate((stereo, np.zeros((count, 2))))
    echo = np.fft.irfft(np.fft.rfft(body, axis=0) * np.fft.rfft(kernel, axis=0), n=size, axis=0)
    return stereo + wet * echo[: len(stereo)]


def peak(signal: Signal) -> float:
    return float(np.max(np.abs(signal))) if len(signal) else 0.0
