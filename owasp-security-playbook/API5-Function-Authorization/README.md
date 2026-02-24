# API5: Broken Function Level Authorization (BFLA) (기능수준 권한부여 미흡)

## 개요
일반 사용자가 관리자 전용 기능이나 특정 민감 기능을 호출할 수 있는 취약점

## IBM API Connect 대응 방안

### RBAC (역할 기반 액세스 제어)
- 역할 기반 액세스 제어를 통해 조직, 카탈로그, 스페이스 단위로 세밀한 권한 관리를 부여
- 게이트웨이 수준에서 Engagement 기능을 활용하여 역할에 따라 접근 가능한 API에서 에러를 리턴하거나, OAuth 스코프 기반의 액세스 제어를 실행

## 검증 체크리스트

### 사전 준비
- [ ] 역할 정의 확인 (admin, user, guest 등)
- [ ] 각 역할별 허용 기능 목록 작성
- [ ] 테스트 계정 준비 (각 역할별)

### 관리자 기능 접근 제어

#### ✅ 시나리오 1: 일반 사용자가 관리자 API 호출
```
DELETE /users/{id}        # 관리자 전용
POST /admin/settings      # 관리자 전용
GET /admin/logs          # 관리자 전용
```
- [ ] 일반 사용자 토큰으로 관리자 API 호출
- [ ] 예상 결과: 403 Forbidden
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 2: HTTP 메서드 기반 권한
```
GET /orders/{id}      # 모든 사용자 허용
POST /orders          # 인증된 사용자
PUT /orders/{id}      # 소유자만
DELETE /orders/{id}   # 관리자만
```
- [ ] 각 메서드별 권한 확인
- [ ] 권한 없는 메서드 호출 시 차단
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 3: 숨겨진 관리자 엔드포인트
```
/api/v1/admin/*
/api/v1/internal/*
/api/v1/debug/*
```
- [ ] 문서화되지 않은 엔드포인트 탐색
- [ ] 일반 사용자 접근 차단 확인
- [ ] 통과 여부: [ ] Pass [ ] Fail

### OAuth Scope 기반 제어

#### ✅ 시나리오 4: Scope 검증
```
read:orders    # 주문 조회만
write:orders   # 주문 생성/수정
admin:orders   # 모든 주문 관리
```
- [ ] 제한된 scope로 토큰 발급
- [ ] scope 밖의 기능 호출 시도
- [ ] 예상 결과: 403 Forbidden
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 5: Scope 상승 시도
- [ ] read:orders scope로 POST 요청 시도
- [ ] write:orders scope로 DELETE 요청 시도
- [ ] 예상 결과: 403 Forbidden
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

### 역할 기반 접근 제어 (RBAC)

#### ✅ 시나리오 6: 역할 확인
- [ ] JWT claims에 role 정보 포함 확인
- [ ] 역할별 API 접근 권한 확인
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 7: 역할 변경 시도
```json
PATCH /users/me
{
  "name": "John",
  "role": "admin"  # 허용되지 않음
}
```
- [ ] 자신의 역할 변경 시도
- [ ] 예상 결과: 403 Forbidden 또는 필드 무시
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

### API Connect 설정 검증

#### Assembly 정책 확인
- [ ] OAuth 정책으로 scope 검증
- [ ] GatewayScript로 역할 검증
- [ ] 에러 처리 구현

#### 예제 Assembly - OAuth Scope 검증
```yaml
assembly:
  execute:
    - oauth:
        version: 2.0.0
        title: OAuth Validation
        oauth-provider: oauth-provider
        scopes:
          - admin:orders  # 필요한 scope
    
    - gatewayscript:
        version: 2.0.0
        title: Check Scope
        source: |
          var scopes = context.get('oauth.scope');
          var method = context.get('request.verb');
          var requiredScope = '';
          
          // 메서드별 필요한 scope 결정
          switch(method) {
            case 'GET':
              requiredScope = 'read:orders';
              break;
            case 'POST':
            case 'PUT':
            case 'PATCH':
              requiredScope = 'write:orders';
              break;
            case 'DELETE':
              requiredScope = 'admin:orders';
              break;
          }
          
          // scope 확인
          if (!scopes.includes(requiredScope)) {
            context.reject('Forbidden', 'Insufficient scope');
            context.message.statusCode = '403';
          }
```

