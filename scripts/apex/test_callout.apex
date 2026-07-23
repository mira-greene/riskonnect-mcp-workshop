// Test MCP server connectivity via Named Credential
// Usage: sf apex run --file scripts/apex/test_callout.apex --target-org <alias>

String namedCredential = 'callout:RiskonnectPolicyAdvisor';

// JSON-RPC request to list tools
String requestBody = '{"jsonrpc":"2.0","method":"tools/list","params":{},"id":1}';

HttpRequest req = new HttpRequest();
req.setEndpoint(namedCredential);
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setBody(requestBody);

Http http = new Http();
HttpResponse res;

try {
    res = http.send(req);
    System.debug('STATUS_CODE=' + res.getStatusCode());
    System.debug('BODY=' + res.getBody());

    if (res.getStatusCode() == 200) {
        System.debug('✓ MCP server reachable');

        // Parse and count tools
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        if (responseMap.containsKey('result')) {
            Map<String, Object> result = (Map<String, Object>) responseMap.get('result');
            if (result.containsKey('tools')) {
                List<Object> tools = (List<Object>) result.get('tools');
                System.debug('TOOL_COUNT=' + tools.size());

                for (Object tool : tools) {
                    Map<String, Object> toolMap = (Map<String, Object>) tool;
                    System.debug('TOOL=' + toolMap.get('name'));
                }
            }
        }
    } else {
        System.debug('✗ Unexpected status code: ' + res.getStatusCode());
    }
} catch (Exception e) {
    System.debug('ERROR=' + e.getMessage());
    System.debug('ERROR_TYPE=' + e.getTypeName());
}
