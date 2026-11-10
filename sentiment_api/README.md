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

## 2) Connect Firebase Functions

Use a deployed HTTPS service URL in `functions/.env`. `http://localhost:8000` is only for locally running Functions emulators; deployed functions cannot reach your computer through localhost.

```env
SENTIMENT_API_URL=https://YOUR-CLOUD-RUN-URL
SENTIMENT_API_TIMEOUT_MS=30000
```

From the repository root, deploy the two review functions:

```powershell
firebase deploy --only "functions:submitMilestoneReview,functions:onReviewCreated" --project neighborhelp-63771
```

`submitMilestoneReview` analyzes submitted review comments. `onReviewCreated` analyzes reviews that do not already have a saved result. They store `sentiment.label`, `confidence`, `probabilities`, `modelVersion`, `analyzedAt`, and `source` on the Firestore review. A successful model response has source `lstm`; a failed or unavailable API call uses the existing keyword fallback.

## 3) Deploy to Google Cloud Run

The service is `neighborhelp-sentiment`, in `asia-southeast1`, in Firebase project `neighborhelp-63771`. Billing must be enabled. The deployment reuses the saved model; it does not retrain it.

From the repository root, with Google Cloud CLI installed:

```powershell
gcloud auth login
gcloud config set project neighborhelp-63771
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\deploy-sentiment-cloudrun.ps1
```

The script builds in Cloud Build and publishes to Artifact Registry, so local Docker is not required. `.gcloudignore` restricts the source upload to the API and saved model. `.dockerignore` restricts the container build context. Keep these exclusions in place; local environment files, application secrets, datasets and test artifacts are excluded.

The Docker image uses Python 3.13 and the tested runtime versions in `requirements.production.txt`. It runs with one CPU and 2 GiB memory. The script caps instances at three and permits scaling to zero. Stop if any build or deployment command fails; the script must not report success after an unsuccessful native command.

After deployment, set the resulting HTTPS URL in `functions/.env` and deploy the two review functions using section 2. Do not commit `.env`.

Verify the running model:

```powershell
$sentimentUrl = 'https://YOUR-CLOUD-RUN-URL'
Invoke-RestMethod "$sentimentUrl/health"
$review = @{ review_text = 'Great service, very professional and on time!' } | ConvertTo-Json
Invoke-RestMethod "$sentimentUrl/predict-sentiment" -Method Post -ContentType 'application/json' -Body $review
```

Health must report `status: ok`; predictions must report `model_family: lstm`. Verify positive and negative examples and retain the deployed model version. A label displayed by the app alone does not prove the model was reached, because fallback classification is supported. Check the saved review's `sentiment.source` when testing a review through the application.

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
