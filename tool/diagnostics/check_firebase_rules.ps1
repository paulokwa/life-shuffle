$ErrorActionPreference = 'Stop'

$projectId = 'life-shuffle-8d3bd'

Write-Host "Checking Firebase access for project $projectId..."
& firebase projects:list
if ($LASTEXITCODE -ne 0) {
  Write-Error 'Firebase project listing failed. Run: firebase login'
}

Write-Host "Deploying Firestore rules to $projectId..."
& firebase deploy --only firestore:rules --project $projectId
if ($LASTEXITCODE -ne 0) {
  Write-Error 'Firestore rules deploy failed. Review Firebase CLI output above.'
}

Write-Host 'Firestore rules deploy completed successfully.'
