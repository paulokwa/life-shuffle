$ErrorActionPreference = 'Stop'

$projectId = 'life-shuffle-8d3bd'
$rulesPath = 'firestore.rules'

Write-Host "Checking local Firestore rules deployment prerequisites for project $projectId..."

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  Write-Error 'Firebase CLI was not found. Install it with: npm install -g firebase-tools'
}

$firebaseVersion = (& firebase --version)
if ($LASTEXITCODE -ne 0) {
  Write-Error 'Firebase CLI version check failed. Reinstall or repair firebase-tools.'
}

if (-not (Test-Path $rulesPath)) {
  Write-Error "Missing $rulesPath. Run this script from the repo root."
}

Write-Host "Firebase CLI version: $firebaseVersion"
Write-Host "Found $rulesPath."
Write-Host ''
Write-Host 'This check script does NOT deploy Firestore rules.'
Write-Host 'Firebase CLI does not provide a standalone local Firestore rules validation command in this project.'
Write-Host "To deploy PRODUCTION Firestore rules, run: powershell -ExecutionPolicy Bypass -File tool/diagnostics/deploy_firebase_rules.ps1"
