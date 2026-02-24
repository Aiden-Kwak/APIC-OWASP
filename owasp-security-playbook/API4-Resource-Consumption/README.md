# API4: Unrestricted Resource Consumption (비제한적 자원소비)

## 개요
API 호출 횟수나 데이터 크기에 제한이 없어 시스템 자원을 고갈(DoS)시키거나 또는 비용 사용량을 발생시키는 취약점

## IBM API Connect 대응 방안

### 1. Rate Limiting 및 Quota Enforcement
- 레이트 리미팅(Rate Limiting) 및 할당량 집행(Quota Enforcement) 정책을 통해 초당 호출 횟수를 제한
- 또한 페이로드 크기 제한, XML/JSON 파서 제한, 숫자 값(Net limit) 제한 등을 통해 백엔드 자원의 고갈을 방지

### 2. AI Gateway 상상선 토큰 수
- Tokenization 단위로 할당량을 관리하여 비용 측정을 방지

## 검증 체크리스트

### 사전 준비
- [ ] Rate Limit 정책 설정 확인
- [ ] Quota 설정 확인
- [ ] 부하 테스트 도구 준비 (ab, wrk, JMeter 등)
- [ ] 모니터링 도구 설정

### Rate Limiting 검증

#### ✅ 시나리오 1: 분당 요청 제한
- [ ] Rate Limit 설정 확인 (예: 100 req/min)
- [ ] 제한 이하로 요청 (정상 동작 확인)
- [ ] 제한 초과 요청 시도
- [ ] 예상 결과: 429 Too Many Requests
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 2: 시간당 요청 제한
- [ ] Rate Limit 설정 확인 (예: 1000 req/hour)
- [ ] 제한 초과 요청 시도
- [ ] 예상 결과: 429 Too Many Requests
- [ ] Retry-After 헤더 확인
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 3: Rate Limit 헤더 확인
```
X-Rate-Limit-Limit: 100
X-Rate-Limit-Remaining: 95
X-Rate-Limit-Reset: 1234567890
```
- [ ] 응답 헤더에 Rate Limit 정보 포함 확인
- [ ] Remaining 값이 감소하는지 확인
- [ ] Reset 시간 후 카운터 리셋 확인
- [ ] 통과 여부: [ ] Pass [ ] Fail

### Quota Enforcement 검증

#### ✅ 시나리오 4: 일일 할당량
- [ ] 일일 할당량 설정 확인 (예: 10,000 req/day)
- [ ] 할당량 초과 요청 시도
- [ ] 예상 결과: 429 Too Many Requests
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 5: 월간 할당량
- [ ] 월간 할당량 설정 확인
- [ ] 할당량 소진 시 동작 확인
- [ ] 통과 여부: [ ] Pass [ ] Fail

### 페이로드 크기 제한

#### ✅ 시나리오 6: 요청 본문 크기 제한
- [ ] 최대 요청 크기 설정 확인 (예: 1MB)
- [ ] 제한 이하 크기로 요청 (정상)
- [ ] 제한 초과 크기로 요청
- [ ] 예상 결과: 413 Payload Too Large
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 7: 응답 크기 제한
- [ ] 최대 응답 크기 설정 확인
- [ ] 대용량 데이터 요청 시 제한 확인
- [ ] 통과 여부: [ ] Pass [ ] Fail

### 배열 및 컬렉션 제한

#### ✅ 시나리오 8: 배열 크기 제한
```json
POST /orders
{
  "items": [
    // 100개 항목 (정상)
  ]
}
```
- [ ] 최대 배열 크기 설정 (예: maxItems: 100)
- [ ] 제한 초과 배열 전송 시도
- [ ] 예상 결과: 400 Bad Request
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 9: 페이지네이션
- [ ] 페이지 크기 제한 확인 (예: max 100 items)
- [ ] 과도한 페이지 크기 요청 시도
- [ ] 예상 결과: 제한된 크기로 응답 또는 400 에러
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

### 동시 연결 제한

#### ✅ 시나리오 10: 동시 요청 제한
- [ ] 동시 연결 수 제한 설정 확인
- [ ] 다수의 동시 요청 전송
- [ ] 제한 초과 시 대기 또는 거부 확인
- [ ] 통과 여부: [ ] Pass [ ] Fail

### API Connect 설정 검증

#### Assembly 정책 확인
- [ ] ratelimit 정책 존재
- [ ] quota 정책 존재
- [ ] validate 정책으로 크기 제한

#### 예제 Assembly - Rate Limiting
```yaml
assembly:
  execute:
    - ratelimit:
        version: 2.0.0
        title: Rate Limit Protection
        rate-limit:
          - key: client.app.id
            limit: 100
            unit: minute
          - key: client.app.id
            limit: 1000
            unit: hour
        error-message: Rate limit exceeded. Please try again later.
    
    - quota:
        version: 2.0.0
        title: Daily Quota
        quota:
          - key: client.app.id
            limit: 10000
            unit: day
        error-message: Daily quota exceeded.
```

