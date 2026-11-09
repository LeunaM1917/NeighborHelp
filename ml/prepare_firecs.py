"""Fetch a pinned, human-annotated public review corpus and preserve its test split."""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import random
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

from ml.common import file_hash, write_json
from ml.sentiment_train import clean_unicode

REVISION = "4da2863e53e7260ab6f2dcd2089af5c112d25c80"
SOURCE = "https://huggingface.co/datasets/ccosme/FiReCS"
ATTRIBUTION = "Cosme, C.J. and De Leon, M.M. (2024). Sentiment Analysis of Code-Switched Filipino-English Product and Service Reviews Using Transformers-Based Large Language Models. DOI: 10.1007/978-981-99-8349-0_11. FiReCS v1.0, CC BY 4.0."


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("ml/data/firecs"))
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args(argv)
    args.output.mkdir(parents=True, exist_ok=True)
    data = {}
    for split in ["train", "test"]:
        name = f"FiReCS_{split}_set.csv"
        path = args.output / name
        if not path.exists():
            with urllib.request.urlopen(f"{SOURCE}/resolve/{REVISION}/{name}", timeout=30) as response:
                path.write_bytes(response.read())
        rows = []
        for raw in csv.DictReader(io.StringIO(path.read_text(encoding="utf-8-sig"))):
            text = (raw.get("review") or "").strip()
            try:
                label = float(raw.get("label", ""))
            except ValueError:
                continue
            if len(text) < 3 or label not in [0, 1, 2]:
                continue
            group = hashlib.sha256(clean_unicode(text).encode()).hexdigest()
            rows.append({"text": text, "label": int(label), "group_id": group, "source": "FiReCS", "split": split})
        data[split] = rows
    # Test identities have priority: never fit on a review represented in test.
    test_groups = {r["group_id"] for r in data["test"]}
    original_train = len(data["train"])
    data["train"] = [r for r in data["train"] if r["group_id"] not in test_groups]
    groups = sorted({r["group_id"] for r in data["train"]})
    random.Random(args.seed).shuffle(groups)
    validation = set(groups[:max(1, int(len(groups) * .2))])
    for row in data["train"]:
        row["split"] = "validation" if row["group_id"] in validation else "train"
    output = args.output / "reviews.csv"
    with output.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=["text", "label", "group_id", "source", "split"])
        writer.writeheader()
        writer.writerows(data["train"] + data["test"])
    manifest = {"source": SOURCE, "revision": REVISION, "license": "CC-BY-4.0", "license_url": "https://creativecommons.org/licenses/by/4.0/", "attribution": ATTRIBUTION,
                "annotation": "Original human sentiment labels, not inferred from star ratings", "labels": {"0": "negative", "1": "neutral", "2": "positive"},
                "languages": ["English", "Tagalog/Taglish"], "cebuano_verified": False, "seed": args.seed,
                "train_rows_removed_for_test_overlap": original_train - len(data["train"]), "data_sha256": file_hash(output),
                "download_sha256": {split: file_hash(args.output / f"FiReCS_{split}_set.csv") for split in data},
                "split_counts": dict(Counter(r["split"] for rows in data.values() for r in rows)),
                "limitations": ["Product and service reviews outside NeighborHelp; domain evaluation still required.", "Official test split retained; a validation split was taken only from original training data."]}
    write_json(args.output / "source.json", manifest)
    (args.output / "ATTRIBUTION.txt").write_text(ATTRIBUTION + "\n" + SOURCE + "\nRevision: " + REVISION + "\nLicense: https://creativecommons.org/licenses/by/4.0/\n", encoding="utf-8")
    print(output)
    print(manifest["split_counts"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
