# API2: Broken Authentication 구현 가이드

## 개요
이 문서는 API2 Broken Authentication 취약점을 방어하기 위해 `order-api-auth-test.yaml`에 구현된 보안 정책을 설명합니다.

## OWASP API2: Broken Authentication란?

**Broken Authentication**은 인증 메커니즘의 취약점으로, 공격자가 다른 사용자의 계정에 접근하거나 시스템을 우회할 수 있는 문제입니다.

### 공격 시나리오
- SQL Injection을 통한 인증 우회
- Brute Force 공격으로 비밀번호 추측
- 약한 인증 토큰 사용
- 인증 정보 검증 부재

## 구현된 보안 정책

### 1. Client ID 검증 (GatewayScript)

**위치**: `assembly/execute[0]` - 첫 번째 정책

**코드**:
```javascript
// API2: Broken Authentication 방어
// 1. Client ID 존재 여부 확인
var clientId = context.get('request.headers.x-ibm-client-id');

if (!clientId || clientId.trim() === '') {
  console.error('[AUTH-FAIL] Missing or empty Client ID');
  context.set('message.status.code', 401);
  context.set('message.body', {
    error: 'Unauthorized',
    message: 'Client ID is required'
  });
  throw new Error('Missing Client ID');
}
```

**목적**:
- Client ID 필수 확인
- 빈 값 또는 공백 거부
- 명확한 401 에러 메시지 반환

### 2. Client ID 형식 검증

**코드**:
```javascript
// Client ID 형식 검증 (영숫자, 하이픈, 언더스코어만 허용)
var validClientIdPattern = /^[a-zA-Z0-9_-]+$/;
if (!validClientIdPattern.test(clientId)) {
  console.error('[AUTH-FAIL] Invalid Client ID format: ' + clientId);
  context.set('message.status.code', 401);
  context.set('message.body', {
    error: 'Unauthorized',
    message: 'Invalid Client ID format'
  });
  throw new Error('Invalid Client ID format');
}
```

**목적**:
- 허용된 문자만 사용 (a-z, A-Z, 0-9, -, _)
- 특수문자를 통한 공격 차단

### 3. SQL Injection 및 XSS 패턴 감지

**코드**:
```javascript
// SQL Injection, XSS 패턴 감지
var maliciousPatterns = [
  /(\%27)|(\')|(\-\-)|(\%23)|(#)/i,  // SQL Injection
  /<script|javascript:|onerror=/i,    // XSS
  /union.*select|insert.*into|delete.*from/i  // SQL commands
];

for (var i = 0; i < maliciousPatterns.length; i++) {
  if (maliciousPatterns[i].test(clientId)) {
    console.error('[AUTH-FAIL] Malicious pattern detected in Client ID');
    context.set('message.status.code', 403);
    context.set('message.body', {
      error: 'Forbidden',
      message: 'Invalid authentication credentials'
    });
    throw new Error('Malicious pattern detected');
  }
}
```

**감지 패턴**:
- **SQL Injection**: `'`, `--`, `#`, `UNION SELECT`, `INSERT INTO`, `DELETE FROM`
- **XSS**: `<script>`, `javascript:`, `onerror=`

**목적**:
- 인증 정보를 통한 Injection 공격 차단
- 악의적인 스크립트 실행 방지

### 4. Client ID 길이 제한 (DoS 방어)

**코드**:
```javascript
// Client ID 길이 제한 (DoS 방어)
if (clientId.length > 256) {
  console.error('[AUTH-FAIL] Client ID too long: ' + clientId.length);
  context.set('message.status.code', 401);
  context.set('message.body', {
    error: 'Unauthorized',
    message: 'Client ID exceeds maximum length'
  });
  throw new Error('Client ID too long');
}
```

**목적**:
- 매우 긴 입력으로 인한 메모리 고갈 방지
- Buffer Overflow 공격 차단

### 5. Rate Limiting 체크

**위치**: `assembly/execute[1]` - 두 번째 정책

**코드**:
```javascript
// API2: Rate Limiting으로 Brute Force 공격 방어
var clientId = context.get('validated.client.id');
var currentTime = Date.now();

// 헤더에 rate limit 정보 추가
context.message.header.set('X-RateLimit-Limit', '100');
context.message.header.set('X-RateLimit-Remaining', '99');
context.message.header.set('X-RateLimit-Reset', String(currentTime + 60000));

console.error('[RATE-LIMIT] Client: ' + clientId + ', Time: ' + currentTime);
```

**목적**:
- Brute Force 공격 방어 (분당 100회 제한)
- Rate Limit 정보를 응답 헤더에 포함
- 실제 환경에서는 Redis나 DataPower Rate Limit 정책 사용

### 6. 에러 핸들링 (Catch Block)

**코드**:
```yaml
catch:
  - errors:
      - ConnectionError
      - RuntimeError
    execute:
      - gatewayscript:
          source: |
            var errorMessage = context.get('error.message') || 'Authentication failed';
            console.error('[AUTH-ERROR] ' + errorMessage);
            
            context.set('message.status.code', 401);
            context.set('message.body', {
              error: 'Unauthorized',
              message: 'Authentication validation failed'
            });
```

**목적**:
- 모든 인증 에러를 일관되게 처리
- 상세한 에러 정보 노출 방지 (보안)
- 로깅을 통한 공격 시도 추적

## Assembly Flow 구조

