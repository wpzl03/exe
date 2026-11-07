# HTML 문서를 A4 PDF로 인쇄 (Edge 헤드리스). 기본 저장 위치는 프로젝트 폴더(03_수업자료)
# 사용: powershell -ExecutionPolicy Bypass -File tools\make-pdf.ps1 -Html docs\proposal.html -OutName "기획안.pdf" -Open
param(
  [Parameter(Mandatory = $true)][string]$Html,
  [Parameter(Mandatory = $true)][string]$OutName,
  [string]$OutDir = "",
  [switch]$Open
)
# param 기본값 안에서는 $PSScriptRoot 가 비어 있어서(PowerShell 5.1) 여기서 정함
if (-not $OutDir) { $OutDir = Split-Path $PSScriptRoot -Parent }

$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$htmlPath = (Resolve-Path $Html).Path
$pdf = Join-Path $OutDir $OutName
$prof = Join-Path $env:TEMP "edge-pdf-profile"
Remove-Item $prof -Recurse -Force -ErrorAction SilentlyContinue

# --no-pdf-header-footer: 브라우저가 붙이는 날짜·주소 머리글/바닥글 빼기
& $edge --headless=new --disable-gpu --no-first-run --user-data-dir="$prof" --no-pdf-header-footer `
  --virtual-time-budget=4000 --print-to-pdf="$pdf" ("file:///" + ($htmlPath -replace '\\', '/')) 2>$null | Out-Null

if (-not (Test-Path $pdf)) { throw "PDF를 만들지 못했어요: $pdf" }
Write-Host "PDF: $pdf"
if ($Open) { Start-Process $pdf }
