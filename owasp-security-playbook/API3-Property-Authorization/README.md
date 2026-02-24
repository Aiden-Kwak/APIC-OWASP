# API3: Broken Object Property Level Authorization (객체 속성 수준 권한부여 미흡)

## 개요
객체의 특정 속성에 대한 권한 검증이 부족하여 민감 정보를 노출하거나 과도하게 노출(Excessive Data Exposure), 허용되지 않은 필드를 조작(Mass Assignment)하는 취약점

## IBM API Connect 대응 방안

### 1. Redaction 정책
- 응답 페이로드에서 민감한 필드를 마스킹하거나 삭제
- 또는 Mediation 정책과 스크립트 결합을 통해 클라이언트가 수정해서는 안 되는 필드를 제한

## 검증 체크리스트

### 사전 준비
- [ ] API 응답 스키마 문서 확인
- [ ] 민감한 필드 목록 작성
- [ ] 읽기 전용 필드 목록 작성
- [ ] 테스트 계정 준비

### Excessive Data Exposure 검증

#### ✅ 시나리오 1: 응답 데이터 과다 노출
- [ ] API 응답에서 모든 필드 확인
- [ ] 불필요한 내부 필드 노출 여부 확인
  - [ ] internalId
  - [ ] password/passwordHash
  - [ ] adminNotes
  - [ ] costPrice
  - [ ] supplierInfo
  - [ ] createdBy/updatedBy (내부 사용자 ID)
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 2: 민감 정보 마스킹
- [ ] 개인정보 마스킹 확인
  - [ ] 이메일: user@example.com → u***@example.com
  - [ ] 전화번호: 010-1234-5678 → 010-****-5678
  - [ ] 주민번호: 123456-1234567 → 123456-*******
  - [ ] 카드번호: 1234-5678-9012-3456 → 1234-****-****-3456
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 3: 역할별 데이터 노출
- [ ] 일반 사용자로 조회 시 제한된 필드만 반환
- [ ] 관리자로 조회 시 전체 필드 반환
- [ ] 역할에 따른 필터링 동작 확인
- [ ] 통과 여부: [ ] Pass [ ] Fail

### Mass Assignment 검증

#### ✅ 시나리오 4: 읽기 전용 필드 수정 시도
- [ ] id 필드 수정 시도
- [ ] createdAt 필드 수정 시도
- [ ] userId 필드 수정 시도
- [ ] isAdmin 필드 수정 시도
- [ ] 예상 결과: 400 Bad Request 또는 필드 무시
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 5: 권한 상승 시도
```json
PATCH /users/123
{
  "name": "John",
  "role": "admin",        // 허용되지 않음
  "isVerified": true,     // 허용되지 않음
  "credits": 999999       // 허용되지 않음
}
```
- [ ] 권한 관련 필드 수정 차단 확인
- [ ] 예상 결과: 필드 무시 또는 400 에러
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 6: 가격 조작 시도
```json
POST /orders
{
  "productId": "prod-123",
  "quantity": 1,
  "price": 0.01,          // 허용되지 않음 (서버에서 계산)
  "discount": 100,        // 허용되지 않음
  "totalAmount": 0.01     // 허용되지 않음
}
```
- [ ] 가격 관련 필드 조작 차단 확인
- [ ] 서버 측에서 가격 재계산 확인
- [ ] 통과 여부: [ ] Pass [ ] Fail

### API Connect 설정 검증

#### Assembly 정책 확인
- [ ] Redaction 정책 구현
- [ ] Map 정책으로 필드 필터링
- [ ] GatewayScript로 커스텀 필터링

#### 예제 Assembly - 응답 필터링
```yaml
assembly:
  execute:
    - invoke:
        title: Call Backend
        target-url: https://backend.example.com/api
        output: backend.response
    
    - gatewayscript:
        version: 2.0.0
        title: Filter Sensitive Fields
        source: |
          var response = context.get('backend.response.body');
          
          // 민감한 필드 제거
          delete response.internalId;
          delete response.adminNotes;
          delete response.costPrice;
          delete response.supplierInfo;
          delete response.passwordHash;
          
          // 개인정보 마스킹
          if (response.email) {
            var parts = response.email.split('@');
            response.email = parts[0].substring(0, 1) + '***@' + parts[1];
          }
          
          if (response.phone) {
            response.phone = response.phone.replace(/(\d{3})-(\d{4})-(\d{4})/, '$1-****-$3');
          }
          
          // userId 부분 마스킹
          if (response.userId) {
            response.userId = response.userId.substring(0, 8) + '****';
          }
          
          context.set('message.body', response);
```

