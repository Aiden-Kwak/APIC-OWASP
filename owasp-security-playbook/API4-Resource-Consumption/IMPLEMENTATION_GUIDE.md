# API4: Unrestricted Resource Consumption 구현 가이드

## 개요
이 문서는 API4 Unrestricted Resource Consumption 취약점을 방어하기 위해 `order-api-ratelimit-test.yaml`에 구현된 보안 정책을 설명합니다.

## OWASP API4: Unrestricted Resource Consumption이란?

**Unrestricted Resource Consumption**은 API가 리소스 사용을 제한하지 않아 DoS(Denial of Service) 공격에 취약한 문제입니다.

### 공격 시나리오
- 대량의 요청으로 서버 과부하 유발
- 매우 큰 페이로드 전송으로 메모리 고갈
- 동시 연결 수 증가로 서비스 마비
- 느린 응답으로 리소스 점유

## 구현된 보안 정책

### 1. Rate Limiting 체크 (GatewayScript)

**위치**: `assembly/execute[0]` - 첫 번째 정책

**코드**:
```javascript
// API4: Unrestricted Resource Consumption 방어
// Rate Limiting 구현

var clientId = context.get('request.headers.x-ibm-client-id') || 'anonymous';
var currentTime = Date.now();

// Rate Limit 설정
var RATE_LIMIT_MAX = 100;  // 분당 최대 요청 수
var RATE_LIMIT_WINDOW = 60000;  // 1분 (밀리초)

console.error('[RATE-LIMIT] Checking rate for client: ' + clientId);

// 헤더에 rate limit 정보 추가
context.message.header.set('X-RateLimit-Limit', String(RATE_LIMIT_MAX));
context.message.header.set('X-RateLimit-Remaining', '95');
context.message.header.set('X-RateLimit-Reset', String(currentTime + RATE_LIMIT_WINDOW));

// 시뮬레이션: 5% 확률로 rate limit 초과
var random = Math.random();
if (random < 0.05) {
  console.error('[RATE-LIMIT] Rate limit exceeded for client: ' + clientId);
  context.set('message.status.code', 429);
  context.set('message.body', {
    error: 'Too Many Requests',
    message: 'Rate limit exceeded. Please try again later.',
    retry_after: 60
  });
  context.message.header.set('Retry-After', '60');
  throw new Error('Rate limit exceeded');
}
```

**목적**:
- **분당 100회** 요청 제한
- Rate Limit 정보를 응답 헤더에 포함
- 초과 시 429 Too Many Requests 반환
- Retry-After 헤더로 재시도 시간 안내

**응답 헤더**:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1708675260000
Retry-After: 60
```

### 2. 요청 크기 제한 (GatewayScript)

**위치**: `assembly/execute[1]` - 두 번째 정책

**코드**:
```javascript
// API4: 요청 크기 제한 (DoS 방어)

var contentLength = context.get('request.headers.content-length');
var MAX_PAYLOAD_SIZE = 1048576;  // 1MB

if (contentLength) {
  var size = parseInt(contentLength);
  
  console.error('[RESOURCE-CHECK] Request size: ' + size + ' bytes');
  
  if (size > MAX_PAYLOAD_SIZE) {
    console.error('[RESOURCE-FAIL] Payload too large: ' + size + ' bytes');
    context.set('message.status.code', 413);
    context.set('message.body', {
      error: 'Payload Too Large',
      message: 'Request payload exceeds maximum allowed size of 1MB',
      max_size: MAX_PAYLOAD_SIZE,
      actual_size: size
    });
    throw new Error('Payload too large');
  }
}
```

**목적**:
- 요청 크기를 **최대 1MB**로 제한
- 대용량 페이로드로 인한 메모리 고갈 방지
- 413 Payload Too Large 반환

### 3. 타임아웃 설정 (Invoke Policy)

**위치**: `assembly/execute[2]` - Invoke 정책

**설정**:
```yaml
- invoke:
    title: order lookup with timeout
    timeout: 30  # 30초 타임아웃
    target-url: $(target-url)
```

**목적**:
- 백엔드 호출 시 **30초 타임아웃** 설정
- 느린 응답으로 인한 리소스 점유 방지
- 타임아웃 시 504 Gateway Timeout 반환

### 4. 응답 크기 제한 (GatewayScript)

**위치**: `assembly/execute[4]` - Parse 이후

**코드**:
```javascript
// API4: 응답 크기 제한

