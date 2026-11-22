# Собирает frontend/dist и подкладывает preview/shim.js, чтобы открыть
# интерфейс в обычном браузере (мок-биндинги Wails) для ревью дизайна.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot   # .../FirmyVPN/frontend
Set-Location $root

npm run build
if ($LASTEXITCODE -ne 0) { throw "vite build failed" }

Copy-Item (Join-Path $PSScriptRoot "shim.js") (Join-Path $root "dist\shim.js") -Force
Copy-Item (Join-Path $PSScriptRoot "frame.html") (Join-Path $root "dist\frame.html") -Force

$p = Join-Path $root "dist\index.html"
$h = Get-Content $p -Raw
if ($h -notmatch 'shim\.js') {
    $h = $h -replace '<script type="module"', "<script src=`"./shim.js`"></script>`n<script type=`"module`""
    [System.IO.File]::WriteAllText($p, $h)
}
Write-Host "preview ready -> http://localhost:4173/" -ForegroundColor Green
