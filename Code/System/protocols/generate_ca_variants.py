#!/usr/bin/env python3
"""
Generate Ca-transient protocol variants + matched targets for twitch fitting.

Two independent changes requested at the 2026-07-22 meeting:
  1. Onset shape: build a fast-onset (2x faster rise) AND a slow-onset variant.
     The onset START row is held fixed so the Ca->force alignment to the target
     is preserved; only the rise duration (onset->peak) is warped.
  2. Equilibrate-then-zero: prepend EXTRA_REST rows of resting pCa so passive
     force fully equilibrates before Ca onset; the equilibrated passive level is
     the zero reference. Targets get the same number of leading baseline rows so
     every file stays row-aligned and the same length.

Decay is left unchanged by default (DECAY_FACTOR=1.0) -- flip it here if the PI
wants faster relaxation later.

All variant protocols/targets are the SAME length so any of them can be dropped
into the existing fitting pipeline by only changing the file path in the
demo's optimization.json.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SYS  = os.path.dirname(HERE)                      # Code/System
PROT = HERE
TGT  = os.path.join(SYS, "target_data")

# ------------------------------------------------------------------ parameters
EXTRA_REST   = 500      # rows of extra resting pCa prepended (0.001 s each = 0.5 s)
ONSET_FACTOR = {        # rise-duration multiplier per variant
    "ext":       1.0,   # baseline: original onset, extended-rest + rezero only
    "fastonset": 0.5,   # 2x faster rise (42 ms -> ~21 ms)
    "slowonset": 2.0,   # 2x slower rise (42 ms -> ~84 ms)
}
DECAY_FACTOR = 1.0      # decay-duration multiplier (1.0 = unchanged)

# ------------------------------------------------------------------ helpers
def read_protocol(path):
    lines = open(path).read().splitlines()
    header = lines[0]
    rows = [r.split("\t") for r in lines[1:] if r.strip()]
    return header, rows

def lininterp(seq, n):
    """Resample list `seq` to `n` points by linear interpolation."""
    m = len(seq)
    if n == m:
        return list(seq)
    if m == 1:
        return [seq[0]] * n
    out = []
    for i in range(n):
        x = i * (m - 1) / (n - 1)
        lo = int(x); hi = min(lo + 1, m - 1); f = x - lo
        out.append(seq[lo] * (1 - f) + seq[hi] * f)
    return out

def find_segments(pca):
    cmin, cmax = min(pca), max(pca)          # pCa: rest is HIGH, peak is LOW
    ca = [10 ** (-p) for p in pca]
    camin, camax = min(ca), max(ca)
    thr = camin + 0.05 * (camax - camin)
    onset = next(i for i, c in enumerate(ca) if c > thr)
    peak  = ca.index(camax)
    # decay ends when Ca returns within 1% of rest after the peak
    endthr = camin + 0.01 * (camax - camin)
    dend = next((i for i in range(peak, len(ca)) if ca[i] < endthr), len(ca) - 1)
    return onset, peak, dend

# ------------------------------------------------------------------ build
header, rows = read_protocol(os.path.join(PROT, "protocol_1s.txt"))
pca   = [float(r[3]) for r in rows]
templ = rows[0]                                   # dt / dhsl / Mode template
dt, dhsl, mode = templ[0], templ[1], templ[2]
rest_pca = pca[0]
N = len(rows)

onset, peak, dend = find_segments(pca)
rise  = pca[onset:peak + 1]
decay = pca[peak + 1:dend + 1]
print(f"orig rows={N}  onset={onset} peak={peak} decay_end={dend}")
print(f"rise={len(rise)} rows ({len(rise)} ms)  decay={len(decay)} rows")

def write_protocol(name, onset_factor):
    n_rise  = max(2, round(len(rise)  * onset_factor))
    n_decay = max(2, round(len(decay) * DECAY_FACTOR))
    new_rise  = lininterp(rise, n_rise)
    new_decay = lininterp(decay, n_decay)
    # lead rest = original pre-onset rest + extra equilibration
    lead = [rest_pca] * (onset + EXTRA_REST)
    body = lead + new_rise + new_decay
    total = N + EXTRA_REST                          # fixed length for all variants
    if len(body) < total:
        body += [rest_pca] * (total - len(body))
    else:
        body = body[:total]
    path = os.path.join(PROT, f"protocol_1s_{name}.txt")
    with open(path, "w") as f:
        f.write(header + "\n")
        for p in body:
            f.write(f"{dt}\t{dhsl}\t{mode}\t{p:.5f}\n")
    print(f"wrote {os.path.basename(path)}  rows={len(body)}  "
          f"rise={n_rise} decay={n_decay}")
    return path

for name, fac in ONSET_FACTOR.items():
    write_protocol(name, fac)

# ------------------------------------------------------------------ targets
# prepend EXTRA_REST leading baseline rows (value 0 = equilibrated passive zero)
for base in ("Con_target.txt", "H251N_target.txt"):
    src = os.path.join(TGT, base)
    vals = [l for l in open(src).read().splitlines() if l.strip() != ""]
    lead0 = ["0.000000"] * EXTRA_REST
    out = lead0 + vals
    dst = os.path.join(TGT, base.replace("_target.txt", "_target_ext.txt"))
    with open(dst, "w") as f:
        f.write("\n".join(out) + "\n")
    print(f"wrote {os.path.basename(dst)}  rows={len(out)}")

print("done")
