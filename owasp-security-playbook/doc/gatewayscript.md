IBM API Connect(APIC) v12 및 v10 환경에서 **GatewayScript(GWS)**는 DataPower 게이트웨이의 기능을 활용하여 API 어셈블리 내에서 복잡한 비즈니스 로직을 처리할 때 사용됩니다. 최신 DataPower API Gateway에서는 별도의 선언 없이 글로벌 context 객체를 바로 사용하는 방식이 성능과 기능 면에서 권장됩니다.
다음은 주요 기능별 사용법과 실제 적용 가능한 코드 예시입니다.
1. 컨텍스트 변수 및 헤더 제어
API 호출 과정에서 발생하는 다양한 데이터(Client ID, 요청 경로 등)를 읽거나 수정할 수 있습니다.
• 변수 읽기 및 쓰기:
• HTTP 헤더 조작:
2. 메시지 페이로드(본문) 처리
JSON 또는 XML 데이터를 비동기 방식으로 읽고 수정할 수 있습니다.
• JSON 응답 수정 예시:
3. 세션 거부 및 상태 코드 제어
보안 검증 실패 시 호출을 즉시 중단하고 특정 에러를 반환합니다.
• 권한 검증 실패 처리:
4. 분석 데이터(Analytics) 커스터마이징
기본 분석 로그 외에 비즈니스에 필요한 특정 데이터를 추가하여 대시보드에서 확인할 수 있습니다.
• 커스텀 데이터 로그 추가:
5. API 어셈블리(YAML) 내 적용 예시
작성한 GatewayScript는 OpenAPI YAML 파일의 execute 섹션에 다음과 같이 포함됩니다.
x-ibm-configuration:
  assembly:
    execute:
      - gatewayscript:
          version: 2.0.0
          title: "Check User Scope"
          source: |
            var scope = context.get('oauth.processing.scope');
            if (scope && scope.indexOf('admin') === -1) {
                context.reject('Forbidden', '관리자 권한이 필요합니다.');
                context.message.statusCode = 403;
            }
주의사항:
• 나노 게이트웨이 및 최신 API 게이트웨이에서는 var apim = require('apim'); 방식보다 글로벌 context 객체를 사용하는 것이 권장됩니다. 기존 방식은 하위 호환성(Migration)을 위한 기능으로 간주되어 경고가 나타날 수 있습니다.
• 데이터를 조작하기 전에는 항상 parse 정책이 선행되어야 게이트웨이가 페이로드를 인식할 수 있습니다