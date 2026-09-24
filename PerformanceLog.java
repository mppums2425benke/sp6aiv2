import java.util.Locale;
import java.util.UUID;

/**
 * Captures elapsed time for one /ask request.
 */
public final class PerformanceLog {
    private final String requestId = UUID.randomUUID().toString();
    private final long started = System.nanoTime();
    private long lastMark = started;

    private long detectionMs = -1;   // Changed from hardcoded -1
    private long translationMs = -1; // Changed from hardcoded -1
    private long sqlMs = -1;
    private long databaseMs = -1;
    private long outputMs = -1;

    public String getRequestId() {
        return requestId;
    }

    // --- Added methods for Detection and Translation ---
    public void markDetection() {
        detectionMs = markDurationMs();
    }

    public void markTranslation() {
        translationMs = markDurationMs();
    }
    // --------------------------------------------------

    public void markSql() {
        sqlMs = markDurationMs();
    }

    public void markDatabase() {
        databaseMs = markDurationMs();
    }

    public void markOutput() {
        outputMs = markDurationMs();
    }

    public String complete(String questionType, String result) {
        long totalMs = elapsedMs();
        return String.format(Locale.ROOT,
                "[performance] requestId=%s questionType=%s totalMs=%d detectionMs=%d translationMs=%d sqlMs=%d databaseMs=%d outputTranslationMs=%d result=%s",
                requestId, sanitize(questionType), totalMs, detectionMs, translationMs, sqlMs, databaseMs, outputMs,
                sanitize(result));
    }

    public String toJson() {
        return "{\"totalMs\":" + elapsedMs()
                + ",\"detectionMs\":" + detectionMs
                + ",\"translationMs\":" + translationMs
                + ",\"sqlMs\":" + sqlMs
                + ",\"databaseMs\":" + databaseMs
                + ",\"outputTranslationMs\":" + outputMs
                + "}";
    }

    private long elapsedMs() {
        return (System.nanoTime() - started) / 1_000_000L;
    }

    private long markDurationMs() {
        long now = System.nanoTime();
        long duration = (now - lastMark) / 1_000_000L;
        lastMark = now;
        return duration;
    }

    private static String sanitize(String value) {
        if (value == null || value.trim().isEmpty()) return "unknown";
        return value.trim().replaceAll("\\s+", "_");
    }
}
