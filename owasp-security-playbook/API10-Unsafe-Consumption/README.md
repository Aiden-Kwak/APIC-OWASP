# API10: Unsafe Consumption of APIs (안전하지 않은 API 소비)

## 개요
서드파티 API로부터 받은 데이터를 신뢰하여 입력 검증 없이 사용하여 발생하는 취약점

## IBM API Connect 대응 방안

### 1. API Analytics 및 DataPower Operations Dashboard (DPOD)
- API 트래픽을 통해 성능을 실시간으로 가시화하고 수집
- 이상 징후를 탐지하여 외부 API 호출 시 Tracing과 Metric 수집이 가능하여 외부 API 문제를 빠르게 파악

### 2. DataPower Nano Gateway
- v12.1에서 도입된 DataPower Nano Gateway는 OpenTelemetry(Otel)을 기본 지원
- 외부 API 호출 시 Tracing 정보를 수집하여 성능 저하 원인 파악

### 3. APIC 통합 서비스
- Ingestion 포트를 수집한 API 이벤트 데이터를 Noname 연동으로 실시간 오프로드할 수 있어 Shadow API를 탐지하고 보안 이상 징후를 발견

## 검증 체크리스트

### 사전 준비
- [ ] 외부 API 목록 작성
- [ ] 각 외부 API의 신뢰도 평가
- [ ] 입력 검증 규칙 정의

### 외부 API 응답 검증

#### ✅ 시나리오 1: 응답 데이터 검증
```json
// 외부 API 응답
{
  "userId": "123",
  "name": "<script>alert('xss')</script>",
  "email": "user@example.com"
}
```
- [ ] 응답 데이터 스키마 검증
- [ ] XSS 패턴 탐지 및 제거
- [ ] SQL Injection 패턴 탐지
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 2: 응답 크기 제한
- [ ] 최대 응답 크기 설정 (예: 10MB)
- [ ] 과도한 크기 응답 차단
- [ ] 메모리 고갈 방지
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 3: 응답 타임아웃
- [ ] 외부 API 타임아웃 설정 (예: 30초)
- [ ] 타임아웃 시 적절한 에러 처리
- [ ] 재시도 로직 구현
- [ ] 통과 여부: [ ] Pass [ ] Fail

### 리다이렉트 처리

#### ✅ 시나리오 4: 오픈 리다이렉트
```
외부 API 응답:
HTTP/1.1 302 Found
Location: http://evil.com/malware
```
- [ ] 리다이렉트 따라가기 비활성화
- [ ] 리다이렉트 목적지 검증
- [ ] 허용된 도메인만 리다이렉트
- [ ] 통과 여부: [ ] Pass [ ] Fail

### 에러 처리

#### ✅ 시나리오 5: 외부 API 장애
```
외부 API: 500 Internal Server Error
```
- [ ] 적절한 폴백 메커니즘
- [ ] 에러 전파 방지
- [ ] 사용자에게 일반적인 에러 메시지
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 6: 부분 장애 처리
```
외부 API 1: 성공
외부 API 2: 실패
외부 API 3: 타임아웃
```
- [ ] 부분 성공 처리
- [ ] Circuit Breaker 패턴 구현
- [ ] 장애 격리
- [ ] 통과 여부: [ ] Pass [ ] Fail

### API Connect 설정 검증

#### Assembly 정책 확인
- [ ] Validate 정책으로 응답 검증
- [ ] 타임아웃 설정
- [ ] 에러 처리 구현

#### 예제 Assembly - 외부 API 안전한 호출
```yaml
assembly:
  execute:
    - invoke:
        version: 2.0.0
        title: Call External API
        target-url: https://external-api.com/endpoint
        timeout: 30
        follow-redirects: false
        backend-type: json
        output: external.response
        stop-on-error:
          - ConnectionError
          - RuntimeError
    
    - gatewayscript:
        version: 2.0.0
        title: Validate External Response
        source: |
          var response = context.get('external.response.body');
          var statusCode = context.get('external.response.statusCode');
          
          // 응답 크기 확인
          var responseSize = JSON.stringify(response).length;
          var maxSize = 10485760; // 10MB
          
          if (responseSize > maxSize) {
            context.reject('PayloadTooLarge', 'External API response too large');
            context.message.statusCode = '502';
            return;
          }
          
          // 상태 코드 확인
          if (statusCode !== '200') {
            console.error('External API error:', statusCode);
            context.reject('BadGateway', 'External API returned error');
            context.message.statusCode = '502';
            return;
          }
          
          // 응답 스키마 검증
          if (!response || typeof response !== 'object') {
            context.reject('BadGateway', 'Invalid response from external API');
            context.message.statusCode = '502';
            return;
          }
          
          // XSS 패턴 제거
          function sanitize(obj) {
            if (typeof obj === 'string') {
              return obj.replace(/<script[^>]*>.*?<\/script>/gi, '')
                       .replace(/<[^>]+>/g, '');
            }
            if (typeof obj === 'object' && obj !== null) {
              for (var key in obj) {
                obj[key] = sanitize(obj[key]);
              }
            }
            return obj;
          }
          
          response = sanitize(response);
          context.set('message.body', response);
  
  catch:
    - gatewayscript:
        version: 2.0.0
        title: Handle External API Error
        source: |
          var error = context.get('error') || {};
          
          console.error('External API call failed:', JSON.stringify(error));
          
          // 사용자에게는 일반적인 메시지만
          context.set('message.body', {
            code: 'SERVICE_UNAVAILABLE',
            message: 'External service temporarily unavailable',
            requestId: context.get('request.headers.x-request-id')
          });
          
          context.message.statusCode = '503';
          context.message.headers.set('Retry-After', '60');
```

