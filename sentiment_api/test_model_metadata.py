"""Serving must respect the preprocessing and labels used by training."""
import json
from types import SimpleNamespace

import numpy as np
import pytest
import main
from vocabulary import clean_review_text_unicode


@pytest.fixture(autouse=True)
def reset_artifact_cache():
    main.get_artifacts.cache_clear()
    yield
    main.get_artifacts.cache_clear()


def test_candidate_metadata_selects_unicode_cleaner_and_version(tmp_path,monkeypatch):
    model=tmp_path/"model.keras"
    model.write_bytes(b"stub")
    model.with_suffix(".metadata.json").write_text(json.dumps({"labels":main.LABELS,"preprocessing":"unicode_v1","model_version":"candidate-test","languages":["English","Tagalog/Taglish"],"approved_for_production":False}))
    monkeypatch.setattr(main,"MODEL_PATH",model)
    monkeypatch.delenv("SENTIMENT_MODEL_VERSION",raising=False)
    monkeypatch.setattr(main.tf.keras.models,"load_model",lambda *args,**kwargs:SimpleNamespace(inputs=[SimpleNamespace(dtype=main.tf.string)]))
    artifacts=main.get_artifacts()
    assert artifacts.preprocessing=="unicode_v1"
    assert artifacts.model_version=="candidate-test"
    assert artifacts.approved_for_production is False
    assert "Cebuano" not in artifacts.languages


def test_reordered_labels_fail_instead_of_swapping_positive_and_negative(tmp_path,monkeypatch):
    model=tmp_path/"model.keras"
    model.write_bytes(b"stub")
    model.with_suffix(".metadata.json").write_text(json.dumps({"labels":["positive","neutral","negative"]}))
    monkeypatch.setattr(main,"MODEL_PATH",model)
    monkeypatch.setattr(main.tf.keras.models,"load_model",lambda *args,**kwargs:object())
    with pytest.raises(RuntimeError,match="label order"):
        main.get_artifacts()


def test_training_and_serving_unicode_cleaners_match():
    from ml.sentiment_train import clean_unicode
    samples=["Maayo ang Niño! https://example.test", " Hindi   maganda ang trabaho. ", "👍 Salamat po!"]
    assert [clean_unicode(s) for s in samples]==[clean_review_text_unicode(s) for s in samples]


def test_invalid_probabilities_fail_closed():
    model=SimpleNamespace(predict=lambda *args,**kwargs:np.array([[np.nan,.2,.8]]))
    with pytest.raises(RuntimeError):
        main.predict_probabilities(model,np.array(["Review"]))


def test_linear_metadata_loads_a_trusted_three_class_pipeline(tmp_path,monkeypatch):
    import joblib
    from sklearn.pipeline import make_pipeline
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.linear_model import LogisticRegression
    pipeline=make_pipeline(TfidfVectorizer(),LogisticRegression()).fit(["bad job","terrible work","ordinary update","scheduled today","great work","excellent job"],[0,0,1,1,2,2])
    model=tmp_path/"model.joblib"
    joblib.dump(pipeline,model)
    model.with_suffix(".metadata.json").write_text(json.dumps({"labels":main.LABELS,"model_family":"tfidf_logistic","preprocessing":"unicode_v1","model_version":"linear-test"}))
    monkeypatch.setattr(main,"MODEL_PATH",model)
    assert main.get_artifacts().model_family=="tfidf_logistic"
