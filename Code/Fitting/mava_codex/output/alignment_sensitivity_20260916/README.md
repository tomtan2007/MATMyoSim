# Control timing-alignment sensitivity

This diagnostic compares two preprocessing policies on the **same six source
force traces**. It does not change the workbook, alter model parameters, or run
an optimization.

- `shared_by_genotype` anchors all Control conditions to the Control Before
  trough. This was the policy used for the current capped feature-fit prototype.
- `independent_trace` anchors each trace to its own detected trough.

The shared policy leaves the Control acute trace with a roughly 208 ms apparent
force delay after calcium onset. Trace-specific alignment removes approximately
192 ms of that delay, leaving a timing discrepancy on the order of one source
sample. Therefore, the prominent Control onset mismatch in the feature-fit
figure is an alignment-policy sensitivity, not evidence for a kinetic driver.

The correct policy depends on the experiment: use a shared time origin only if
the source traces have verified common stimulus timing. Confirm this with the PI
before replacing the primary preparation policy or rerunning fits.
