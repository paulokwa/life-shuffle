$ErrorActionPreference = 'Stop'

$serviceAccountPath = Join-Path $PSScriptRoot '..\serviceAccountKey.json'
$serviceAccountPath = [System.IO.Path]::GetFullPath($serviceAccountPath)

if (-not $env:FIREBASE_SERVICE_ACCOUNT_JSON -and -not (Test-Path $serviceAccountPath)) {
  Write-Host 'Generate Firebase service account JSON and save it locally as tool/serviceAccountKey.json. Do not commit it.'
  exit 1
}

git check-ignore -q 'tool/serviceAccountKey.json'
if ($LASTEXITCODE -ne 0) {
  Write-Error 'tool/serviceAccountKey.json is not gitignored. Add it to .gitignore before saving credentials there.'
}

Write-Host 'tool/serviceAccountKey.json is gitignored.'
Write-Host 'Running Firestore calendar diagnostic...'
node 'tool/diagnostics/check_firestore_calendar.js'
if ($LASTEXITCODE -ne 0) {
  Write-Error 'Firestore calendar diagnostic failed.'
}