#### 예제 Assembly - 역할 기반 제어
```yaml
assembly:
  execute:
    - validate-jwt:
        version: 2.0.0
        title: Validate JWT
        jwt: request.headers.authorization
        output-claims: decoded.claims
    
    - gatewayscript:
        version: 2.0.0
        title: Role-Based Access Control
        source: |
          var claims = context.get('decoded.claims');
          var userRole = claims.role || 'guest';
          var path = context.get('request.path');
          var method = context.get('request.verb');
          
          // 관리자 전용 경로
          var adminPaths = ['/admin', '/users', '/settings'];
          var isAdminPath = adminPaths.some(p => path.startsWith(p));
          
          // 관리자 전용 메서드
          var adminMethods = ['DELETE', 'PUT'];
          var isAdminMethod = adminMethods.includes(method);
          
          // 권한 검증
          if ((isAdminPath || isAdminMethod) && userRole !== 'admin') {
            context.reject('Forbidden', 'Admin permission required');
            context.message.statusCode = '403';
            return;
          }
          
          // 역할 정보를 다음 정책에 전달
          context.set('user.role', userRole);
```

#### 예제 - OpenAPI Security 정의
```yaml
paths:
  /orders:
    get:
      security:
        - oauth2: [read:orders]
    post:
      security:
        - oauth2: [write:orders]
  
  /orders/{id}:
    delete:
      security:
        - oauth2: [admin:orders]
  
  /admin/users:
    get:
      security:
        - oauth2: [admin:users]

components:
  securitySchemes:
    oauth2:
      type: oauth2
      flows:
        authorizationCode:
          authorizationUrl: https://auth.example.com/oauth/authorize
          tokenUrl: https://auth.example.com/oauth/token
          scopes:
            read:orders: Read orders
            write:orders: Create and update orders
            admin:orders: Full order management
            admin:users: User management
```

## 테스트 명령어

### curl 테스트 - 일반 사용자
```bash
# 일반 사용자 토큰으로 관리자 API 호출
curl -X DELETE "https://api.example.com/users/123" \
  -H "Authorization: Bearer ${USER_TOKEN}" \
  -H "Accept: application/json"

# 예상: 403 Forbidden
```

### curl 테스트 - Scope 검증
```bash
# read:orders scope로 POST 시도
curl -X POST "https://api.example.com/orders" \
  -H "Authorization: Bearer ${READ_ONLY_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"productId": "123", "quantity": 1}'

# 예상: 403 Forbidden
```

### Python 테스트
```python
import requests

# 일반 사용자 토큰
user_token = 'user-token-with-limited-scope'

# 관리자 전용 API 호출 시도
admin_endpoints = [
    ('DELETE', '/users/123'),
    ('POST', '/admin/settings'),
    ('GET', '/admin/logs'),
    ('PUT', '/users/123/role')
]

for method, endpoint in admin_endpoints:
    response = requests.request(
        method,
        f'https://api.example.com{endpoint}',
        headers={'Authorization': f'Bearer {user_token}'}
    )
    
    assert response.status_code == 403, \
        f"{method} {endpoint} should be forbidden, got {response.status_code}"
    
    print(f"✓ {method} {endpoint}: Correctly blocked")
```

### Scope 테스트
```python
import requests

# 제한된 scope 토큰
scopes = {
    'read:orders': 'read-only-token',
    'write:orders': 'write-token',
    'admin:orders': 'admin-token'
}

# read:orders로 DELETE 시도 (실패해야 함)
response = requests.delete(
    'https://api.example.com/orders/123',
    headers={'Authorization': f'Bearer {scopes["read:orders"]}'}
)
assert response.status_code == 403, "Scope escalation possible!"

# admin:orders로 DELETE (성공해야 함)
response = requests.delete(
    'https://api.example.com/orders/123',
    headers={'Authorization': f'Bearer {scopes["admin:orders"]}'}
)
assert response.status_code in [200, 204], "Admin scope not working!"
```

## 보안 설정 체크리스트

### 역할 정의
- [ ] 역할 목록 정의 (admin, user, guest 등)
- [ ] 각 역할별 권한 매트릭스 작성
- [ ] 최소 권한 원칙 적용

### OAuth Scope 설정
- [ ] Scope 목록 정의
- [ ] 각 API별 필요 scope 정의
- [ ] Scope 검증 정책 구현

### API 엔드포인트 보호
- [ ] 관리자 전용 경로 식별
- [ ] 민감한 기능 식별
- [ ] 각 엔드포인트별 권한 설정

### 모니터링
- [ ] 403 에러 모니터링
- [ ] 권한 상승 시도 탐지
- [ ] 비정상 접근 패턴 알림

## 결과 기록

### 테스트 일시
- 테스트 날짜: ___________
- 테스트 담당자: ___________

### 역할 및 권한
- 정의된 역할: ___________
- OAuth Scopes: ___________

### 발견된 문제
1. ___________
2. ___________
3. ___________

### 조치 사항
1. ___________
2. ___________
3. ___________

## 참고 자료
- [OWASP API5:2023](https://owasp.org/API-Security/editions/2023/en/0xa5-broken-function-level-authorization/)
- [OAuth 2.0 Scopes](https://oauth.net/2/scope/)
- [RBAC Best Practices](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html)