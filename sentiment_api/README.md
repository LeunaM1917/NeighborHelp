# NeighborHelp Sentiment API (LSTM)

FastAPI service using the trained model in `../LSTM_train/`:

- `neighborhelp_lstm_sentiment.keras`
- `vocabulary.json` (fallback if the model expects token ids)

Endpoints:

- `GET /health`
- `POST /predict-sentiment`

Cloud Functions (`onReviewCreated`) call this API when `SENTIMENT_API_URL` is set, then write `sentiment` back onto the Firestore review doc. The Flutter app already shows sentiment chips on review tiles.

## 1) Install & run locally

```powershell
cd d:\NeighborHelp\sentiment_api
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

Health check:

```powershell
curl http://localhost:8000/health
```

Predict:

```powershell
curl -X POST "http://localhost:8000/predict-sentiment" `
  -H "Content-Type: application/json" `
  -d "{\"review_text\":\"Great service, very professional and on time!\"}"
```

Run smoke tests:

```powershell
pip install httpx pytest
pytest test_sentiment.py -q
```

## 2) Wire Firebase Functions

Add to `functions/.env` (then redeploy functions):

```env
SENTIMENT_API_URL=http://localhost:8000
# Or your Cloud Run URL, e.g. https://neighborhelp-sentiment-xxxxx-uc.a.run.app
SENTIMENT_API_TIMEOUT_MS=15000
```

Deploy:

```powershell
cd d:\NeighborHelp
firebase deploy --only functions
```

When a review with a comment is created, `onReviewCreated` calls `/predict-sentiment` and stores:

- `sentiment.label` — `negative` | `neutral` | `positive`
- `sentiment.confidence`
- `sentiment.probabilities`
- `sentiment.modelVersion`
- `sentiment.analyzedAt`
- `sentiment.source` — `lstm`

## 3) Deploy to Google Cloud Run (production)

From repo root (`d:\NeighborHelp`):

```powershell
gcloud auth login
gcloud config set project neighborhelp-63771

docker build -f sentiment_api/Dockerfile -t neighborhelp-sentiment .

docker tag neighborhelp-sentiment gcr.io/neighborhelp-63771/neighborhelp-sentiment
docker push gcr.io/neighborhelp-63771/neighborhelp-sentiment

gcloud run deploy neighborhelp-sentiment `
  --image gcr.io/neighborhelp-63771/neighborhelp-sentiment `
  --platform managed `
  --region asia-southeast1 `
  --allow-unauthenticated `
  --memory 2Gi `
  --cpu 1 `
  --timeout 60 `
  --min-instances 0 `
  --max-instances 3
```

Copy the service URL into `functions/.env`:

```env
SENTIMENT_API_URL=https://YOUR-CLOUD-RUN-URL
```

Redeploy functions:

```powershell
firebase deploy --only functions
```

## Environment variables

| Variable | Default |
|----------|---------|
| `SENTIMENT_MODEL_PATH` | `../LSTM_train/neighborhelp_lstm_sentiment.keras` |
| `SENTIMENT_VOCABULARY_PATH` | `../LSTM_train/vocabulary.json` |
| `SENTIMENT_TOKENIZER_PATH` | `tokenizer.json` (optional Keras tokenizer export) |
| `SENTIMENT_MAXLEN` | `120` |
| `SENTIMENT_MODEL_VERSION` | model filename |
| `CORS_ALLOW_ORIGINS` | `*` |
| `LOG_LEVEL` | `INFO` |

## Model notes

The exported Keras model accepts **raw cleaned strings** (TextVectorization baked in). `vocabulary.json` is kept for compatibility if you re-export a numeric-input model later.
