# API9: Improper Inventory Management (부적절한 자산관리)

## 개요
배기되지 않은 구버전 API나 테스트용 엔드포인트가 방치되어 공격 대상이 되는 취약점

## IBM API Connect 대응 방안

### 1. 전체 수명 주기 관리
- Lifecycle Management 기능을 통해 API의 생성부터 폐기까지 체계적으로 관리

### 2. 버전 관리
- 패키지 버전이나 테스트용 엔드포인트가 방치되지 않도록 거버넌스 도구를 활용
- HTTPS 및 TLS 1.3과 같은 최신 보안 표준 적용

### 3. API 인벤토리 관리
- 조직 내 존재하는 모든 API 목록 관리
- Shadow API 탐지 (Noname 연동 등)

## 검증 체크리스트

### 사전 준비
- [ ] 전체 API 목록 작성
- [ ] 각 API의 버전 정보 확인
- [ ] 테스트/개발 환경 API 목록 확인

### API 인벤토리 관리

#### ✅ 시나리오 1: API 목록 완전성
- [ ] 모든 배포된 API 문서화
- [ ] 각 API의 소유자 명시
- [ ] 각 API의 목적 및 사용처 기록
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 2: 버전 관리
```
/api/v1/users  (현재 버전)
/api/v2/users  (최신 버전)
/api/v3/users  (베타)
```
- [ ] 각 버전의 상태 명시 (active, deprecated, retired)
- [ ] 구버전 지원 종료 일정 공지
- [ ] 버전별 문서 유지
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 3: 구버전 API 접근
```
GET /api/v1/users  (deprecated)
```
- [ ] 구버전 API 접근 시 경고 헤더 반환
- [ ] Deprecation 헤더 확인
- [ ] Sunset 헤더 확인 (종료 예정일)
- [ ] 통과 여부: [ ] Pass [ ] Fail

### 테스트/개발 환경 보호

#### ✅ 시나리오 4: 테스트 엔드포인트 노출
```
/api/test/*
/api/debug/*
/api/internal/*
/api/admin/*
```
- [ ] 프로덕션에 테스트 엔드포인트 없음
- [ ] 디버그 엔드포인트 비활성화
- [ ] 내부 API 외부 접근 차단
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 5: 환경 분리
- [ ] 개발/스테이징/프로덕션 환경 분리
- [ ] 각 환경별 별도 인증
- [ ] 프로덕션 데이터 테스트 환경 사용 금지
- [ ] 통과 여부: [ ] Pass [ ] Fail

### Shadow API 탐지

#### ✅ 시나리오 6: 문서화되지 않은 API
- [ ] API 게이트웨이 로그 분석
- [ ] 문서에 없는 엔드포인트 탐지
- [ ] 비인가 API 배포 탐지
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 7: Zombie API
```
/api/old-service/*  (더 이상 사용 안함)
```
- [ ] 사용되지 않는 API 식별
- [ ] 트래픽 없는 API 확인
- [ ] 폐기 대상 API 목록 작성
- [ ] 통과 여부: [ ] Pass [ ] Fail

### API Connect 설정 검증

#### Lifecycle 관리
- [ ] API 상태 관리 (Draft, Published, Deprecated, Retired)
- [ ] 버전 관리 정책
- [ ] 폐기 프로세스

#### 예제 - API 버전 관리
```yaml
openapi: 3.0.1
info:
  title: User API
  version: 2.0.0
  x-ibm-name: user-api-v2
  description: User management API v2
  
servers:
  - url: /api/v2

# 구버전 경고
x-ibm-configuration:
  properties:
    deprecation-warning:
      value: 'This API version will be retired on 2024-12-31'
  
  assembly:
    execute:
      - gatewayscript:
          version: 2.0.0
          title: Add Deprecation Headers
          source: |
            var apiVersion = context.get('api.version');
            
            // v1은 deprecated
            if (apiVersion === '1.0.0') {
              context.message.headers.set('Deprecation', 'true');
              context.message.headers.set('Sunset', 'Sat, 31 Dec 2024 23:59:59 GMT');
              context.message.headers.set('Link', '</api/v2>; rel="successor-version"');
            }
```

#### 예제 - 환경별 설정
```yaml
# Catalog 설정
catalogs:
  development:
    gateway: dev-gateway
    properties:
      environment: development
      debug-mode: true
  
  staging:
    gateway: staging-gateway
    properties:
      environment: staging
      debug-mode: false
  
  production:
    gateway: prod-gateway
    properties:
      environment: production
      debug-mode: false
      require-approval: true
```