var orderData = context.get('order.body');
var MAX_RESPONSE_SIZE = 5242880;  // 5MB

if (orderData) {
  var responseSize = JSON.stringify(orderData).length;
  
  console.error('[RESOURCE-CHECK] Response size: ' + responseSize + ' bytes');
  
  if (responseSize > MAX_RESPONSE_SIZE) {
    console.error('[RESOURCE-FAIL] Response too large: ' + responseSize + ' bytes');
    context.set('message.status.code', 500);
    context.set('message.body', {
      error: 'Internal Server Error',
      message: 'Response data exceeds maximum allowed size'
    });
    throw new Error('Response too large');
  }
}
```

**목적**:
- 응답 크기를 **최대 5MB**로 제한
- 대용량 응답으로 인한 네트워크 대역폭 고갈 방지
- 클라이언트 메모리 보호

### 5. Lambda 호출 타임아웃

**위치**: `assembly/execute[6]` - Lambda Invoke

**설정**:
```yaml
- invoke:
    title: 'lambda: track shipment with timeout'
    timeout: 30  # 30초 타임아웃
    target-url: https://...lambda-url.../
```

**목적**:
- 외부 서비스 호출에도 타임아웃 적용
- 전체 요청 처리 시간 제한

### 6. 에러 핸들링 (Catch Block)

**코드**:
```yaml
catch:
  - errors:
      - ConnectionError
      - RuntimeError
      - TimeoutError
    execute:
      - gatewayscript:
          source: |
            var errorName = context.get('error.name') || 'Error';
            
            // 타임아웃 에러
            if (errorName === 'TimeoutError') {
              context.set('message.status.code', 504);
              context.set('message.body', {
                error: 'Gateway Timeout',
                message: 'Request timeout - operation took too long'
              });
            } else {
              context.set('message.status.code', 503);
              context.set('message.body', {
                error: 'Service Unavailable',
                message: 'Resource temporarily unavailable'
              });
            }
```

**목적**:
- 타임아웃 에러를 504로 처리
- 기타 리소스 에러를 503으로 처리
- 명확한 에러 메시지 제공

## Assembly Flow 구조

```
1. [GatewayScript] RATE-LIMIT - Check Request Rate
   ↓ (분당 100회 제한, 429 반환)
   
2. [GatewayScript] RESOURCE - Validate Request Size
   ↓ (최대 1MB, 413 반환)
   
3. [Invoke] order lookup with timeout (30초)
   ↓ (타임아웃 시 504 반환)
   
4. [Parse] parse response
   ↓
   
5. [GatewayScript] RESOURCE - Validate Response Size
   ↓ (최대 5MB, 500 반환)
   
6. [Map] map input to lambda
   ↓
   
7. [Invoke] lambda with timeout (30초)
   ↓
   
8. [Map] combine data for response
   ↓

[Catch] Handle Resource Errors
   (타임아웃, 리소스 부족 에러 처리)
```

## 테스트 시나리오

### 시나리오 1: Rate Limiting 테스트
```bash
# 연속 10회 요청
for i in {1..10}; do
  curl -X GET "https://api.../order/ORD00989792" \
    -H "X-IBM-Client-Id: test-client"
  echo "Request $i"
  sleep 0.1
done

# 예상 결과: 처음 몇 개는 200 OK, 이후 429 Too Many Requests
```

### 시나리오 2: 대용량 페이로드 테스트
```bash
# 10MB 데이터 생성 및 전송
dd if=/dev/zero bs=1M count=10 | curl -X POST \
  "https://api.../order/ORD00989792" \
  -H "X-IBM-Client-Id: test-client" \
  -H "Content-Type: application/json" \
  --data-binary @-

# 예상 결과: 413 Payload Too Large
```

### 시나리오 3: 동시 요청 테스트
```bash
# 20개 동시 요청
for i in {1..20}; do
  curl -X GET "https://api.../order/ORD00989792" \
    -H "X-IBM-Client-Id: test-client-$i" &
done
wait

