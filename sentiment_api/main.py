import logging
import os
from functools import lru_cache
from pathlib import Path
from typing import Dict, List, Literal, Optional

import numpy as np
import tensorflow as tf
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, field_validator
from tensorflow.keras.preprocessing.sequence import pad_sequences

from vocabulary import clean_review_text, load_vocabulary_index, text_to_sequence


logger = logging.getLogger("neighborhelp-sentiment")
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)

_REPO_ROOT = Path(__file__).resolve().parent.parent
_DEFAULT_MODEL = _REPO_ROOT / "LSTM_train" / "neighborhelp_lstm_sentiment.keras"
_DEFAULT_VOCAB = _REPO_ROOT / "LSTM_train" / "vocabulary.json"

MODEL_PATH = Path(os.getenv("SENTIMENT_MODEL_PATH", str(_DEFAULT_MODEL)))
VOCABULARY_PATH = Path(os.getenv("SENTIMENT_VOCABULARY_PATH", str(_DEFAULT_VOCAB)))
TOKENIZER_PATH = Path(os.getenv("SENTIMENT_TOKENIZER_PATH", "tokenizer.json"))
MAX_SEQUENCE_LENGTH = int(os.getenv("SENTIMENT_MAXLEN", "120"))

LABELS: List[str] = ["negative", "neutral", "positive"]
Label = Literal["negative", "neutral", "positive"]


class PredictSentimentRequest(BaseModel):
    review_text: str = Field(..., min_length=3, max_length=5000, description="Raw user review text")
    review_id: Optional[str] = Field(default=None, description="Optional review document ID for traceability")
    provider_id: Optional[str] = Field(default=None, description="Optional provider ID for analytics routing")

    @field_validator("review_text")
    @classmethod
    def not_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("review_text cannot be empty or whitespace only")
        return value


class PredictSentimentResponse(BaseModel):
    sentiment: Label
    confidence: float
    probabilities: Dict[Label, float]
    cleaned_text: str
    review_id: Optional[str] = None
    provider_id: Optional[str] = None
    model_version: str


class SentimentArtifacts(BaseModel):
    model: object
    word_index: Optional[Dict[str, int]]
    model_version: str

    class Config:
        arbitrary_types_allowed = True


def model_accepts_raw_text(model: tf.keras.Model) -> bool:
    try:
        input_dtype = model.inputs[0].dtype
        return input_dtype == tf.string
    except Exception:
        return False


def load_tokenizer(tokenizer_path: Path):
    if not tokenizer_path.exists():
        return None
    payload = tokenizer_path.read_text(encoding="utf-8")
    return tf.keras.preprocessing.text.tokenizer_from_json(payload)


def preprocess_for_model(
    model: tf.keras.Model,
    word_index: Optional[Dict[str, int]],
    tokenizer,
    cleaned_text: str,
) -> np.ndarray:
    if model_accepts_raw_text(model):
        return np.array([cleaned_text], dtype=object)

    if tokenizer is not None:
        seq = tokenizer.texts_to_sequences([cleaned_text])
        padded = pad_sequences(seq, maxlen=MAX_SEQUENCE_LENGTH, padding="post", truncating="post")
        return padded.astype(np.int32)

    if word_index is not None:
        seq = text_to_sequence(cleaned_text, word_index)
        padded = pad_sequences([seq], maxlen=MAX_SEQUENCE_LENGTH, padding="post", truncating="post")
        return padded.astype(np.int32)

    raise RuntimeError(
        "Model expects tokenized sequences but no vocabulary/tokenizer was found. "
        f"Set SENTIMENT_VOCABULARY_PATH or SENTIMENT_TOKENIZER_PATH."
    )


