# BindCraft Trajectory Analysis & 10LG Binder Design — Summer Research

This repository documents summer research on characterizing [BindCraft](https://github.com/martinpacesa/BindCraft) hallucination trajectories and using BindCraft to design peptide binders against the target protein **10LG**, with downstream validation via molecular dynamics (MD) in Amber.

The work has three main components:

1. **Trajectory analysis** — instrumenting BindCraft's design code to log per-iteration data (Time for each stage, `Loss function` over time, and `Sequence Matrix` over time), then characterizing the resulting trajectories using PCA and [CompariPSSM](https://github.com/ifigenia-t/CompariPSSM).
2. **Binder design on 10LG** — using BindCraft to generate short peptide binders (length 10–25) against 10LG, followed by filtering and selection of candidates.
3. **MD validation (in progress)** — running classical MD in Amber on a subset of selected designs to assess stability (RMSD) and estimate binding free energy (MM/PBSA).

---

## Repository Structure

```
bindcraft-summer-research/
├── README.md
│
├── bindcraft_modifications/
│   ├── colabdesign_utils.py        # patched design/colabdesign_utils.py
│   ├── CHANGES.md                  # detailed writeup of the 4 modifications
│   └── original_vs_modified.diff   # raw diff against upstream BindCraft
│
├── trajectory_analysis/
│   ├── scripts/
│   │   ├── parse_logs.py           # aggregates *_seqmatrix.npy, *_loss_log.csv, *_stage_times.txt
│   │   ├── pca.py                  # PCA/UMAP characterization of trajectories
│   │   └── comparipssm.py          # sequence-matrix similarity metric (PSSM comparison)
│   ├── notebooks/
│   │   └── trajectory_exploration.ipynb
│   └── results/
│       ├── figures/
│       └── tables/
│
├── fixed_length_experiment/
│   ├── config/                     # BindCraft settings used for the fixed-length run
│   ├── raw_outputs/                # pointer/symlink to BindCraft output directory
│   └── results/
│       ├── figures/
│       └── comparepssm_scores.csv
│
├── binder_design_10LG/
│   ├── config/                     # BindCraft settings.json (peptide, length 10-25, target 10LG)
│   ├── raw_designs/
│   ├── filtered_designs/
│   └── selected_designs/
│       └── structures/
│
├── md_simulations/
│   ├── amber_inputs/
│   │   ├── tleap/
│   │   └── parameters/
│   ├── trajectories/               # large files — not tracked in git, stored separately
│   ├── analysis/
│   │   ├── rmsd/
│   │   └── mmpbsa/
│   └── README.md                   # status notes for this component
│
└── docs/
    └── lab_notebook.md             # running notes / dated log
```

---

## 1. BindCraft Trajectory Analysis

### 1.1 Modifications to `design/colabdesign_utils.py`

The stock BindCraft design script was patched with four additions to make hallucination trajectories inspectable after the fact. Full diffs are in [`bindcraft_modifications/CHANGES.md`](bindcraft_modifications/CHANGES.md); summary below.

| # | Change | Purpose |
|---|--------|---------|
| 1 | Added `csv`, `time`, and `contextlib.contextmanager` imports | Support the timing and logging utilities added below |
| 2 | Added a `timed()` context manager and `print_stage_times()` helper | Times each design stage (e.g. Stage 1: Logits, Stage 2, ...) and writes a per-stage timing summary to `<design_name>_stage_times.txt` |
| 3 | Added a `_log_seq_matrix()` callback registered on `af_model._callbacks["design"]["post"]` | Captures the binder sequence logits at every design iteration and saves the full stack to `<design_name>_seqmatrix.npy` |
| 4 | Added a `_log_losses()` callback registered on `af_model._callbacks["design"]["post"]` | Appends each iteration's loss terms (pae, plddt, total_loss, etc.) as a row to `<design_name>_loss_log.csv` |

Each design stage in the `4stage` algorithm was wrapped in the `timed(...)` context manager, and `print_stage_times()` is called just before the final trajectory PDB is saved, writing the summary alongside the trajectory output.

**Net effect:** every BindCraft trajectory run with the patched script produces three extra artifacts per design, without changing the design outputs themselves:
- `<design_name>_seqmatrix.npy` — per-iteration sequence logits, shape `(iterations, length, 20)`
- `<design_name>_loss_log.csv` — per-iteration loss terms
- `<design_name>_stage_times.txt` — wall-clock time per design stage

### 1.2 Trajectory Characterization

Using the logged sequence matrices, loss curves, and stage timings, trajectories were characterized with:
- Comparison of per-stage timing across trajectories
- Comparison of loss dynamics (convergence rate, stage-to-stage behavior) across trajectories
- **PCA** on sequence-logit trajectories to visualize how designs move through sequence space over the course of hallucination

> Scripts: `trajectory_analysis/scripts/parse_logs.py`, `trajectory_analysis/scripts/pca_umap.py`
> *(to be added — see note in Status section)*

### 1.3 Fixed-Length Run + PSSM Comparison

A second BindCraft run was performed using a **fixed design length**, with the same logging/characterization pipeline applied. Additionally, a `comparepssm` function was written to quantify the similarity between sequence matrices (PSSM-style comparison) across trajectories/runs.

> Scripts: `trajectory_analysis/scripts/comparepssm.py`
> Config: `fixed_length_experiment/config/`

---

## 2. Binder Design on 10LG

BindCraft (default pipeline, with the logging patch above applied) was used to design short peptide binders against the target protein **10LG**, using a length range of **10–25 residues** instead of the larger protein lengths typically used.

- **Config:** `binder_design_10LG/config/`
- **Raw designs:** `binder_design_10LG/raw_designs/`
- **Filtering:** designs were filtered down from the raw output pool using BindCraft's standard filtering metrics *(criteria to be documented — see Status section)*; filtered candidates are in `binder_design_10LG/filtered_designs/`
- **Selected designs:** a final subset was selected for presentation/downstream validation, in `binder_design_10LG/selected_designs/`

---

## 3. MD Validation (In Progress)

A subset of the selected 10LG binder designs will be run through classical MD in **Amber** to evaluate:
- **RMSD** — structural stability of the designed complex over the simulation
- **MM/PBSA** — approximate binding free energy estimation

This component is still in progress. See [`md_simulations/README.md`](md_simulations/README.md) for current status, input files, and parameters as they're finalized.

---

## Status / TODO

- [ ] Add trajectory analysis scripts (`parse_logs.py`, `pca_umap.py`, `comparepssm.py`) and notebook
- [ ] Document 10LG design filtering criteria
- [ ] Add selected design structures + summary table
- [ ] Set up Amber MD inputs (tleap, parameters)
- [ ] Run RMSD analysis
- [ ] Run MM/PBSA analysis
- [ ] Add figures/results from PCA/UMAP and comparepssm to `trajectory_analysis/results/`

## Notes

- Large trajectory/simulation files (raw BindCraft outputs, Amber trajectory files) are not tracked in git — see `.gitignore` and store separately (e.g. lab storage/scratch).
- This README will be updated as remaining scripts and MD results are added.
