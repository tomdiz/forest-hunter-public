"""Compose the game's two music loops as mono 16-bit WAV files, in code. No third-party audio.

music_calm.wav  - a slow A minor pad, a deep bass and a sparse echoing pluck melody (exploring).
music_tense.wav - a heartbeat, a pulsing bass, a droning semitone clash and a rising tremolo (the stag is hunting you).

Notes that run past the end of a loop wrap around to the start, so both loops repeat without a seam.
"""
import math, random, struct, sys, wave, os

SR = 22050
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)


def hz(midi): return 440.0 * 2 ** ((midi - 69) / 12)


def put(buf, samples, start):
    """Mix samples into the loop buffer, wrapping past the end."""
    length = len(buf)
    for i, v in enumerate(samples):
        buf[(start + i) % length] += v


def tone(freq, seconds, partials, env, vib=0.0, vib_rate=5.0):
    n = int(seconds * SR)
    out = []
    for i in range(n):
        t = i / SR
        f = freq * (1 + vib * math.sin(2 * math.pi * vib_rate * t))
        ph = 2 * math.pi * f * t
        s = 0.0
        for k, g in partials:
            s += g * math.sin(k * ph)
        out.append(s * env(t, seconds))
    return out


def pad_env(attack, release):
    def e(t, dur):
        return min(1.0, t / attack) * max(0.0, min(1.0, (dur - t) / release))
    return e


def pluck_env(decay):
    def e(t, dur):
        return min(1.0, t / 0.006) * math.exp(-t / decay)
    return e


def thump(seconds=0.22, f0=85, f1=38, tau=0.07):
    n = int(seconds * SR)
    out, ph = [], 0.0
    for i in range(n):
        t = i / SR
        f = f0 + (f1 - f0) * min(1.0, t / 0.12)
        ph += 2 * math.pi * f / SR
        out.append(math.sin(ph) * math.exp(-t / tau))
    return out


def tick(seconds=0.05, rnd=None):
    n = int(seconds * SR)
    rnd = rnd or random.Random(1)
    out, prev = [], 0.0
    for i in range(n):
        v = rnd.uniform(-1, 1)
        hp = v - prev * 0.9
        prev = v
        out.append(hp * math.exp(-i / SR / 0.012))
    return out


def echo(buf, delay_s, gain, taps):
    """Circular echo, so the tail of the loop rolls into its start."""
    length = len(buf)
    out = list(buf)
    d = int(delay_s * SR)
    for k in range(1, taps + 1):
        g = gain ** k
        shift = d * k
        for i in range(length):
            out[(i + shift) % length] += buf[i] * g
    return out


def normalise(buf, peak):
    m = max(abs(v) for v in buf) or 1.0
    return [v * peak / m for v in buf]


def save(name, buf, peak=0.8):
    buf = normalise(buf, peak)
    with wave.open(f"{OUT}/{name}.wav", "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in buf))
    print(name, round(len(buf) / SR, 1), "s")


# --- Calm: A minor, 66 bpm, 8 chords of 4 beats ------------------------------
def calm():
    bpm = 66
    beat = 60.0 / bpm
    chord_len = 4 * beat
    chords = [  # (bass, triad)
        (33, [57, 60, 64]),   # Am
        (29, [53, 57, 60]),   # F
        (36, [55, 60, 64]),   # C
        (31, [55, 59, 62]),   # G
        (33, [57, 60, 64]),   # Am
        (26, [57, 62, 65]),   # Dm
        (29, [53, 57, 60]),   # F
        (28, [56, 59, 64]),   # E
    ]
    length = int(len(chords) * chord_len * SR)
    pad, bass, mel = [0.0] * length, [0.0] * length, [0.0] * length
    rnd = random.Random(7)
    scale = [69, 72, 74, 76, 79, 81]  # A minor pentatonic upward from A4
    for c, (root, triad) in enumerate(chords):
        start = int(c * chord_len * SR)
        for note in triad + [triad[0] - 12]:
            # Two slightly detuned voices make the pad shimmer.
            for detune in (0.997, 1.003):
                put(pad, [v * 0.16 for v in tone(hz(note) * detune, chord_len + 1.2, [(1, 1.0), (2, 0.25)], pad_env(1.2, 1.6))], start)
        put(bass, [v * 0.55 for v in tone(hz(root), chord_len + 0.6, [(1, 1.0), (2, 0.3)], pluck_env(1.9))], start)
        # A few melody notes per chord, mostly on or near the beat.
        beats = rnd.sample([0.0, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5], rnd.choice([2, 3]))
        for b in sorted(beats):
            note = rnd.choice(scale)
            put(mel, [v * 0.22 for v in tone(hz(note), 2.6, [(1, 1.0), (2, 0.35), (3, 0.12)], pluck_env(0.7))], start + int(b * beat * SR))
    mel = echo(mel, beat * 1.5, 0.42, 3)
    return [p + b + m for p, b, m in zip(pad, bass, mel)]


# --- Tense: 96 bpm, 8 bars -----------------------------------------------------
def tense():
    bpm = 96
    beat = 60.0 / bpm
    bars = 8
    length = int(bars * 4 * beat * SR)
    buf = [0.0] * length
    rnd = random.Random(3)
    total = bars * 4 * beat
    # A drone with a semitone clash that swells in and out.
    for note, gain in ((33, 0.4), (45, 0.28), (52, 0.2)):
        put(buf, [v * gain for v in tone(hz(note), total + 1.0, [(1, 1.0), (2, 0.2)], pad_env(1.5, 1.5), vib=0.002, vib_rate=0.3)], 0)
    for bar in (2, 3, 6, 7):
        put(buf, [v * 0.2 for v in tone(hz(46), 4 * beat + 1.0, [(1, 1.0), (2, 0.3)], pad_env(1.0, 1.2))], int(bar * 4 * beat * SR))
    # Heartbeat: a strong beat and a softer one just after it.
    for b in range(bars * 4):
        t = int(b * beat * SR)
        put(buf, [v * 0.9 for v in thump()], t)
        put(buf, [v * 0.5 for v in thump(0.18, 75, 40, 0.06)], t + int(0.3 * beat * SR))
    # Eighth-note pulse on the bass, with an accent at the start of each bar.
    for e in range(bars * 8):
        t = int(e * beat * 0.5 * SR)
        accent = 1.0 if e % 8 == 0 else 0.55
        put(buf, [v * 0.35 * accent for v in tone(hz(33), 0.3, [(1, 1.0), (2, 0.5), (3, 0.25)], pluck_env(0.09))], t)
    # Quiet hi-hat ticks on the off-beats.
    for b in range(bars * 4):
        put(buf, [v * 0.12 for v in tick(0.05, rnd)], int((b + 0.5) * beat * SR))
    # A tremolo riser: two close notes that swell over two bars, then drop.
    for start_bar in (0, 2, 4, 6):
        dur = 8 * beat
        n = int(dur * SR)
        riser = []
        for i in range(n):
            t = i / SR
            swell = (t / dur) ** 1.5
            trem = 0.55 + 0.45 * math.sin(2 * math.pi * 7.0 * t)
            riser.append((math.sin(2 * math.pi * hz(81) * t) + math.sin(2 * math.pi * hz(82) * t)) * 0.07 * swell * trem)
        put(buf, riser, int(start_bar * 4 * beat * SR))
    return buf


save("music_calm", calm(), 0.8)
save("music_tense", tense(), 0.85)
