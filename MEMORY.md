# MATMyoSim Memory Index

This file is the source of truth for the latest project state. Dated entries
must distinguish observed results from interpretation, and explicitly mark
superseded claims inline.

## 2026-09-08 — BPS focus and Mavacamten sequential analysis

- The immediate deliverable is the 48-fit Mavacamten sequential analysis:
  three alignment/genotype groups, four nested stages, and four restarts per
  stage. It is run serially in one MATLAB instance as an immutable capsule.
- Fix C is closed only on the load-bearing items: verify the unfinished
  worker diff; trace authority-note claims to signed evidence; and run/report
  the relevant tests and dry run. Do not expand this into tamper/hash/reseal
  hardening or an additional independent-review round before producing fits.
- Cap corrective-review work at two rounds. Each round must name the exact
  presentation sentence it protects. Work that does not protect a claim to
  the PI/BPS audience is deferred.
- Delegate by task shape: use long unattended runs for fits, multistarts, and
  length sweeps; reserve history- and judgment-heavy questions for review
  against the project record. The reviewer should not be the agent that made
  the change.
- Scientific claim boundary: the 30-restart analysis established practical
  non-identifiability at the current single-cell twitch data scale. `k_1` is
  unconstrained across near-quality fits, and only the `k_5_0`-increase
  direction consistently reproduces the observed force increase. Do not
  present a unique HCM driver parameter from this fit. The defensible BPS
  statement is: the 6-state model wins AIC in both conditions, while the
  specific driver parameter is not identifiable without reducing free
  parameters, adding constraints, or collecting additional data.
- Narrative rule: every lab-meeting/BPS claim must be date-stamped and tied
  to a result capsule or a named historical analysis. Mark prior claims
  superseded inline; never treat a stale prose summary as the latest result.

### Superseded claims

- **Superseded:** `k_1` is a 5.2× or 10.5× HCM driver.
- **Superseded:** `k_7_1` has a unique ~7× control-to-HCM change.
- **Current interpretation:** individual kinetic drivers are not identifiable
  from the present single-cell twitch fit at this model complexity.