#### 예제 Assembly - 페이로드 크기 제한
```yaml
assembly:
  execute:
    - gatewayscript:
        version: 2.0.0
        title: Check Payload Size
        source: |
          var contentLength = context.get('request.headers.content-length');
          var maxSize = 1048576; // 1MB
          
          if (contentLength && parseInt(contentLength) > maxSize) {
            context.reject('PayloadTooLarge', 'Request body too large');
            context.message.statusCode = '413';
            context.message.headers.set('Retry-After', '3600');
          }
    
    - validate:
        version: 2.0.0
        title: Validate Request
        definition: api-definition
        output: validation.output
```

#### 예제 - OpenAPI 스키마 제한
```yaml
components:
  schemas:
    OrderRequest:
      type: object
      properties:
        items:
          type: array
          maxItems: 100        # 최대 100개
          items:
            type: object
        notes:
          type: string
          maxLength: 500       # 최대 500자
        quantity:
          type: integer
          minimum: 1
          maximum: 999         # 최대 999개
```

### AI Gateway Tokenization

#### ✅ 시나리오 11: 토큰 기반 할당량
- [ ] AI 모델 호출 시 토큰 수 측정
- [ ] 토큰 기반 할당량 설정 확인
- [ ] 할당량 초과 시 차단 확인
- [ ] 통과 여부: [ ] Pass [ ] Fail

## 테스트 명령어

### Apache Bench (ab) 테스트
```bash
# 분당 150개 요청 (100개 제한 초과)
ab -n 150 -c 10 \
  -H "X-IBM-Client-Id: ${CLIENT_ID}" \
  https://api.example.com/orders

# 결과 확인
# - 100개는 200 OK
# - 50개는 429 Too Many Requests
```

### wrk 부하 테스트
```bash
# 10개 스레드, 100개 연결, 30초 동안
wrk -t10 -c100 -d30s \
  -H "X-IBM-Client-Id: ${CLIENT_ID}" \
  https://api.example.com/orders

# 결과에서 429 응답 확인
```

### curl 테스트 - Rate Limit 헤더
```bash
# Rate Limit 헤더 확인
for i in {1..10}; do
  echo "Request #${i}:"
  curl -s -D - -o /dev/null \
    -H "X-IBM-Client-Id: ${CLIENT_ID}" \
    https://api.example.com/orders | \
    grep -i "x-rate-limit"
  sleep 1
done
```

### Python 테스트 - Rate Limiting
```python
import requests
import time

url = 'https://api.example.com/orders'
headers = {'X-IBM-Client-Id': 'your-client-id'}

success_count = 0
rate_limited_count = 0

# 150개 요청 전송
for i in range(150):
    response = requests.get(url, headers=headers)
    
    if response.status_code == 200:
        success_count += 1
    elif response.status_code == 429:
        rate_limited_count += 1
        print(f"Rate limited at request #{i+1}")
        
        # Retry-After 헤더 확인
        retry_after = response.headers.get('Retry-After')
        print(f"Retry after: {retry_after} seconds")
        break
    
    time.sleep(0.1)

print(f"Success: {success_count}, Rate Limited: {rate_limited_count}")
assert rate_limited_count > 0, "Rate limiting not working!"
```

### 대용량 페이로드 테스트
```bash
# 1MB 초과 파일 생성
dd if=/dev/zero of=large_payload.json bs=1M count=2

# 대용량 페이로드 전송
curl -X POST "https://api.example.com/upload" \
  -H "X-IBM-Client-Id: ${CLIENT_ID}" \
  -H "Content-Type: application/json" \
  -d @large_payload.json

# 예상: 413 Payload Too Large
```

## 보안 설정 체크리스트

### Rate Limiting 설정
- [ ] 분당 제한 설정
- [ ] 시간당 제한 설정
- [ ] 일일 제한 설정
- [ ] 클라이언트별 제한 설정
- [ ] Rate Limit 헤더 활성화

### Quota 설정
- [ ] 일일 할당량 설정
- [ ] 월간 할당량 설정
- [ ] 플랜별 할당량 차등 설정
- [ ] 할당량 초과 시 알림 설정

### 크기 제한
- [ ] 최대 요청 크기 설정
- [ ] 최대 응답 크기 설정
- [ ] 배열 크기 제한 (maxItems)
- [ ] 문자열 길이 제한 (maxLength)
- [ ] 숫자 범위 제한 (minimum/maximum)

### 모니터링
- [ ] Rate Limit 초과 알림 설정
- [ ] Quota 소진 알림 설정
- [ ] 비정상 트래픽 탐지
- [ ] 대시보드 구성

## 결과 기록

### 테스트 일시
- 테스트 날짜: ___________
- 테스트 담당자: ___________

### Rate Limit 설정
- 분당 제한: ___________
- 시간당 제한: ___________
- 일일 제한: ___________

### 발견된 문제
1. ___________
2. ___________
3. ___________

### 조치 사항
1. ___________
2. ___________
3. ___________

## 참고 자료
- [OWASP API4:2023](https://owasp.org/API-Security/editions/2023/en/0xa4-unrestricted-resource-consumption/)
- [IBM API Connect Rate Limiting](https://www.ibm.com/docs/en/api-connect/10.0.x?topic=constructs-rate-limit)
- [HTTP 429 Too Many Requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/429)