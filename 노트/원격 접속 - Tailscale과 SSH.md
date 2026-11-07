---
tags: [수업, 원격접속, 네트워크]
PC주소: 100.79.255.74
---

# 🔐 원격 접속 — Tailscale과 SSH

← [[오늘 배운 내용 2026-11-07]]

## 개념
- **Tailscale** — 내 기기들끼리만 연결되는 사설 네트워크(VPN). 같은 계정으로 로그인한 기기마다 `100.x.x.x` 주소가 생긴다. 집 밖에서도 연결됨.
- **SSH** — 다른 컴퓨터에 명령창으로 접속하는 방법.
  - **클라이언트**(접속하는 쪽): Windows에 기본 설치
  - **서버**(접속받는 쪽, `sshd`): 따로 설치해야 함

## 내 기기
| 기기 | Tailscale 주소 |
|---|---|
| 이 PC (`node`, Windows) | **100.79.255.74** |
| 휴대폰 (`s25`, Android) | 100.118.80.127 |

## 설치 과정 기록
1. Tailscale: `winget install --id Tailscale.Tailscale -e` → 로그인 페이지에서 로그인 → 연결
2. SSH 서버: Windows 기본 방식(`Add-WindowsCapability`)은 **다운로드 49%에서 멈춤**
3. 대신 **마이크로소프트 공식 OpenSSH 설치 파일**: `winget install --id Microsoft.OpenSSH.Preview -e` (관리자 권한)
4. 서비스 자동 시작: `Set-Service sshd -StartupType Automatic`, `Start-Service sshd`
5. **보안 설정:** 방화벽에서 22번 포트를 **Tailscale 주소(100.64.0.0/10)에서만** 허용
   → 같은 와이파이의 다른 기기는 접속 불가

## 휴대폰에서 접속하기 (Termius)
1. 휴대폰 **Tailscale 앱이 Connected** 인지 확인
2. Termius 실행 → 계정 만들기는 건너뛰기
3. **＋ › New Host**
   - Hostname: `100.79.255.74`
   - Port: `22`
   - Username: `wpzl1`
   - Password: **Windows(Microsoft 계정) 비밀번호** — *PIN 아님*
4. 저장(✓) → 눌러서 접속 → 처음 묻는 확인 창은 **Continue**
5. `C:\Users\wpzl1>` 가 보이면 성공 → `dir` 입력해 보기

Termux 라면: `pkg install openssh` → `ssh wpzl1@100.79.255.74`

## 안 될 때
| 메시지 | 원인 |
|---|---|
| Permission denied | 비밀번호 틀림 (PIN을 넣었는지 확인) |
| Connection timed out | 휴대폰 Tailscale 꺼짐 |
| Connection refused | PC의 sshd 서비스 꺼짐 |

## 상태 확인 명령 (PC에서)
```powershell
tailscale status                       # 연결된 기기 목록
tailscale ping 100.118.80.127          # 휴대폰과 연결 확인
Get-Service sshd                       # SSH 서버 실행 여부
```
