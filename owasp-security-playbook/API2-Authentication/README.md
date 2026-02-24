# API2: Broken Authentication (인증 미흡)

## 개요
인증 메커니즘이 잘못 구현되어 공격자가 토큰을 탈취하거나 구현 결함을 악용하여 다른 사용자의 신분을 도용하는 취약점

## IBM API Connect 대응 방안

### 1. 강력한 인증 방식
- API Key, OAuth 2.0, JWT 등 다양한 인증 방식 지원
- LDAP, Active Directory와 같은 기업 내 ID 관리 시스템과 연동

### 2. 세션 하이재킹 방지
- 쿠키 만료 정책과 저장 보호를 위한 상호 TLS(mTLS)를 강제

## 검증 체크리스트

### 사전 준비
- [ ] 인증 메커니즘 확인 (OAuth 2.0, JWT, API Key 등)
- [ ] 토큰 발급 엔드포인트 확인
- [ ] 테스트 계정 준비

### 인증 메커니즘 검증

#### ✅ 시나리오 1: 인증 없이 접근 시도
- [ ] Authorization 헤더 없이 API 호출
- [ ] 예상 결과: 401 Unauthorized
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 2: 잘못된 토큰 사용
- [ ] 무효한 토큰으로 API 호출
- [ ] 예상 결과: 401 Unauthorized
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 3: 만료된 토큰 사용
- [ ] 만료된 JWT 토큰으로 API 호출
- [ ] 예상 결과: 401 Unauthorized, "Token expired" 메시지
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 4: 변조된 토큰 사용
- [ ] JWT 페이로드 변조 후 API 호출
- [ ] 예상 결과: 401 Unauthorized, "Invalid signature"
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

### OAuth 2.0 검증

#### ✅ 시나리오 5: 토큰 발급 프로세스
- [ ] Authorization Code Flow 테스트
- [ ] Client Credentials Flow 테스트
- [ ] Refresh Token 동작 확인
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 6: Scope 검증
- [ ] 제한된 scope로 토큰 발급
- [ ] 권한 밖의 API 호출 시도
- [ ] 예상 결과: 403 Forbidden
- [ ] 실제 결과: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

### JWT 검증

#### ✅ 시나리오 7: JWT 서명 알고리즘
- [ ] 지원하는 알고리즘 확인 (RS256, HS256 등)
- [ ] "none" 알고리즘 차단 확인
- [ ] 약한 알고리즘(HS256) 사용 여부
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 8: JWT Claims 검증
- [ ] iss (issuer) 검증
- [ ] aud (audience) 검증
- [ ] exp (expiration) 검증
- [ ] nbf (not before) 검증
- [ ] 통과 여부: [ ] Pass [ ] Fail

### API Connect 설정 검증

#### Assembly 정책 확인
- [ ] validate-jwt 정책 존재
- [ ] oauth 정책 구성
- [ ] 토큰 검증 로직 구현

#### 예제 Assembly
```yaml
assembly:
  execute:
    - validate-jwt:
        version: 2.0.0
        title: Validate JWT Token
        jwt: request.headers.authorization
        output-claims: decoded.claims
        issuer-claim: iss
        audience-claim: aud
        jws-jwk: |
          {
            "kty": "RSA",
            "use": "sig",
            "kid": "key-1",
            "n": "...",
            "e": "AQAB"
          }
    
    - gatewayscript:
        version: 2.0.0
        title: Check Token Expiration
        source: |
          var claims = context.get('decoded.claims');
          var now = Math.floor(Date.now() / 1000);
          
          if (claims.exp < now) {
            context.reject('Unauthorized', 'Token expired');
            context.message.statusCode = '401';
          }
```

### 세션 관리 검증

#### ✅ 시나리오 9: 토큰 만료 시간
- [ ] Access Token 만료 시간 확인 (권장: 15분-1시간)
- [ ] Refresh Token 만료 시간 확인 (권장: 7-30일)
- [ ] 실제 설정: ___________
- [ ] 통과 여부: [ ] Pass [ ] Fail

#### ✅ 시나리오 10: 토큰 갱신
- [ ] Refresh Token으로 새 Access Token 발급
- [ ] 만료된 Refresh Token 사용 시 차단
- [ ] 통과 여부: [ ] Pass [ ] Fail

### mTLS (Mutual TLS) 검증

#### ✅ 시나리오 11: 클라이언트 인증서
- [ ] mTLS 설정 확인
- [ ] 유효한 인증서로 연결
- [ ] 무효한 인증서로 연결 시도 (차단되어야 함)
- [ ] 통과 여부: [ ] Pass [ ] Fail

## 테스트 명령어

### curl 테스트
```bash
# 인증 없이 접근
curl -X GET "https://api.example.com/orders" \
  -H "Accept: application/json"
# 예상: 401 Unauthorized

# 잘못된 토큰
curl -X GET "https://api.example.com/orders" \
  -H "Authorization: Bearer invalid-token" \
  -H "Accept: application/json"
# 예상: 401 Unauthorized

# 유효한 토큰
curl -X GET "https://api.example.com/orders" \
  -H "Authorization: Bearer ${VALID_TOKEN}" \
  -H "Accept: application/json"
# 예상: 200 OK
```

### Python 테스트
```python
import requests
import jwt
from datetime import datetime, timedelta

# 만료된 토큰 생성
expired_token = jwt.encode(
    {
        'sub': 'user123',
        'exp': datetime.utcnow() - timedelta(hours=1)
    },
    'secret',
    algorithm='HS256'
)

# 만료된 토큰으로 요청
response = requests.get(
    'https://api.example.com/orders',
    headers={'Authorization': f'Bearer {expired_token}'}
)

assert response.status_code == 401, "만료된 토큰이 허용됨!"
```

### JWT 디코딩 테스트
```bash
# JWT 토큰 디코딩 (jwt.io 또는 CLI)
echo "eyJhbGc..." | base64 -d

# JWT 검증
jwt decode ${TOKEN}
```

## 보안 설정 체크리스트

### OAuth 2.0 설정
- [ ] Authorization Server 구성
- [ ] Client 등록 및 관리
- [ ] Scope 정의
- [ ] Token 만료 시간 설정
- [ ] Refresh Token Rotation 활성화

### JWT 설정
- [ ] 강력한 서명 알고리즘 사용 (RS256 권장)
- [ ] 비밀키 안전하게 관리
- [ ] Claims 검증 활성화
- [ ] 토큰 만료 시간 설정

### API Connect 설정
- [ ] Security Definitions 구성
- [ ] validate-jwt 정책 추가
- [ ] 에러 처리 구현
- [ ] Rate Limiting 설정

## 결과 기록

### 테스트 일시
- 테스트 날짜: ___________
- 테스트 담당자: ___________

### 인증 메커니즘
- 사용 중인 방식: [ ] OAuth 2.0 [ ] JWT [ ] API Key [ ] mTLS
- 토큰 만료 시간: ___________
- 서명 알고리즘: ___________

### 발견된 문제
1. ___________
2. ___________
3. ___________

### 조치 사항
1. ___________
2. ___________
3. ___________

## 참고 자료
- [OWASP API2:2023](https://owasp.org/API-Security/editions/2023/en/0xa2-broken-authentication/)
- [OAuth 2.0 RFC 6749](https://tools.ietf.org/html/rfc6749)
- [JWT Best Practices RFC 8725](https://tools.ietf.org/html/rfc8725)
- [IBM API Connect OAuth](https://www.ibm.com/docs/en/api-connect/10.0.x?topic=security-oauth)