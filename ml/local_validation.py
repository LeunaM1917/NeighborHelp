"""Freeze independently labeled local reviews before tuning; never invent labels."""
from __future__ import annotations
import argparse
import csv
import json
from collections import Counter
from pathlib import Path
from ml.common import LABELS, file_hash, read_rows, split_groups, write_json

LANGUAGES = ("English", "Tagalog/Taglish", "Cebuano/Bisaya")
FIELDS = ("text", "label", "language", "group_id", "source", "permission_or_license",
          "redacted", "reviewer_1_id", "reviewer_1_label", "reviewer_2_id", "reviewer_2_label",
          "adjudicator_id", "adjudication_notes", "native_speaker_verified")

def validate(rows: list[dict]) -> list[dict]:
    """Two independent labels and a documented resolution; no automatic sentiment labels."""
    clean, seen = [], set()
    for index, raw in enumerate(rows, 2):
        row = {k: str(raw.get(k, "")).strip() for k in FIELDS}
        if not any(row.values()):
            continue
        prefix = f"Row {index}: "
        if not all(row[k] for k in ("text", "group_id", "source", "permission_or_license", "reviewer_1_id", "reviewer_2_id")):
            raise ValueError(prefix + "complete text, source, permission, group and independent reviewer IDs.")
        if row["redacted"].lower() != "yes":
            raise ValueError(prefix + "a person must confirm personal details were removed (redacted=yes).")
        if row["reviewer_1_id"] == row["reviewer_2_id"]:
            raise ValueError(prefix + "reviewer IDs must differ.")
        if any(row[k] not in LABELS for k in ("label", "reviewer_1_label", "reviewer_2_label")):
            raise ValueError(prefix + "use negative, neutral or positive labels.")
        if row["reviewer_1_label"] != row["reviewer_2_label"]:
            if not row["adjudicator_id"] or not row["adjudication_notes"]:
                raise ValueError(prefix + "resolve disagreement with a named adjudicator and notes.")
        elif row["label"] != row["reviewer_1_label"]:
            raise ValueError(prefix + "the final label must match agreed labels.")
        if row["language"] not in LANGUAGES:
            raise ValueError(prefix + "choose one of the three target language groups.")
        if row["language"] == "Cebuano/Bisaya" and row["native_speaker_verified"].lower() != "yes":
            raise ValueError(prefix + "Cebuano/Bisaya needs native-speaker verification.")
        key = " ".join(row["text"].casefold().split())
        if key in seen:
            raise ValueError(prefix + "duplicate text; keep paraphrases/translations in the same group.")
        seen.add(key)
        clean.append(row)
    if not clean:
        raise ValueError("No human-labeled reviews supplied. Fill the collection template first.")
    return clean

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, help="Permissioned, redacted, independently labeled CSV")
    parser.add_argument("--output", type=Path, required=True, help="New output directory (never overwrite a freeze)")
    parser.add_argument("--template", action="store_true", help="Create an empty collection form only")
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args(argv)
    if args.output.exists():
        parser.error("Output already exists; preserve frozen test data and choose a new directory.")
    if args.template:
        args.output.mkdir(parents=True)
        with (args.output / "local_reviews.csv").open("w", encoding="utf-8", newline="") as stream:
            csv.DictWriter(stream, fieldnames=FIELDS).writeheader()
        return 0
    if not args.data:
        parser.error("--data is required unless creating a template.")
    rows = validate(read_rows(args.data))
    partitions = split_groups(rows, args.seed)
    # Each language/class needs independent train/validation/test coverage.
    counts = {split: {language: dict(Counter(r["label"] for r in values if r["language"] == language))
                      for language in LANGUAGES} for split, values in partitions.items()}
    for split, languages in counts.items():
        for language, classes in languages.items():
            if any(classes.get(label, 0) < 10 for label in LABELS):
                raise ValueError(f"{split}/{language} needs at least 10 examples per class. Collect more independent reviews; do not move test rows to improve coverage.")
    args.output.mkdir(parents=True)
    output = args.output / "reviews.csv"
    # Training snapshots intentionally exclude annotator identities and permission records.
    with output.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=["text", "label", "language", "group_id", "split", "source"])
        writer.writeheader()
        for split, values in partitions.items():
            for row in values:
                writer.writerow({k: split if k == "split" else row[k] for k in writer.fieldnames})
    agreement = sum(r["reviewer_1_label"] == r["reviewer_2_label"] for r in rows) / len(rows)
    write_json(args.output / "manifest.json", {"source_sha256": file_hash(args.data), "snapshot_sha256": file_hash(output),
        "seed": args.seed, "rows": len(rows), "counts": counts, "raw_annotator_agreement": agreement,
        "test_policy": "Freeze once before tuning. Do not optimize against test labels.", "is_model_approval": False})
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
