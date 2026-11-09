"""Fit constrained P/R/A/C weights from independently graded provider matches."""
from __future__ import annotations

import argparse
import hashlib
import math
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

import numpy as np

from ml.common import file_hash, read_rows, split_groups, write_json

FEATURES = ("proximity", "rating", "availability", "completion")
BASELINE = np.array([.4, .3, .2, .1], dtype=float)
GATES = ("identity_verified", "certificate_verified", "account_active", "service_matches")


def boolean(value, field):
    value = str(value).strip().lower()
    if value not in {"true", "false", "1", "0"}:
        raise ValueError(f"{field} must explicitly be true or false.")
    return value in {"true", "1"}


def features(row):
    def number(name, low=0, high=float("inf")):
        value = float(row[name])
        if not math.isfinite(value) or not low <= value <= high:
            raise ValueError(f"Invalid {name}")
        return value
    distance = number("distance_km")
    search_radius, service_radius = number("max_search_radius_km", .001), number("service_radius_km", .001)
    rating = number("bayesian_rating", 0, 5)
    review_count = number("review_count")
    completed, accepted = number("completed_bookings"), number("accepted_bookings")
    if completed > accepted or any(x != int(x) for x in [review_count, completed, accepted]):
        raise ValueError("Booking/review counts must be whole, with completed no larger than accepted.")
    gates = [boolean(row[name], name) for name in GATES]
    eligible = all(gates) and distance <= search_radius and distance <= service_radius
    return np.array([max(0., 1 - distance / search_radius), (3.5 if review_count <= 0 else rating) / 5,
                     float(boolean(row["available"], "available")), .5 if accepted < 3 else completed / accepted]), eligible


def load_ranking(path, seed):
    rows, pairs, queries = [], set(), defaultdict(list)
    for line, raw in enumerate(read_rows(path), 2):
        if not raw.get("query_id") or not raw.get("provider_id") or not raw.get("label_source"):
            raise ValueError(f"Row {line}: query_id, provider_id and label_source are required.")
        if str(raw.get("relevance", "")).strip() not in {"0", "1", "2", "3"}:
            raise ValueError(f"Row {line}: human relevance grade 0–3 is missing. Unlabeled examples are not training data.")
        key = (raw["query_id"], raw["provider_id"])
        if key in pairs:
            raise ValueError("Duplicate query/provider pair")
        pairs.add(key)
        vector, eligible = features(raw)
        row = {**raw, "x": vector, "eligible": eligible, "label": int(raw["relevance"]), "group_id": raw.get("group_id") or raw["query_id"]}
        if not eligible and row["label"] != 0:
            raise ValueError("Ineligible providers must have relevance 0; eligibility cannot be learned away.")
        rows.append(row)
        queries[row["query_id"]].append(row)
    for query in queries.values():
        if len(query) < 2 or len({r["group_id"] for r in query}) != 1:
            raise ValueError("Each query needs at least two providers within the same split group.")
    partitions = split_groups(rows, seed)
    if any(len({r["query_id"] for r in group}) < 3 for group in partitions.values()):
        raise ValueError("At least three independent requests are needed in each split; collect at least 15 labeled requests for a pilot.")
    return partitions


def grouped(rows):
    result = defaultdict(list)
    for row in rows:
        result[row["query_id"]].append(row)
    return result


def pairwise_differences(rows):
    differences = []
    for query in grouped(rows).values():
        eligible = [r for r in query if r["eligible"]]
        for left in eligible:
            for right in eligible:
                if left["label"] > right["label"]:
                    differences.append(left["x"] - right["x"])
    if not differences:
        raise ValueError("Training needs relative preference judgments among eligible providers, not only exclusions or ties.")
    return np.array(differences)


def project_weights(values):
    # Projection onto sum(w)=1 with 5–75% bounds preserves all four factors.
    lower, upper = float(min(values) - 1), float(max(values) + 1)
    for _ in range(70):
        middle = (lower + upper) / 2
        projected = np.clip(values - middle, .05, .75)
        if projected.sum() > 1:
            lower = middle
        else:
            upper = middle
    return np.clip(values - (lower + upper) / 2, .05, .75)


