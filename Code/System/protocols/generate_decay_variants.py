#!/usr/bin/env python3
"""
Generate slow-onset Ca protocols at several DECAY speeds, on top of the
slow-onset + extended-rest/rezero baseline. Onset is held at the slow shape
(2x slower rise); only the decay (peak->rest) segment is time-warped.

Targets are unchanged (Con_target_ext.txt / H251N_target_ext.txt) because the
experimental force is the same; only the Ca INPUT decay changes.

Naming: protocol_1s_slowonset_dXXX.txt where XXX = decay factor *100
        (d050 = 2x faster decay, d100 = unchanged = protocol_1s_slowonset.txt).
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))

EXTRA_REST   = 500
ONSET_FACTOR = 2.0                      # slow onset (fixed)
DECAY_FACTORS = [0.5, 0.7, 1.3]         # new variants (1.0 already exists)

def read_protocol(path):
    lines = open(path).read().splitlines()
    header = lines[0]
    rows = [r.split("\t") for r in lines[1:] if r.strip()]
    return header, rows

def lininterp(seq, n):
    m = len(seq)
    if n == m: return list(seq)
    if m == 1: return [seq[0]] * n
    out = []
    for i in range(n):
        x = i * (m - 1) / (n - 1)
        lo = int(x); hi = min(lo + 1, m - 1); f = x - lo
        out.append(seq[lo] * (1 - f) + seq[hi] * f)
    return out

def find_segments(pca):
    ca = [10 ** (-p) for p in pca]
    cmin, cmax = min(ca), max(ca)
    thr = cmin + 0.05 * (cmax - cmin)
    onset = next(i for i, c in enumerate(ca) if c > thr)
    peak  = ca.index(cmax)
    endthr = cmin + 0.01 * (cmax - cmin)
    dend = next((i for i in range(peak, len(ca)) if ca[i] < endthr), len(ca) - 1)
    return onset, peak, dend

header, rows = read_protocol(os.path.join(HERE, "protocol_1s.txt"))
pca = [float(r[3]) for r in rows]
t0 = rows[0]
dt, dhsl, mode = t0[0], t0[1], t0[2]
rest = pca[0]
N = len(rows)
onset, peak, dend = find_segments(pca)
rise  = pca[onset:peak + 1]
decay = pca[peak + 1:dend + 1]
total = N + EXTRA_REST
n_rise = max(2, round(len(rise) * ONSET_FACTOR))

for dfac in DECAY_FACTORS:
    n_decay = max(2, round(len(decay) * dfac))
    body = ([rest] * (onset + EXTRA_REST)
            + lininterp(rise, n_rise)
            + lininterp(decay, n_decay))
    if len(body) < total: body += [rest] * (total - len(body))
    else:                 body = body[:total]
    tag = f"d{int(round(dfac*100)):03d}"
    path = os.path.join(HERE, f"protocol_1s_slowonset_{tag}.txt")
    with open(path, "w") as f:
        f.write(header + "\n")
        for p in body:
            f.write(f"{dt}\t{dhsl}\t{mode}\t{p:.5f}\n")
    print(f"wrote {os.path.basename(path)}  rows={len(body)}  "
          f"rise={n_rise} decay={n_decay} (factor {dfac})")

print("done (decay 1.0 = existing protocol_1s_slowonset.txt)")
