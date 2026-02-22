# n8n-oracle-cloud-deploy

> **[English](#english)** | **[한국어](#한국어)**

---

<a id="english"></a>

## English

Scripts for deploying n8n to Oracle Cloud Free Tier (VM.Standard.E2.1.Micro, 1GB RAM).

Migrates workflows, credentials, and execution history from a local Docker n8n instance. Sets up external access with a free DuckDNS domain and Let's Encrypt HTTPS.

### Structure

```
oracle-setup.sh           # Server init (swap, Docker, Nginx, certbot, firewall)
docker-compose.cloud.yml  # Memory-optimized n8n Docker config
.env.cloud.example        # Environment variables template
scripts/
  deploy-to-oracle.sh     # Local → remote one-click deploy
  duckdns-update.sh       # DuckDNS IP update (cron, every 5 min)
  nginx-n8n.conf          # Nginx reverse proxy + SSL
```

### Prerequisites

- Oracle Cloud account with a Free Tier instance (Oracle Linux 9)
- SSH key created and instance connection verified
- Ingress rules for ports 80, 443 added to OCI Security List (0.0.0.0/0, TCP)
  - ⚠️ **Do NOT open port 5678** — n8n is only accessible via nginx reverse proxy on port 443
- [DuckDNS](https://www.duckdns.org) subdomain registered with token
- Docker installed locally with an existing n8n volume

### Usage

1. Copy `.env.cloud.example` to `.env.cloud` and fill in the values

```bash
cp .env.cloud.example .env.cloud
# Edit N8N_DOMAIN, N8N_ENCRYPTION_KEY
```

2. Enter your DuckDNS subdomain and token in `scripts/duckdns-update.sh`

3. Replace `YOUR_DOMAIN` with your actual domain in `scripts/nginx-n8n.conf`

4. Edit the config section at the top of `scripts/deploy-to-oracle.sh`, then run

```bash
chmod +x scripts/deploy-to-oracle.sh
./scripts/deploy-to-oracle.sh
```

### Memory Optimization

Settings for stable n8n operation on a 1GB RAM instance:

- 4GB swap (swappiness=10)
- Node.js heap limited to 512MB (`NODE_OPTIONS=--max-old-space-size=512`)
- Docker memory limit 768MB, swap allowance 2GB
- Execution history auto-pruned after 7 days
- Telemetry and version notifications disabled
- Concurrent execution limit of 5

### Notes

- Certbot on Oracle Linux 9 may require the EPEL repository (`--enablerepo=ol9_developer_EPEL`)
- SELinux requires `setsebool -P httpd_can_network_connect 1` and `httpd_sys_content_t` context on `/var/www/html`
- Windows Git Bash may mangle paths when running SSH. Use the built-in OpenSSH (`C:\Windows\System32\OpenSSH\ssh.exe`) instead
- Shell scripts transferred from Windows need CRLF→LF conversion: `sed -i 's/\r$//' script.sh`

---

<a id="한국어"></a>

## 한국어

Oracle Cloud Free Tier(VM.Standard.E2.1.Micro, 1GB RAM)에 n8n을 배포하는 스크립트 모음.

로컬 Docker n8n의 워크플로, Credential, 실행 이력을 그대로 마이그레이션하고, DuckDNS 무료 도메인 + Let's Encrypt HTTPS로 외부 접속을 구성한다.

### 구성

```
oracle-setup.sh           # 서버 초기 세팅 (swap, Docker, Nginx, certbot, firewall)
docker-compose.cloud.yml  # 1GB RAM 최적화 n8n Docker 설정
.env.cloud.example        # 환경변수 템플릿
scripts/
  deploy-to-oracle.sh     # 로컬 → 원격 배포 자동화
  duckdns-update.sh       # DuckDNS IP 갱신 (cron 5분)
  nginx-n8n.conf          # Nginx reverse proxy + SSL
```

### 사전 준비

- Oracle Cloud 계정 + Free Tier 인스턴스 생성 (Oracle Linux 9)
- SSH 키 생성 및 인스턴스 연결 확인
- OCI Security List에 포트 80, 443 Ingress 규칙 추가 (0.0.0.0/0, TCP)
  - ⚠️ **포트 5678은 절대 개방하지 말 것** — n8n은 nginx 리버스 프록시를 통해 443 포트로만 접근
- [DuckDNS](https://www.duckdns.org) 서브도메인 등록 및 토큰 확인
- 로컬에 Docker가 설치되어 있고 n8n 볼륨이 존재할 것

### 사용법

1. `.env.cloud.example`을 `.env.cloud`로 복사하고 값 입력

```bash
cp .env.cloud.example .env.cloud
# N8N_DOMAIN, N8N_ENCRYPTION_KEY 편집
```

2. `scripts/duckdns-update.sh`에 DuckDNS 서브도메인과 토큰 입력

3. `scripts/nginx-n8n.conf`의 `YOUR_DOMAIN`을 실제 도메인으로 변경

4. `scripts/deploy-to-oracle.sh` 상단 설정값 편집 후 실행

```bash
chmod +x scripts/deploy-to-oracle.sh
./scripts/deploy-to-oracle.sh
```

### 메모리 최적화

1GB RAM 인스턴스에서 n8n이 안정적으로 동작하기 위한 설정:

- 4GB swap (swappiness=10)
- Node.js 힙 512MB 제한 (`NODE_OPTIONS=--max-old-space-size=512`)
- Docker 메모리 768MB 제한, swap 2GB 허용
- 실행 이력 7일 자동 정리
- 텔레메트리/버전 알림 비활성화
- 동시 실행 제한 5개

### 참고

- Oracle Linux 9에서 certbot은 EPEL 리포지토리가 필요할 수 있다 (`--enablerepo=ol9_developer_EPEL`)
- SELinux 환경에서는 `setsebool -P httpd_can_network_connect 1`과 `/var/www/html`의 `httpd_sys_content_t` 컨텍스트 설정이 필요하다
- Windows Git Bash에서 SSH 실행 시 경로 치환 문제가 있을 수 있다. Windows 내장 OpenSSH(`C:\Windows\System32\OpenSSH\ssh.exe`)를 사용하면 해결된다
- 전송한 셸 스크립트가 CRLF 줄바꿈일 경우 원격에서 `sed -i 's/\r$//' script.sh`로 변환 필요
