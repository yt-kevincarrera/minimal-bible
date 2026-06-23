# Genera assets/data/rv1960.json a partir de una traducción de DOMINIO PÚBLICO
# de la API gratuita bible.helloao.org, con los nombres de libro EXACTOS que
# espera la app (ver jsonKey en lib/data/books.dart).
#
# Uso (PowerShell, desde la raíz del proyecto):
#   powershell -ExecutionPolicy Bypass -File tools/fetch_bible.ps1
#
# Traducción por defecto: spa_rvg (Reina-Valera Gómez, libre).
# Otras de dominio público: spa_r09 (Reina-Valera 1909).
param([string]$translation = 'spa_rvg')

$ErrorActionPreference = 'Stop'
$base = "https://bible.helloao.org/api/$translation"

# Nombres de libro en orden canónico 1..66 (deben coincidir con books.dart).
$JKEYS = @(
  'Génesis','Éxodo','Levítico','Números','Deuteronomio','Josué','Jueces','Rut',
  '1 Samuel','2 Samuel','1 Reyes','2 Reyes','1 Crónicas','2 Crónicas','Esdras',
  'Nehemías','Ester','Job','Salmos','Proverbios','Eclesiastés','Cantares',
  'Isaías','Jeremías','Lamentaciones','Ezequiel','Daniel','Oseas','Joel','Amós',
  'Abdías','Jonás','Miqueas','Nahúm','Habacuc','Sofonías','Hageo','Zacarías',
  'Malaquías','S. Mateo','S. Marcos','S. Lucas','S.Juan','Hechos','Romanos',
  '1 Corintios','2 Corintios','Gálatas','Efesios','Filipenses','Colosenses',
  '1 Tesalonicenses','2 Tesalonicenses','1 Timoteo','2 Timoteo','Tito','Filemón',
  'Hebreos','Santiago','1 Pedro','2 Pedro','1 Juan','2 Juan','3 Juan','Judas',
  'Apocalipsis'
)

function Get-JsonUtf8($url) {
  $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30
  return ([System.Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray())) | ConvertFrom-Json
}

$books = (Get-JsonUtf8 "$base/books.json").books
$result = [ordered]@{}
$total = 0

foreach ($b in $books) {
  $key = $JKEYS[$b.order - 1]
  if (-not $key) { continue }
  $result[$key] = [ordered]@{}
  for ($c = 1; $c -le $b.numberOfChapters; $c++) {
    $ok = $false
    for ($try = 0; $try -lt 5 -and -not $ok; $try++) {
      try {
        $j = Get-JsonUtf8 "$base/$($b.id)/$c.json"
        $chap = [ordered]@{}
        foreach ($item in $j.chapter.content) {
          if ($item.type -eq 'verse') {
            $txt = (($item.content | ForEach-Object {
              if ($_ -is [string]) { $_ } elseif ($_.text) { $_.text }
            }) -join '').Trim()
            if ($txt) { $chap["$($item.number)"] = $txt; $total++ }
          }
        }
        $result[$key]["$c"] = $chap
        $ok = $true
      } catch { Start-Sleep -Milliseconds 500 }
    }
    if (-not $ok) { Write-Host "FAIL $($b.id) $c" }
  }
  Write-Host "$key ($($b.order)/66)"
}

$json = $result | ConvertTo-Json -Depth 8 -Compress
$path = (Resolve-Path .).Path + "\assets\data\rv1960.json"
[System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "WROTE $path  ($total versículos, traducción: $translation)"
