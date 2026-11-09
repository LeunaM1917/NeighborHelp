"""Dataset checks and metrics shared by offline experiments."""
from __future__ import annotations

import csv
import hashlib
import json
import math
import random
from collections import Counter, defaultdict
from pathlib import Path

LABELS = ("negative", "neutral", "positive")
SPLITS = ("train", "validation", "test")


def read_rows(path: Path) -> list[dict]:
    if path.suffix.lower() == ".jsonl":
        return [json.loads(line) for line in path.read_text(encoding="utf-8-sig").splitlines() if line.strip()]
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + "\n", encoding="utf-8")


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def split_groups(rows: list[dict], seed: int) -> dict[str, list[dict]]:
    """Assign whole groups once. Explicit supplied splits take precedence.

    Automatic assignment uses 60/20/20 independent of labels; it is not a
    stratified split. Callers check class/query coverage rather than hiding a
    bad small-data split by repeatedly choosing seeds against the test set.
    """
    explicit = {bool(str(row.get("split", "")).strip()) for row in rows}
    if len(explicit) > 1:
        raise ValueError("Provide a split for every row, or leave every split blank.")
    groups = defaultdict(list)
    for row in rows:
        groups[row["group_id"]].append(row)
    assigned = {}
    if explicit == {True}:
        for key, group in groups.items():
            values = {str(r["split"]).strip().lower() for r in group}
            if len(values) != 1 or not values.issubset(SPLITS):
                raise ValueError("A group crosses splits or uses an unsupported split name.")
            assigned[key] = values.pop()
    else:
        keys = sorted(groups)
        random.Random(seed).shuffle(keys)
        train_end, validation_end = int(len(keys) * .6), int(len(keys) * .8)
        assigned = {key: "train" if i < train_end else "validation" if i < validation_end else "test" for i, key in enumerate(keys)}
    partitions = {name: [] for name in SPLITS}
    for key, group in groups.items():
        partitions[assigned[key]].extend(group)
    if any(not rows for rows in partitions.values()):
        raise ValueError("Training, validation and test each need independent nonempty groups.")
    return partitions


def classification_metrics(truth: list[int], probabilities) -> dict:
    if not truth or len(truth) != len(probabilities):
        raise ValueError("Metrics require matching nonempty labels and predictions.")
    matrix = [[0] * 3 for _ in LABELS]
    calibration = [[] for _ in range(10)]
    brier = 0.0
    for actual, scores in zip(truth, probabilities):
        if len(scores) != 3 or any(not math.isfinite(float(p)) or p < 0 for p in scores) or abs(sum(scores) - 1) > 1e-4:
            raise ValueError("Expected three finite normalized class probabilities.")
        predicted = max(range(3), key=lambda i: scores[i])
        matrix[actual][predicted] += 1
        confidence = float(scores[predicted])
        calibration[min(9, int(confidence * 10))].append((confidence, actual == predicted))
        brier += sum((float(p) - int(i == actual)) ** 2 for i, p in enumerate(scores))
    per_class = {}
    for i, label in enumerate(LABELS):
        tp = matrix[i][i]
        precision = tp / max(1, sum(row[i] for row in matrix))
        recall = tp / max(1, sum(matrix[i]))
        per_class[label] = {"precision": precision, "recall": recall, "f1": 2 * precision * recall / (precision + recall) if precision + recall else 0.0, "support": sum(matrix[i])}
    ece = sum(len(bucket) / len(truth) * abs(sum(c for c, _ in bucket) / len(bucket) - sum(hit for _, hit in bucket) / len(bucket)) for bucket in calibration if bucket)
    return {"count": len(truth), "accuracy": sum(matrix[i][i] for i in range(3)) / len(truth), "macro_f1": sum(x["f1"] for x in per_class.values()) / 3,
            "per_class": per_class, "confusion_matrix": matrix, "matrix_order": list(LABELS), "brier_score": brier / len(truth), "expected_calibration_error_10_bins": ece}


def partition_summary(partitions: dict) -> dict:
    return {name: {"rows": len(rows), "groups": len({r["group_id"] for r in rows}), "labels": dict(Counter(str(r.get("label", "unlabeled")) for r in rows))} for name, rows in partitions.items()}
