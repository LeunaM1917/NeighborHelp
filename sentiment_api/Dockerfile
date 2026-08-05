FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    SENTIMENT_MODEL_PATH=/models/neighborhelp_lstm_sentiment.keras \
    SENTIMENT_VOCABULARY_PATH=/models/vocabulary.json \
    SENTIMENT_MODEL_VERSION=neighborhelp_lstm_sentiment.keras

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY sentiment_api/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY sentiment_api/main.py sentiment_api/vocabulary.py /app/
COPY LSTM_train/neighborhelp_lstm_sentiment.keras LSTM_train/vocabulary.json /models/

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
