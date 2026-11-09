"""Train an independent word/character TF-IDF comparison model."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import sklearn
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import FeatureUnion, Pipeline
from threadpoolctl import threadpool_limits

from ml.common import LABELS, classification_metrics, file_hash, partition_summary, write_json
from ml.sentiment_train import load_sentiment


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source", required=True)
    parser.add_argument("--languages", required=True)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args(argv)
    if args.output.exists():
        parser.error("Use a fresh output directory.")
    data, audit = load_sentiment(args.data, args.seed)
    vectors = FeatureUnion([
        ("word", TfidfVectorizer(ngram_range=(1,2), min_df=2, max_features=60000, sublinear_tf=True)),
        ("character", TfidfVectorizer(analyzer="char_wb", ngram_range=(3,5), min_df=2, max_features=60000, sublinear_tf=True)),
    ], transformer_weights={"word":1.,"character":.7})
    train = vectors.fit_transform([r["cleaned"] for r in data["train"]])
    validation = vectors.transform([r["cleaned"] for r in data["validation"]])
    y_train = [r["label"] for r in data["train"]]
    y_validation = [r["label"] for r in data["validation"]]
    trials=[]
    with threadpool_limits(limits=2):
        for strength in [.25, 1., 4., 16.]:
            classifier=LogisticRegression(C=strength, max_iter=1000, class_weight="balanced", random_state=args.seed)
            classifier.fit(train,y_train)
            result=classification_metrics(y_validation,classifier.predict_proba(validation))
            trials.append((result["macro_f1"],-strength,classifier,result))
            print(f"C={strength}: validation macro F1={result['macro_f1']:.4f}",flush=True)
    chosen=max(trials,key=lambda t:t[:2])
    pipeline=Pipeline([("features",vectors),("classifier",chosen[2])])
    test=classification_metrics([r["label"] for r in data["test"]],pipeline.predict_proba([r["cleaned"] for r in data["test"]]))
    by_source={}
    for source in sorted({r.get("source","unspecified") for r in data["test"]}):
        subset=[r for r in data["test"] if r.get("source","unspecified")==source]
        by_source[source]=classification_metrics([r["label"] for r in subset],pipeline.predict_proba([r["cleaned"] for r in subset]))
    by_language={}
    for language in sorted({r.get('language','unspecified') for r in data['test']}):
        subset=[r for r in data['test'] if r.get('language','unspecified')==language]
        by_language[language]=classification_metrics([r['label'] for r in subset],pipeline.predict_proba([r['cleaned'] for r in subset]))
    args.output.mkdir(parents=True)
    artifact=args.output/"model.joblib"
    joblib.dump(pipeline,artifact,compress=3)
    version="neighborhelp-tfidf-"+datetime.now(timezone.utc).isoformat()
    write_json(artifact.with_suffix(".metadata.json"),{"model_family":"tfidf_logistic","labels":list(LABELS),"preprocessing":"unicode_v1","model_version":version,
               "source":args.source,"data_sha256":file_hash(args.data),"languages":args.languages.split(","),"approved_for_production":False,"sklearn_version":sklearn.__version__})
    write_json(args.output/"metrics.json",{"kind":"sentiment_training","model_family":"tfidf_logistic","created_at":datetime.now(timezone.utc).isoformat(),"source":args.source,
               "languages":args.languages.split(","),"data_sha256":file_hash(args.data),"candidate_sha256":file_hash(artifact),"seed":args.seed,"partitions":partition_summary(data),
               "split_audit":audit,"validation":chosen[3],"selected_C":-chosen[1],"test":test,"test_by_source":by_source,"test_by_language":by_language,"production_model_replaced":False,
               "software":{"scikit_learn":sklearn.__version__,"numpy":np.__version__},"limitations":["Language names alone do not establish deployment performance; review separate per-language results and sample coverage.","Public benchmark reviews do not establish NeighborHelp service-domain accuracy.","Use a fresh held-out local set; previously examined test partitions are not new validation evidence."]})
    print(f"Test accuracy={test['accuracy']:.4f}; macro F1={test['macro_f1']:.4f}. Production unchanged.",flush=True)
    return 0


if __name__=="__main__":
    raise SystemExit(main())
