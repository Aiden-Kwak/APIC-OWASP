# API7: Server Side Request Forgery (SSRF) (서버측 요청 위조)

## 개요
API가 사용자 제공 URL을 유효성 검사 없이 호출하여 공격자가 내부 네트워크나 원하는 목적지로 요청하는 취약점

## IBM API Connect 대응 방안

### Invoke 정책 보호
- Invoke 정책에서 백엔드 다른 URL을 고정하거나 검증
- Validate 정책과 정책과 액션 제어를 통해 기능을 제한하고 보안적인 URI 검증

## 검증 체크리스트

### 사전 준비
- [ ] 백엔드 URL 목록 확인
- [ ] 허용된 호스트 화이트리스트 작성
- [ ] 내부 네트워크 대역 확인

### URL 검증

#### ✅ 시나리오 1: 내부 IP 접근 시도
```
POST /api/fetch
{
  "url": "http://localhost:8080/admin"
}
```
- [ ] localhost 접근 시도
- [ ] 127.0.0.1 접근 시도
- [ ] 0.0.0.0 접근 시도
- [ ] 예상 결과: 403 Forbidden
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 2: 내부 네트워크 접근
```
POST /api/fetch
{
  "url": "http://192.168.1.1/admin"
}
```
- [ ] 192.168.x.x (Private IP)
- [ ] 10.x.x.x (Private IP)
- [ ] 172.16.x.x - 172.31.x.x (Private IP)
- [ ] 예상 결과: 403 Forbidden
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 3: AWS 메타데이터 접근
```
POST /api/fetch
{
  "url": "http://169.254.169.254/latest/meta-data/"
}
```
- [ ] AWS 메타데이터 서비스 접근 시도
- [ ] 예상 결과: 403 Forbidden
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 4: URL 우회 시도
```
POST /api/fetch
{
  "url": "http://127.0.0.1@evil.com"
}
```
- [ ] URL 파싱 우회 시도
- [ ] http://127.1 (축약형)
- [ ] http://[::1] (IPv6 localhost)
- [ ] http://0x7f000001 (16진수)
- [ ] 예상 결과: 모두 차단
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

### 프로토콜 검증

#### ✅ 시나리오 5: 허용되지 않은 프로토콜
```
POST /api/fetch
{
  "url": "file:///etc/passwd"
}
```
- [ ] file:// 프로토콜
- [ ] ftp:// 프로토콜
- [ ] gopher:// 프로토콜
- [ ] dict:// 프로토콜
- [ ] 예상 결과: 400 Bad Request
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

### 리다이렉트 검증

#### ✅ 시나리오 6: 오픈 리다이렉트 악용
```
POST /api/fetch
{
  "url": "https://trusted.com/redirect?url=http://169.254.169.254"
}
```
- [ ] 리다이렉트 따라가기 비활성화 확인
- [ ] 리다이렉트 목적지 검증
- [ ] 통과 여부: [ ] Pass [ ] Fail

### API Connect 설정 검증

#### Assembly 정책 확인
- [ ] Invoke 정책의 target-url 고정
- [ ] URL 검증 GatewayScript 구현
- [ ] 화이트리스트 기반 검증

#### 예제 Assembly - URL 화이트리스트
```yaml
assembly:
  execute:
    - gatewayscript:
        version: 2.0.0
        title: Validate Backend URL
        source: |
          var url = require('url');
          var targetUrl = context.get('backend-url') || 
                         context.get('request.parameters.url');
          
          // 허용된 호스트 화이트리스트
          var allowedHosts = [
            'api.example.com',
            'backend.example.com',
            'trusted-partner.com'
          ];
          
          // URL 파싱
          var parsedUrl = url.parse(targetUrl);
          
          // 프로토콜 검증 (https만 허용)
          if (parsedUrl.protocol !== 'https:') {
            context.reject('BadRequest', 'Only HTTPS protocol allowed');
            context.message.statusCode = '400';
            return;
          }
          
          // 호스트 화이트리스트 검증
          if (!allowedHosts.includes(parsedUrl.hostname)) {
            context.reject('Forbidden', 'Host not allowed');
            context.message.statusCode = '403';
            return;
          }
          
          // 내부 IP 차단
          var hostname = parsedUrl.hostname;
          var privateIPRegex = /^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|169\.254\.|::1|localhost)/;
          
          if (privateIPRegex.test(hostname)) {
            context.reject('Forbidden', 'Private IP addresses not allowed');
            context.message.statusCode = '403';
            return;
          }
    
    - invoke:
        version: 2.0.0
        title: Call Backend
        target-url: $(backend-url)
        follow-redirects: false  # 리다이렉트 따라가지 않음
        timeout: 30
```

