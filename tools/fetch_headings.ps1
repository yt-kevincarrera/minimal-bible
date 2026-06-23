$ErrorActionPreference = 'Stop'
$trans = 'spa_onbv'
$base = "https://bible.helloao.org/api/$trans"

function Get-JsonUtf8($url) {
  $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30
  $text = [System.Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray())
  return $text | ConvertFrom-Json
}

$books = (Get-JsonUtf8 "$base/books.json")
$result = [ordered]@{}
$totalHeadings = 0

foreach ($b in $books.books) {
  $order = $b.order
  $nChap = $b.numberOfChapters
  for ($c = 1; $c -le $nChap; $c++) {
    $ok = $false
    for ($try = 0; $try -lt 5 -and -not $ok; $try++) {
      try {
        $j = Get-JsonUtf8 "$base/$($b.id)/$c.json"
        $pendingTitles = @()
        foreach ($item in $j.chapter.content) {
          if ($item.type -eq 'heading') {
            $pendingTitles += ($item.content -join ' ').Trim()
          } elseif ($item.type -eq 'verse') {
            if ($pendingTitles.Count -gt 0) {
              $title = ($pendingTitles -join ' · ')
              if (-not $result.Contains("$order")) { $result["$order"] = [ordered]@{} }
              if (-not $result["$order"].Contains("$c")) { $result["$order"]["$c"] = [ordered]@{} }
              $result["$order"]["$c"]["$($item.number)"] = $title
              $totalHeadings++
              $pendingTitles = @()
            }
          }
        }
        $ok = $true
      } catch {
        Start-Sleep -Milliseconds 600
      }
    }
    if (-not $ok) { Write-Host "FAIL $($b.id) $c" }
  }
  Write-Host "done $($b.id) ($order/66) headings so far: $totalHeadings"
}

$json = $result | ConvertTo-Json -Depth 6 -Compress
$path = (Resolve-Path .).Path + "\assets\data\headings.json"
[System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "WROTE $path  total headings: $totalHeadings  size: $($json.Length)"