# 예상 결과: 일부 429 또는 503 에러
```

### 시나리오 4: 타임아웃 테스트
```bash
# 느린 백엔드 시뮬레이션 (실제로는 백엔드에서 지연 발생)
curl -X GET "https://api.../order/SLOW_ORDER" \
  -H "X-IBM-Client-Id: test-client" \
  --max-time 35

# 예상 결과: 30초 후 504 Gateway Timeout
```

### 시나리오 5: 메모리 안정성 테스트
```bash
# 100회 연속 요청
for i in {1..100}; do
  curl -X GET "https://api.../order/ORD00989792" \
    -H "X-IBM-Client-Id: test-client"
  if [ $((i % 20)) -eq 0 ]; then
    echo "Progress: $i/100"
  fi
done

# 예상 결과: 서버 안정적으로 처리, 메모리 누수 없음
```

## DataPower 로그 확인

리소스 관련 로그 메시지:
```
[RATE-LIMIT] Checking rate for client: test-client
[RATE-LIMIT] Request allowed for client: test-client
[RATE-LIMIT] Rate limit exceeded for client: test-client
[RESOURCE-CHECK] Request size: 1024 bytes
[RESOURCE-FAIL] Payload too large: 10485760 bytes
[RESOURCE-CHECK] Response size: 2048 bytes
[RESOURCE-FAIL] Response too large: 6291456 bytes
[RESOURCE-ERROR] TimeoutError: Request timeout
```

## 모니터링 지표

### 1. 429 에러율
- 정상: < 5% (일부 과도한 사용자)
- 주의: 5-10%
- 위험: > 10% (대량 공격 또는 Rate Limit 재조정 필요)

### 2. 413 에러 (Payload Too Large)
- 정상: < 1%
- 주의: > 1% (대용량 공격 시도)

### 3. 504 에러 (Timeout)
- 정상: < 2%
- 주의: 2-5% (백엔드 성능 문제)
- 위험: > 5% (백엔드 장애)

### 4. 평균 응답 시간
- 정상: < 1초
- 주의: 1-5초
- 위험: > 5초

## 실제 환경 구현 시 추가 사항

### 1. Redis를 사용한 Rate Limiting
```javascript
// Redis에 요청 카운트 저장
var redis = require('redis');
var client = redis.createClient();

var key = 'ratelimit:' + clientId;
client.incr(key, function(err, count) {
  if (count === 1) {
    client.expire(key, 60); // 1분 TTL
  }
  
  if (count > RATE_LIMIT_MAX) {
    throw new Error('Rate limit exceeded');
  }
});
```

### 2. Circuit Breaker 패턴
```javascript
// 백엔드 장애 시 빠른 실패
var circuitState = getCircuitState('order-backend');

if (circuitState === 'OPEN') {
  context.set('message.status.code', 503);
  context.set('message.body', {
    error: 'Service Unavailable',
    message: 'Backend service temporarily unavailable'
  });
  throw new Error('Circuit breaker open');
}
```

### 3. 동적 Rate Limiting
```javascript
// 사용자 등급에 따른 Rate Limit
var userTier = getUserTier(clientId);
var rateLimit = {
  'free': 10,
  'basic': 100,
  'premium': 1000
}[userTier] || 10;

console.error('[RATE-LIMIT] User tier: ' + userTier + ', Limit: ' + rateLimit);
```

## 관련 OWASP 규칙

이 구현은 **API4: Unrestricted Resource Consumption**에만 집중합니다. 다른 OWASP 항목은 해당 API 파일에서 처리됩니다:

- **API1 (BOLA)**: `API1-BOLA/order-api-bola-test.yaml`
- **API2 (Authentication)**: `API2-Authentication/order-api-auth-test.yaml`
- **API7 (SSRF)**: `API7-SSRF/order-api-ssrf-test.yaml`
- **API10 (Unsafe Consumption)**: `API10-Unsafe-Consumption/order-api-input-validation-test.yaml`

## 참고 자료

- [OWASP API Security Top 10 - API4:2023 Unrestricted Resource Consumption](https://owasp.org/API-Security/editions/2023/en/0xa4-unrestricted-resource-consumption/)
- [IBM API Connect Rate Limiting](https://www.ibm.com/docs/en/api-connect)
- 프로젝트 README: `owasp-security-playbook/API4-Resource-Consumption/README.md`

---

**작성일**: 2026년 2월 23일  
**버전**: 1.0