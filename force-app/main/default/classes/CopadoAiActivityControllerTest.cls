@IsTest
private class CopadoAiActivityControllerTest {
    private static final String SUMMARY_BODY =
        '[{"user_id":"005xx","count_messages":12,"max_messages":30000}]';
    private static String lastEndpoint;
    private static Map<String, String> lastHeaders = new Map<String, String>();

    private class ActivityMock implements HttpCalloutMock {
        private final Integer statusCode;
        private final String body;
        private final Boolean failCallout;

        ActivityMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
            this.failCallout = false;
        }

        ActivityMock(Boolean failCallout) {
            this.statusCode = 0;
            this.body = null;
            this.failCallout = failCallout;
        }

        public HttpResponse respond(HttpRequest req) {
            CopadoAiActivityControllerTest.lastEndpoint = req.getEndpoint();
            CopadoAiActivityControllerTest.lastHeaders.put('X-Authorization', req.getHeader('X-Authorization'));
            if (failCallout) {
                CalloutException ex = new CalloutException();
                ex.setMessage('Read timed out');
                throw ex;
            }
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }

    @IsTest
    static void testGetActivitySummary_Success() {
        Test.setMock(HttpCalloutMock.class, new ActivityMock(200, SUMMARY_BODY));

        Test.startTest();
        List<CopadoAiActivityController.ActivitySummaryWrapper> rows =
            CopadoAiActivityController.getActivitySummary('2026-08-01', '2026-09-01');
        Test.stopTest();

        Assert.areEqual(1, rows.size(), 'Summary should return one user row.');
        Assert.areEqual('005xx', rows[0].userId);
        Assert.areEqual(12L, rows[0].totalPrompts);
        Assert.areEqual(30000L, rows[0].messageLimit);
        Assert.isTrue(lastEndpoint.startsWith('callout:Copado_AI_API/activity/summary'), 'Summary path should be used on the named credential.');
        Assert.isTrue(lastEndpoint.contains('2026-08-01T00%3A00%3A00Z'), 'Start date should include the beginning of the day.');
        Assert.isTrue(lastEndpoint.contains('2026-09-01T23%3A59%3A59Z'), 'End date should include the end of the day.');
        Assert.isNull(lastHeaders.get('X-Authorization'), 'Apex must not set the API key header.');
    }

    @IsTest
    static void testErrorStatuses() {
        Test.setMock(HttpCalloutMock.class, new ActivityMock(401, '{}'));
        assertSummaryError('Unauthorized. Check the API key in the Copado AI external credential.');
        Test.setMock(HttpCalloutMock.class, new ActivityMock(403, '{}'));
        assertSummaryError('Forbidden. Check the named credential endpoint and API key.');
        Test.setMock(HttpCalloutMock.class, new ActivityMock(404, '{}'));
        assertSummaryError('Resource not found. Check the named credential endpoint and API key.');
        Test.setMock(HttpCalloutMock.class, new ActivityMock(429, '{}'));
        assertSummaryError('Rate limit exceeded. Please try again later.');
        Test.setMock(HttpCalloutMock.class, new ActivityMock(500, '{}'));
        assertSummaryError('Copado AI API error. Contact your administrator.');
        Test.setMock(HttpCalloutMock.class, new ActivityMock(200, 'not-json'));
        assertSummaryError('Copado AI API error. Contact your administrator.');
    }

    @IsTest
    static void testCalloutException() {
        Test.setMock(HttpCalloutMock.class, new ActivityMock(true));
        assertSummaryError('Unable to reach Copado AI. Please try again later.');

        AuraHandledException thrown;
        try {
            CopadoAiActivityController.getRawActivity('2026-08-01', '2026-09-01', 20);
        } catch (AuraHandledException e) {
            thrown = e;
        }
        Assert.isNotNull(thrown, 'Raw activity should surface callout failures.');
        Assert.areEqual('Unable to reach Copado AI. Please try again later.', thrown.getMessage());
    }

