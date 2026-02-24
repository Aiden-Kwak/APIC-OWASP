# API8: Security Misconfiguration (보안 설정 오류)

## 개요
보안 패치 미적용, 잘못된 HTTP 헤더 설정, 부적절한 CORS 정책 등으로 인한 취약점

## IBM API Connect 대응 방안

### 1. 보안 정책 적용
- 보안 헤더 설정 (X-Content-Type-Options, X-Frame-Options 등)
- 부적절한 CORS 설정으로 인한 허점을 방지하기 위해 적절한 CORS 설정

### 2. API Studio 및 API Agent
- 자원의 인터페이스를 통해 개발자에게 적절한 보안 정책을 권고
- 예를 들어, 인증 정책이 추가 되지 않은 경우 알림

## 검증 체크리스트

### 사전 준비
- [ ] 보안 헤더 목록 확인
- [ ] CORS 정책 확인
- [ ] TLS/SSL 설정 확인
- [ ] 에러 메시지 정책 확인

### 보안 헤더 검증

#### ✅ 시나리오 1: 필수 보안 헤더
```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Security-Policy: default-src 'self'
```
- [ ] 모든 응답에 보안 헤더 포함 확인
- [ ] 각 헤더의 값이 적절한지 확인
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 2: 민감 정보 노출 헤더
```
Server: Apache/2.4.1 (Unix)  # 버전 정보 노출
X-Powered-By: PHP/7.4.3      # 기술 스택 노출
```
- [ ] Server 헤더 제거 또는 일반화
- [ ] X-Powered-By 헤더 제거
- [ ] 기타 정보 노출 헤더 확인
- [ ] 통과 여부: [ ] Pass [ ] Fail

### CORS 설정 검증

#### ✅ 시나리오 3: CORS 정책
```
Access-Control-Allow-Origin: *  # 위험!
```
- [ ] 와일드카드(*) 사용 여부 확인
- [ ] 허용된 Origin 목록 확인
- [ ] credentials와 함께 * 사용 금지 확인
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 4: CORS Preflight
```
OPTIONS /api/orders
Origin: https://evil.com
```
- [ ] 허용되지 않은 Origin 차단
- [ ] 허용된 메서드만 반환
- [ ] 허용된 헤더만 반환
- [ ] 통과 여부: [ ] Pass [ ] Fail

### TLS/SSL 설정

#### ✅ 시나리오 5: TLS 버전
- [ ] TLS 1.2 이상만 허용
- [ ] TLS 1.0, 1.1 비활성화
- [ ] SSL 2.0, 3.0 비활성화
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 6: 암호화 스위트
- [ ] 강력한 암호화 스위트 사용
- [ ] 약한 암호화 알고리즘 비활성화
- [ ] Perfect Forward Secrecy 지원
- [ ] 통과 여부: [ ] Pass [ ] Fail

### 에러 메시지 검증

#### ✅ 시나리오 7: 상세한 에러 정보 노출
```json
{
  "error": "SQLException: Table 'users' doesn't exist",
  "stack": "at com.example.UserService.getUser...",
  "path": "/var/www/api/users.php"
}
```
- [ ] 스택 트레이스 노출 여부
- [ ] 데이터베이스 정보 노출 여부
- [ ] 파일 경로 노출 여부
- [ ] 예상: 일반적인 에러 메시지만 반환
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 8: 에러 메시지 일관성
- [ ] 4xx 에러: 일관된 형식
- [ ] 5xx 에러: 내부 정보 숨김
- [ ] 에러 코드 표준화
- [ ] 통과 여부: [ ] Pass [ ] Fail

### API Connect 설정 검증

#### Assembly 정책 확인
- [ ] 보안 헤더 설정 정책
- [ ] CORS 정책 구성
- [ ] 에러 처리 정책

#### 예제 Assembly - 보안 헤더
```yaml
assembly:
  execute:
    - set-variable:
        version: 2.0.0
        title: Set Security Headers
        actions:
          - set: message.headers.X-Content-Type-Options
            value: nosniff
          - set: message.headers.X-Frame-Options
            value: DENY
          - set: message.headers.X-XSS-Protection
            value: '1; mode=block'
          - set: message.headers.Strict-Transport-Security
            value: 'max-age=31536000; includeSubDomains; preload'
          - set: message.headers.Content-Security-Policy
            value: "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"
          - set: message.headers.Referrer-Policy
            value: 'strict-origin-when-cross-origin'
          - set: message.headers.Permissions-Policy
            value: 'geolocation=(), microphone=(), camera=()'
    
    # Server 헤더 제거
    - gatewayscript:
        version: 2.0.0
        title: Remove Sensitive Headers
        source: |
          context.message.headers.remove('Server');
          context.message.headers.remove('X-Powered-By');
          context.message.headers.remove('X-AspNet-Version');
```

#### 예제 - CORS 설정
```yaml
x-ibm-configuration:
  cors:
    enabled: true
    allow-credentials: false
    allow-origins:
      - 'https://app.example.com'
      - 'https://admin.example.com'
    allow-methods:
      - GET
      - POST
      - PUT
      - DELETE
      - OPTIONS
    allow-headers:
      - Content-Type
      - Authorization
      - X-Request-ID
    expose-headers:
      - X-Rate-Limit-Limit
      - X-Rate-Limit-Remaining
    max-age: 3600
```

