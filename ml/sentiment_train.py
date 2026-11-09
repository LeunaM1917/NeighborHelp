"""Train/evaluate a three-class raw-text LSTM candidate, never the live model.

Run from the repository root: python -m ml.sentiment_train --help
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import unicodedata
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

from ml.common import LABELS, classification_metrics, file_hash, partition_summary, read_rows, split_groups, write_json


def clean_unicode(text: str) -> str:
    text = unicodedata.normalize("NFKC", text).lower()
    text = re.sub(r"https?://\S+|www\.\S+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def load_sentiment(path: Path, seed: int) -> tuple[dict, dict]:
    rows, seen, conflicts, duplicates = [], {}, set(), 0
    for line, raw in enumerate(read_rows(path), 2):
        text = str(raw.get("text", "")).strip()
        label = str(raw.get("label", "")).strip().lower()
        if label in {"0", "1", "2"}:
            label = LABELS[int(label)]
        if len(text) < 3 or label not in LABELS:
            raise ValueError(f"Row {line}: text and an explicit negative/neutral/positive label are required. Stars are not sentiment labels.")
        cleaned = clean_unicode(text)
        # Group spelling/case/spacing and punctuation variants together.
        identity = re.sub(r"[^\w\s]", "", cleaned)
        digest = hashlib.sha256(identity.encode()).hexdigest()
        row = {**raw, "text": text, "cleaned": cleaned, "label": LABELS.index(label), "text_hash": digest, "group_id": str(raw.get("group_id", "")).strip() or digest}
        if digest in seen:
            previous = seen[digest]
            if previous["label"] != row["label"]:
                conflicts.add(digest)
            if str(previous.get("split", "")).strip() != str(row.get("split", "")).strip():
                raise ValueError("Duplicate text crosses declared splits. Resolve this leakage before training.")
            duplicates += 1
            continue
        seen[digest] = row
        rows.append(row)
    rows = [r for r in rows if r["text_hash"] not in conflicts]
    if len(rows) < 150:
        raise ValueError("At least 150 unique labeled reviews are required for this pilot; larger human-reviewed domain data is preferable.")
    partitions = split_groups(rows, seed)
    for name, group in partitions.items():
        counts = Counter(r["label"] for r in group)
        if any(counts[i] < 10 for i in range(3)):
            raise ValueError(f"{name} needs at least 10 independent reviews per sentiment class. Add data or supply a reviewed split; do not tune the test split for a better result.")
    return partitions, {"removed_duplicates": duplicates, "quarantined_conflicting_texts": len(conflicts), "split_method": "supplied grouped split" if rows[0].get("split") else "seeded 60/20/20 group split (not stratified)"}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--source", required=True, help="Dataset provenance and annotation method")
    parser.add_argument("--languages", required=True, help="Comma-separated languages actually represented in the data")
    parser.add_argument("--mode", choices=["scratch", "finetune"], default="scratch")
    parser.add_argument("--base-model", type=Path, default=Path("LSTM_train/neighborhelp_lstm_sentiment.keras"))
    parser.add_argument("--epochs", type=int, default=8)
    parser.add_argument("--batch-size", type=int, default=64)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--threads", type=int, default=2)
    parser.add_argument("--max-tokens", type=int, default=20000)
    parser.add_argument("--sequence-length", type=int, default=150)
    args = parser.parse_args(argv)
    if args.output.resolve() == args.base_model.parent.resolve() or args.output.exists():
        parser.error("Use a new output directory outside the existing model directory. Existing artifacts will not be overwritten.")
    if args.epochs < 1 or args.threads < 1:
        parser.error("epochs and threads must be positive")
    partitions, audit = load_sentiment(args.data, args.seed)
    os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")
    os.environ.setdefault("TF_NUM_INTRAOP_THREADS", str(args.threads))
    os.environ.setdefault("TF_NUM_INTEROP_THREADS", "1")
    import numpy as np
    import tensorflow as tf
    tf.keras.utils.set_random_seed(args.seed)
    tf.config.threading.set_intra_op_parallelism_threads(args.threads)
    tf.config.threading.set_inter_op_parallelism_threads(1)
    tf.config.experimental.enable_op_determinism()
    args.output.mkdir(parents=True)
    preprocessing = "unicode_v1"
    if args.mode == "finetune":
        model = tf.keras.models.load_model(args.base_model, compile=False)
        if str(model.inputs[0].dtype) != "string" or model.output_shape[-1] != 3:
            raise ValueError("Fine tuning requires a raw-string, three-class model.")
        metadata = args.base_model.with_suffix(".metadata.json")
        prior = json.loads(metadata.read_text()) if metadata.exists() else {}
        if prior and prior.get("labels") != list(LABELS):
            raise ValueError("The base model label order must be negative, neutral, positive.")
        preprocessing = prior.get("preprocessing", "legacy_ascii_v1")
        for layer in model.layers:
            layer.trainable = isinstance(layer, tf.keras.layers.Dense)
        learning_rate = 1e-4
    else:
        vectorizer = tf.keras.layers.TextVectorization(max_tokens=args.max_tokens, output_sequence_length=args.sequence_length)
        vectorizer.adapt(tf.data.Dataset.from_tensor_slices([r["cleaned"] for r in partitions["train"]]).batch(args.batch_size))
        inputs = tf.keras.Input(shape=(), dtype=tf.string)
        features = vectorizer(inputs)
        features = tf.keras.layers.Embedding(len(vectorizer.get_vocabulary()), 64, mask_zero=True)(features)
        features = tf.keras.layers.Bidirectional(tf.keras.layers.LSTM(32))(features)
        features = tf.keras.layers.Dropout(.3)(features)
        features = tf.keras.layers.Dense(32, activation="relu")(features)
        outputs = tf.keras.layers.Dense(3, activation="softmax")(features)
        model = tf.keras.Model(inputs, outputs)
        learning_rate = 1e-3
    if preprocessing == "legacy_ascii_v1":
        sys.path.insert(0, str(Path("sentiment_api").resolve()))
        from vocabulary import clean_review_text
        for rows in partitions.values():
            for row in rows:
                row["cleaned"] = clean_review_text(row["text"])
    elif preprocessing != "unicode_v1":
        raise ValueError("Unsupported base model preprocessing")
    def dataset(rows, training=False):
        ds = tf.data.Dataset.from_tensor_slices((tf.constant([r["cleaned"] for r in rows]), np.asarray([r["label"] for r in rows], dtype=np.int32)))
        if training:
            ds = ds.shuffle(len(rows), seed=args.seed, reshuffle_each_iteration=True)
        options = tf.data.Options()
        options.threading.private_threadpool_size = args.threads
        return ds.batch(args.batch_size).with_options(options).prefetch(1)
    model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate), loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    history = model.fit(dataset(partitions["train"], True), validation_data=dataset(partitions["validation"]), epochs=args.epochs,
                        callbacks=[tf.keras.callbacks.EarlyStopping(monitor="val_loss", patience=2, restore_best_weights=True), tf.keras.callbacks.CSVLogger(str(args.output / "history.csv"))], verbose=2)
    candidate_path = args.output / "model.keras"
    model.save(candidate_path)
    def evaluate(loaded, rows, cleaner):
        probabilities = []
        for i in range(0, len(rows), args.batch_size):
            batch = tf.constant([cleaner(r["text"]) for r in rows[i:i+args.batch_size]])
            probabilities.extend(loaded(batch, training=False).numpy().tolist())
        return classification_metrics([r["label"] for r in rows], probabilities)
    cleaner = clean_unicode if preprocessing == "unicode_v1" else clean_review_text
    validation = evaluate(model, partitions["validation"], cleaner)
    # Test data is consulted only after architecture, early stopping and fit are fixed.
    test = evaluate(model, partitions["test"], cleaner)
    baseline = None
    if args.base_model.exists():
        sys.path.insert(0, str(Path("sentiment_api").resolve()))
        from vocabulary import clean_review_text
        old_model = tf.keras.models.load_model(args.base_model, compile=False)
        base_meta_path = args.base_model.with_suffix(".metadata.json")
        base_meta = json.loads(base_meta_path.read_text()) if base_meta_path.exists() else {}
        base_cleaner = clean_unicode if base_meta.get("preprocessing") == "unicode_v1" else clean_review_text
        baseline = evaluate(old_model, partitions["test"], base_cleaner)
    by_source = {}
    for source in sorted({r.get("source", "unspecified") for r in partitions["test"]}):
        subset = [r for r in partitions["test"] if r.get("source", "unspecified") == source]
        by_source[source] = {"candidate": evaluate(model, subset, cleaner)}
        if baseline is not None:
            by_source[source]["existing_model"] = evaluate(old_model, subset, base_cleaner)
    by_language = {}
    for language in sorted({r.get('language','unspecified') for r in partitions['test']}):
        subset = [r for r in partitions['test'] if r.get('language','unspecified') == language]
        by_language[language] = evaluate(model, subset, cleaner)
    report = {"created_at": datetime.now(timezone.utc).isoformat(), "kind": "sentiment_training", "source": args.source, "languages": args.languages.split(","),
              "data_sha256": file_hash(args.data), "candidate_sha256": file_hash(candidate_path), "seed": args.seed, "mode": args.mode,
              "epochs_run": len(history.history["loss"]), "split_audit": audit, "partitions": partition_summary(partitions), "validation": validation, "test": test, "existing_model_test": baseline, "test_by_source": by_source, "test_by_language": by_language,
              "production_model_replaced": False, "limitations": ["Dataset metrics are not proof of performance on NeighborHelp users.", "Existing model training data is unknown; its prior overlap with a public benchmark cannot be ruled out.", "Language support requires separate human-reviewed tests in every claimed language."]}
    write_json(args.output / "metrics.json", report)
    write_json(candidate_path.with_suffix(".metadata.json"), {"labels": list(LABELS), "preprocessing": preprocessing,
               "model_version": "neighborhelp-lstm-" + report["created_at"], "data_sha256": report["data_sha256"], "source": args.source,
               "languages": report["languages"], "approved_for_production": False})
    print(json.dumps({"output": str(args.output), "test_macro_f1": test["macro_f1"], "test_accuracy": test["accuracy"], "production_model_replaced": False}), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
