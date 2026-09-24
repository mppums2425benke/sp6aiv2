import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Turns raw query rows into a concise plain-English answer without a second
 * AI call. The formatter is schema-neutral and uses the returned column
 * labels, so it also handles newly configured tables and fields.
 */
public class AnswerFormatter {

    public static String format(List<Map<String, Object>> rows) {
        return format(rows, null);
    }

    public static String format(List<Map<String, Object>> rows, Map<String, String> displayLabels) {
        if (rows.isEmpty()) {
            return "No matching records found.";
        }

        if (rows.size() == 1 && rows.get(0).size() == 1) {
            Object value = rows.get(0).values().iterator().next();
            return "Answer: " + formatValue(value);
        }

        if (rows.size() == 1) {
            return formatSingleResult(rows.get(0), displayLabels);
        }

        return rows.size() + " matching record(s) found:";
    }

    private static String formatSingleResult(Map<String, Object> row, Map<String, String> displayLabels) {
        StringBuilder sb = new StringBuilder();
        int index = 0;
        for (Map.Entry<String, Object> entry : row.entrySet()) {
            if (index++ > 0) sb.append("; ");
            sb.append(displayLabel(entry.getKey(), displayLabels)).append(" = ")
                    .append(formatValue(entry.getValue()));
        }
        return sb.toString();
    }

    private static String displayLabel(String column, Map<String, String> displayLabels) {
        if (displayLabels != null) {
            String label = displayLabels.get(column);
            if (label != null && !label.trim().isEmpty()) return label.trim();
        }
        return humanize(column);
    }

    private static String humanize(String column) {
        if (column == null || column.trim().isEmpty()) return "Value";
        String text = column.trim().replace('_', ' ');
        StringBuilder result = new StringBuilder();
        for (String word : text.split("\\s+")) {
            if (word.isEmpty()) continue;
            if (result.length() > 0) result.append(' ');
            result.append(Character.toUpperCase(word.charAt(0))).append(word.substring(1).toLowerCase());
        }
        return result.toString();
    }

    private static String formatValue(Object value) {
        if (value == null) return "?";
        if (value instanceof Number) {
            if (value instanceof Float || value instanceof Double) {
                return String.format(Locale.US, "%.2f", ((Number) value).doubleValue());
            }
            return value.toString();
        }
        return value.toString().trim();
    }
}
