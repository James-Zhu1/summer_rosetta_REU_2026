# Changes to `design/colabdesign_utils.py`

This documents the modifications made to BindCraft's `design/colabdesign_utils.py` for this project. The goal was to make hallucination trajectories inspectable after the fact — per-iteration sequence logits, per-iteration loss terms, and per-stage timing — without changing BindCraft's actual design behavior or outputs.

Full raw diff: [`original_vs_modified.diff`](original_vs_modified.diff)
Patched file: [`colabdesign_utils.py`](colabdesign_utils.py)

All four changes live inside `binder_hallucination()`, plus one small addition at the top of the file.

---

## 1. New imports

Added `csv` to the standard import line, plus `time` and `contextlib.contextmanager` as new imports, to support the timing and logging utilities added below.

```diff
-import os, re, shutil, math, pickle
+import os, re, shutil, math, pickle, csv
 import matplotlib.pyplot as plt
 import numpy as np
 import jax
 ...
 from .pyrosetta_utils import pr_relax, align_pdbs
 from .generic_utils import update_failures

+import time
+from contextlib import contextmanager
```

---

## 2. Stage-timing helper (`timed` + `print_stage_times`)

A `timed()` context manager wraps a block of code, measures its wall-clock duration, and accumulates it into a shared dict (`stage_times`) keyed by stage name. `print_stage_times()` then prints (and optionally saves) a formatted summary — each stage's time, its percentage of the total, and the grand total.

```python
@contextmanager
def timed(name, store):
    """Time the wrapped block and add the elapsed seconds to store[name]."""
    t0 = time.perf_counter()
    try:
        yield
    finally:
        dt = time.perf_counter() - t0
        store[name] = store.get(name, 0.0) + dt
        print(f"  [timing] {name}: {dt:.1f}s")


def print_stage_times(store, save_path=None):
    """Print a per-stage timing summary (and optionally write it to save_path)."""
    if not store:
        return
    total = sum(store.values())
    lines = ["", "=== Hallucination stage timing ==="]
    for k, v in store.items():
        pct = (100 * v / total) if total else 0.0
        lines.append(f"  {k:<22} {v:8.1f}s  ({pct:4.1f}%)")
    lines.append(f"  {'TOTAL':<22} {total:8.1f}s")
    print("\n".join(lines))
    if save_path:
        try:
            with open(save_path, "w") as fh:
                fh.write("\n".join(lines[1:]) + "\n")   # skip leading blank line
        except OSError as e:
            print(f"  [timing] could not write {save_path}: {e}")
```

**Usage inside `binder_hallucination()`:** a `stage_times = {}` dict is created right before the `4stage` branch, and each stage of the algorithm is wrapped:

```diff
+    stage_times = {}
     if advanced_settings["design_algorithm"] == '4stage':
         print("Stage 1: Test Logits")
-        af_model.design_logits(iters=50, e_soft=0.9, models=design_models, ...)
+        with timed("Stage 1: Logits", stage_times):
+            af_model.design_logits(iters=50, e_soft=0.9, models=design_models, ...)
```

The same `with timed(...)` wrapping is applied to every other stage of the `4stage` algorithm:

| Stage | Timer label |
|---|---|
| Stage 1 — Test Logits | `Stage 1: Logits` |
| Stage 1B — Additional Logits Optimisation | `Stage 1B: Additional Logits` |
| Stage 2 — Softmax Optimisation | `Stage 2: Softmax` |
| Stage 3 — One-hot Optimisation | `Stage 3: One-hot` |
| Stage 4 — PSSM Semigreedy Optimisation | `Stage 4: Semigreedy` |

Finally, right before the trajectory PDB is saved, the summary is printed and written to `<design_name>_stage_times.txt` alongside the trajectory output:

