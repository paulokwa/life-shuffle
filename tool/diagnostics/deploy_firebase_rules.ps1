$ErrorActionPreference = 'Stop'

$projectId = 'life-shuffle-8d3bd'
$rulesPath = 'firestore.rules'

Write-Warning "This script deploys PRODUCTION Firestore rules to project $projectId."
Write-Warning 'Do not run it unless the rules change has been reviewed and approved for production.'

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  Write-Error 'Firebase CLI was not found. Install it with: npm install -g firebase-tools'
}

if (-not (Test-Path $rulesPath)) {
  Write-Error "Missing $rulesPath. Run this script from the repo root."
}

Write-Host "Checking Firebase access for project $projectId..."
& firebase projects:list --non-interactive
if ($LASTEXITCODE -ne 0) {
  Write-Error 'Firebase project listing failed. Run: firebase login'
}

Write-Warning "Deploying PRODUCTION Firestore rules from $rulesPath to $projectId..."
& firebase deploy --only firestore:rules --project $projectId --non-interactive
if ($LASTEXITCODE -ne 0) {
  Write-Error 'Production Firestore rules deploy failed. Review Firebase CLI output above.'
}

Write-Host 'Production Firestore rules deploy completed successfully.'
