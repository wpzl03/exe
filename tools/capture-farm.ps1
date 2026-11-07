# 주문관리 앱(farm-orders)에 예시 주문을 넣고 화면을 캡처해 docs\shot_list.png, docs\shot_input.png 로 저장
# 사용: powershell -ExecutionPolicy Bypass -File tools\capture-farm.ps1

$root = Split-Path $PSScriptRoot -Parent
$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$work = Join-Path $env:TEMP "farm-capture"
New-Item -ItemType Directory -Force $work | Out-Null

# 앱 HTML 의 </body> 앞에 예시 데이터 스크립트(seed.js)를 끼워 넣은 임시 페이지 만들기
$html = [IO.File]::ReadAllText((Join-Path $root "farm-orders\index.html"), [Text.Encoding]::UTF8)
$seed = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "seed.js"), [Text.Encoding]::UTF8)
$i = $html.LastIndexOf("</body>")
$page = Join-Path $work "seed.html"
[IO.File]::WriteAllText($page, $html.Substring(0, $i) + $seed + $html.Substring($i), (New-Object Text.UTF8Encoding $false))
$url = "file:///" + ($page -replace '\\', '/')

foreach ($mode in "list", "input") {
  $prof = Join-Path $work "profile_$mode"            # 매번 빈 브라우저 저장소로 시작
  Remove-Item $prof -Recurse -Force -ErrorAction SilentlyContinue
  $out = Join-Path $root "docs\shot_$mode.png"
  & $edge --headless=new --disable-gpu --no-first-run --hide-scrollbars --force-color-profile=srgb `
    --user-data-dir="$prof" --virtual-time-budget=6000 --window-size=1100,1000 `
    --screenshot="$out" "$url#$mode" 2>$null | Out-Null
  Write-Host "캡처: $out"
}
