# 날씨 앱 로컬 서버
#  - http://localhost:8000 에서 index.html 을 보여줌
#  - /api/stock?symbols=^KS11,005930.KS 요청을 받아 Yahoo Finance 시세를 대신 가져다 줌
#    (브라우저가 Yahoo Finance 에 직접 요청하면 CORS 정책 때문에 막히기 때문)

$port = 8000
$root = $PSScriptRoot
$ProgressPreference = 'SilentlyContinue'   # Invoke-RestMethod 진행 표시줄 끄기 (속도 향상)

function Get-Quote($symbol) {
  $url = "https://query1.finance.yahoo.com/v8/finance/chart/$([uri]::EscapeDataString($symbol))?range=5d&interval=1d"
  $r = Invoke-RestMethod $url -Headers @{ "User-Agent" = "Mozilla/5.0" } -TimeoutSec 10
  $res = $r.chart.result[0]
  $closes = @($res.indicators.quote[0].close | Where-Object { $_ -ne $null })
  $price = [double]$res.meta.regularMarketPrice
  # 전일 종가 = 일별 종가 중 마지막 바로 앞 값
  if ($closes.Count -ge 2) { $prev = [double]$closes[$closes.Count - 2] } else { $prev = [double]$res.meta.chartPreviousClose }
  [pscustomobject]@{
    symbol   = $symbol
    price    = $price
    prev     = $prev
    change   = $price - $prev
    pct      = if ($prev) { ($price - $prev) / $prev * 100 } else { 0 }
    currency = $res.meta.currency
    time     = $res.meta.regularMarketTime
  }
}

# ── 네이버 메일 설정 ──────────────────────────────
. (Join-Path $root "naver-mail.ps1")
$credFile = Join-Path $root "mail-cred.xml"   # 로그인 정보 (Windows 계정 암호화, 이 PC·이 계정에서만 열림)
$mailCred = $null
$mailCache = $null; $mailCacheTime = [datetime]::MinValue

# 로그인은 웹페이지의 로그인 창에서 함 (/api/mail/login). 성공하면 여기에 저장됨
if (Test-Path $credFile) {
  $mailCred = Import-Clixml $credFile
  Write-Host "네이버 메일: 저장된 로그인 정보($($mailCred.UserName))를 사용해요."
} else {
  Write-Host "네이버 메일: 아직 로그인 전이에요. 웹페이지의 메일 버튼을 눌러 로그인하세요."
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
Write-Host "날씨 앱 실행 중: http://localhost:$port"
Write-Host "종료하려면 이 창에서 Ctrl+C 를 누르거나 창을 닫으세요."
Start-Process "http://localhost:$port"

try {
  while ($listener.IsListening) {
    # Ctrl+C 가 먹히도록 0.5초씩 나눠서 기다림
    $task = $listener.GetContextAsync()
    while (-not $task.AsyncWaitHandle.WaitOne(500)) { }
    $ctx = $task.GetAwaiter().GetResult()
    $req = $ctx.Request
    $resp = $ctx.Response
    try {
      $path = $req.Url.AbsolutePath
      if ($path -eq "/api/stock") {
        $symbols = @(($req.QueryString["symbols"] -split ",") |
          Where-Object { $_ -match '^[A-Za-z0-9^=.\-]{1,20}$' } | Select-Object -First 10)
        $list = foreach ($s in $symbols) {
          try { Get-Quote $s } catch { [pscustomobject]@{ symbol = $s; error = $true } }
        }
        $body = ConvertTo-Json -InputObject @($list) -Depth 3 -Compress
        $type = "application/json; charset=utf-8"
      } elseif ($path -eq "/api/mail/login" -and $req.HttpMethod -eq "POST") {
        # 웹페이지 로그인 창에서 보낸 아이디/비밀번호로 실제 접속해 보고, 성공하면 암호화해서 저장
        $json = (New-Object IO.StreamReader($req.InputStream, [Text.Encoding]::UTF8)).ReadToEnd() | ConvertFrom-Json
        $cred = New-Object PSCredential($json.id, (ConvertTo-SecureString $json.pw -AsPlainText -Force))
        try {
          $obj = Get-NaverMailCount $cred
          $obj.enabled = $true
          $cred | Export-Clixml $credFile
          $mailCred = $cred
          $mailCache = $obj; $mailCacheTime = Get-Date
          Write-Host "네이버 메일 로그인 성공: $($cred.UserName)"
        } catch {
          $msg = if ($_.Exception.Message -eq "LOGIN_FAILED") { "로그인 실패 — 아이디/비밀번호와 IMAP 사용 설정을 확인하세요. (2단계 인증 사용 시 애플리케이션 비밀번호)" } else { $_.Exception.Message }
          $obj = @{ enabled = $false; error = $msg }
        }
        $body = $obj | ConvertTo-Json -Compress
        $type = "application/json; charset=utf-8"
      } elseif ($path -eq "/api/mail") {
        if (-not $mailCred) {
          $obj = @{ enabled = $false }
        } elseif ($mailCache -and ((Get-Date) - $mailCacheTime).TotalSeconds -lt 60) {
          $obj = $mailCache   # 1분 안에 다시 물어보면 저장해 둔 값 사용
        } else {
          try {
            $obj = Get-NaverMailCount $mailCred
            $obj.enabled = $true
            $mailCache = $obj; $mailCacheTime = Get-Date
          } catch {
            if ($_.Exception.Message -eq "LOGIN_FAILED") {
              # 틀린 정보는 지워서 다음 실행 때 다시 입력받기
              Remove-Item $credFile -ErrorAction SilentlyContinue
              $mailCred = $null
              $obj = @{ enabled = $false; error = "로그인 정보가 맞지 않아요. 다시 로그인해 주세요." }
            } else {
              $obj = @{ enabled = $true; error = $_.Exception.Message }
            }
          }
        }
        $body = $obj | ConvertTo-Json -Compress
        $type = "application/json; charset=utf-8"
      } elseif ($path -eq "/" -or $path -eq "/index.html") {
        $body = [IO.File]::ReadAllText((Join-Path $root "index.html"), [Text.Encoding]::UTF8)
        $type = "text/html; charset=utf-8"
      } else {
        $resp.StatusCode = 404
        $body = "Not found"
        $type = "text/plain; charset=utf-8"
      }
      $bytes = [Text.Encoding]::UTF8.GetBytes($body)
      $resp.ContentType = $type
      $resp.OutputStream.Write($bytes, 0, $bytes.Length)
      Write-Host "$(Get-Date -Format HH:mm:ss) $path"
    } catch {
      Write-Host "오류: $($_.Exception.Message)"
    } finally {
      $resp.Close()
    }
  }
} finally {
  $listener.Stop()
}
