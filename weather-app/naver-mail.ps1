# 네이버 메일(IMAP)에 접속해서 오늘 받은 메일 수를 세는 함수
# 미리 해둘 것: 네이버 메일 > 환경설정 > POP3/IMAP 설정 > IMAP/SMTP 사용 "사용함"
# 2단계 인증을 쓰는 계정은 비밀번호 대신 "애플리케이션 비밀번호"가 필요해요.

function Get-NaverMailCount([pscredential]$Credential) {
  $client = New-Object Net.Sockets.TcpClient("imap.naver.com", 993)
  try {
    $ssl = New-Object Net.Security.SslStream($client.GetStream())
    $ssl.AuthenticateAsClient("imap.naver.com")
    $reader = New-Object IO.StreamReader($ssl, [Text.Encoding]::UTF8)
    $writer = New-Object IO.StreamWriter($ssl, (New-Object Text.UTF8Encoding $false))
    $writer.NewLine = "`r`n"
    $writer.AutoFlush = $true
    $null = $reader.ReadLine()   # 서버 인사말: "* OK ... Naver Imap Server ready."

    # IMAP 명령 하나 보내고, 응답 줄들을 돌려줌 (명령마다 A1, A2 … 태그를 붙임)
    $state = @{ n = 0 }
    $send = {
      param($cmd)
      $state.n++
      $tag = "A$($state.n)"
      $writer.WriteLine("$tag $cmd")
      while ($true) {
        $line = $reader.ReadLine()
        if ($null -eq $line) { throw "메일 서버 연결이 끊겼어요." }
        if ($line.StartsWith("$tag ")) {
          if ($line -notmatch "^$tag OK") { throw "IMAP 오류: $line" }
          return
        }
        $line   # 태그 없는 응답 줄(* ...)은 결과로 내보냄
      }
    }

    # IMAP 문자열 규칙: 큰따옴표로 감싸고 \ 와 " 앞에 \ 붙이기
    $quote = { param($s) '"' + ($s -replace '\\', '\\' -replace '"', '\"') + '"' }
    $user = $Credential.UserName -replace '@naver\.com$', ''
    $pass = $Credential.GetNetworkCredential().Password

    try { $null = & $send "LOGIN $(& $quote $user) $(& $quote $pass)" }
    catch { throw "LOGIN_FAILED" }

    $null = & $send "EXAMINE INBOX"   # 읽기 전용으로 받은메일함 열기 (읽음 표시가 바뀌지 않음)

    # SEARCH 결과 "* SEARCH 3 7 12" → 번호 개수 = 메일 수
    $countOf = {
      param($criteria)
      $line = @(& $send "SEARCH $criteria") | Where-Object { $_ -like "* SEARCH*" } | Select-Object -First 1
      if (-not $line) { return 0 }
      @(($line -replace '^\* SEARCH\s*', '').Trim() -split '\s+' | Where-Object { $_ }).Count
    }
    $today = (Get-Date).ToString("dd-MMM-yyyy", [Globalization.CultureInfo]::InvariantCulture)  # 예: 07-Nov-2026
    $total = & $countOf "SINCE $today"
    $unread = & $countOf "UNSEEN SINCE $today"

    try { $null = & $send "LOGOUT" } catch { }

    return @{ today = $total; unread = $unread; checkedAt = (Get-Date).ToString("HH:mm") }
  } finally {
    $client.Close()
  }
}