#### 예제 Assembly - 입력 필터링 (Mass Assignment 방지)
```yaml
assembly:
  execute:
    - gatewayscript:
        version: 2.0.0
        title: Whitelist Input Fields
        source: |
          var input = context.get('message.body');
          
          // 허용된 필드만 추출
          var allowedFields = ['name', 'email', 'phone', 'address'];
          var filtered = {};
          
          allowedFields.forEach(function(field) {
            if (input[field] !== undefined) {
              filtered[field] = input[field];
            }
          });
          
          // 읽기 전용 필드 제거
          delete filtered.id;
          delete filtered.createdAt;
          delete filtered.updatedAt;
          delete filtered.userId;
          delete filtered.isAdmin;
          delete filtered.role;
          delete filtered.credits;
          
          context.set('message.body', filtered);
    
    - invoke:
        title: Call Backend
        target-url: https://backend.example.com/api
```

### Redaction 정책 사용
```yaml
assembly:
  execute:
    - invoke:
        title: Get User Data
        target-url: https://backend.example.com/users/{id}
        output: user.data
    
    - redact:
        version: 2.0.0
        title: Redact Sensitive Fields
        actions:
          - action: redact
            path: user.data.body.password
          - action: redact
            path: user.data.body.ssn
          - action: redact
            path: user.data.body.creditCard
```

## 테스트 명령어

### curl 테스트 - Excessive Data Exposure
```bash
# 응답 데이터 확인
curl -X GET "https://api.example.com/users/123" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Accept: application/json" | jq .

# 민감한 필드가 있는지 확인
curl -X GET "https://api.example.com/users/123" \
  -H "Authorization: Bearer ${TOKEN}" | \
  jq 'keys | map(select(. == "password" or . == "internalId" or . == "adminNotes"))'
```

### curl 테스트 - Mass Assignment
```bash
# 읽기 전용 필드 수정 시도
curl -X PATCH "https://api.example.com/users/123" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "id": "999",
    "isAdmin": true,
    "credits": 999999
  }'

# 예상: id, isAdmin, credits 필드는 무시되거나 400 에러
```

### Python 테스트
```python
import requests

# Excessive Data Exposure 테스트
response = requests.get(
    'https://api.example.com/users/123',
    headers={'Authorization': f'Bearer {token}'}
)

data = response.json()

# 민감한 필드가 없어야 함
sensitive_fields = ['password', 'passwordHash', 'internalId', 'adminNotes']
exposed_fields = [f for f in sensitive_fields if f in data]

assert len(exposed_fields) == 0, f"민감한 필드 노출: {exposed_fields}"

# Mass Assignment 테스트
response = requests.patch(
    'https://api.example.com/users/123',
    headers={'Authorization': f'Bearer {token}'},
    json={
        'name': 'John Doe',
        'isAdmin': True,  # 허용되지 않음
        'credits': 999999  # 허용되지 않음
    }
)

# 업데이트 후 확인
updated = requests.get(
    'https://api.example.com/users/123',
    headers={'Authorization': f'Bearer {token}'}
).json()

assert updated.get('isAdmin') != True, "isAdmin 필드가 수정됨!"
assert updated.get('credits') != 999999, "credits 필드가 수정됨!"
```

## 보안 설정 체크리스트

### 응답 필터링
- [ ] 민감한 필드 목록 정의
- [ ] Redaction 정책 구현
- [ ] 역할별 필드 필터링 구현
- [ ] 마스킹 규칙 정의

### 입력 검증
- [ ] 허용 필드 화이트리스트 정의
- [ ] 읽기 전용 필드 목록 정의
- [ ] 입력 검증 정책 구현
- [ ] 스키마 검증 활성화

### OpenAPI 스키마
- [ ] readOnly 속성 정의
- [ ] writeOnly 속성 정의
- [ ] 필수 필드 정의
- [ ] 데이터 타입 및 형식 정의

## 결과 기록

### 테스트 일시
- 테스트 날짜: ___________
- 테스트 담당자: ___________

### 노출된 민감 필드
1. ___________
2. ___________
3. ___________

### 수정 가능한 읽기 전용 필드
1. ___________
2. ___________
3. ___________

### 조치 사항
1. ___________
2. ___________
3. ___________

## 참고 자료
- [OWASP API3:2023](https://owasp.org/API-Security/editions/2023/en/0xa3-broken-object-property-level-authorization/)
- [IBM API Connect Redaction](https://www.ibm.com/docs/en/api-connect/10.0.x?topic=constructs-redact)
- [Mass Assignment Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Mass_Assignment_Cheat_Sheet.html)