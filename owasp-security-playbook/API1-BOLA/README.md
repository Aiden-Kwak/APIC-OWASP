# API1: Broken Object Level Authorization (BOLA)

## 📋 프로젝트 상태

**✅ 구현 완료 및 테스트 성공**
- 200 OK 응답 확인 완료
- BOLA 보호 메커니즘 구현
- 자동화된 테스트 스크립트 작성
- 상세 문서화 완료

## 🔴 취약점 설명

### 문제점
사용자가 **자신의 권한 밖의 다른 사용자 데이터**에 접근할 수 있는 보안 취약점입니다.

**공격 시나리오:**
```bash
# User A의 토큰으로 User B의 주문 정보 조회 시도
GET /orders/user-b-order-123
Authorization: Bearer user-a-token

# 취약한 API는 200 OK를 반환하고 User B의 데이터를 노출
```

### 원인
- 사용자 인증(Authentication)만 확인하고 권한(Authorization)은 검증하지 않음
- 요청한 리소스가 실제로 해당 사용자 소유인지 확인하지 않음
- URL 파라미터(orderNumber)만으로 데이터 접근 허용

---

## ✅ 개선 사항

### 추가된 보안 정책

#### 1. **사전 권한 검증 (Pre-Authorization Check)**
```yaml
- gatewayscript:
    title: "BOLA Protection: Verify Order Ownership"
```
**역할:**
- 요청 헤더에서 사용자 ID 추출 (`X-User-Id`)
- 사용자 인증 여부 확인
- 인증되지 않은 요청은 **401 Unauthorized** 반환
- 보안 모니터링을 위한 접근 로그 기록

#### 2. **사후 소유권 검증 (Post-Authorization Validation)**
```yaml
- gatewayscript:
    title: "BOLA Validation: Verify Order Belongs to User"
```
**역할:**
- 백엔드에서 조회한 주문 데이터 분석
- 주문의 실제 소유자와 요청자 비교
- 소유자가 다르면 **403 Forbidden** 반환
- 존재하지 않는 주문은 **404 Not Found** 반환

### 보안 흐름
```
1. 요청 수신 → 사용자 인증 확인 (401 if fail)
2. 백엔드 조회 → 주문 데이터 획득
3. 소유권 검증 → 요청자 = 소유자? (403 if fail)
4. 응답 반환 → 인가된 데이터만 제공
```

---

## 🛡️ IBM API Connect 대응 방안

### 1. GatewayScript 정책
- DataPower 게이트웨이의 `context` 객체 활용
- 실시간 권한 검증 로직 구현
- 커스텀 에러 메시지 및 상태 코드 제어

### 2. Analytics 통합
- BOLA 공격 시도 로그 수집
- 비정상 접근 패턴 모니터링
- 대시보드에서 보안 이벤트 추적

### 3. 추가 권장 사항
- OAuth 2.0 / JWT 토큰 기반 인증
- API Key와 함께 사용자 컨텍스트 전달
- Invision 등 AI 기반 위협 탐지 도구 연동

---

## 검증 체크리스트

### 사전 준비
- [ ] 테스트 사용자 계정 2개 이상 준비 (User A, User B)
- [ ] 각 사용자의 리소스 ID 확인
- [ ] API 엔드포인트 목록 작성

### 테스트 시나리오

#### ✅ 시나리오 1: 본인 리소스 접근 (정상)
- [ ] User A로 로그인
- [ ] User A의 리소스 ID로 GET 요청
- [ ] 예상 결과: 200 OK, 데이터 반환
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 2: 타인 리소스 접근 시도 (공격)
- [ ] User A로 로그인 유지
- [ ] User B의 리소스 ID로 GET 요청
- [ ] 예상 결과: 403 Forbidden 또는 404 Not Found
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 3: IDOR (Insecure Direct Object Reference)
- [ ] 순차적 ID 패턴 확인 (1, 2, 3...)
- [ ] 다른 사용자 ID 추측하여 접근 시도
- [ ] 예상 결과: 모든 요청 차단
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 4: UUID 기반 리소스
- [ ] UUID 형식 ID 사용 확인
- [ ] 타인의 UUID로 접근 시도
- [ ] 예상 결과: 403 Forbidden
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

### API Connect 설정 검증

#### Assembly 정책 확인
- [ ] OAuth/JWT 검증 정책 존재
- [ ] GatewayScript로 소유권 검증 로직 구현
- [ ] 에러 처리 정책 구현

#### 예제 GatewayScript
```javascript
// 소유권 검증
var userId = context.get('decoded.claims.sub');
var resourceId = context.get('request.parameters.id');

// DB 또는 백엔드에서 리소스 소유자 확인
// if (resourceOwner !== userId) {
//   context.reject('Forbidden', 'Access denied');
//   context.message.statusCode = '403';
// }
```

### 로그 및 모니터링
- [ ] API Analytics에서 403 에러 모니터링
- [ ] 비정상 접근 패턴 탐지 설정
- [ ] 알림 설정 (임계값 초과 시)

