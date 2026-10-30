public with sharing class CopadoAiActivityController {
    @TestVisible
    private static final Integer TIMEOUT_MS = 30000;
    @TestVisible
    private static final Integer MAX_RAW_LIMIT = 200;
    private static final String ENDPOINT = 'callout:Copado_AI_API';
    private static final Map<Integer, String> STATUS_MESSAGES = new Map<Integer, String>{
        401 => 'Unauthorized. Check the API key in the Copado AI external credential.',
        403 => 'Forbidden. Check the named credential endpoint and API key.',
        404 => 'Resource not found. Check the named credential endpoint and API key.',
        429 => 'Rate limit exceeded. Please try again later.'
    };

    public class ActivitySummaryWrapper {
        @AuraEnabled public String userId;
        @AuraEnabled public Long totalPrompts;
        @AuraEnabled public Long messageLimit;
    }

    public class RawActivityWrapper {
        @AuraEnabled public String eventId;
        @AuraEnabled public String userId;
        @AuraEnabled public String action;
        @AuraEnabled public String workspaceId;
        @AuraEnabled public String prompt;
        @AuraEnabled public String timestamp;
    }

    @AuraEnabled
    public static List<ActivitySummaryWrapper> getActivitySummary(String startDate, String endDate) {
        try {
            assertDateRange(startDate, endDate);
            String path = '/activity/summary' + buildDateQuery(startDate, endDate, null);
            return CopadoAiActivityResponseParser.parseSummary(parseResponse(send(buildRequest(path))));
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            handleError('getActivitySummary', e);
            return null;
        }
    }

    @AuraEnabled
    public static List<RawActivityWrapper> getRawActivity(String startDate, String endDate, Integer limitCount) {
        try {
            assertDateRange(startDate, endDate);
            String path = '/activity' + buildDateQuery(startDate, endDate, capLimit(limitCount));
            return CopadoAiActivityResponseParser.parseRaw(parseResponse(send(buildRequest(path))));
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            handleError('getRawActivity', e);
            return null;
        }
    }

    @TestVisible
    private static HttpRequest buildRequest(String path) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT + path);
        req.setMethod('GET');
        req.setTimeout(TIMEOUT_MS);
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        return req;
    }

    private static String parseResponse(HttpResponse res) {
        Integer status = res.getStatusCode();
        if (status == 200) {
            return res.getBody();
        }
        String message = STATUS_MESSAGES.get(status);
        if (message == null) {
            message = 'Copado AI API error. Contact your administrator.';
        }
        throwHandled(message);
        return null;
    }

    private static void handleError(String context, Exception e) {
        System.debug(LoggingLevel.ERROR, 'CopadoAiActivityController.' + context + ' failed: ' + e.getTypeName());
        if (e instanceof CalloutException) {
            throwHandled('Unable to reach Copado AI. Please try again later.');
        }
        throwHandled('Copado AI API error. Contact your administrator.');
    }

    private static HttpResponse send(HttpRequest req) {
        return new Http().send(req);
    }

    private static String buildDateQuery(String startDate, String endDate, Integer limitCount) {
        List<String> parts = new List<String>();
        addDateParam(parts, 'date_since', startDate, true);
        addDateParam(parts, 'date_until', endDate, false);
        if (limitCount != null) {
            parts.add('limit=' + limitCount);
        }
        return parts.isEmpty() ? '' : '?' + String.join(parts, '&');
    }

    private static void addDateParam(List<String> parts, String name, String value, Boolean isStart) {
        if (String.isBlank(value)) {
            return;
        }
        String normalized = value.length() == 10
            ? value + (isStart ? 'T00:00:00Z' : 'T23:59:59Z')
            : value;
        parts.add(name + '=' + EncodingUtil.urlEncode(normalized, 'UTF-8'));
    }

    private static Integer capLimit(Integer limitCount) {
        Integer requested = limitCount == null ? MAX_RAW_LIMIT : limitCount;
        return requested < 1 ? 1 : Math.min(requested, MAX_RAW_LIMIT);
    }

    private static void assertDateRange(String startDate, String endDate) {
        if (String.isNotBlank(startDate) && String.isNotBlank(endDate) && startDate > endDate) {
            throwHandled('Start date must be on or before the end date.');
        }
    }

    private static void throwHandled(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        throw ex;
    }
}