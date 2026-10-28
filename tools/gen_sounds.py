"""Synthesise the game's sound effects as mono 16-bit WAV files. No third-party assets, so no licenses to track."""
import math, random, struct, sys, wave, os

SR = 22050
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
rnd = random.Random(42)


def n(seconds): return int(SR * seconds)


def noise(count): return [rnd.uniform(-1, 1) for _ in range(count)]


def lowpass(x, cutoff):
    """One-pole low-pass. Run it twice for a steeper slope."""
    a = 1 - math.exp(-2 * math.pi * cutoff / SR)
    y, out = 0.0, []
    for v in x:
        y += a * (v - y)
        out.append(y)
    return out


def highpass(x, cutoff):
    lp = lowpass(x, cutoff)
    return [a - b for a, b in zip(x, lp)]


def env(count, attack, decay_tau):
    """Fast attack then exponential decay."""
    out = []
    for i in range(count):
        t = i / SR
        a = min(1.0, t / attack) if attack > 0 else 1.0
        out.append(a * math.exp(-t / decay_tau))
    return out


def mul(a, b): return [x * y for x, y in zip(a, b)]


def add(*tracks):
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def scale(x, g): return [v * g for v in x]


def shift(x, seconds): return [0.0] * n(seconds) + x


def sweep(count, f0, f1, wave_fn=math.sin):
    """A tone whose frequency glides from f0 to f1."""
    out, phase = [], 0.0
    for i in range(count):
        f = f0 + (f1 - f0) * i / max(count - 1, 1)
        phase += 2 * math.pi * f / SR
        out.append(wave_fn(phase))
    return out


def saw(phase): return 2 * ((phase / (2 * math.pi)) % 1.0) - 1


def tone(count, freq, wave_fn=math.sin): return sweep(count, freq, freq, wave_fn)


def normalise(x, peak=0.9):
    m = max(abs(v) for v in x) or 1.0
    return [v * peak / m for v in x]


def fade_edges(x, ms=8):
    k = n(ms / 1000)
    x = list(x)
    for i in range(min(k, len(x))):
        g = i / k
        x[i] *= g
        x[-1 - i] *= g
    return x


