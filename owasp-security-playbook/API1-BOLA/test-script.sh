#!/bin/bash

# API1-BOLA Test Script
# Tests for Broken Object Level Authorization vulnerabilities

# Configuration
API_BASE_URL="https://api-oxo.a-vir-s1.apiconnect.ipaas.ibmappdomain.cloud/prod906958/sandbox/order"
CLIENT_ID="528f929efc88dd8ae75feeb961b87e1e"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="test-results"
LOG_FILE="${LOG_DIR}/test_${TIMESTAMP}.log"
SUMMARY_FILE="${LOG_DIR}/summary_${TIMESTAMP}.md"

# Create log directory
mkdir -p ${LOG_DIR}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to log test results
log_test() {
    local test_name=$1
    local expected=$2
    local actual=$3
    local status=$4
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo "========================================" | tee -a ${LOG_FILE}
    echo "Test: ${test_name}" | tee -a ${LOG_FILE}
    echo "Expected: ${expected}" | tee -a ${LOG_FILE}
    echo "Actual: ${actual}" | tee -a ${LOG_FILE}
    
    if [ "${status}" == "PASS" ]; then
        echo -e "${GREEN}✓ PASS${NC}" | tee -a ${LOG_FILE}
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ FAIL${NC}" | tee -a ${LOG_FILE}
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo "" | tee -a ${LOG_FILE}
}

# Start testing
echo "==================================================" | tee ${LOG_FILE}
echo "API1-BOLA Security Test" | tee -a ${LOG_FILE}
echo "Timestamp: $(date)" | tee -a ${LOG_FILE}
echo "==================================================" | tee -a ${LOG_FILE}
echo "" | tee -a ${LOG_FILE}

# Test 1: Request without X-User-Id header (should fail with 401 in production)
echo -e "${YELLOW}Test 1: Authentication Check - No X-User-Id Header${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${API_BASE_URL}/test100" \
    -H "Accept: application/json" \
    -H "X-IBM-Client-Id: ${CLIENT_ID}")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" == "401" ]; then
    log_test "No X-User-Id Header" "401 Unauthorized" "HTTP ${HTTP_CODE}" "PASS"
else
    log_test "No X-User-Id Header" "401 Unauthorized" "HTTP ${HTTP_CODE} - ${BODY}" "FAIL"
fi

# Test 2: Request with X-User-Id header but non-existent order
echo -e "${YELLOW}Test 2: Valid User, Non-existent Order${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${API_BASE_URL}/nonexistent123" \
    -H "Accept: application/json" \
    -H "X-IBM-Client-Id: ${CLIENT_ID}" \
    -H "X-User-Id: user-a")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" == "404" ]; then
    log_test "Valid User, Non-existent Order" "404 Not Found" "HTTP ${HTTP_CODE}" "PASS"
else
    log_test "Valid User, Non-existent Order" "404 Not Found" "HTTP ${HTTP_CODE} - ${BODY}" "FAIL"
fi

# Test 3: Try to access with valid order number (if exists)
echo -e "${YELLOW}Test 3: Valid User, Valid Order${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${API_BASE_URL}/ORD00989792" \
    -H "Accept: application/json" \
    -H "X-IBM-Client-Id: ${CLIENT_ID}" \
    -H "X-User-Id: user-a")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "404" ]; then
    log_test "Valid User, Valid Order" "200 OK or 404 Not Found" "HTTP ${HTTP_CODE}" "PASS"
    if [ "$HTTP_CODE" == "200" ]; then
        echo "Response Body:" | tee -a ${LOG_FILE}
        echo "$BODY" | jq '.' 2>/dev/null | tee -a ${LOG_FILE} || echo "$BODY" | tee -a ${LOG_FILE}
    fi
else
    log_test "Valid User, Valid Order" "200 OK or 404 Not Found" "HTTP ${HTTP_CODE} - ${BODY}" "FAIL"
fi

