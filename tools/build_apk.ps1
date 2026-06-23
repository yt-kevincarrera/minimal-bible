# Compila La Biblia en APKs de RELEASE separados por arquitectura (ABI),
# mucho más livianos que el APK universal (~26-32 MB el de arm64 vs ~61 MB el
# universal, porque el universal mete las 3 arquitecturas dentro).
#
# Uso (PowerShell, desde la raíz del proyecto):
#   powershell -ExecutionPolicy Bypass -File tools/build_apk.ps1
#
# Requiere tener Flutter instalado y assets/data/rv1960.json ya presente
# (ver assets/data/README.md). Genera 3 APKs en
# build/app/outputs/flutter-apk/ :
#   *-arm64-v8a.apk    <- reparte ESTE (casi todos los teléfonos modernos)
#   *-armeabi-v7a.apk  <- teléfonos viejos de 32 bits
#   *-x86_64.apk       <- emuladores / equipos x86

$ErrorActionPreference = 'Stop'

if (-not (Test-Path 'assets/data/rv1960.json')) {
    Write-Warning 'Falta assets/data/rv1960.json: el APK compilará pero NO mostrará texto. Ver assets/data/README.md.'
}

flutter build apk --release --split-per-abi

$out = 'build/app/outputs/flutter-apk'
Write-Host ''
Write-Host "APKs generados en $out :" -ForegroundColor Green
Get-ChildItem $out -Filter *.apk | ForEach-Object {
    '{0,8:N1} MB  {1}' -f ($_.Length / 1MB), $_.Name
}
Write-Host ''
Write-Host 'Reparte el de arm64-v8a (salvo teléfonos muy viejos de 32 bits -> armeabi-v7a).'
