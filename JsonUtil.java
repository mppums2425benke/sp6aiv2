/**
 * Minimal JSON string escaping/unescaping. Good enough for the simple
 * flat request/response shapes used here - not a general JSON parser.
 * If the payloads ever get more complex than "a few known string
 * fields," switch to a real JSON library instead of extending this.
 */
public class JsonUtil {

    public static String escape(String s) {
        return s.replace("\\", "\\\\")
                 .replace("\"", "\\\"")
                 .replace("\n", "\\n")
                 .replace("\r", "");
    }

    public static String unescape(String s) {
        return s.replace("\\n", "\n")
                 .replace("\\\"", "\"")
                 .replace("\\\\", "\\");
    }

    /**
     * Extracts the string value of a top-level JSON field like "question".
     * Returns null if not found. Only handles simple flat objects.
     */
    public static String extractField(String json, String fieldName) {
        String needle = "\"" + fieldName + "\"";
        int idx = json.indexOf(needle);
        if (idx == -1) return null;

        int colon = json.indexOf(':', idx + needle.length());
        if (colon == -1) return null;

        int start = json.indexOf('"', colon + 1);
        if (start == -1) return null;
        start++;

        int end = start;
        while (end < json.length()) {
            if (json.charAt(end) == '"' && json.charAt(end - 1) != '\\') break;
            end++;
        }
        if (end >= json.length()) return null;

        return unescape(json.substring(start, end));
    }
}


