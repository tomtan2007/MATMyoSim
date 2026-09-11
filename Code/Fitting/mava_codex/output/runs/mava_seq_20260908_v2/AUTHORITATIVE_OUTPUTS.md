# Authoritative mavacamten analysis outputs

- Run ID: `mava_seq_20260908_v2`
- Repository HEAD: `96e55ba365c7a4b57e199a22f4288801a6dad469`
- Manifest SHA-256 input identity: `8d15eddc5d32a4c1457f3f088bae5d05ebbb796972c1eaf9b7d66093006fff77`
- Run immutable hash: `147f80fa673ffabb4d055be53640833adc960fac29f78a182d8eba38039b9265`
- Manifest: `/Users/tomtan/Research/MATMyoSim/Code/Fitting/mava_codex/output/runs/mava_seq_20260908_v2/manifest.json`
- Tables: `/Users/tomtan/Research/MATMyoSim/Code/Fitting/mava_codex/output/runs/mava_seq_20260908_v2/tables`
- Figures: `/Users/tomtan/Research/MATMyoSim/Code/Fitting/mava_codex/output/runs/mava_seq_20260908_v2/figures`

## Authoritative artifact hashes

- `/Users/tomtan/Research/MATMyoSim/Code/Fitting/mava_codex/output/runs/mava_seq_20260908_v2/tables/restart_summary.csv`: `498179344f746d50440d59427998267a8458a17449e61cf394cc4160f40c62f8`
- `/Users/tomtan/Research/MATMyoSim/Code/Fitting/mava_codex/output/runs/mava_seq_20260908_v2/tables/stage_summary.csv`: `ee6b46988844b2160a4e03cd98f7461432a0c4e10eb8ff39ee4cc89ea715e11b`
- `/Users/tomtan/Research/MATMyoSim/Code/Fitting/mava_codex/output/runs/mava_seq_20260908_v2/tables/boundary_diagnostics.csv`: `e83f8d8ee61faabdaa843b5a8b28e1fa5cfc9841cdeb80c1ed9f7c2ea8a05768`
- `/Users/tomtan/Research/MATMyoSim/Code/Fitting/mava_codex/output/runs/mava_seq_20260908_v2/tables/waveform_metrics.csv`: `20f0f6ccbcf9a9730d5e669bcf7b737db59344e4cc1e7fe8c90d8547fa2fa631`
- `/Users/tomtan/Research/MATMyoSim/Code/Fitting/mava_codex/output/runs/mava_seq_20260908_v2/tables/identifiability_summary.csv`: `eddc9270caba000b7b567cd722babfa0d40eb7c3a4a59566ed67cd1b1057119a`
- `/Users/tomtan/Research/MATMyoSim/Code/Fitting/mava_codex/output/runs/mava_seq_20260908_v2/figures/experimental_traces_and_alignment.png`: `a95753faa7bd17a399cbb2826f6200f5397100ad7ad64f9539f1d868aa729d3f`
- `/Users/tomtan/Research/MATMyoSim/Code/Fitting/mava_codex/output/runs/mava_seq_20260908_v2/figures/k123_failed_fits.png`: `fb795d5cd6d19336f98b035c9cf0dcf23d089464d12d37220a19c0327a0a69a8`
- `/Users/tomtan/Research/MATMyoSim/Code/Fitting/mava_codex/output/runs/mava_seq_20260908_v2/figures/sequential_error_aic.png`: `b11c89148f56b94404cd369a49eddd87d8a762c09b38d1b6a8929cc9ccb2c3ca`
- `/Users/tomtan/Research/MATMyoSim/Code/Fitting/mava_codex/output/runs/mava_seq_20260908_v2/figures/best_fit_waveforms.png`: `dfec570b9dfc8b81de3d3ac18743db4621fff58176091b26dfe675006f36b227`
- `/Users/tomtan/Research/MATMyoSim/Code/Fitting/mava_codex/output/runs/mava_seq_20260908_v2/figures/boundary_identifiability.png`: `37216e15f9ea7c9d38d141193c239e2e049e7b9d467cb3fb47d8c7018323961f`
- `/Users/tomtan/Research/MATMyoSim/Code/Fitting/mava_codex/output/runs/mava_seq_20260908_v2/tables/adaptive_restart_decision.json`: `687ee20bcde1d0428d129152bbb4c82bab7a8cce821ba5dc4d5719d6b83d258b`

AIC and Akaike weights are comparable only within the same genotype and alignment policy. They must not be compared across genotypes or alignment policies.

The independently fitted `k_2` is diagnostic only. Do not interpret fitted free-`k_2` ratios as biological mavacamten effects.

The identifiability labels are practical identifiability diagnostics from this multistart ensemble, not proof of structural identifiability.

Control parameter and treatment-timing conclusions are provisional because the workbook has no stimulus timing metadata.

- Computed acute peak-force ratio for `shared_by_genotype__Control`: 34.7% of Before.
- Computed acute peak-force ratio for `shared_by_genotype__H251N`: 33.1% of Before.
- Computed acute peak-force ratio for `independent_trace__Control`: 34.7% of Before.

- `shared_by_genotype__Control`: k123 observed: 4/4 converged; 4 boundary-affected starts; stage delta AIC 2.55e+03; Best defensible stage: plus_k40 (weight 0.728; 4/4 converged); Practical identifiability: 0 stable, 0 weak, 5 non-identifiable; 1 near-optimal starts; 1 clusters.
- `shared_by_genotype__H251N`: k123 observed: 4/4 converged; 4 boundary-affected starts; stage delta AIC 4.38e+03; Best defensible stage: plus_k73 (weight 1.000; 8/8 converged); Practical identifiability: 0 stable, 0 weak, 6 non-identifiable; 1 near-optimal starts; 1 clusters.
- `independent_trace__Control`: k123 observed: 4/4 converged; 4 boundary-affected starts; stage delta AIC 2.82e+03; Best defensible stage: plus_k73 (weight 0.518; 8/8 converged); Practical identifiability: 0 stable, 0 weak, 6 non-identifiable; 1 near-optimal starts; 1 clusters.

Largest observed consecutive stage-level AIC improvement: 3.78e+03 (shared_by_genotype__H251N: k123 to plus_k50).

Question for the PI: Are the six Mava traces synchronized to the same electrical or calcium stimulus time? Does the first column represent a common absolute stimulus time, or could each averaged trace have an arbitrary temporal offset? The signed shared-Control metrics place acute rise-lag 145 ms later than Before. Should I preserve that difference, or independently align each trace's contraction onset to the calcium transient?
