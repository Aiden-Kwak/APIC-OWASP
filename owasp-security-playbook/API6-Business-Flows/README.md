# API6: Unrestricted Access to Sensitive Business Flows (민감한 비즈니스 흐름에 대한 무제한 접근)

## 개요
구현상의 버그가 없더라도 티켓 예매나 댓글 게시와 같은 비즈니스 흐름을 자동화하여 도용하는 취약점

## IBM API Connect 대응 방안

### Quota Enforcement 정책
- Quota Enforcement 정책을 통해 비즈니스 단위별 이용량을 통제
- APIs 하나 이상의 플랜에 포함되어 호출 제한 및 Engagement 기능을 활용하여 특정 API에서 에러를 리턴하거나 호출 패턴이 일반적인 범위를 벗어난 경우 알림

## 검증 체크리스트

### 사전 준비
- [ ] 민감한 비즈니스 플로우 식별
- [ ] 정상 사용 패턴 정의
- [ ] 비정상 패턴 탐지 규칙 정의

### 자동화 공격 방지

#### ✅ 시나리오 1: 티켓 예매 자동화
```
POST /tickets/purchase
- 짧은 시간에 다수 구매 시도
- 동일 IP에서 반복 요청
```
- [ ] 1분 내 5회 이상 구매 시도
- [ ] 예상 결과: 429 Too Many Requests 또는 차단
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 2: 계정 생성 자동화
```
POST /users/register
- 동일 IP에서 다수 계정 생성
- 유사한 패턴의 정보
```
- [ ] 1시간 내 10개 이상 계정 생성 시도
- [ ] 예상 결과: Rate limiting 또는 CAPTCHA 요구
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 3: 댓글/리뷰 스팸
```
POST /products/{id}/reviews
- 짧은 시간에 다수 리뷰 작성
- 동일 내용 반복
```
- [ ] 1분 내 5개 이상 리뷰 작성 시도
- [ ] 예상 결과: Rate limiting
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

### Idempotency Key 검증

#### ✅ 시나리오 4: 중복 요청 방지
```
POST /orders
Headers:
  X-Idempotency-Key: unique-key-123
```
- [ ] 동일한 Idempotency Key로 재요청
- [ ] 예상 결과: 기존 결과 반환, 중복 생성 안됨
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 5: Idempotency Key 없이 요청
- [ ] 중요한 작업에 Idempotency Key 필수 확인
- [ ] 없을 경우 400 Bad Request
- [ ] 통과 여부: [ ] Pass [ ] Fail

### 비즈니스 로직 검증

#### ✅ 시나리오 6: 순서 우회 시도
```
정상 플로우:
1. POST /cart/add
2. POST /cart/checkout
3. POST /payment/process

우회 시도:
1. POST /payment/process (직접 호출)
```
- [ ] 필수 단계 건너뛰기 시도
- [ ] 예상 결과: 400 Bad Request, "Invalid state"
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 7: 가격 조작 방지
```
POST /orders
{
  "items": [
    {"id": "prod-1", "price": 0.01}  // 실제 가격: 100
  ]
}
```
- [ ] 클라이언트가 제공한 가격 무시
- [ ] 서버에서 가격 재계산 확인
- [ ] 통과 여부: [ ] Pass [ ] Fail

### 사용량 기반 제한

#### ✅ 시나리오 8: 일일 작업 제한
```
POST /api/export
- 하루 3회 제한
```
- [ ] 제한 횟수 초과 시도
- [ ] 예상 결과: 429 Too Many Requests
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 9: 사용자별 할당량
- [ ] 무료 사용자: 10 req/day
- [ ] 프리미엄 사용자: 1000 req/day
- [ ] 플랜별 제한 동작 확인
- [ ] 통과 여부: [ ] Pass [ ] Fail

### API Connect 설정 검증

#### Assembly 정책 확인
- [ ] Rate Limiting 정책
- [ ] Quota 정책
- [ ] Idempotency 검증 로직
- [ ] 비즈니스 로직 검증

#### 예제 Assembly - Idempotency Key
```yaml
assembly:
  execute:
    - gatewayscript:
        version: 2.0.0
        title: Check Idempotency Key
        source: |
          var idempotencyKey = context.get('request.headers.x-idempotency-key');
          var method = context.get('request.verb');
          
          // POST, PUT, PATCH에 Idempotency Key 필수
          if (['POST', 'PUT', 'PATCH'].includes(method)) {
            if (!idempotencyKey) {
              context.reject('BadRequest', 'X-Idempotency-Key header required');
              context.message.statusCode = '400';
              return;
            }
            
            // Redis 또는 캐시에서 이전 요청 확인
            // var previousResult = cache.get(idempotencyKey);
            // if (previousResult) {
            //   context.set('message.body', previousResult);
            //   context.message.statusCode = '200';
            //   return;
            // }
          }
    
    - invoke:
        title: Process Request
        target-url: https://backend.example.com/api
        output: backend.response
    
    - gatewayscript:
        version: 2.0.0
        title: Store Idempotency Result
        source: |
          var idempotencyKey = context.get('request.headers.x-idempotency-key');
          var response = context.get('backend.response.body');
          
          if (idempotencyKey) {
            // 결과를 24시간 동안 캐시
            // cache.set(idempotencyKey, response, 86400);
          }
```

