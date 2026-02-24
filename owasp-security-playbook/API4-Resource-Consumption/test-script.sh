#!/bin/bash

# API4: Unrestricted Resource Consumption 테스트 스크립트
# Rate limiting 및 리소스 제한을 테스트합니다

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
    local description="$2"
    local result="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    log ""
    log "테스트 #$TOTAL_TESTS: $test_name"
    log "설명: $description"
    log "결과: $result"
    
    if [[ "$result" == *"PASS"* ]]; then
        log "$(echo -e ${GREEN}✅ PASS${NC})"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        log "$(echo -e ${RED}❌ FAIL${NC})"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# 테스트 시작
log "====================================="
log "API4: Unrestricted Resource Consumption 테스트 시작"
log "시간: $(date)"
log "====================================="

# 시나리오 1: Rate Limiting 테스트
log ""
log "=== 시나리오 1: Rate Limiting 테스트 ==="

log "연속 10회 요청 전송..."
RATE_LIMIT_HIT=false
TEMP_FILE=$(mktemp)

for i in {1..10}; do
    HTTP_CODE=$(curl -s -o "$TEMP_FILE" -w "%{http_code}" "$BASE_URL$API_PATH/ORD00989792")
    log "요청 #$i: HTTP $HTTP_CODE"
    
    if [ "$HTTP_CODE" = "429" ]; then
        RATE_LIMIT_HIT=true
        log "Rate limit 감지됨!"
        break
    fi
    sleep 0.1
done

rm -f "$TEMP_FILE"

if [ "$RATE_LIMIT_HIT" = true ]; then
    test_result "Rate Limiting" "연속 요청 시 429 반환" "PASS - Rate limit 적용됨"
else
    test_result "Rate Limiting" "연속 요청 시 429 반환" "FAIL - Rate limit 미적용"
fi

# 시나리오 2: 대용량 페이로드 테스트
log ""
log "=== 시나리오 2: 대용량 페이로드 테스트 ==="

# 10MB 데이터 생성
LARGE_PAYLOAD=$(python3 -c "print('A' * 10485760)")
TEMP_FILE=$(mktemp)

HTTP_CODE=$(curl -s -o "$TEMP_FILE" -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$LARGE_PAYLOAD" \
    "$BASE_URL$API_PATH/ORD00989792" 2>/dev/null)

rm -f "$TEMP_FILE"

if [ "$HTTP_CODE" = "413" ] || [ "$HTTP_CODE" = "400" ]; then
    test_result "대용량 페이로드" "10MB 데이터 전송 시 거부" "PASS - HTTP $HTTP_CODE 반환"
else
    test_result "대용량 페이로드" "10MB 데이터 전송 시 거부" "FAIL - HTTP $HTTP_CODE 반환 (413 또는 400 예상)"
fi

# 시나리오 3: 동시 요청 테스트
log ""
log "=== 시나리오 3: 동시 요청 테스트 ==="

log "20개의 동시 요청 전송..."
CONCURRENT_LIMIT_HIT=false

for i in {1..20}; do
    (
        TEMP_FILE=$(mktemp)
        HTTP_CODE=$(curl -s -o "$TEMP_FILE" -w "%{http_code}" "$BASE_URL$API_PATH/ORD00989792")
        if [ "$HTTP_CODE" = "429" ] || [ "$HTTP_CODE" = "503" ]; then
            echo "LIMIT_HIT"
        fi
        rm -f "$TEMP_FILE"
    ) &
done

wait

if grep -q "LIMIT_HIT" /tmp/concurrent_test_* 2>/dev/null; then
    CONCURRENT_LIMIT_HIT=true
fi

rm -f /tmp/concurrent_test_* 2>/dev/null

if [ "$CONCURRENT_LIMIT_HIT" = true ]; then
    test_result "동시 요청 제한" "동시 요청 시 429/503 반환" "PASS - 동시 요청 제한 적용됨"
else
    test_result "동시 요청 제한" "동시 요청 시 429/503 반환" "FAIL - 동시 요청 제한 미적용"
fi

# 시나리오 4: 긴 응답 시간 테스트
log ""
log "=== 시나리오 4: 타임아웃 테스트 ==="

TEMP_FILE=$(mktemp)
START_TIME=$(date +%s)

# 30초 타임아웃 설정
HTTP_CODE=$(curl -s -o "$TEMP_FILE" -w "%{http_code}" --max-time 30 "$BASE_URL$API_PATH/ORD00989792")

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

rm -f "$TEMP_FILE"

log "응답 시간: ${ELAPSED}초"

if [ $ELAPSED -lt 10 ]; then
    test_result "응답 시간" "10초 이내 응답" "PASS - ${ELAPSED}초"
else
    test_result "응답 시간" "10초 이내 응답" "FAIL - ${ELAPSED}초 (너무 느림)"
fi

# 시나리오 5: 메모리 소비 테스트
log ""
log "=== 시나리오 5: 반복 요청 메모리 테스트 ==="

log "100회 연속 요청으로 메모리 누수 확인..."
MEMORY_LEAK=false

for i in {1..100}; do
    TEMP_FILE=$(mktemp)
    HTTP_CODE=$(curl -s -o "$TEMP_FILE" -w "%{http_code}" "$BASE_URL$API_PATH/ORD00989792")
    rm -f "$TEMP_FILE"
    
    if [ "$HTTP_CODE" = "500" ] || [ "$HTTP_CODE" = "503" ]; then
        MEMORY_LEAK=true
        log "서버 에러 감지: HTTP $HTTP_CODE (요청 #$i)"
        break
    fi
    
    if [ $((i % 20)) -eq 0 ]; then
        log "진행 중: $i/100 요청 완료"
    fi
done

if [ "$MEMORY_LEAK" = false ]; then
    test_result "메모리 안정성" "100회 요청 후 서버 안정성" "PASS - 서버 안정적"
else
    test_result "메모리 안정성" "100회 요청 후 서버 안정성" "FAIL - 서버 에러 발생"
fi

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
# API4: Unrestricted Resource Consumption 테스트 결과

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
1. Rate Limiting 테스트 (연속 10회 요청)
2. 대용량 페이로드 테스트 (10MB)
3. 동시 요청 테스트 (20개 동시)
4. 응답 시간 테스트 (타임아웃)
5. 메모리 안정성 테스트 (100회 반복)

## 상세 결과
자세한 내용은 $LOG_FILE를 참조하세요.

## 발견된 문제
$(if [ $FAILED_TESTS -gt 0 ]; then echo "- $FAILED_TESTS개의 테스트 실패"; else echo "- 발견된 문제 없음"; fi)

## 권장 조치사항
1. Rate limiting 정책 적용 (예: 분당 100회)
2. 요청 크기 제한 (예: 최대 1MB)
3. 동시 연결 수 제한
4. 응답 타임아웃 설정 (예: 30초)
5. 메모리 사용량 모니터링
6. Circuit breaker 패턴 적용
EOF

log ""
log "결과가 test-results에 저장되었습니다."
log "- 로그: $LOG_FILE"
log "- 요약: $SUMMARY_FILE"

# Made with Bob