def save(name, x, peak=0.9, fade=True):
    x = normalise(fade_edges(x) if fade else x, peak)
    with wave.open(f"{OUT}/{name}.wav", "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in x))
    print(name, round(len(x) / SR, 2), "s")


def loop_crossfade(x, seconds):
    """Make a loop seamless by blending its tail into its head."""
    k = n(seconds)
    body = x[: len(x) - k]
    for i in range(k):
        g = i / k
        body[i] = body[i] * g + x[len(x) - k + i] * (1 - g)
    return body


# --- Rifle ------------------------------------------------------------------
def shot():
    c = n(0.7)
    crack = mul(highpass(noise(c), 1500), env(c, 0.0, 0.012))
    body = mul(lowpass(lowpass(noise(c), 1800), 1800), env(c, 0.0, 0.07))
    thump = mul(sweep(c, 110, 38), env(c, 0.0, 0.12))
    tail = mul(lowpass(noise(c), 500), env(c, 0.02, 0.28))
    return add(scale(crack, 0.9), scale(body, 1.0), scale(thump, 1.1), scale(tail, 0.35))


def tick(strength=1.0, pitch=900):
    c = n(0.05)
    return add(scale(mul(highpass(noise(c), 1200), env(c, 0.0, 0.006)), 0.8 * strength),
               scale(mul(tone(c, pitch), env(c, 0.0, 0.012)), 0.5 * strength))


def reload():
    total = add(
        tick(0.9, 700),
        shift(scale(mul(lowpass(noise(n(0.3)), 1200), [math.sin(math.pi * i / n(0.3)) for i in range(n(0.3))]), 0.25), 0.3),
        shift(tick(0.8, 1100), 0.8),
        shift(tick(1.2, 500), 1.25),
    )
    return total + [0.0] * (n(1.5) - len(total))


# --- Hunter -----------------------------------------------------------------
def footstep(seed):
    c = n(0.2)
    r = random.Random(seed)
    nz = [r.uniform(-1, 1) for _ in range(c)]
    return add(mul(lowpass(lowpass(nz, 700 + seed * 60), 700), env(c, 0.0, 0.035)),
               scale(mul(tone(c, 90 + seed * 7), env(c, 0.0, 0.05)), 0.5))


def hurt():
    c = n(0.45)
    return add(scale(mul(sweep(c, 170, 70, saw), env(c, 0.005, 0.12)), 0.5),
               scale(mul(lowpass(noise(c), 900), env(c, 0.0, 0.05)), 0.7),
               scale(mul(sweep(c, 90, 45), env(c, 0.0, 0.1)), 0.8))


def pickup():
    c = n(0.45)
    return add(scale(mul(tone(c, 1900), env(c, 0.0, 0.09)), 0.6),
               shift(scale(mul(tone(c, 2500), env(c, 0.0, 0.09)), 0.5), 0.09))


def impact():
    c = n(0.25)
    return add(scale(mul(lowpass(lowpass(noise(c), 900), 900), env(c, 0.0, 0.035)), 1.0),
               scale(mul(sweep(c, 140, 70), env(c, 0.0, 0.05)), 0.7))


# --- Stag -------------------------------------------------------------------
def groan(seconds, f0, f1, vibrato=5.0, breath=0.25):
    c = n(seconds)
    out, phase = [], 0.0
    for i in range(c):
        t = i / SR
        f = f0 + (f1 - f0) * i / c
        f *= 1 + 0.03 * math.sin(2 * math.pi * vibrato * t)
        phase += 2 * math.pi * f / SR
        s = 0.0
        for h, g in ((1, 1.0), (2, 0.6), (3, 0.5), (4, 0.3), (5, 0.2)):
            s += g * math.sin(h * phase)
        out.append(s)
    shape = [min(1.0, i / n(0.12)) * math.exp(-max(0.0, i / SR - seconds * 0.45) / (seconds * 0.3)) for i in range(c)]
    breathy = lowpass(noise(c), 1200)
    return add(mul(out, shape), scale(mul(breathy, shape), breath))


def stag_bellow(): return groan(1.3, 95, 78, 5.5, 0.3)
def stag_hit(): return groan(0.5, 160, 90, 9.0, 0.45)
def stag_die(): return groan(2.2, 120, 45, 4.0, 0.3)


def stag_snort():
    c = n(0.4)
    return add(*[shift(scale(mul(highpass(lowpass(noise(n(0.14)), 2500), 400), env(n(0.14), 0.01, 0.05)), 1.0), 0.17 * k) for k in range(2)])


def critter_hit():
    c = n(0.28)
    return add(scale(mul(sweep(c, 1100, 450), env(c, 0.004, 0.07)), 0.8),
               scale(mul(sweep(c, 2200, 900), env(c, 0.004, 0.05)), 0.3))


# --- Music stings -----------------------------------------------------------
def note(freq, seconds, tau):
    c = n(seconds)
    return mul(add(tone(c, freq), scale(tone(c, freq * 2), 0.35), scale(tone(c, freq * 3), 0.12)), env(c, 0.008, tau))


def win():
    notes = [261.6, 329.6, 392.0, 523.3]
    parts = [shift(note(f, 0.9, 0.25), 0.14 * i) for i, f in enumerate(notes)]
    parts.append(shift(add(note(261.6, 1.2, 0.5), note(329.6, 1.2, 0.5), note(392.0, 1.2, 0.5), note(523.3, 1.2, 0.5)), 0.56))
    return add(*parts)


def lose():
    notes = [220.0, 174.6, 146.8, 110.0]
    parts = [shift(note(f, 1.0, 0.35), 0.28 * i) for i, f in enumerate(notes)]
    return add(*parts)


# --- Loops ------------------------------------------------------------------
def fire_loop():
    seconds = 6.0
    c = n(seconds)
    hiss = scale(lowpass(lowpass(noise(c), 600), 600), 1.0)
    crackle = [0.0] * c
    t = 0.0
    while t < seconds - 0.1:
        t += rnd.uniform(0.04, 0.45)
        i = int(t * SR)
        length = n(rnd.uniform(0.004, 0.02))
        amp = rnd.uniform(0.15, 0.9)
        for k in range(min(length, c - i)):
            crackle[i + k] += amp * rnd.uniform(-1, 1) * math.exp(-k / (length / 3))
    mixed = add(scale(hiss, 2.2), scale(highpass(crackle, 800), 1.0))
    return loop_crossfade(mixed, 0.4)


def ambience():
    seconds = 10.0
    c = n(seconds)
    river = lowpass(lowpass(noise(c), 1400), 1400)
    wind = lowpass(lowpass(lowpass(noise(c), 300), 300), 300)
    out = []
    for i in range(c):
        t = i / SR
        gust = 0.55 + 0.45 * math.sin(2 * math.pi * t / 7.0 + 1.0) * math.sin(2 * math.pi * t / 3.3)
        out.append(river[i] * 0.9 + wind[i] * 9.0 * gust)
    return loop_crossfade(out, 0.8)


save("shot", shot(), 0.95)
save("reload", reload(), 0.7)
for k in range(3):
    save(f"footstep{k + 1}", footstep(k + 1), 0.5)
save("hurt", hurt(), 0.9)
save("pickup", pickup(), 0.6)
save("impact", impact(), 0.8)
save("stag_bellow", stag_bellow(), 0.9)
save("stag_hit", stag_hit(), 0.9)
save("stag_die", stag_die(), 0.9)
save("stag_snort", stag_snort(), 0.7)
save("critter_hit", critter_hit(), 0.6)
save("win", win(), 0.7)
save("lose", lose(), 0.7)
save("fire_loop", fire_loop(), 0.6, fade=False)
save("ambience", ambience(), 0.5, fade=False)


# --- Cabin props ------------------------------------------------------------
def door_open():
    c = n(0.8)
    creak = mul(sweep(c, 120, 230, saw), [min(1.0, i / n(0.08)) * math.exp(-i / SR / 0.45) for i in range(c)])
    wobble = [0.6 + 0.4 * math.sin(2 * math.pi * 23 * i / SR) for i in range(c)]
    rasp = mul(highpass(noise(c), 900), [0.06 * math.exp(-i / SR / 0.4) for i in range(c)])
    return add(scale(mul(creak, wobble), 0.35), rasp, scale(tick(0.8, 600), 0.5))


def door_close():
    c = n(0.5)
    body = mul(lowpass(lowpass(noise(c), 700), 700), env(c, 0.0, 0.05))
    knock = mul(sweep(c, 95, 45), env(c, 0.0, 0.09))
    creak = mul(sweep(n(0.3), 210, 130, saw), [math.exp(-i / SR / 0.2) * 0.15 for i in range(n(0.3))])
    return add(scale(body, 1.0), scale(knock, 0.9), creak)


def rest():
    return add(*[shift(note(f, 1.6, 0.6), 0.28 * i) for i, f in enumerate([392.0, 493.9, 587.3])])


save("door_open", door_open(), 0.7)
save("door_close", door_close(), 0.8)
save("rest", rest(), 0.55)
