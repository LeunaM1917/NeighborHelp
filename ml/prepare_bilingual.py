"""Add human-labeled English DynaSent reviews to the FiReCS pilot data."""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import random
import re
import urllib.request
import zipfile
from collections import Counter
from pathlib import Path

from ml.common import LABELS, file_hash, read_rows, write_json
from ml.prepare_firecs import main as prepare_firecs
from ml.sentiment_train import clean_unicode

DYNASENT_REVISION = "707b6208978bfe7ff251a0c3263c9f0552c27b48"


def identity(text):
    return hashlib.sha256(re.sub(r"[^\w\s]", "", clean_unicode(text)).encode()).hexdigest()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("ml/data/bilingual"))
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args(argv)
    args.output.mkdir(parents=True, exist_ok=True)
    firecs = Path("ml/data/firecs/reviews.csv")
    if not firecs.exists():
        prepare_firecs([])
    # Pin the exact author repository revision used by the recorded experiment.
    lock = args.output / "dynasent-source-lock.json"
    if lock.exists():
        revision = json.loads(lock.read_text())["revision"]
    else:
        revision = DYNASENT_REVISION
        write_json(lock, {"revision": revision})
    archive_path = args.output / "dynasent-v1.1.zip"
    if not archive_path.exists():
        with urllib.request.urlopen(f"https://raw.githubusercontent.com/cgpotts/dynasent/{revision}/dynasent-v1.1.zip", timeout=45) as response:
            archive_path.write_bytes(response.read())
    combined = [{**r, "language": "Tagalog/Taglish and English"} for r in read_rows(firecs)]
    with zipfile.ZipFile(archive_path) as archive:
        for source_split, target_split, per_class in [("train", "train", 2000), ("dev", "validation", 400), ("test", "test", 600)]:
            name = next(n for n in archive.namelist() if n.endswith(f"round01-yelp-{source_split}.jsonl"))
            rows = [json.loads(line) for line in archive.read(name).decode("utf-8").splitlines() if line.strip()]
            rng = random.Random(args.seed)
            for label in LABELS:
                choices = [r for r in rows if r.get("gold_label") == label]
                rng.shuffle(choices)
                for row in choices[:per_class]:
                    combined.append({"text": row["sentence"], "label": str(LABELS.index(label)), "group_id": "dynasent:" + row["review_id"], "source": "DynaSent round 1", "split": target_split, "language": "English"})
    # Assign each full original review and each normalized duplicate to its most
    # protected split. Remove lower-priority copies, never move test to training.
    order = {"train": 0, "validation": 1, "test": 2}
    protected = {}
    group_split = {}
    for row in combined:
        digest = identity(row["text"])
        protected[digest] = max(protected.get(digest, 0), order[row["split"]])
        group_split[row["group_id"]] = max(group_split.get(row["group_id"], 0), order[row["split"]])
    filtered = [r for r in combined if order[r["split"]] == protected[identity(r["text"])] == group_split[r["group_id"]]]
    output = args.output / "reviews.csv"
    with output.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=["text", "label", "group_id", "source", "split", "language"])
        writer.writeheader()
        writer.writerows(filtered)
    attribution = "DynaSent: Potts, Wu, Geiger and Kiela (2020), https://github.com/cgpotts/dynasent, data CC BY 4.0. FiReCS: Cosme and De Leon (2024), https://huggingface.co/datasets/ccosme/FiReCS, CC BY 4.0."
    write_json(args.output / "source.json", {"attribution": attribution, "dynasent_revision": revision, "dynasent_archive_sha256": file_hash(archive_path),
               "firecs_manifest": "../firecs/source.json", "data_sha256": file_hash(output), "seed": args.seed,
               "removed_cross_split_text_or_review_overlap": len(combined) - len(filtered), "counts": dict(Counter(f'{r["source"]}:{r["split"]}' for r in filtered)),
               "cebuano_verified": False, "pilot_test_reused": "FiReCS test was previously evaluated in the initial pilot; this is an extended language-coverage experiment, not a new untouched FiReCS benchmark."})
    (args.output / "ATTRIBUTION.txt").write_text(attribution + "\nhttps://creativecommons.org/licenses/by/4.0/\n", encoding="utf-8")
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