#### 예제 - Shadow API 탐지
```yaml
assembly:
  execute:
    - gatewayscript:
        version: 2.0.0
        title: Log API Usage
        source: |
          var path = context.get('request.path');
          var method = context.get('request.verb');
          var apiName = context.get('api.name');
          var apiVersion = context.get('api.version');
          
          // API 사용 로깅
          console.info('API_USAGE', JSON.stringify({
            timestamp: new Date().toISOString(),
            api: apiName,
            version: apiVersion,
            method: method,
            path: path,
            clientId: context.get('client.app.id'),
            userId: context.get('authenticated.username')
          }));
```

## 테스트 명령어

### API 인벤토리 확인
```bash
# API Connect CLI로 API 목록 조회
apic apis:list --server https://apic-manager.com --org myorg

# 각 Catalog별 API 확인
apic apis:list --server https://apic-manager.com --org myorg --catalog production
apic apis:list --server https://apic-manager.com --org myorg --catalog sandbox
```

### 구버전 API 테스트
```bash
# v1 API 호출 (deprecated)
curl -v -X GET "https://api.example.com/api/v1/users" \
  -H "Authorization: Bearer ${TOKEN}"

# 응답 헤더 확인:
# Deprecation: true
# Sunset: Sat, 31 Dec 2024 23:59:59 GMT
# Link: </api/v2>; rel="successor-version"
```

### Shadow API 탐지
```bash
# 알려지지 않은 엔드포인트 스캔
for endpoint in /api/test /api/debug /api/internal /api/admin; do
  echo "Testing: ${endpoint}"
  curl -s -o /dev/null -w "%{http_code}\n" \
    "https://api.example.com${endpoint}"
done

# 모두 404 또는 403이어야 함
```

### Python 테스트
```python
import requests
from datetime import datetime

# API 버전 확인
versions = ['v1', 'v2', 'v3']
for version in versions:
    response = requests.get(
        f'https://api.example.com/api/{version}/users',
        headers={'Authorization': f'Bearer {token}'}
    )
    
    print(f"\nVersion {version}:")
    print(f"Status: {response.status_code}")
    
    # Deprecation 헤더 확인
    if 'Deprecation' in response.headers:
        print(f"⚠️  Deprecated!")
        if 'Sunset' in response.headers:
            sunset = response.headers['Sunset']
            print(f"   Sunset: {sunset}")
        if 'Link' in response.headers:
            print(f"   Successor: {response.headers['Link']}")

# Shadow API 탐지
shadow_endpoints = [
    '/api/test',
    '/api/debug',
    '/api/internal',
    '/api/admin',
    '/api/v0',
    '/.git',
    '/swagger.json',
    '/api-docs'
]

print("\n=== Shadow API Detection ===")
for endpoint in shadow_endpoints:
    response = requests.get(
        f'https://api.example.com{endpoint}',
        headers={'Authorization': f'Bearer {token}'}
    )
    
    if response.status_code not in [404, 403]:
        print(f"⚠️  Found: {endpoint} ({response.status_code})")
    else:
        print(f"✓ Blocked: {endpoint}")
```

## 보안 설정 체크리스트

### API 인벤토리
- [ ] 전체 API 목록 유지
- [ ] 각 API의 소유자 명시
- [ ] 각 API의 상태 추적
- [ ] 정기적인 인벤토리 검토

### 버전 관리
- [ ] 버전 관리 정책 수립
- [ ] Deprecation 프로세스 정의
- [ ] 구버전 지원 기간 명시
- [ ] 버전 업그레이드 가이드 제공

### 환경 관리
- [ ] 환경별 분리 (dev/staging/prod)
- [ ] 환경별 접근 제어
- [ ] 프로덕션 데이터 보호
- [ ] 테스트 엔드포인트 제거

### 모니터링
- [ ] API 사용량 모니터링
- [ ] Shadow API 탐지
- [ ] Zombie API 식별
- [ ] 정기적인 보안 감사

## 결과 기록

### 테스트 일시
- 테스트 날짜: ___________
- 테스트 담당자: ___________

### API 인벤토리
- 총 API 수: ___________
- 활성 API: ___________
- Deprecated API: ___________
- Retired API: ___________

### 발견된 문제
1. ___________
2. ___________
3. ___________

### 조치 사항
1. ___________
2. ___________
3. ___________

## 참고 자료
- [OWASP API9:2023](https://owasp.org/API-Security/editions/2023/en/0xa9-improper-inventory-management/)
- [API Versioning Best Practices](https://www.ibm.com/docs/en/api-connect/10.0.x?topic=apis-versioning)
- [HTTP Deprecation Header](https://tools.ietf.org/id/draft-dalal-deprecation-header-01.html)
- [HTTP Sunset Header](https://tools.ietf.org/html/rfc8594)