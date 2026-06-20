param(
  [Parameter(Mandatory = $true)]
  [string]$FeedUrl
)

$ErrorActionPreference = 'Stop'

try {
  $response = Invoke-WebRequest -Uri $FeedUrl -UseBasicParsing -TimeoutSec 30
  $statusCode = [int]$response.StatusCode
  $contentType = $response.Headers['Content-Type']
  $body = [string]$response.Content

  Write-Host "HTTP status: $statusCode"
  Write-Host "Content-Type: $contentType"
  Write-Host "Contains BEGIN:VCALENDAR: $($body.Contains('BEGIN:VCALENDAR'))"
  Write-Host "Contains END:VCALENDAR: $($body.Contains('END:VCALENDAR'))"
} catch {
  $response = $_.Exception.Response
  if ($response -and $response.StatusCode) {
    $statusCode = [int]$response.StatusCode
    Write-Host "HTTP status: $statusCode"
    Write-Host "Content-Type: $($response.ContentType)"

    $body = ''
    try {
      $stream = $response.GetResponseStream()
      if ($stream) {
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()
      }
    } catch {
      $body = ''
    }

    Write-Host "Contains BEGIN:VCALENDAR: $($body.Contains('BEGIN:VCALENDAR'))"
    Write-Host "Contains END:VCALENDAR: $($body.Contains('END:VCALENDAR'))"
    if ($statusCode -eq 404 -or $statusCode -eq 500) {
      Write-Host 'Response body:'
      Write-Host $body
    }
  } else {
    Write-Error "ICS feed request failed: $($_.Exception.Message)"
  }
}