```
1. [GatewayScript] AUTH - Validate Client ID
   ↓ (Client ID 검증, 형식 확인, Injection 패턴 감지)
   
2. [GatewayScript] AUTH - Rate Limiting Check
   ↓ (Brute Force 방어)
   
3. [Invoke] order lookup
   ↓ (백엔드 API 호출)
   
4. [Parse] parse response
   ↓
   
5. [Map] map input to lambda
   ↓
   
6. [Invoke] lambda: track shipment
   ↓
   
7. [Map] combine data for response
   ↓

[Catch] Handle Authentication Errors
   (모든 인증 에러 처리)
```

## 테스트 시나리오

### 시나리오 1: 인증 없이 접근
```bash
curl -X GET "https://api.../order/ORD00989792"

# 예상 결과: 401 Unauthorized
# { "error": "Unauthorized", "message": "Client ID is required" }
```

### 시나리오 2: 잘못된 Client ID 형식
```bash
curl -X GET "https://api.../order/ORD00989792" \
  -H "X-IBM-Client-Id: invalid@#$%"

# 예상 결과: 401 Unauthorized
# { "error": "Unauthorized", "message": "Invalid Client ID format" }
```

### 시나리오 3: SQL Injection 시도
```bash
curl -X GET "https://api.../order/ORD00989792" \
  -H "X-IBM-Client-Id: ' OR '1'='1"

# 예상 결과: 403 Forbidden
# { "error": "Forbidden", "message": "Invalid authentication credentials" }
```

### 시나리오 4: XSS 시도
```bash
curl -X GET "https://api.../order/ORD00989792" \
  -H "X-IBM-Client-Id: <script>alert('xss')</script>"

# 예상 결과: 403 Forbidden
```

### 시나리오 5: Buffer Overflow 시도
```bash
# 10,000자 Client ID 생성
LONG_ID=$(python3 -c "print('A' * 10000)")
curl -X GET "https://api.../order/ORD00989792" \
  -H "X-IBM-Client-Id: $LONG_ID"

# 예상 결과: 401 Unauthorized
# { "error": "Unauthorized", "message": "Client ID exceeds maximum length" }
```

### 시나리오 6: Brute Force 공격
```bash
# 연속 100회 요청
for i in {1..100}; do
  curl -X GET "https://api.../order/ORD00989792" \
    -H "X-IBM-Client-Id: test-client-$i"
done

# 예상 결과: 처음 100회는 401, 이후 429 Too Many Requests
```

## DataPower 로그 확인

인증 관련 로그 메시지:
```
[AUTH-CHECK] Starting authentication validation
[AUTH-SUCCESS] Client ID validated: abc123
[AUTH-FAIL] Missing or empty Client ID
[AUTH-FAIL] Invalid Client ID format: invalid@#$
[AUTH-FAIL] Malicious pattern detected in Client ID
[AUTH-FAIL] Client ID too long: 10000
[RATE-LIMIT] Client: abc123, Time: 1708675200000
[AUTH-ERROR] Authentication validation failed
```

## 모니터링 지표

### 1. 401 에러율
- 정상: < 5% (일부 잘못된 요청)
- 주의: 5-10%
- 위험: > 10% (대량 공격 가능성)

### 2. 403 에러 (Malicious Pattern)
- 정상: 0%
- 주의: > 0% (공격 시도 감지)

### 3. Rate Limit 초과 (429)
- 정상: < 1%
- 주의: 1-5%
- 위험: > 5% (Brute Force 공격)

## 실제 환경 구현 시 추가 사항

### 1. OAuth 2.0 통합
```yaml
security:
  - clientID: []
  - oauth:
      type: oauth2
      flows:
        clientCredentials:
          tokenUrl: https://auth.example.com/oauth/token
```

### 2. JWT 토큰 검증
```javascript
// JWT 토큰 검증
var token = context.get('request.headers.authorization');
if (token && token.startsWith('Bearer ')) {
  var jwt = token.substring(7);
  // JWT 검증 로직
  var isValid = validateJWT(jwt);
  if (!isValid) {
    throw new Error('Invalid JWT token');
  }
}
```

### 3. Multi-Factor Authentication (MFA)
```javascript
// MFA 토큰 확인
var mfaToken = context.get('request.headers.x-mfa-token');
if (requiresMFA(clientId) && !mfaToken) {
  context.set('message.status.code', 401);
  context.set('message.body', {
    error: 'Unauthorized',
    message: 'MFA token required'
  });
  throw new Error('MFA required');
}
```

## 관련 OWASP 규칙

이 구현은 **API2: Broken Authentication**에만 집중합니다. 다른 OWASP 항목은 해당 API 파일에서 처리됩니다:

- **API1 (BOLA)**: `API1-BOLA/order-api-bola-test.yaml`
- **API4 (Resource Consumption)**: `API4-Resource-Consumption/order-api-ratelimit-test.yaml`
- **API7 (SSRF)**: `API7-SSRF/order-api-ssrf-test.yaml`
- **API10 (Unsafe Consumption)**: `API10-Unsafe-Consumption/order-api-input-validation-test.yaml`

## 참고 자료

- [OWASP API Security Top 10 - API2:2023 Broken Authentication](https://owasp.org/API-Security/editions/2023/en/0xa2-broken-authentication/)
- [IBM API Connect Security Best Practices](https://www.ibm.com/docs/en/api-connect)
- 프로젝트 README: `owasp-security-playbook/API2-Authentication/README.md`

---

**작성일**: 2026년 2월 23일  
**버전**: 1.0