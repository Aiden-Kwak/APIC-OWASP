# OWASP API Security Top 10 검증 Playbook

IBM API Connect 환경에서 OWASP API Security Top 10 (2023)을 체계적으로 검증하기 위한 실행 가이드입니다.

## 📋 목차

- [개요](#개요)
- [Playbook 구조](#playbook-구조)
- [사용 방법](#사용-방법)
- [검증 항목](#검증-항목)
- [실행 순서](#실행-순서)
- [결과 보고](#결과-보고)

## 개요

이 playbook은 다음을 제공합니다:

- ✅ **체계적인 체크리스트**: 각 보안 항목별 단계별 검증 절차
- 🔧 **실행 가능한 테스트**: curl, Python 등 즉시 실행 가능한 테스트 코드
- 📊 **IBM API Connect 설정 예제**: 실제 적용 가능한 Assembly 정책
- 📝 **결과 기록 양식**: 테스트 결과를 문서화하는 표준 양식

## Playbook 구조

```
owasp-security-playbook/
├── README.md (이 파일)
├── API1-BOLA/
│   └── README.md
├── API2-Authentication/
│   └── README.md
├── API3-Property-Authorization/
│   └── README.md
├── API4-Resource-Consumption/
│   └── README.md
├── API5-Function-Authorization/
│   └── README.md
├── API6-Business-Flows/
│   └── README.md
├── API7-SSRF/
│   └── README.md
├── API8-Security-Config/
│   └── README.md
├── API9-Inventory-Management/
│   └── README.md
└── API10-Unsafe-Consumption/
    └── README.md
```

## 사용 방법

### 1. 사전 준비

```bash
# 환경 변수 설정
export API_BASE_URL="https://your-apic-gateway.com"
export CLIENT_ID="your-client-id"
export OAUTH_TOKEN="your-oauth-token"

# 필요한 도구 설치
pip install requests pytest
npm install -g newman
```

### 2. 개별 항목 검증

각 폴더의 README.md를 따라 단계별로 검증:

```bash
# 예: API1 BOLA 검증
cd API1-BOLA
cat README.md

# 체크리스트를 따라 테스트 실행
curl -X GET "${API_BASE_URL}/orders/user-a-order-id" \
  -H "Authorization: Bearer ${OAUTH_TOKEN}"
```

### 3. 전체 검증 실행

모든 항목을 순차적으로 검증하려면:

```bash
# 전체 검증 스크립트 실행 (아래 참조)
./run-all-tests.sh
```

## 검증 항목

### API1: Broken Object Level Authorization (BOLA)
**위험도**: 🔴 Critical  
**검증 시간**: ~30분  
**주요 테스트**: 타인 리소스 접근 시도, IDOR 공격

### API2: Broken Authentication
**위험도**: 🔴 Critical  
**검증 시간**: ~45분  
**주요 테스트**: 토큰 검증, OAuth 플로우, JWT 보안

### API3: Broken Object Property Level Authorization
**위험도**: 🟠 High  
**검증 시간**: ~40분  
**주요 테스트**: 민감 정보 노출, Mass Assignment

### API4: Unrestricted Resource Consumption
**위험도**: 🟠 High  
**검증 시간**: ~35분  
**주요 테스트**: Rate Limiting, Quota, 페이로드 크기

### API5: Broken Function Level Authorization (BFLA)
**위험도**: 🟠 High  
**검증 시간**: ~30분  
**주요 테스트**: 관리자 기능 접근, Scope 검증

### API6: Unrestricted Access to Sensitive Business Flows
**위험도**: 🟡 Medium  
**검증 시간**: ~40분  
**주요 테스트**: 자동화 공격, Idempotency

### API7: Server Side Request Forgery (SSRF)
**위험도**: 🟠 High  
**검증 시간**: ~35분  
**주요 테스트**: 내부 IP 접근, URL 검증

### API8: Security Misconfiguration
**위험도**: 🟡 Medium  
**검증 시간**: ~45분  
**주요 테스트**: 보안 헤더, CORS, TLS 설정

### API9: Improper Inventory Management
**위험도**: 🟡 Medium  
**검증 시간**: ~30분  
**주요 테스트**: API 인벤토리, 버전 관리, Shadow API

### API10: Unsafe Consumption of APIs
**위험도**: 🟡 Medium  
**검증 시간**: ~35분  
**주요 테스트**: 외부 API 검증, Circuit Breaker

## 실행 순서

### 권장 순서

1. **Phase 1: 인증 및 권한 (Critical)**
   - API2: Authentication
   - API1: BOLA
   - API5: Function Authorization

2. **Phase 2: 데이터 보호 (High)**
   - API3: Property Authorization
   - API4: Resource Consumption
   - API7: SSRF

3. **Phase 3: 운영 보안 (Medium)**
   - API8: Security Configuration
   - API9: Inventory Management
   - API6: Business Flows
   - API10: Unsafe Consumption

### 빠른 검증 (1시간)

Critical 항목만 검증:
```bash
# API2, API1, API5만 실행
for api in API2-Authentication API1-BOLA API5-Function-Authorization; do
  echo "Testing ${api}..."
  cd ${api}
  # 핵심 테스트만 실행
  cd ..
done
```

### 전체 검증 (6시간)

모든 항목을 상세히 검증:
```bash
./run-all-tests.sh --full
```

## 결과 보고

### 1. 개별 결과 기록

각 README.md의 "결과 기록" 섹션을 작성:

```markdown
### 테스트 일시
- 테스트 날짜: 2024-01-15
- 테스트 담당자: 홍길동

### 발견된 문제
1. 타인 주문 접근 가능 (API1)
2. Rate Limiting 미설정 (API4)

### 조치 사항
1. GatewayScript로 소유권 검증 추가
2. Rate Limit 정책 적용 (100 req/min)
```

### 2. 종합 보고서 생성

```bash
# 종합 보고서 생성 스크립트
./generate-report.sh > security-report.md
```

### 3. 보고서 템플릿

```markdown
# OWASP API Security 검증 보고서

## 요약
- 검증 일시: 2024-01-15
- 검증자: 홍길동
- 총 검증 항목: 10개
- 통과: 7개
- 실패: 3개

## 상세 결과

### 🔴 Critical Issues
1. API1: BOLA - 타인 리소스 접근 가능
2. API2: Authentication - 만료된 토큰 허용

### 🟠 High Issues
1. API4: Resource Consumption - Rate Limiting 없음

### 🟡 Medium Issues
(없음)

## 권장 조치사항
1. 즉시 조치 (Critical)
   - API1: 소유권 검증 로직 추가
   - API2: JWT 만료 시간 검증 활성화

2. 단기 조치 (1주일 이내)
   - API4: Rate Limiting 정책 적용

3. 중기 조치 (1개월 이내)
   - 전체 API 보안 헤더 표준화
```

## 자동화 스크립트

### run-all-tests.sh

```bash
#!/bin/bash
# OWASP API Security 전체 검증 스크립트

set -e

echo "======================================"
echo "OWASP API Security 검증 시작"
echo "======================================"

# 환경 변수 확인
if [ -z "$API_BASE_URL" ]; then
  echo "Error: API_BASE_URL not set"
  exit 1
fi

# 결과 저장
RESULTS_DIR="results/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

# 각 API 검증
for api_dir in API*; do
  if [ -d "$api_dir" ]; then
    echo ""
    echo "Testing ${api_dir}..."
    echo "======================================" | tee -a "$RESULTS_DIR/summary.txt"
    
    # 테스트 실행 (각 폴더에 test.sh가 있다고 가정)
    if [ -f "$api_dir/test.sh" ]; then
      cd "$api_dir"
      ./test.sh 2>&1 | tee -a "../$RESULTS_DIR/${api_dir}.log"
      cd ..
    else
      echo "No test script found for ${api_dir}" | tee -a "$RESULTS_DIR/summary.txt"
    fi
  fi
done

echo ""
echo "======================================"
echo "검증 완료"
echo "결과: $RESULTS_DIR"
echo "======================================"
```

### generate-report.sh

```bash
#!/bin/bash
# 검증 결과 보고서 생성

echo "# OWASP API Security 검증 보고서"
echo ""
echo "생성 일시: $(date)"
echo ""

echo "## 검증 결과 요약"
echo ""

TOTAL=0
PASS=0
FAIL=0

for api_dir in API*; do
  if [ -d "$api_dir" ]; then
    TOTAL=$((TOTAL + 1))
    
    # 각 폴더의 결과 확인 (예시)
    if grep -q "통과 여부: \[x\] Pass" "$api_dir/README.md" 2>/dev/null; then
      PASS=$((PASS + 1))
      echo "- ✅ ${api_dir}: PASS"
    else
      FAIL=$((FAIL + 1))
      echo "- ❌ ${api_dir}: FAIL"
    fi
  fi
done

echo ""
echo "총 ${TOTAL}개 항목 중 ${PASS}개 통과, ${FAIL}개 실패"
```

## 추가 리소스

### 문서
- [OWASP API Security Top 10 2023](https://owasp.org/API-Security/)
- [IBM API Connect Documentation](https://www.ibm.com/docs/en/api-connect)
- [DataPower Gateway Documentation](https://www.ibm.com/docs/en/datapower-gateway)

### 도구
- [Postman](https://www.postman.com/) - API 테스트
- [OWASP ZAP](https://www.zaproxy.org/) - 보안 스캐닝
- [Burp Suite](https://portswigger.net/burp) - 침투 테스트

### 커뮤니티
- [OWASP Slack](https://owasp.org/slack/invite)
- [IBM API Connect Community](https://community.ibm.com/community/user/integration/communities/community-home?CommunityKey=2106cca0-a9f9-45c6-9b28-01a28f4ce947)

## 라이선스

이 playbook은 교육 및 보안 검증 목적으로 자유롭게 사용할 수 있습니다.

## 기여

개선 사항이나 추가 테스트 케이스가 있다면 기여해주세요!

---

**마지막 업데이트**: 2024-01-15  
**버전**: 1.0.0  
**작성자**: IBM API Connect Security Team