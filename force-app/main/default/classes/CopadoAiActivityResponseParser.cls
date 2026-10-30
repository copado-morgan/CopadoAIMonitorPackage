/**
 * Parses Copado AI activity API payloads into Aura-enabled wrappers.
 */
public with sharing class CopadoAiActivityResponseParser {
    private static final Integer PROMPT_PREVIEW_LENGTH = 240;

    private class SummaryDto {
        public String user_id;
        public Decimal count_messages;
        public Decimal max_messages;
    }

    private class RawDto {
        public String id;
        public String user_id;
        public String action;
        public String workspace_id;
        public String message;
        public String created_at;
    }

    public static List<CopadoAiActivityController.ActivitySummaryWrapper> parseSummary(String body) {
        List<CopadoAiActivityController.ActivitySummaryWrapper> mapped =
            new List<CopadoAiActivityController.ActivitySummaryWrapper>();
        if (String.isBlank(body)) {
            return mapped;
        }
        for (SummaryDto dto : (List<SummaryDto>) JSON.deserialize(body, List<SummaryDto>.class)) {
            CopadoAiActivityController.ActivitySummaryWrapper row =
                new CopadoAiActivityController.ActivitySummaryWrapper();
            row.userId = dto.user_id;
            row.totalPrompts = toLong(dto.count_messages);
            row.messageLimit = toLong(dto.max_messages);
            mapped.add(row);
        }
        return mapped;
    }

    public static List<CopadoAiActivityController.RawActivityWrapper> parseRaw(String body) {
        List<CopadoAiActivityController.RawActivityWrapper> mapped =
            new List<CopadoAiActivityController.RawActivityWrapper>();
        if (String.isBlank(body)) {
            return mapped;
        }
        for (RawDto dto : (List<RawDto>) JSON.deserialize(body, List<RawDto>.class)) {
            CopadoAiActivityController.RawActivityWrapper row =
                new CopadoAiActivityController.RawActivityWrapper();
            row.eventId = dto.id;
            row.userId = dto.user_id;
            row.action = dto.action;
            row.workspaceId = dto.workspace_id;
            row.prompt = truncate(dto.message);
            row.timestamp = normalizeTimestamp(dto.created_at);
            mapped.add(row);
        }
        return mapped;
    }

    private static String truncate(String message) {
        if (message == null || message.length() <= PROMPT_PREVIEW_LENGTH) {
            return message;
        }
        return message.substring(0, PROMPT_PREVIEW_LENGTH) + '...';
    }

    private static Long toLong(Decimal value) {
        return value == null ? null : value.longValue();
    }

    private static String normalizeTimestamp(String value) {
        if (String.isBlank(value)) {
            return value;
        }
        Integer dot = value.indexOf('.');
        if (dot < 0) {
            return value;
        }
        Integer zone = indexOfZone(value, dot);
        if (zone < 0 || zone - dot - 1 <= 3) {
            return value;
        }
        return value.substring(0, dot + 4) + value.substring(zone);
    }

    private static Integer indexOfZone(String value, Integer after) {
        Integer zone = value.indexOf('Z', after);
        if (zone >= 0) {
            return zone;
        }
        zone = value.indexOf('+', after);
        if (zone >= 0) {
            return zone;
        }
        return value.length() > after + 1 ? value.indexOf('-', after + 1) : -1;
    }
}