    @IsTest
    static void testGetRawActivity_Success() {
        String body = '[{"id":"evt-1","user_id":"005xx","action":"new_message","workspace_id":"ws-1",'
            + '"message":"' + 'x'.repeat(300) + '","created_at":"2026-10-08T17:43:18.263960Z"}]';
        Test.setMock(HttpCalloutMock.class, new ActivityMock(200, body));

        Test.startTest();
        List<CopadoAiActivityController.RawActivityWrapper> rows =
            CopadoAiActivityController.getRawActivity('2026-08-01', '2026-09-01', 500);
        Test.stopTest();

        Assert.areEqual(1, rows.size(), 'Raw activity should return one event.');
        Assert.areEqual('evt-1', rows[0].eventId);
        Assert.areEqual('005xx', rows[0].userId);
        Assert.areEqual('new_message', rows[0].action);
        Assert.areEqual('ws-1', rows[0].workspaceId);
        Assert.areEqual(243, rows[0].prompt.length(), 'Message preview should be truncated.');
        Assert.isTrue(rows[0].prompt.endsWith('...'));
        Assert.areEqual('2026-10-08T17:43:18.263Z', rows[0].timestamp);
        Assert.isTrue(lastEndpoint.startsWith('callout:Copado_AI_API/activity?'), 'Raw path should be used.');
        Assert.isTrue(lastEndpoint.contains('limit=200'), 'Raw results should be capped at 200.');
        Assert.isFalse(lastEndpoint.contains('/activity/summary'));
    }

    @IsTest
    static void testLimitsAndEmptyBodies() {
        Test.setMock(HttpCalloutMock.class, new ActivityMock(200, ''));
        Assert.areEqual(0, CopadoAiActivityController.getActivitySummary(null, null).size());
        Assert.areEqual('callout:Copado_AI_API/activity/summary', lastEndpoint, 'No query string without dates.');
        Assert.areEqual(0, CopadoAiActivityController.getRawActivity('2026-08-01', null, 0).size());
        Assert.isTrue(lastEndpoint.contains('limit=1'), 'Limit should be raised to at least 1.');
        Assert.areEqual(0, CopadoAiActivityController.getRawActivity(null, '2026-09-01', null).size());
        Assert.isTrue(lastEndpoint.contains('limit=200'), 'Default limit should be 200.');
    }

    @IsTest
    static void testTimestampNormalization() {
        String body = '[{"id":"a","created_at":"2026-10-08T17:43:18.263960+02:00"},'
            + '{"id":"b","created_at":"2026-10-08T17:43:18.263960-05:00"},'
            + '{"id":"c","created_at":"2026-10-08T17:43:18.26Z"},'
            + '{"id":"d","created_at":"2026-10-08T17:43:18Z"},'
            + '{"id":"e","created_at":"2026-10-08T17:43:18.263960"},'
            + '{"id":"f"}]';
        Test.setMock(HttpCalloutMock.class, new ActivityMock(200, body));
        List<CopadoAiActivityController.RawActivityWrapper> rows =
            CopadoAiActivityController.getRawActivity(null, null, 10);
        Assert.areEqual('2026-10-08T17:43:18.263+02:00', rows[0].timestamp);
        Assert.areEqual('2026-10-08T17:43:18.263-05:00', rows[1].timestamp);
        Assert.areEqual('2026-10-08T17:43:18.26Z', rows[2].timestamp);
        Assert.areEqual('2026-10-08T17:43:18Z', rows[3].timestamp);
        Assert.areEqual('2026-10-08T17:43:18.263960', rows[4].timestamp);
        Assert.isNull(rows[5].timestamp);
    }

    @IsTest
    static void testBuildRequest_Headers() {
        Test.startTest();
        HttpRequest req = CopadoAiActivityController.buildRequest('/activity/summary');
        Test.stopTest();

        Assert.areEqual('GET', req.getMethod());
        Assert.areEqual(30000, CopadoAiActivityController.TIMEOUT_MS);
        Assert.isNull(req.getHeader('X-Authorization'), 'The key is injected by the external credential, not Apex.');
        Assert.areEqual('application/json', req.getHeader('Content-Type'));
        Assert.areEqual('application/json', req.getHeader('Accept'));
        Assert.areEqual('callout:Copado_AI_API/activity/summary', req.getEndpoint());
    }

    @IsTest
    static void testDateRangeValidation() {
        AuraHandledException thrown;
        try {
            CopadoAiActivityController.getActivitySummary('2026-09-02', '2026-09-01');
        } catch (AuraHandledException e) {
            thrown = e;
        }
        Assert.isNotNull(thrown, 'Reversed dates should be rejected.');
        Assert.areEqual('Start date must be on or before the end date.', thrown.getMessage());
    }

    private static void assertSummaryError(String expectedMessage) {
        AuraHandledException thrown;
        try {
            CopadoAiActivityController.getActivitySummary('2026-08-01', '2026-09-01');
        } catch (AuraHandledException e) {
            thrown = e;
        }
        Assert.isNotNull(thrown, 'Expected AuraHandledException: ' + expectedMessage);
        Assert.areEqual(expectedMessage, thrown.getMessage());
    }
}