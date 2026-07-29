"""
After a ctrl fit completes, update the HCM optimization.json bounds so each
shared parameter is constrained to within max_ratio_log log-units of the ctrl
best-fit value.  Default ±1 log unit = factor of 10 in each direction.

Usage:
    python3 update_hcm_bounds_from_ctrl.py <ctrl_best.json> <hcm_optimization.json>
"""

import json, math, sys

ctrl_best_path = sys.argv[1]
hcm_opt_path   = sys.argv[2]
max_ratio_log  = 1.0   # ±1 log unit = 10× each way

ctrl_best  = json.load(open(ctrl_best_path))
ctrl_vals  = {}
for p in ctrl_best['MyoSim_optimization']['parameter']:
    val = 10**(p['min_value'] + p['p_value'] * (p['max_value'] - p['min_value']))
    ctrl_vals[p['name']] = (val, p['min_value'], p['max_value'])

hcm_opt    = json.load(open(hcm_opt_path))
hcm_params = hcm_opt['MyoSim_optimization']['parameter']

for p in hcm_params:
    name = p['name']
    if name not in ctrl_vals:
        continue
    ctrl_val, global_min, global_max = ctrl_vals[name]
    ctrl_log = math.log10(ctrl_val)

    new_min = max(global_min, ctrl_log - max_ratio_log)
    new_max = min(global_max, ctrl_log + max_ratio_log)

    if new_max <= new_min:          # safety: fallback to global bounds
        new_min, new_max = global_min, global_max

    p['min_value'] = round(new_min, 6)
    p['max_value'] = round(new_max, 6)
    p['p_value']   = 0.5            # start at center of new range

    actual_min = 10**new_min
    actual_max = 10**new_max
    print(f"  {name:8s}: ctrl={ctrl_val:.3g}  →  HCM bounds [{actual_min:.3g}, {actual_max:.3g}]")

with open(hcm_opt_path, 'w') as f:
    json.dump(hcm_opt, f, indent=4)

print(f"Updated: {hcm_opt_path}")
