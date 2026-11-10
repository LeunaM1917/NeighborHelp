FROM python:3.13-slim

WORKDIR /app

ARG SENTIMENT_ARTIFACT_DIR=LSTM_train
ARG SENTIMENT_MODEL_FILENAME=neighborhelp_lstm_sentiment.keras

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TF_NUM_INTRAOP_THREADS=1 \
    TF_NUM_INTEROP_THREADS=1 \
    OMP_NUM_THREADS=1 \
    SENTIMENT_MODEL_PATH=/models/${SENTIMENT_MODEL_FILENAME} \
    SENTIMENT_VOCABULARY_PATH=/models/vocabulary.json

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY sentiment_api/requirements.production.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY sentiment_api/main.py sentiment_api/vocabulary.py /app/
COPY ${SENTIMENT_ARTIFACT_DIR}/ /models/

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
