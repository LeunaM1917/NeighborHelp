# Deploy sentiment API to Google Cloud Run WITHOUT local Docker.
# Builds the container in Google Cloud (Cloud Build).

$ErrorActionPreference = "Stop"
$Project = "neighborhelp-63771"
$Region = "asia-southeast1"
$Service = "neighborhelp-sentiment"
$Image = "$Region-docker.pkg.dev/$Project/cloud-run-source-deploy/$Service"

Set-Location $PSScriptRoot\..

function Test-Command($name) {
  return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

if (-not (Test-Command gcloud)) {
  Write-Host ""
  Write-Host "Google Cloud SDK (gcloud) is not installed." -ForegroundColor Red
  Write-Host ""
  Write-Host "Option A - Deploy to Cloud Run (production, no local Docker):" -ForegroundColor Yellow
  Write-Host "  1. Install: https://cloud.google.com/sdk/docs/install"
  Write-Host "  2. Re-run: .\scripts\deploy-sentiment-cloudrun.ps1"
  Write-Host ""
  Write-Host "Option B - Test locally only (no Cloud Run):" -ForegroundColor Yellow
  Write-Host "  1. Run: .\scripts\run-sentiment-api.ps1"
  Write-Host "  2. Use Firebase emulators: firebase emulators:start --only functions,firestore"
  Write-Host ""
  exit 1
}

if (-not (Test-Path "LSTM_train\neighborhelp_lstm_sentiment.keras")) {
  Write-Host "Missing LSTM_train\neighborhelp_lstm_sentiment.keras" -ForegroundColor Red
  exit 1
}

Write-Host "Enabling required Google Cloud APIs..."
gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com `
  --project $Project
if ($LASTEXITCODE -ne 0) { throw "Could not enable the required Google Cloud APIs." }

Write-Host "Ensuring Artifact Registry repo exists..."
gcloud artifacts repositories describe cloud-run-source-deploy `
  --location $Region --project $Project 2>$null
if ($LASTEXITCODE -ne 0) {
  gcloud artifacts repositories create cloud-run-source-deploy `
    --repository-format docker `
    --location $Region `
    --project $Project `
    --description "Cloud Run source deploy images"
  if ($LASTEXITCODE -ne 0) { throw "Could not create the sentiment image repository." }
}

Write-Host "Building image in Google Cloud (no local Docker needed)..."
gcloud builds submit . `
  --project $Project `
  --config cloudbuild-sentiment.yaml `
  --substitutions=_IMAGE_NAME=$Image `
  --timeout 1200
if ($LASTEXITCODE -ne 0) { throw "Sentiment image build failed; the current live service was not updated." }

Write-Host "Deploying to Cloud Run..."
gcloud run deploy $Service `
  --image $Image `
  --platform managed `
  --region $Region `
  --project $Project `
  --allow-unauthenticated `
  --memory 2Gi `
  --cpu 1 `
  --timeout 60 `
  --min-instances 0 `
  --max-instances 3
if ($LASTEXITCODE -ne 0) { throw "Cloud Run deployment failed." }

$Url = gcloud run services describe $Service --region $Region --project $Project --format "value(status.url)"
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($Url)) { throw "Could not verify the deployed service URL." }

Write-Host ""
Write-Host "Deployed successfully!" -ForegroundColor Green
Write-Host "Service URL: $Url"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Open functions\.env and set SENTIMENT_API_URL to the URL above"
Write-Host "  2. Run: firebase deploy --only functions"
Write-Host ""
