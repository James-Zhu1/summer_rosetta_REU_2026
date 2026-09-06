# Summer Research 2026 — BindCraft Trajectory Analysis & 10LG Binder Design

This repository documents summer research characterizing [BindCraft](https://github.com/martinpacesa/BindCraft) hallucination trajectories and using BindCraft to design peptide binders against the target protein **10LG**, with downstream validation via molecular dynamics (MD) in Amber.

The work is split into three self-contained parts, each with its own README:

| Part | Description |
|---|---|
| [`bindcraft_analysis/`](bindcraft_analysis/README.md) | Instrumented BindCraft's design code to log per-iteration sequence/loss/timing data, then characterized trajectories (single-trajectory convergence, population PCA/UMAP, CompariPSSM) to explore whether more dynamic filters could replace BindCraft's hardcoded thresholds. |
| [`bindcraft_design_10LG/`](bindcraft_design_10LG/README.md) | Used BindCraft's default pipeline to design short peptide binders (length 10–25) against 10LG, then filtered and selected candidates. *(README in progress)* |
| [`md_simulations/`](md_simulations/README.md) | Classical MD in Amber on a subset of selected 10LG binder designs — RMSD and MM/PBSA. *(In progress; README in progress)* |

---

## Repository Structure

```
summer-research-2026/
├── README.md                        # you are here
│
├── bindcraft_analysis/
│   ├── README.md
│   ├── bindcraft_modifications/
│   │   ├── colabdesign_utils.py
│   │   ├── CHANGES.md
│   │   └── original_vs_modified.diff
│   ├── notebooks/
│   │   ├── 01_single_trajectory_convergence.ipynb
│   │   ├── 02_variable_length_population_analysis.ipynb
│   │   └── 03_fixed_length_analysis_comparipssm.ipynb
│   └── results/
│       ├── figures/
│       └── tables/
│
├── bindcraft_design_10LG/
│   ├── README.md
│   ├── config/
│   ├── raw_designs/
│   └── selected_designs/
│       └── structures/
│
└── md_simulations/
    ├── README.md
    ├── amber_inputs/
    │   ├── tleap/
    │   └── parameters/
    ├── trajectories/
    └── analysis/
        ├── rmsd/
        └── mmpbsa/
```

## Notes

- Large trajectory/simulation files (raw BindCraft outputs, Amber trajectory files, PSSM/score exports) are not tracked in git — see each part's own README for what's excluded and why.
- See each subfolder's README for methods, findings, and status specific to that part of the work.
