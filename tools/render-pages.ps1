# PDF의 각 쪽을 PNG 이미지로 저장 (Windows 기본 PDF 엔진 사용, 별도 설치 없음)
# 레이아웃 검수용: 표 테두리 잘림, 빈 쪽, 쪽 끝에 홀로 남은 제목 등을 눈으로 확인
# 사용: powershell -ExecutionPolicy Bypass -File tools\render-pages.ps1 -Pdf "$env:USERPROFILE\OneDrive\바탕 화면\기획안.pdf"
param(
  [Parameter(Mandatory = $true)][string]$Pdf,
  [string]$OutDir = (Join-Path $env:TEMP "pdf-pages")
)

New-Item -ItemType Directory -Force $OutDir | Out-Null
Get-ChildItem $OutDir -Filter "page*.png" -ErrorAction SilentlyContinue | Remove-Item

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Storage.StorageFolder, Windows.Storage, ContentType = WindowsRuntime]
$null = [Windows.Data.Pdf.PdfDocument, Windows.Data.Pdf, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.IRandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]

# WinRT 비동기 작업을 PowerShell 에서 기다리기 위한 도우미
$asTaskOp = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
$asTaskAction = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' })[0]
function Await($op, [Type]$type) { $t = $asTaskOp.MakeGenericMethod($type).Invoke($null, @($op)); $t.Wait(-1) | Out-Null; $t.Result }
function AwaitAction($op) { $t = $asTaskAction.Invoke($null, @($op)); $t.Wait(-1) | Out-Null }

$file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync((Resolve-Path $Pdf).Path)) ([Windows.Storage.StorageFile])
$doc = Await ([Windows.Data.Pdf.PdfDocument]::LoadFromFileAsync($file)) ([Windows.Data.Pdf.PdfDocument])
$folder = Await ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync((Resolve-Path $OutDir).Path)) ([Windows.Storage.StorageFolder])

Write-Host "쪽 수: $($doc.PageCount)"
for ($i = 0; $i -lt $doc.PageCount; $i++) {
  $page = $doc.GetPage($i)
  $png = Await ($folder.CreateFileAsync("page$($i + 1).png", [Windows.Storage.CreationCollisionOption]::ReplaceExisting)) ([Windows.Storage.StorageFile])
  $stream = Await ($png.OpenAsync([Windows.Storage.FileAccessMode]::ReadWrite)) ([Windows.Storage.Streams.IRandomAccessStream])
  AwaitAction ($page.RenderToStreamAsync($stream))
  $stream.Dispose(); $page.Dispose()
  Write-Host (Join-Path $OutDir "page$($i + 1).png")
}