#### 예제 - Circuit Breaker 패턴
```yaml
assembly:
  execute:
    - gatewayscript:
        version: 2.0.0
        title: Circuit Breaker Check
        source: |
          // Circuit Breaker 상태 확인 (Redis 또는 캐시 사용)
          var circuitState = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN
          var failureThreshold = 5;
          var timeout = 60; // seconds
          
          // OPEN 상태면 요청 차단
          if (circuitState === 'OPEN') {
            context.reject('ServiceUnavailable', 'Circuit breaker is open');
            context.message.statusCode = '503';
            context.message.headers.set('Retry-After', timeout.toString());
            return;
          }
    
    - invoke:
        title: Call External API
        target-url: https://external-api.com/endpoint
        timeout: 30
        output: external.response
    
    - gatewayscript:
        version: 2.0.0
        title: Circuit Breaker Success
        source: |
          // 성공 시 실패 카운터 리셋
          // resetFailureCount();
  
  catch:
    - gatewayscript:
        version: 2.0.0
        title: Circuit Breaker Failure
        source: |
          // 실패 카운트 증가
          // incrementFailureCount();
          // if (failureCount >= threshold) {
          //   openCircuit();
          // }
          
          context.set('message.body', {
            code: 'SERVICE_UNAVAILABLE',
            message: 'Service temporarily unavailable'
          });
          context.message.statusCode = '503';
```

#### 예제 - 응답 스키마 검증
```yaml
assembly:
  execute:
    - invoke:
        title: Call External API
        target-url: https://external-api.com/users
        output: external.response
    
    - validate:
        version: 2.0.0
        title: Validate External Response
        definition: external-api-schema
        output: validation.output
        
# external-api-schema 정의
components:
  schemas:
    ExternalUserResponse:
      type: object
      required:
        - id
        - name
        - email
      properties:
        id:
          type: string
          pattern: '^[0-9]+$'
        name:
          type: string
          maxLength: 100
          pattern: '^[a-zA-Z\s]+$'
        email:
          type: string
          format: email
          maxLength: 255
        age:
          type: integer
          minimum: 0
          maximum: 150
```

## 테스트 명령어

### 외부 API 응답 검증 테스트
```bash
# 정상 응답
curl -X GET "https://api.example.com/proxy/external-users" \
  -H "Authorization: Bearer ${TOKEN}"

# 예상: 200 OK, 검증된 데이터

# 외부 API 장애 시뮬레이션 (외부 API를 모의로 다운)
# 예상: 503 Service Unavailable
```

### Python 테스트
```python
import requests
import time

# 외부 API 타임아웃 테스트
start = time.time()
try:
    response = requests.get(
        'https://api.example.com/proxy/slow-external-api',
        headers={'Authorization': f'Bearer {token}'},
        timeout=35  # API 타임아웃보다 길게
    )
except requests.Timeout:
    print("Request timed out (expected)")

duration = time.time() - start
assert duration < 35, "API should timeout before client"
print(f"✓ API timed out after {duration:.2f}s")

# XSS 패턴 제거 테스트
malicious_data = {
    'name': '<script>alert("xss")</script>John',
    'bio': '<img src=x onerror=alert(1)>'
}

response = requests.post(
    'https://api.example.com/proxy/external-api',
    headers={'Authorization': f'Bearer {token}'},
    json=malicious_data
)

data = response.json()
assert '<script>' not in str(data), "XSS not sanitized!"
assert '<img' not in str(data), "XSS not sanitized!"
print("✓ XSS patterns removed")

# Circuit Breaker 테스트
failure_count = 0
for i in range(10):
    response = requests.get(
        'https://api.example.com/proxy/failing-external-api',
        headers={'Authorization': f'Bearer {token}'}
    )
    
    if response.status_code == 503:
        failure_count += 1
        if 'Retry-After' in response.headers:
            print(f"✓ Circuit breaker opened after {i} failures")
            break

assert failure_count > 0, "Circuit breaker not working!"
```

## 보안 설정 체크리스트

### 외부 API 호출
- [ ] 타임아웃 설정
- [ ] 리다이렉트 비활성화
- [ ] 응답 크기 제한
- [ ] 재시도 로직 구현

### 응답 검증
- [ ] 스키마 검증
- [ ] XSS 패턴 제거
- [ ] SQL Injection 패턴 제거
- [ ] 데이터 타입 검증

### 에러 처리
- [ ] Circuit Breaker 구현
- [ ] 폴백 메커니즘
- [ ] 적절한 에러 메시지
- [ ] 에러 로깅

### 모니터링
- [ ] 외부 API 응답 시간 추적
- [ ] 실패율 모니터링
- [ ] Circuit Breaker 상태 추적
- [ ] 알림 설정

## 결과 기록

### 테스트 일시
- 테스트 날짜: ___________
- 테스트 담당자: ___________

### 외부 API 목록
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
- [OWASP API10:2023](https://owasp.org/API-Security/editions/2023/en/0xaa-unsafe-consumption-of-apis/)
- [Circuit Breaker Pattern](https://martinfowler.com/bliki/CircuitBreaker.html)
- [OpenTelemetry](https://opentelemetry.io/)
- [IBM DataPower Nano Gateway](https://www.ibm.com/docs/en/datapower-gateway)