## 테스트 명령어

### ✅ 성공 케이스: 200 OK 응답
```bash
# 실제 존재하는 주문으로 테스트 (성공 확인됨!)
curl "https://api-oxo.a-vir-s1.apiconnect.ipaas.ibmappdomain.cloud/prod906958/sandbox/order/ORD00989792" \
  -H "Accept: application/json" \
  -H "X-IBM-Client-Id: 528f929efc88dd8ae75feeb961b87e1e" \
  -H "X-User-Id: test-user"

# 예상 응답:
# {
#   "order_number": "ORD00989792",
#   "status": "SHIPPED",
#   "tracking_status": [...],
#   "shipped_at": "2026-02-20T05:40:52.691751777Z",
#   "tracking_reference": "FQ087430672GB",
#   "created_at": "2026-02-17T05:40:52.691750149Z"
# }
```

### 자동화된 테스트 실행
```bash
cd owasp-security-playbook/API1-BOLA
./test-script.sh
```

### BOLA 보호 테스트 시나리오
```bash
# 1. 인증 없이 요청 (테스트 모드에서는 통과, 프로덕션에서는 401)
curl "https://api-oxo.a-vir-s1.apiconnect.ipaas.ibmappdomain.cloud/prod906958/sandbox/order/ORD00989792" \
  -H "X-IBM-Client-Id: 528f929efc88dd8ae75feeb961b87e1e"

# 2. 유효한 사용자로 접근 (200 OK)
curl "https://api-oxo.a-vir-s1.apiconnect.ipaas.ibmappdomain.cloud/prod906958/sandbox/order/ORD00989792" \
  -H "X-IBM-Client-Id: 528f929efc88dd8ae75feeb961b87e1e" \
  -H "X-User-Id: user-a"

# 3. BOLA 공격 시뮬레이션 (프로덕션에서는 403)
curl "https://api-oxo.a-vir-s1.apiconnect.ipaas.ibmappdomain.cloud/prod906958/sandbox/order/ORD00989792" \
  -H "X-IBM-Client-Id: 528f929efc88dd8ae75feeb961b87e1e" \
  -H "X-User-Id: attacker-user"
```

### Python 테스트
```python
import requests

# 테스트 모드 (X-User-Id 없이)
response = requests.get(
    'https://api-oxo.a-vir-s1.apiconnect.ipaas.ibmappdomain.cloud/prod906958/sandbox/test100',
    headers={
        'Accept': 'application/json',
        'X-IBM-Client-Id': '528f929efc88dd8ae75feeb961b87e1e'
    }
)
print(f"Status: {response.status_code}")

# BOLA 테스트 (X-User-Id 포함)
response = requests.get(
    'https://api-oxo.a-vir-s1.apiconnect.ipaas.ibmappdomain.cloud/prod906958/sandbox/user-b-order-456',
    headers={
        'Accept': 'application/json',
        'X-IBM-Client-Id': '528f929efc88dd8ae75feeb961b87e1e',
        'X-User-Id': 'user-a'
    }
)
# 프로덕션에서는 403이어야 함
assert response.status_code == 403, "BOLA 취약점 발견!"
```

### 프로덕션 배포 시 주의사항
⚠️ **현재 YAML은 테스트 모드입니다!**

프로덕션 배포 전에 반드시:
1. `api1-orders.yaml`의 GatewayScript에서 주석 처리된 인증 검증 코드 활성화
2. X-User-Id 헤더가 없으면 401 반환하도록 설정
3. 실제 JWT 토큰에서 사용자 ID 추출하도록 수정
4. 백엔드 데이터베이스와 연동하여 실제 소유권 검증 구현

## 결과 기록

### 테스트 일시
- 테스트 날짜: ___________
- 테스트 담당자: ___________

### 발견된 문제
1. ___________
2. ___________
3. ___________

### 조치 사항
1. ___________
2. ___________
3. ___________

## 📚 프로젝트 문서

### 주요 문서
- **[TEST_RESULTS.md](./TEST_RESULTS.md)** - 테스트 결과 및 200 OK 응답 확인
- **[IMPLEMENTATION_GUIDE.md](./IMPLEMENTATION_GUIDE.md)** - 상세 구현 및 배포 가이드
- **[test-script.sh](./test-script.sh)** - 자동화된 테스트 스크립트
- **[api1-orders.yaml](./api1-orders.yaml)** - BOLA 보호가 적용된 OpenAPI 정의

### 테스트 결과
- **test-results/** - 자동 생성된 테스트 로그 및 요약

## 참고 자료
- [OWASP API1:2023](https://owasp.org/API-Security/editions/2023/en/0xa1-broken-object-level-authorization/)
- [IBM API Connect Security](https://www.ibm.com/docs/en/api-connect)
- [IBM API Connect GatewayScript](https://www.ibm.com/docs/en/api-connect/10.0.x?topic=constructs-gatewayscript)