#### 예제 - 에러 처리
```yaml
assembly:
  execute:
    - invoke:
        title: Call Backend
        target-url: https://backend.example.com/api
        output: backend.response
  
  catch:
    - gatewayscript:
        version: 2.0.0
        title: Sanitize Error Response
        source: |
          var error = context.get('error') || {};
          var statusCode = context.get('message.statusCode') || '500';
          
          // 에러 정보 sanitize
          var sanitizedError = {
            code: 'ERROR',
            message: 'An error occurred',
            requestId: context.get('request.headers.x-request-id')
          };
          
          // 클라이언트 에러(4xx)는 상세 정보 제공
          if (statusCode.startsWith('4')) {
            sanitizedError.code = error.name || 'CLIENT_ERROR';
            sanitizedError.message = error.message || 'Bad request';
          }
          
          // 서버 에러(5xx)는 일반적인 메시지만
          if (statusCode.startsWith('5')) {
            sanitizedError.code = 'SERVER_ERROR';
            sanitizedError.message = 'Internal server error';
            
            // 내부 로그에만 상세 정보 기록
            console.error('Internal Error:', JSON.stringify(error));
          }
          
          // 민감한 정보 제거
          delete sanitizedError.stack;
          delete sanitizedError.path;
          delete sanitizedError.query;
          
          context.set('message.body', sanitizedError);
          context.set('message.headers.content-type', 'application/json');
```

## 테스트 명령어

### 보안 헤더 테스트
```bash
# 보안 헤더 확인
curl -I "https://api.example.com/orders" \
  -H "Authorization: Bearer ${TOKEN}"

# 확인할 헤더:
# X-Content-Type-Options: nosniff
# X-Frame-Options: DENY
# X-XSS-Protection: 1; mode=block
# Strict-Transport-Security: max-age=31536000
# Content-Security-Policy: default-src 'self'

# 제거되어야 할 헤더:
# Server (또는 일반화된 값)
# X-Powered-By (없어야 함)
```

### CORS 테스트
```bash
# Preflight 요청
curl -X OPTIONS "https://api.example.com/orders" \
  -H "Origin: https://evil.com" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: Authorization" \
  -v

# 허용되지 않은 Origin은 CORS 헤더 없어야 함

# 허용된 Origin
curl -X OPTIONS "https://api.example.com/orders" \
  -H "Origin: https://app.example.com" \
  -H "Access-Control-Request-Method: GET" \
  -v

# Access-Control-Allow-Origin: https://app.example.com
```

### TLS 테스트
```bash
# TLS 버전 확인
nmap --script ssl-enum-ciphers -p 443 api.example.com

# 또는 openssl
openssl s_client -connect api.example.com:443 -tls1
openssl s_client -connect api.example.com:443 -tls1_1
openssl s_client -connect api.example.com:443 -tls1_2
openssl s_client -connect api.example.com:443 -tls1_3

# TLS 1.0, 1.1은 실패해야 함
```

### Python 테스트
```python
import requests

# 보안 헤더 검증
response = requests.get(
    'https://api.example.com/orders',
    headers={'Authorization': f'Bearer {token}'}
)

required_headers = {
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '1',
    'Strict-Transport-Security': 'max-age=31536000'
}

for header, expected in required_headers.items():
    actual = response.headers.get(header, '')
    assert expected in actual, f"Missing or incorrect {header}"
    print(f"✓ {header}: {actual}")

# 민감한 헤더 확인
sensitive_headers = ['Server', 'X-Powered-By', 'X-AspNet-Version']
for header in sensitive_headers:
    assert header not in response.headers or \
           not any(ver in response.headers[header].lower() 
                  for ver in ['apache', 'nginx', 'php', 'asp']), \
           f"Version info exposed in {header}"
    print(f"✓ {header}: Not exposing version info")

# CORS 테스트
response = requests.options(
    'https://api.example.com/orders',
    headers={'Origin': 'https://evil.com'}
)

# 허용되지 않은 Origin은 CORS 헤더 없어야 함
assert 'Access-Control-Allow-Origin' not in response.headers, \
    "CORS allows unauthorized origin!"
```

## 보안 설정 체크리스트

### 보안 헤더
- [ ] X-Content-Type-Options 설정
- [ ] X-Frame-Options 설정
- [ ] X-XSS-Protection 설정
- [ ] Strict-Transport-Security 설정
- [ ] Content-Security-Policy 설정
- [ ] Referrer-Policy 설정
- [ ] Permissions-Policy 설정

### CORS 설정
- [ ] 와일드카드(*) 사용 금지
- [ ] 허용된 Origin 명시
- [ ] 허용된 메서드 제한
- [ ] 허용된 헤더 제한
- [ ] credentials 설정 검토

### TLS/SSL
- [ ] TLS 1.2 이상만 허용
- [ ] 강력한 암호화 스위트
- [ ] 인증서 유효성 확인
- [ ] HSTS 활성화

### 에러 처리
- [ ] 스택 트레이스 숨김
- [ ] 내부 경로 숨김
- [ ] 데이터베이스 정보 숨김
- [ ] 일관된 에러 형식

### 버전 관리
- [ ] API 버전 명시
- [ ] 구버전 지원 정책
- [ ] 버전 업그레이드 공지

## 결과 기록

### 테스트 일시
- 테스트 날짜: ___________
- 테스트 담당자: ___________

### 설정 상태
- TLS 버전: ___________
- CORS 정책: ___________
- 보안 헤더: ___________

### 발견된 문제
1. ___________
2. ___________
3. ___________

### 조치 사항
1. ___________
2. ___________
3. ___________

## 참고 자료
- [OWASP API8:2023](https://owasp.org/API-Security/editions/2023/en/0xa8-security-misconfiguration/)
- [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)
- [Mozilla Observatory](https://observatory.mozilla.org/)
- [SSL Labs](https://www.ssllabs.com/ssltest/)