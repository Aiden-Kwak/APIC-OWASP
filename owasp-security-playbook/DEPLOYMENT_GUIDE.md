# OWASP API Security 테스트용 API 배포 가이드

## 개요
이 문서는 OWASP API Security Top 10 테스트를 위한 API 정의 파일들을 IBM API Connect에 배포하는 방법을 설명합니다.

## 생성된 API 정의 파일 목록

각 OWASP 보안 항목별로 테스트용 API 정의 파일이 생성되었습니다:

| 보안 항목 | 파일 위치 | 설명 |
|----------|----------|------|
| API1: BOLA | `API1-BOLA/order-api-bola-test.yaml` | 객체 수준 권한 검증 |
| API2: Authentication | `API2-Authentication/order-api-auth-test.yaml` | 강화된 인증 메커니즘 |
| API4: Resource Consumption | `API4-Resource-Consumption/order-api-ratelimit-test.yaml` | Rate Limiting 및 리소스 제한 |
| API7: SSRF | `API7-SSRF/order-api-ssrf-test.yaml` | URL 검증 및 SSRF 방어 |
| API10: Unsafe Consumption | `API10-Unsafe-Consumption/order-api-input-validation-test.yaml` | 외부 API 응답 검증 |

## 배포 방법

### 1. API Manager 접속
1. IBM API Connect Manager에 로그인
2. 해당 Provider Organization 선택
3. **Develop** 탭으로 이동

### 2. API 가져오기
각 테스트 항목별로 다음 단계를 반복:

1. **Add** → **API** 클릭
2. **From existing OpenAPI service** 선택
3. 해당 YAML 파일 업로드
   - 예: `order-api-bola-test.yaml`
4. **Next** 클릭
5. API 정보 확인 후 **Next**
6. **Edit API** 클릭

### 3. API 설정 확인

#### 기본 정보
- **Title**: 각 파일의 title 확인 (예: Order-Aiden-BOLA-Test)
- **Version**: 2.0.0-xxx (xxx는 테스트 유형)
- **Base Path**: `/order`

#### Security 설정
- **Client ID** 인증이 기본으로 설정됨
- 필요시 OAuth 추가 가능

#### Assembly Flow
각 API는 다음과 같은 보안 정책이 포함되어 있습니다:

**API1 (BOLA)**
- 사용자 권한 검증 GatewayScript
- 응답 데이터 소유권 검증
- 민감 정보 필터링

**API2 (Authentication)**
- Client ID 검증 및 형식 체크
- SQL Injection/XSS 패턴 감지
- Rate Limiting 체크
- 에러 핸들링

**API4 (Rate Limiting)**
- Rate Limit 체크 (분당 100회)
- 요청 크기 제한 (1MB)
- 응답 크기 제한 (5MB)
- 타임아웃 설정 (30초)

**API7 (SSRF)**
- 입력 파라미터 검증
- URL 스키마/IP 주소 감지
- Path Traversal 방어
- URL 화이트리스트 검증

**API10 (Input Validation)**
- 외부 API 응답 검증
- 필수 필드 확인
- 데이터 타입 검증
- XSS 방어 (HTML 태그 제거)
- 응답 크기 제한

### 4. API 저장 및 게시

#### 저장
1. Assembly 탭에서 정책 확인
2. **Save** 클릭

#### 온라인 상태로 전환
1. API 목록에서 해당 API 선택
2. 오른쪽 상단 토글을 **Online**으로 변경

#### Product에 추가
1. **Develop** → **Products** 이동
2. 기존 Product 선택 또는 새로 생성
3. **APIs** 섹션에서 테스트 API 추가
4. **Save** 클릭

#### Catalog에 게시
1. Product 선택
2. **Publish** 클릭
3. Target Catalog 선택 (예: Sandbox)
4. **Publish** 확인

### 5. 엔드포인트 확인

게시 후 다음 형식으로 엔드포인트가 생성됩니다:

```
https://{gateway-url}/{org}/{catalog}/{base-path}/{path}
```

예시:
```
https://api-oxo.a-vir-s1.apiconnect.ipaas.ibmappdomain.cloud/prod906958/sandbox/order/ORD00989792
```

## 테스트 실행

### 1. Client ID 발급
1. **Manage** 탭으로 이동
2. Sandbox Catalog 선택
3. **Consumer organizations** → 조직 선택
4. **Applications** → 애플리케이션 선택
5. **Credentials** 탭에서 Client ID 확인

### 2. API 호출 테스트

#### 기본 테스트
```bash
curl -X GET \
  "https://{gateway-url}/{org}/{catalog}/order/ORD00989792" \
  -H "X-IBM-Client-Id: {your-client-id}"
```

