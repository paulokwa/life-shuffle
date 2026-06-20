$ErrorActionPreference = 'Stop'

function Strip-Ansi {
  param([string]$Text)
  return ($Text -replace "$([char]27)\[[0-9;?]*[ -/]*[@-~]", '')
}

Write-Host 'Checking Netlify login and linked site...'
$statusOutput = & cmd.exe /d /c "netlify status 2>&1"
if ($LASTEXITCODE -ne 0) {
  Write-Error "Netlify status failed. Run: netlify login ; netlify link"
}

$cleanStatus = Strip-Ansi (($statusOutput | Out-String))
$projectLine = ($cleanStatus -split "`r?`n") | Where-Object { $_ -match 'Current project:' } | Select-Object -First 1
if ($projectLine) {
  Write-Host ($projectLine.Trim())
} else {
  Write-Host 'Netlify status succeeded.'
}

Write-Host 'Checking Netlify environment variable names...'
$contextNames = @('production', 'deploy-preview', 'branch-deploy', 'dev')
$presence = @{
  FIREBASE_WEB_API_KEY = New-Object System.Collections.Generic.List[string]
  FIREBASE_SERVICE_ACCOUNT_JSON = New-Object System.Collections.Generic.List[string]
}

foreach ($context in $contextNames) {
  $envOutput = & cmd.exe /d /c "netlify env:list --context $context --json 2>&1"
  if ($LASTEXITCODE -ne 0) {
    Write-Error "netlify env:list failed for context '$context'. Confirm the site is linked and your account has access."
  }

  try {
    $envJson = (($envOutput | Out-String) | ConvertFrom-Json)
  } catch {
    Write-Error "Could not parse netlify env:list JSON for context '$context'."
  }

  $keys = @($envJson.PSObject.Properties.Name)
  foreach ($name in @('FIREBASE_WEB_API_KEY', 'FIREBASE_SERVICE_ACCOUNT_JSON')) {
    if ($keys -contains $name) {
      $presence[$name].Add($context)
    }
  }
}

foreach ($name in @('FIREBASE_WEB_API_KEY', 'FIREBASE_SERVICE_ACCOUNT_JSON')) {
  $contexts = @($presence[$name].ToArray())
  if ($contexts.Count -eq 0) {
    Write-Host "${name}: MISSING"
  } else {
    Write-Host "${name}: present in context(s): $($contexts -join ', ')"
  }
}

Write-Host 'Done. No secret values were printed.'