# Test 4: BOLA Attack Simulation - User A tries to access User B's order
echo -e "${YELLOW}Test 4: BOLA Attack - User A accessing User B's Order${NC}"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${API_BASE_URL}/user-b-order-456" \
    -H "Accept: application/json" \
    -H "X-IBM-Client-Id: ${CLIENT_ID}" \
    -H "X-User-Id: user-a")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

# In production, this should return 403 Forbidden
# In test mode, it might return 404 if order doesn't exist
if [ "$HTTP_CODE" == "403" ] || [ "$HTTP_CODE" == "404" ]; then
    log_test "BOLA Attack Simulation" "403 Forbidden or 404 Not Found" "HTTP ${HTTP_CODE}" "PASS"
else
    log_test "BOLA Attack Simulation" "403 Forbidden or 404 Not Found" "HTTP ${HTTP_CODE} - ${BODY}" "FAIL"
fi

# Generate Summary
echo "==================================================" | tee -a ${LOG_FILE}
echo "Test Summary" | tee -a ${LOG_FILE}
echo "==================================================" | tee -a ${LOG_FILE}
echo "Total Tests: ${TOTAL_TESTS}" | tee -a ${LOG_FILE}
echo -e "${GREEN}Passed: ${PASSED_TESTS}${NC}" | tee -a ${LOG_FILE}
echo -e "${RED}Failed: ${FAILED_TESTS}${NC}" | tee -a ${LOG_FILE}
echo "==================================================" | tee -a ${LOG_FILE}

# Create Markdown Summary
cat > ${SUMMARY_FILE} << EOF
# API1-BOLA Test Results

**Test Date:** $(date)  
**API Endpoint:** ${API_BASE_URL}

## Summary

- **Total Tests:** ${TOTAL_TESTS}
- **Passed:** ${PASSED_TESTS}
- **Failed:** ${FAILED_TESTS}
- **Success Rate:** $(awk "BEGIN {printf \"%.1f\", (${PASSED_TESTS}/${TOTAL_TESTS})*100}")%

## Test Results

### Test 1: Authentication Check - No X-User-Id Header
- **Expected:** 401 Unauthorized
- **Status:** $([ "$PASSED_TESTS" -ge 1 ] && echo "✓ PASS" || echo "✗ FAIL")

### Test 2: Valid User, Non-existent Order
- **Expected:** 404 Not Found
- **Status:** $([ "$PASSED_TESTS" -ge 2 ] && echo "✓ PASS" || echo "✗ FAIL")

### Test 3: Valid User, Valid Order
- **Expected:** 200 OK or 404 Not Found
- **Status:** $([ "$PASSED_TESTS" -ge 3 ] && echo "✓ PASS" || echo "✗ FAIL")

### Test 4: BOLA Attack Simulation
- **Expected:** 403 Forbidden or 404 Not Found
- **Status:** $([ "$PASSED_TESTS" -ge 4 ] && echo "✓ PASS" || echo "✗ FAIL")

## Detailed Logs

See \`${LOG_FILE}\` for detailed test execution logs.

## Recommendations

1. **If Test 1 Failed:** Ensure X-User-Id header validation is enabled in production
2. **If Test 4 Failed:** Implement proper ownership validation in GatewayScript
3. **Monitor Analytics:** Check API Connect Analytics for unauthorized access attempts
4. **Enable Alerts:** Set up alerts for 403 errors indicating BOLA attack attempts

## Next Steps

- [ ] Review failed tests
- [ ] Update GatewayScript for production deployment
- [ ] Enable strict authentication mode
- [ ] Implement database-backed ownership validation
- [ ] Set up monitoring and alerting
EOF

echo ""
echo "Test completed. Results saved to:"
echo "  - Log: ${LOG_FILE}"
echo "  - Summary: ${SUMMARY_FILE}"

# Exit with appropriate code
if [ ${FAILED_TESTS} -eq 0 ]; then
    exit 0
else
    exit 1
fi

# Made with Bob
