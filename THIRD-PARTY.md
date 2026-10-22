# Third-party dependency

This project is an extension of `qjgqjg/moon-causal@0.2.5`, by its upstream contributors,
licensed under Apache-2.0: https://github.com/qjgqjg/moon-causal .

The declared Mooncakes dependency is real: `rake_integer_cells` is called by the
single-margin interoperability baseline, `effective_sample_size` by diagnostics,
and `hajek_mean` by the validated weighted-mean adapter. This project does not
claim authorship of those routines or copy upstream source/test files.

New code adds a validated multi-margin problem model, per-row absolute bounds,
bounded scalar projections, simultaneous residual checks, explicit iteration-limit
status, and an external weight audit. These features are not a claim that the
upstream is deficient, nor evidence of upstream collaboration or endorsement.

Our source is MIT; upstream remains Apache-2.0. The dependency's Apache license is
included under `licenses/`. When redistributing dependency source or compiled
artifacts, retain its license, attribution and any applicable upstream notices.
