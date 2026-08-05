import json
import re
from pathlib import Path
from typing import Dict, List


def clean_review_text(text: str) -> str:
    """Keep aligned with training / inference cleaning."""
    text = text.lower()
    text = re.sub(r"http\S+|www\.\S+", " ", text)
    text = re.sub(r"[^a-z0-9\s']", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def load_vocabulary_index(vocabulary_path: Path) -> Dict[str, int]:
    payload = json.loads(vocabulary_path.read_text(encoding="utf-8"))
    if not isinstance(payload, list):
        raise ValueError("vocabulary.json must be a JSON array of tokens")
    return {word: idx for idx, word in enumerate(payload)}


def text_to_sequence(cleaned_text: str, word_index: Dict[str, int], oov_index: int = 1) -> List[int]:
    return [word_index.get(token, oov_index) for token in cleaned_text.split() if token]
