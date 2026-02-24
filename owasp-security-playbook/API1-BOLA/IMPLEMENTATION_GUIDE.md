# API1-BOLA 구현 가이드

## 현재 구현 상태

### ✅ 구현 완료
1. **사전 인증 검증 (Pre-Authentication)**
   - X-User-Id 헤더 확인
   - 테스트 모드: 헤더 없으면 경고 로그 + 익명 사용자로 처리
   - 프로덕션 모드: 헤더 없으면 401 반환 (주석 처리됨)

### 🔄 구현 진행 중
2. **사후 소유권 검증 (Post-Authorization)**
   - 현재 제거됨 (비동기 처리 이슈로 인해)
   - 프로덕션 배포 시 다시 추가 필요

## 200 응답 받기

현재 YAML을 배포하면 다음과 같이 200 응답을 받을 수 있습니다:

```bash
# 실제 존재하는 주문 번호로 테스트
curl -X GET "https://api-oxo.a-vir-s1.apiconnect.ipaas.ibmappdomain.cloud/prod906958/sandbox/order/ORD00989792" \
  -H "Accept: application/json" \
  -H "X-IBM-Client-Id: 528f929efc88dd8ae75feeb961b87e1e" \
  -H "X-User-Id: test-user"
```

### 예상 응답 (200 OK):
```json
{
  "order_number": "ORD00989792",
  "status": "SHIPPED",
  "shipped_at": "2026-02-20T05:36:12.058320228Z",
  "tracking_reference": "1Z001985YW90838348",
  "tracking_status": {...},
  "created_at": "2026-02-17T05:36:12.05831904Z"
}
```

## 배포 단계

### 1. API Connect에서 YAML 업데이트
1. API Manager에 로그인
2. API1-BOLA API 선택
3. 수정된 `api1-orders.yaml` 업로드
4. Sandbox 카탈로그에 재배포

### 2. 테스트 실행
```bash
cd owasp-security-playbook/API1-BOLA
./test-script.sh
```

### 3. 200 응답 확인
```bash
# 성공 케이스
curl -X GET "https://api-oxo.a-vir-s1.apiconnect.ipaas.ibmappdomain.cloud/prod906958/sandbox/order/ORD00989792" \
  -H "X-IBM-Client-Id: 528f929efc88dd8ae75feeb961b87e1e" \
  -H "X-User-Id: test-user" \
  -v
```

## BOLA 보호 강화 방안

### Phase 1: 현재 (테스트 모드)
- ✅ 기본 인증 체크
- ✅ 로깅 및 모니터링
- ⚠️ 소유권 검증 없음

### Phase 2: 프로덕션 준비
1. **첫 번째 GatewayScript 수정**
   ```javascript
   // 주석 해제하여 엄격한 인증 활성화
   if (!userId) {
       context.reject('Unauthorized', 'User authentication required');
       context.message.statusCode = 401;
   }
   ```

2. **소유권 검증 추가 (map 정책 이후)**
   ```javascript
   - gatewayscript:
       version: 2.0.0
       title: "Validate Order Ownership"
       source: |
         var userId = context.get('validated.user.id');
         var orderData = context.get('order.body');
         
         // 주문 소유자 확인 (백엔드에 user_id 필드 필요)
         if (orderData.user_id && orderData.user_id !== userId) {
             context.reject('Forbidden', 'Access denied');
             context.message.statusCode = 403;
         }
   ```

3. **데이터베이스 연동**
   - 백엔드 API에 user_id 필드 추가
   - 주문 생성 시 사용자 ID 저장
   - 조회 시 소유권 검증

### Phase 3: 고급 보안
1. **JWT 토큰 통합**
   - OAuth 2.0 / OpenID Connect
   - JWT에서 사용자 ID 추출
   - 토큰 검증 정책 추가

2. **Rate Limiting**
   - 사용자당 요청 제한
   - BOLA 공격 패턴 탐지

3. **Analytics & Monitoring**
   - 403 에러 모니터링
   - 비정상 접근 패턴 알림
   - Invision 연동

## 테스트 시나리오

### 시나리오 1: 정상 접근 (200 OK)
```bash
curl "https://api.../order/ORD00989792" \
  -H "X-IBM-Client-Id: xxx" \
  -H "X-User-Id: owner-user"
# 예상: 200 OK + 주문 데이터
```

### 시나리오 2: 인증 없음 (401 Unauthorized)
```bash
curl "https://api.../order/ORD00989792" \
  -H "X-IBM-Client-Id: xxx"
# 예상: 401 Unauthorized (프로덕션 모드)
```

### 시나리오 3: BOLA 공격 (403 Forbidden)
```bash
curl "https://api.../order/ORD00989792" \
  -H "X-IBM-Client-Id: xxx" \
  -H "X-User-Id: attacker-user"
# 예상: 403 Forbidden (소유권 검증 활성화 시)
```

### 시나리오 4: 존재하지 않는 주문 (404 Not Found)
```bash
curl "https://api.../order/INVALID123" \
  -H "X-IBM-Client-Id: xxx" \
  -H "X-User-Id: test-user"
# 예상: 404 Not Found
```

## 문제 해결

### 401 에러가 계속 발생하는 경우
1. X-User-Id 헤더 추가 확인
2. API가 최신 버전으로 배포되었는지 확인
3. 캐시 클리어 후 재시도

### 404 에러가 발생하는 경우
1. 주문 번호 확인 (ORD00989792 사용)
2. API 경로 확인 (/order/{orderNumber})
3. 백엔드 API 상태 확인

### 200 응답을 받지 못하는 경우
1. 두 번째 GatewayScript 제거 확인
2. API 재배포
3. 브라우저/클라이언트 캐시 클리어

## 참고 자료
- [OWASP API1:2023](https://owasp.org/API-Security/editions/2023/en/0xa1-broken-object-level-authorization/)
- [IBM API Connect GatewayScript](https://www.ibm.com/docs/en/api-connect/10.0.x?topic=constructs-gatewayscript)
- [DataPower Context API](https://www.ibm.com/docs/en/datapower-gateway/10.0.x)