#### API1 (BOLA) 테스트
```bash
# 정상 요청
curl -X GET \
  "https://{gateway-url}/{org}/{catalog}/order/ORD00989792" \
  -H "X-IBM-Client-Id: {your-client-id}"

# 다른 사용자 주문 접근 시도
curl -X GET \
  "https://{gateway-url}/{org}/{catalog}/order/ORD99999999" \
  -H "X-IBM-Client-Id: {your-client-id}"
```

#### API2 (Authentication) 테스트
```bash
# 인증 없이 접근
curl -X GET \
  "https://{gateway-url}/{org}/{catalog}/order/ORD00989792"

# 잘못된 Client ID
curl -X GET \
  "https://{gateway-url}/{org}/{catalog}/order/ORD00989792" \
  -H "X-IBM-Client-Id: invalid-id"

# SQL Injection 시도
curl -X GET \
  "https://{gateway-url}/{org}/{catalog}/order/ORD00989792" \
  -H "X-IBM-Client-Id: ' OR '1'='1"
```

#### API4 (Rate Limiting) 테스트
```bash
# 연속 요청 (Rate Limit 테스트)
for i in {1..10}; do
  curl -X GET \
    "https://{gateway-url}/{org}/{catalog}/order/ORD00989792" \
    -H "X-IBM-Client-Id: {your-client-id}"
  sleep 0.1
done
```

#### API7 (SSRF) 테스트
```bash
# URL 스키마 포함 시도
curl -X GET \
  "https://{gateway-url}/{org}/{catalog}/order/http://internal-server" \
  -H "X-IBM-Client-Id: {your-client-id}"

# IP 주소 포함 시도
curl -X GET \
  "https://{gateway-url}/{org}/{catalog}/order/127.0.0.1" \
  -H "X-IBM-Client-Id: {your-client-id}"

# Path Traversal 시도
curl -X GET \
  "https://{gateway-url}/{org}/{catalog}/order/../../../etc/passwd" \
  -H "X-IBM-Client-Id: {your-client-id}"
```

#### API10 (Input Validation) 테스트
```bash
# 정상 요청 (외부 API 응답 검증)
curl -X GET \
  "https://{gateway-url}/{org}/{catalog}/order/ORD00989792" \
  -H "X-IBM-Client-Id: {your-client-id}"
```

### 3. 자동화된 테스트 스크립트 실행

각 폴더의 `test-script.sh`를 사용하여 자동화된 테스트 실행:

```bash
# API1 BOLA 테스트
cd owasp-security-playbook/API1-BOLA
./test-script.sh

# API2 Authentication 테스트
cd ../API2-Authentication
./test-script.sh

# API4 Resource Consumption 테스트
cd ../API4-Resource-Consumption
./test-script.sh
```

## 로그 및 모니터링

### DataPower 로그 확인
1. DataPower Gateway 콘솔 접속
2. **Troubleshooting** → **Logs** 이동
3. 다음 로그 메시지 확인:
   - `[BOLA-CHECK]` - BOLA 검증 로그
   - `[AUTH-CHECK]` - 인증 검증 로그
   - `[RATE-LIMIT]` - Rate Limiting 로그
   - `[SSRF-CHECK]` - SSRF 검증 로그
   - `[INPUT-VALIDATION]` - 입력 검증 로그

### API Connect Analytics
1. **Manage** → Catalog 선택
2. **Analytics** 탭 이동
3. API 호출 통계 및 에러율 확인

## 문제 해결

### API 배포 실패
- YAML 파일 형식 확인
- GatewayScript 문법 오류 확인
- DataPower Gateway 상태 확인

### 401 Unauthorized 에러
- Client ID 확인
- API가 Online 상태인지 확인
- Product가 게시되었는지 확인

### 404 Not Found 에러
- Base Path 확인 (`/order`)
- Catalog 이름 확인
- API가 해당 Product에 포함되었는지 확인

### GatewayScript 에러
- DataPower 로그에서 상세 에러 확인
- JavaScript 문법 오류 확인
- Context 변수 이름 확인

## 다음 단계

1. ✅ 각 API 정의 파일을 APIC에 배포
2. ✅ Client ID 발급 및 테스트 준비
3. ✅ 자동화된 테스트 스크립트 실행
4. ✅ 테스트 결과 분석 및 보고서 작성
5. ✅ 발견된 취약점 수정
6. ✅ 프로덕션 환경에 보안 정책 적용

## 참고 자료

- [IBM API Connect Documentation](https://www.ibm.com/docs/en/api-connect)
- [OWASP API Security Top 10](https://owasp.org/API-Security/editions/2023/en/0x11-t10/)
- [DataPower GatewayScript Reference](https://www.ibm.com/docs/en/datapower-gateway)
- 프로젝트 내 README: `owasp-security-playbook/README.md`

---

**작성일**: 2026년 2월 23일  
**버전**: 1.0