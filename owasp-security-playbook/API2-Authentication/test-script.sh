#!/bin/bash

# API2: Broken Authentication 테스트 스크립트
# 인증 메커니즘의 취약점을 테스트합니다

# 색상 코드
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 테스트 설정
BASE_URL="https://api-oxo.a-vir-s1.apiconnect.ipaas.ibmappdomain.cloud/prod906958/sandbox"
API_PATH="/order"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="test-results"
LOG_FILE="$RESULTS_DIR/test_$TIMESTAMP.log"
SUMMARY_FILE="$RESULTS_DIR/summary_$TIMESTAMP.md"

# 결과 디렉토리 생성
mkdir -p $RESULTS_DIR

# 테스트 카운터
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 로그 함수
log() {
    echo "$1" | tee -a $LOG_FILE
}

# 테스트 결과 함수
test_result() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    local description="$4"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    log ""
    log "테스트 #$TOTAL_TESTS: $test_name"
    log "설명: $description"
    log "예상: $expected"
    log "실제: $actual"
    
    if [ "$expected" = "$actual" ]; then
        log "$(echo -e ${GREEN}✅ PASS${NC})"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log "$(echo -e ${RED}❌ FAIL${NC})"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# 테스트 시작
log "====================================="
log "API2: Broken Authentication 테스트 시작"
log "시간: $(date)"
log "====================================="

# 시나리오 1: 인증 없이 접근
log ""
log "=== 시나리오 1: 인증 없이 API 접근 ==="

TEMP_FILE=$(mktemp)
HTTP_CODE=$(curl -s -o "$TEMP_FILE" -w "%{http_code}" "$BASE_URL$API_PATH/ORD00989792")
test_result "인증 없이 접근" "401" "$HTTP_CODE" "인증 없이 API 호출 시 401 반환 확인"
rm -f "$TEMP_FILE"

# 시나리오 2: 잘못된 인증 정보
log ""
log "=== 시나리오 2: 잘못된 인증 정보 ==="

TEMP_FILE=$(mktemp)
HTTP_CODE=$(curl -s -o "$TEMP_FILE" -w "%{http_code}" \
    -H "X-IBM-Client-Id: invalid-client-id" \
    "$BASE_URL$API_PATH/ORD00989792")
test_result "잘못된 Client ID" "401" "$HTTP_CODE" "잘못된 Client ID로 접근 시 401 반환"
rm -f "$TEMP_FILE"

# 시나리오 3: 빈 인증 헤더
log ""
log "=== 시나리오 3: 빈 인증 헤더 ==="

TEMP_FILE=$(mktemp)
HTTP_CODE=$(curl -s -o "$TEMP_FILE" -w "%{http_code}" \
    -H "X-IBM-Client-Id: " \
    "$BASE_URL$API_PATH/ORD00989792")
test_result "빈 Client ID" "401" "$HTTP_CODE" "빈 Client ID로 접근 시 401 반환"
rm -f "$TEMP_FILE"

# 시나리오 4: SQL Injection 시도
log ""
log "=== 시나리오 4: SQL Injection 시도 ==="

TEMP_FILE=$(mktemp)
HTTP_CODE=$(curl -s -o "$TEMP_FILE" -w "%{http_code}" \
    -H "X-IBM-Client-Id: ' OR '1'='1" \
    "$BASE_URL$API_PATH/ORD00989792")
test_result "SQL Injection" "401" "$HTTP_CODE" "SQL Injection 시도 시 401 반환"
rm -f "$TEMP_FILE"

# 시나리오 5: 특수문자 포함 인증
log ""
log "=== 시나리오 5: 특수문자 포함 인증 ==="

TEMP_FILE=$(mktemp)
HTTP_CODE=$(curl -s -o "$TEMP_FILE" -w "%{http_code}" \
    -H "X-IBM-Client-Id: <script>alert('xss')</script>" \
    "$BASE_URL$API_PATH/ORD00989792")
test_result "XSS 시도" "401" "$HTTP_CODE" "XSS 시도 시 401 반환"
rm -f "$TEMP_FILE"

# 시나리오 6: 매우 긴 인증 토큰
log ""
log "=== 시나리오 6: 버퍼 오버플로우 테스트 ==="

LONG_TOKEN=$(python3 -c "print('A' * 10000)")
TEMP_FILE=$(mktemp)
HTTP_CODE=$(curl -s -o "$TEMP_FILE" -w "%{http_code}" \
    -H "X-IBM-Client-Id: $LONG_TOKEN" \
    "$BASE_URL$API_PATH/ORD00989792")
test_result "긴 토큰" "401" "$HTTP_CODE" "매우 긴 토큰으로 접근 시 401 반환"
rm -f "$TEMP_FILE"

# 결과 요약
log ""
log "====================================="
log "테스트 결과 요약"
log "====================================="
log "총 테스트: $TOTAL_TESTS"
log "통과: $PASSED_TESTS"
log "실패: $FAILED_TESTS"

if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc)
    log "성공률: ${SUCCESS_RATE}%"
fi

log "====================================="

# 요약 파일 생성
cat > $SUMMARY_FILE << EOF
# API2: Broken Authentication 테스트 결과

## 테스트 정보
- 실행 시간: $(date)
- API URL: $BASE_URL
- 로그 파일: $LOG_FILE

## 결과 요약
- 총 테스트: $TOTAL_TESTS
- 통과: $PASSED_TESTS
- 실패: $FAILED_TESTS
- 성공률: ${SUCCESS_RATE}%

## 테스트 시나리오
1. 인증 없이 API 접근
2. 잘못된 인증 정보
3. 빈 인증 헤더
4. SQL Injection 시도
5. XSS 시도
6. 버퍼 오버플로우 테스트

## 상세 결과
자세한 내용은 $LOG_FILE를 참조하세요.

## 발견된 문제
$(if [ $FAILED_TESTS -gt 0 ]; then echo "- $FAILED_TESTS개의 테스트 실패"; else echo "- 발견된 문제 없음"; fi)

## 권장 조치사항
1. 모든 API 엔드포인트에 인증 적용
2. 강력한 인증 메커니즘 사용 (OAuth 2.0, JWT)
3. 인증 실패 시 적절한 에러 메시지 반환
4. Rate limiting 적용하여 brute force 공격 방지
5. 입력 값 검증 및 sanitization
EOF

log ""
log "결과가 test-results에 저장되었습니다."
log "- 로그: $LOG_FILE"
log "- 요약: $SUMMARY_FILE"

# Made with Bob
