import csv
import math
from pathlib import Path

import numpy as np
import pytest

from ml.common import classification_metrics, split_groups
from ml.ranking_train import BASELINE, features, fit, pairwise_differences, ranking_metrics, load_ranking
from ml.sentiment_train import clean_unicode, load_sentiment


def test_groups_cannot_cross_explicit_splits():
    with pytest.raises(ValueError, match="crosses splits"):
        split_groups([{"group_id":"same","split":"train"},{"group_id":"same","split":"test"}],42)


def test_group_splits_are_repeatable_and_disjoint():
    rows=[{"group_id":str(i//2)} for i in range(100)]
    a,b=split_groups(rows,42),split_groups(rows,42)
    assert a==b
    memberships={name:{r["group_id"] for r in group} for name,group in a.items()}
    assert not memberships["train"] & memberships["test"]
    assert not memberships["validation"] & memberships["test"]
    assert sum(map(len,a.values()))==100


def test_metrics_penalize_a_missing_class_and_reject_invalid_probabilities():
    metrics=classification_metrics([0,1,2],[[1.,0.,0.]]*3)
    assert metrics["accuracy"]==pytest.approx(1/3)
    assert metrics["per_class"]["neutral"]["recall"]==0
    assert metrics["macro_f1"] < metrics["accuracy"]
    with pytest.raises(ValueError):
        classification_metrics([0],[[float("nan"),0,0]])
    with pytest.raises(ValueError):
        classification_metrics([0],[[1,1,1]])


def test_unicode_cleaning_keeps_philippine_letters_and_removes_urls():
    assert clean_unicode("  MAAYO ang Niño! https://example.test/a  ")=="maayo ang niño!"


def base_row(**patch):
    return {"distance_km":1,"max_search_radius_km":10,"service_radius_km":5,"identity_verified":"true","certificate_verified":"true","account_active":"true","service_matches":"true","available":"true","bayesian_rating":5,"review_count":0,"completed_bookings":1,"accepted_bookings":1,**patch}


def test_rank_features_match_app_cold_start_priors_and_fixed_eligibility():
    vector,eligible=features(base_row())
    assert eligible
    assert vector.tolist()==pytest.approx([.9,.7,1.,.5])
    assert not features(base_row(certificate_verified="false"))[1]
    assert not features(base_row(distance_km=6))[1]
    with pytest.raises(ValueError):
        features(base_row(completed_bookings=3,accepted_bookings=1))


def test_synthetic_fitter_check_learns_preferences_without_removing_factors():
    # Artificial preferences verify the optimizer, not real matching quality.
    rows=[]
    for i in range(5):
        for provider,available,proximity,label in [("a",0,.95,0),("b",1,.2,3)]:
            rows.append({"query_id":str(i),"provider_id":provider,"label":label,"eligible":True,"x":np.array([proximity,.7,available,.5])})
    weights=fit(pairwise_differences(rows),.01)
    assert sum(weights)==pytest.approx(1)
    assert min(weights)>=.05-1e-9 and max(weights)<=.75+1e-9
    assert weights[2]>BASELINE[2]
    assert ranking_metrics(rows,weights)["ndcg_at_5"]>ranking_metrics(rows,BASELINE)["ndcg_at_5"]


def test_unlabeled_provider_packet_is_not_silently_treated_as_training_data():
    with pytest.raises(ValueError,match="label_source"):
        load_ranking(Path("ml/labeling/provider_matches.csv"),42)


def test_duplicate_reviews_cannot_leak_across_declared_partitions(tmp_path):
    path=tmp_path/"reviews.csv"
    with path.open("w",newline="",encoding="utf-8") as stream:
        writer=csv.DictWriter(stream,fieldnames=["text","label","split"])
        writer.writeheader()
        writer.writerows([{"text":"Good work!","label":"positive","split":"train"},{"text":"good work","label":"positive","split":"test"}])
    with pytest.raises(ValueError,match="crosses declared splits"):
        load_sentiment(path,42)


def test_ranking_cli_writes_unapproved_candidates_from_synthetic_fixtures(tmp_path):
    import json
    from ml.ranking_train import main as train
    rows=[]
    for query in range(30):
        for provider,available,distance,label in [("a","false",.2,0),("b","true",3.,3),("c","true",4.,2)]:
            rows.append({**base_row(available=available,distance_km=distance),"query_id":str(query),"provider_id":provider,"relevance":label,"label_source":"synthetic_unit_test"})
    path=tmp_path/"synthetic-fixture.csv"
    with path.open("w",newline="",encoding="utf-8") as stream:
        writer=csv.DictWriter(stream,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    output=tmp_path/"run"
    assert train(["--data",str(path),"--output",str(output)])==0
    assert json.loads((output/"weights.json").read_text())["approved_for_production"] is False
    assert json.loads((output/"metrics.json").read_text())["production_weights_changed"] is False