def fit(differences, regularization, iterations=1500):
    weights = BASELINE.copy()
    for step in range(iterations):
        margin = np.clip(8 * differences @ weights, -50, 50)
        gradient = (-8 * differences / (1 + np.exp(margin))[:, None]).mean(axis=0) + 2 * regularization * (weights - BASELINE)
        candidate = project_weights(weights - .1 / math.sqrt(1 + step / 100) * gradient)
        if np.max(abs(candidate - weights)) < 1e-9:
            break
        weights = candidate
    return weights


def ranking_metrics(rows, weights):
    ndcg, agreement, top_quality = [], [], []
    empty_queries = 0
    for query in grouped(rows).values():
        candidates = [r for r in query if r["eligible"]]
        if not candidates:
            empty_queries += 1
            continue
        # Provider id is only a deterministic offline tie break; it is not a feature.
        ranked = sorted(candidates, key=lambda r: (-float(r["x"] @ weights), r["provider_id"]))
        ideal = sorted((r["label"] for r in candidates), reverse=True)[:5]
        dcg = lambda labels: sum((2 ** grade - 1) / math.log2(i + 2) for i, grade in enumerate(labels))
        denominator = dcg(ideal)
        if denominator > 0:
            ndcg.append(dcg([r["label"] for r in ranked[:5]]) / denominator)
        maximum = max(r["label"] for r in candidates)
        if maximum > 0:
            top_quality.append(ranked[0]["label"] == maximum)
        for left in candidates:
            for right in candidates:
                if left["label"] > right["label"]:
                    difference = float((left["x"] - right["x"]) @ weights)
                    agreement.append(1. if difference > 1e-10 else .5 if abs(difference) <= 1e-10 else 0.)
    average = lambda values: float(np.mean(values)) if values else None
    return {"requests": len(grouped(rows)), "scored_requests": len(ndcg), "no_eligible_provider_requests": empty_queries,
            "ndcg_at_5": average(ndcg), "top_choice_matches_best_grade": average(top_quality), "pairwise_agreement": average(agreement)}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args(argv)
    if args.output.exists():
        parser.error("Use a new output directory; prior experiments will not be overwritten.")
    partitions = load_ranking(args.data, args.seed)
    differences = pairwise_differences(partitions["train"])
    trials = []
    for penalty in [0., .01, .1, 1.]:
        weights = fit(differences, penalty)
        metrics = ranking_metrics(partitions["validation"], weights)
        if metrics["ndcg_at_5"] is None:
            raise ValueError("Validation requests need at least one relevant eligible provider.")
        trials.append((metrics["ndcg_at_5"], -float(np.linalg.norm(weights - BASELINE)), penalty, weights, metrics))
    chosen = max(trials, key=lambda t: t[:2])
    weights = chosen[3]
    baseline_validation = ranking_metrics(partitions["validation"], BASELINE)
    meaningful_gain = chosen[0] > (baseline_validation["ndcg_at_5"] or 0) + .01
    # The held-out test set is evaluated only after selection on validation.
    baseline_test, candidate_test = ranking_metrics(partitions["test"], BASELINE), ranking_metrics(partitions["test"], weights)
    args.output.mkdir(parents=True)
    report = {"created_at": datetime.now(timezone.utc).isoformat(), "kind": "provider_ranking_training", "data_sha256": file_hash(args.data), "seed": args.seed,
              "features": list(FEATURES), "baseline_weights": dict(zip(FEATURES, BASELINE.tolist())), "candidate_weights": dict(zip(FEATURES, weights.tolist())),
              "training_pairs": len(differences), "partition_requests": {k: len(grouped(v)) for k, v in partitions.items()},
              "validation": {"baseline": baseline_validation, "candidate": chosen[4], "regularization": chosen[2]},
              "test": {"baseline": baseline_test, "candidate": candidate_test}, "validation_gain_over_one_percentage_point": meaningful_gain,
              "production_weights_changed": False, "requires_domain_review": True,
              "limitations": ["Grades must come from independent human judgments or valid pre-outcome historical snapshots.", "An improved benchmark does not guarantee better live service outcomes.", "App near-tie randomization is excluded from deterministic offline NDCG scoring."]}
    write_json(args.output / "metrics.json", report)
    write_json(args.output / "weights.json", {"version": 1, "weights": report["candidate_weights"], "feature_schema": "neighborhelp-prac-v1", "approved_for_production": False})
    print(args.output / "metrics.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