#### 예제 Assembly - 비즈니스 플로우 검증
```yaml
assembly:
  execute:
    - gatewayscript:
        version: 2.0.0
        title: Validate Business Flow
        source: |
          var path = context.get('request.path');
          var sessionState = context.get('session.state') || {};
          
          // 결제 처리는 장바구니 체크아웃 후에만 가능
          if (path === '/payment/process') {
            if (!sessionState.checkoutCompleted) {
              context.reject('BadRequest', 'Checkout required before payment');
              context.message.statusCode = '400';
              return;
            }
          }
          
          // 주문 확인은 결제 완료 후에만 가능
          if (path === '/orders/confirm') {
            if (!sessionState.paymentCompleted) {
              context.reject('BadRequest', 'Payment required before confirmation');
              context.message.statusCode = '400';
              return;
            }
          }
    
    - ratelimit:
        version: 2.0.0
        title: Business Flow Rate Limit
        rate-limit:
          - key: client.app.id
            limit: 5
            unit: minute
          - key: client.app.id
            limit: 100
            unit: day
```

#### 예제 - 플랜별 할당량
```yaml
# API 플랜 정의
plans:
  free:
    rate-limits:
      - limit: 10
        unit: day
    quotas:
      - limit: 100
        unit: month
  
  premium:
    rate-limits:
      - limit: 1000
        unit: day
    quotas:
      - limit: 100000
        unit: month
```

## 테스트 명령어

### 자동화 공격 시뮬레이션
```bash
#!/bin/bash
# 티켓 예매 자동화 시도

for i in {1..20}; do
  echo "Purchase attempt #${i}"
  curl -X POST "https://api.example.com/tickets/purchase" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d '{
      "eventId": "event-123",
      "quantity": 1
    }'
  sleep 0.5
done

# 예상: 5-10회 후 429 Too Many Requests
```

### Idempotency Key 테스트
```bash
# 동일한 Idempotency Key로 재요청
IDEMPOTENCY_KEY=$(uuidgen)

# 첫 번째 요청
curl -X POST "https://api.example.com/orders" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Idempotency-Key: ${IDEMPOTENCY_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"productId": "prod-123", "quantity": 1}'

# 동일한 키로 재요청 (중복 생성 안되어야 함)
curl -X POST "https://api.example.com/orders" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Idempotency-Key: ${IDEMPOTENCY_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"productId": "prod-123", "quantity": 1}'
```

### Python 테스트
```python
import requests
import time
from uuid import uuid4

# 자동화 공격 시뮬레이션
url = 'https://api.example.com/tickets/purchase'
headers = {'Authorization': f'Bearer {token}'}

success_count = 0
blocked_count = 0

for i in range(20):
    response = requests.post(
        url,
        headers=headers,
        json={'eventId': 'event-123', 'quantity': 1}
    )
    
    if response.status_code == 201:
        success_count += 1
    elif response.status_code == 429:
        blocked_count += 1
        print(f"Blocked at attempt #{i+1}")
        break
    
    time.sleep(0.5)

print(f"Success: {success_count}, Blocked: {blocked_count}")
assert blocked_count > 0, "No rate limiting detected!"

# Idempotency 테스트
idempotency_key = str(uuid4())

# 첫 번째 요청
response1 = requests.post(
    'https://api.example.com/orders',
    headers={
        'Authorization': f'Bearer {token}',
        'X-Idempotency-Key': idempotency_key
    },
    json={'productId': 'prod-123', 'quantity': 1}
)

order_id1 = response1.json().get('id')

# 동일한 키로 재요청
response2 = requests.post(
    'https://api.example.com/orders',
    headers={
        'Authorization': f'Bearer {token}',
        'X-Idempotency-Key': idempotency_key
    },
    json={'productId': 'prod-123', 'quantity': 1}
)

order_id2 = response2.json().get('id')

# 동일한 주문 ID여야 함
assert order_id1 == order_id2, "Idempotency not working!"
```

## 보안 설정 체크리스트

### 비즈니스 플로우 보호
- [ ] 민감한 플로우 식별
- [ ] 각 플로우별 Rate Limit 설정
- [ ] Idempotency Key 구현
- [ ] 순서 검증 로직 구현

### 자동화 탐지
- [ ] 비정상 패턴 정의
- [ ] 탐지 규칙 구현
- [ ] 알림 설정
- [ ] 자동 차단 메커니즘

### 플랜 관리
- [ ] 플랜별 제한 정의
- [ ] Quota 설정
- [ ] 플랜 업그레이드 프로세스
- [ ] 사용량 모니터링

## 결과 기록

### 테스트 일시
- 테스트 날짜: ___________
- 테스트 담당자: ___________

### 보호 대상 플로우
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
- [OWASP API6:2023](https://owasp.org/API-Security/editions/2023/en/0xa6-unrestricted-access-to-sensitive-business-flows/)
- [Idempotency Patterns](https://stripe.com/docs/api/idempotent_requests)
- [Rate Limiting Strategies](https://cloud.google.com/architecture/rate-limiting-strategies-techniques)