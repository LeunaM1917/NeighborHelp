# Run the LSTM sentiment API locally (loads model from LSTM_train/).
Set-Location $PSScriptRoot\..\sentiment_api
if (-not (Test-Path .venv\Scripts\Activate.ps1)) {
  python -m venv .venv
  .venv\Scripts\pip.exe install -r requirements.txt
}
. .venv\Scripts\Activate.ps1
Write-Host "Sentiment API: http://localhost:8000  (health: /health)"
uvicorn main:app --host 0.0.0.0 --port 8000