@lru_cache(maxsize=1)
def get_artifacts() -> SentimentArtifacts:
    if not MODEL_PATH.exists():
        raise RuntimeError(
            f"Model file not found at '{MODEL_PATH}'. "
            "Set SENTIMENT_MODEL_PATH to neighborhelp_lstm_sentiment.keras location."
        )

    logger.info("Loading sentiment model from %s", MODEL_PATH)
    model = tf.keras.models.load_model(MODEL_PATH, compile=False)

    word_index = None
    if VOCABULARY_PATH.exists():
        word_index = load_vocabulary_index(VOCABULARY_PATH)
        logger.info("Loaded vocabulary (%d tokens) from %s", len(word_index), VOCABULARY_PATH)
    elif TOKENIZER_PATH.exists():
        logger.info("Using tokenizer.json at %s", TOKENIZER_PATH)
    elif not model_accepts_raw_text(model):
        raise RuntimeError(
            f"Numeric-input model requires vocabulary at '{VOCABULARY_PATH}' or tokenizer.json."
        )

    version = os.getenv("SENTIMENT_MODEL_VERSION") or MODEL_PATH.name
    logger.info(
        "Sentiment model loaded. raw_text_input=%s vocab=%s",
        model_accepts_raw_text(model),
        word_index is not None,
    )

    return SentimentArtifacts(model=model, word_index=word_index, model_version=version)


def predict_probabilities(model: tf.keras.Model, features: np.ndarray) -> np.ndarray:
    preds = model.predict(features, verbose=0)
    probs = np.array(preds[0], dtype=np.float32).flatten()

    if probs.size == 1:
        p_pos = float(probs[0])
        p_neg = 1.0 - p_pos
        probs = np.array([p_neg, 0.0, p_pos], dtype=np.float32)
    elif probs.size != 3:
        raise RuntimeError(f"Unexpected model output size: {probs.size}. Expected 3 classes.")

    total = float(np.sum(probs))
    if total <= 0:
        raise RuntimeError("Model returned non-positive probability sum.")
    return probs / total


app = FastAPI(
    title="NeighborHelp Sentiment API",
    version="1.0.0",
    description="LSTM sentiment inference API for NeighborHelp reviews.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ALLOW_ORIGINS", "*").split(","),
    allow_credentials=True,
    allow_methods=["POST", "GET", "OPTIONS"],
    allow_headers=["*"],
)


@app.on_event("startup")
def warmup_model() -> None:
    try:
        get_artifacts()
    except Exception as exc:
        logger.exception("Failed to load sentiment artifacts: %s", exc)


@app.get("/health")
def health() -> Dict[str, str]:
    try:
        artifacts = get_artifacts()
        return {"status": "ok", "model_version": artifacts.model_version}
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Model unavailable: {exc}") from exc


@app.post("/predict-sentiment", response_model=PredictSentimentResponse)
def predict_sentiment(payload: PredictSentimentRequest) -> PredictSentimentResponse:
    try:
        artifacts = get_artifacts()
        cleaned = clean_review_text(payload.review_text)
        if len(cleaned) < 2:
            raise HTTPException(status_code=400, detail="review_text too short after cleaning")
        tokenizer = load_tokenizer(TOKENIZER_PATH) if TOKENIZER_PATH.exists() else None
        features = preprocess_for_model(artifacts.model, artifacts.word_index, tokenizer, cleaned)
        probs = predict_probabilities(artifacts.model, features)
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Prediction failed: %s", exc)
        raise HTTPException(status_code=500, detail=f"Prediction failed: {exc}") from exc

    idx = int(np.argmax(probs))
    sentiment = LABELS[idx]
    confidence = float(probs[idx])
    probabilities: Dict[Label, float] = {
        "negative": float(probs[0]),
        "neutral": float(probs[1]),
        "positive": float(probs[2]),
    }

    return PredictSentimentResponse(
        sentiment=sentiment,  # type: ignore[arg-type]
        confidence=confidence,
        probabilities=probabilities,
        cleaned_text=cleaned,
        review_id=payload.review_id,
        provider_id=payload.provider_id,
        model_version=artifacts.model_version,
    )