```diff
     ### save trajectory PDB
     final_plddt = get_best_plddt(af_model, length)
+    print_stage_times(stage_times,
+                      save_path=os.path.join(os.path.dirname(design_paths["Trajectory"]),
+                                             design_name + "_stage_times.txt"))
     af_model.save_pdb(model_pdb_path)
```

---

## 3. Per-iteration sequence matrix logging

A callback (`_log_seq_matrix`) is registered on ColabDesign's `af_model._callbacks["design"]["post"]` hook, which fires after every design iteration. It pulls the current binder sequence logits out of `af.aux["seq"]["logits"]`, appends them to an in-memory list, and rewrites the full stacked array to disk every iteration (so the file is still usable if a run is interrupted).

```python
output_folder = os.path.dirname(design_paths["Trajectory"])   # main output folder, not Trajectory/
seq_matrix_log = []
seq_matrix_path = os.path.join(output_folder, design_name + "_seqmatrix.npy")

def _log_seq_matrix(af):
    mat = np.asarray(af.aux["seq"]["logits"])[0]        # shape (length, 20)
    seq_matrix_log.append(mat.copy())
    np.save(seq_matrix_path, np.stack(seq_matrix_log))  # rewrite full stack each iter
    if len(seq_matrix_log) == 1:
        print(f"Logging binder sequence matrix each iter -> {seq_matrix_path}")

af_model._callbacks["design"]["post"].append(_log_seq_matrix)
```

**Output:** `<design_name>_seqmatrix.npy`, shape `(iterations, length, 20)` — the raw material for all the sequence-matrix characterization (heatmaps, PCA, UMAP, CompariPSSM) done in the trajectory-analysis notebooks.

---

## 4. Per-iteration loss logging

A second callback (`_log_losses`), registered the same way, records the loss terms at every iteration. Each row captures `logged_row` (a running counter), the ColabDesign iteration index (`af._k`), the total loss, and every individual loss term found in `af.aux["losses"]` (e.g. `pae`, `plddt`, `i_pae`, `con`, `i_con`, `helix`, `rg`). New loss-term keys are added to the CSV header dynamically the first time they appear. The file is rewritten in full on every iteration, so it stays valid even if the run stops early.

```python
loss_log_path = os.path.join(output_folder, design_name + "_loss_log.csv")
loss_log_rows = []
loss_log_fields = ["logged_row", "iter", "total_loss"]

def _loss_to_float(x):
    try:
        return float(np.asarray(x).mean())
    except Exception:
        return str(x)

def _log_losses(af):
    row = {
        "logged_row": len(loss_log_rows),
        "iter": getattr(af, "_k", None),
        "total_loss": _loss_to_float(af.aux.get("loss", np.nan)),
    }

    # Individual loss terms: pae, plddt, i_pae, con, i_con, helix, rg, etc.
    for k, v in af.aux.get("losses", {}).items():
        row[k] = _loss_to_float(v)
        if k not in loss_log_fields:
            loss_log_fields.append(k)

    loss_log_rows.append(row)

    # Rewrite each iteration so the file is still useful if the run stops early
    with open(loss_log_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=loss_log_fields)
        writer.writeheader()
        writer.writerows(loss_log_rows)

    if len(loss_log_rows) == 1:
        print(f"Logging trajectory losses each iter -> {loss_log_path}")

af_model._callbacks["design"]["post"].append(_log_losses)
```

**Output:** `<design_name>_loss_log.csv` — one row per iteration, one column per loss term.

---

## Net effect

Every trajectory run through the patched script produces three extra artifacts per design, with no change to BindCraft's own design outputs (PDB, stats CSVs, etc.):

| File | Contents |
|---|---|
| `<design_name>_seqmatrix.npy` | Per-iteration sequence logits, shape `(iterations, length, 20)` |
| `<design_name>_loss_log.csv` | Per-iteration loss terms (total + individual) |
| `<design_name>_stage_times.txt` | Wall-clock time per design stage |

These three files are what all three notebooks in `bindcraft_analysis/notebooks/` are built on.