#### 예제 Assembly - 고정 URL
```yaml
properties:
  backend-url:
    value: 'https://api.example.com/endpoint'
    description: Fixed backend URL
    encoded: false

assembly:
  execute:
    - invoke:
        version: 2.0.0
        title: Call Fixed Backend
        target-url: $(backend-url)  # 고정된 URL만 사용
        follow-redirects: false
        inject-proxy-headers: false
```

#### 예제 - RBAC 기반 URL 제한
```yaml
assembly:
  execute:
    - gatewayscript:
        version: 2.0.0
        title: RBAC URL Validation
        source: |
          var userRole = context.get('decoded.claims.role');
          var targetUrl = context.get('request.parameters.url');
          
          // 역할별 허용 URL 패턴
          var roleUrls = {
            'admin': [
              'https://api.example.com/.*',
              'https://admin.example.com/.*'
            ],
            'user': [
              'https://api.example.com/public/.*'
            ]
          };
          
          var allowedPatterns = roleUrls[userRole] || [];
          var isAllowed = allowedPatterns.some(function(pattern) {
            return new RegExp(pattern).test(targetUrl);
          });
          
          if (!isAllowed) {
            context.reject('Forbidden', 'URL not allowed for your role');
            context.message.statusCode = '403';
          }
```

## 테스트 명령어

### curl 테스트 - 내부 IP
```bash
# localhost 접근 시도
curl -X POST "https://api.example.com/fetch" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"url": "http://localhost:8080/admin"}'

# 예상: 403 Forbidden

# AWS 메타데이터 접근 시도
curl -X POST "https://api.example.com/fetch" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"url": "http://169.254.169.254/latest/meta-data/"}'

# 예상: 403 Forbidden
```

### Python 테스트
```python
import requests

# SSRF 공격 벡터
ssrf_payloads = [
    'http://localhost:8080/admin',
    'http://127.0.0.1/admin',
    'http://0.0.0.0/admin',
    'http://192.168.1.1/admin',
    'http://10.0.0.1/admin',
    'http://169.254.169.254/latest/meta-data/',
    'http://[::1]/admin',
    'http://127.1/admin',
    'file:///etc/passwd',
    'ftp://internal-server/',
    'gopher://internal-server:70/'
]

for payload in ssrf_payloads:
    response = requests.post(
        'https://api.example.com/fetch',
        headers={'Authorization': f'Bearer {token}'},
        json={'url': payload}
    )
    
    assert response.status_code in [400, 403], \
        f"SSRF vulnerability: {payload} returned {response.status_code}"
    
    print(f"✓ Blocked: {payload}")
```

### URL 파싱 우회 테스트
```python
import requests

# URL 파싱 우회 시도
bypass_attempts = [
    'http://127.0.0.1@evil.com',
    'http://evil.com#@127.0.0.1',
    'http://127.0.0.1%00.evil.com',
    'http://127.0.0.1%2F@evil.com',
    'http://0x7f000001',  # 16진수
    'http://2130706433',  # 10진수
    'http://017700000001',  # 8진수
]

for url in bypass_attempts:
    response = requests.post(
        'https://api.example.com/fetch',
        headers={'Authorization': f'Bearer {token}'},
        json={'url': url}
    )
    
    assert response.status_code in [400, 403], \
        f"Bypass successful: {url}"
    
    print(f"✓ Blocked bypass: {url}")
```

## 보안 설정 체크리스트

### URL 검증
- [ ] 프로토콜 화이트리스트 (https만)
- [ ] 호스트 화이트리스트
- [ ] 내부 IP 차단
- [ ] 메타데이터 서비스 차단

### Invoke 정책 설정
- [ ] target-url 고정 또는 검증
- [ ] follow-redirects: false
- [ ] inject-proxy-headers: false
- [ ] timeout 설정

### 네트워크 보안
- [ ] 방화벽 규칙 설정
- [ ] 네트워크 세그멘테이션
- [ ] 아웃바운드 트래픽 제한

### 모니터링
- [ ] SSRF 시도 탐지
- [ ] 비정상 URL 패턴 알림
- [ ] 내부 IP 접근 시도 로깅

## 결과 기록

### 테스트 일시
- 테스트 날짜: ___________
- 테스트 담당자: ___________

### 허용된 백엔드
1. ___________
2. ___________
3. ___________

### 발견된 문제
1. ___________
2. ___________
3. ___________

### 조치 사항
1. ___________
2. ___________
3. ___________

## 참고 자료
- [OWASP API7:2023](https://owasp.org/API-Security/editions/2023/en/0xa7-server-side-request-forgery/)
- [SSRF Bible](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html)
- [AWS SSRF Protection](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html)