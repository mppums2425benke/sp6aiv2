import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * The enforcement layer. The LLM's output is NEVER trusted on its own -
 * this class decides whether a generated SQL statement is actually
 * allowed to run.
 */
public class SqlGuard {

    private static final String[] FORBIDDEN_KEYWORDS = {
            "INSERT", "UPDATE", "DELETE", "DROP", "ALTER", "CREATE",
            "TRUNCATE", "EXEC", "EXECUTE", "GRANT", "REVOKE", "MERGE"
    };

    private static final Pattern SELECT_ONLY = Pattern.compile("^\\s*SELECT\\b", Pattern.CASE_INSENSITIVE);

    // Table names are double-quoted and contain a literal dot.
    private static final Pattern TABLE_PATTERN = Pattern.compile(
            "\\bFROM\\s+\"([^\"]+)\"|\\bJOIN\\s+\"([^\"]+)\"", Pattern.CASE_INSENSITIVE);

    public static class Result {
        public final boolean allowed;
        public final String reason;
        public final String sql;
        public final String summary;
        public final String visualization;
        public final String xAxis;
        public final String yAxis;
        public final java.util.Map<String, String> buttons;
        public final java.util.Map<String, String> paging;

        Result(boolean allowed, String reason, String sql) {
            this(allowed, reason, sql, null, "auto", null, null, java.util.Collections.<String, String>emptyMap(), java.util.Collections.<String, String>emptyMap());
        }

        Result(boolean allowed, String reason, String sql, String summary) {
            this(allowed, reason, sql, summary, "auto", null, null, java.util.Collections.<String, String>emptyMap(), java.util.Collections.<String, String>emptyMap());
        }

        Result(boolean allowed, String reason, String sql, String summary, String visualization) {
            this(allowed, reason, sql, summary, visualization, null, null, java.util.Collections.<String, String>emptyMap(), java.util.Collections.<String, String>emptyMap());
        }

        Result(boolean allowed, String reason, String sql, String summary, String visualization, String xAxis, String yAxis) {
            this(allowed, reason, sql, summary, visualization, xAxis, yAxis, java.util.Collections.<String, String>emptyMap(), java.util.Collections.<String, String>emptyMap());
        }

        Result(boolean allowed, String reason, String sql, String summary, String visualization, String xAxis, String yAxis, java.util.Map<String, String> buttons) {
            this(allowed, reason, sql, summary, visualization, xAxis, yAxis, buttons, java.util.Collections.<String, String>emptyMap());
        }

        Result(boolean allowed, String reason, String sql, String summary, String visualization, String xAxis, String yAxis, java.util.Map<String, String> buttons, java.util.Map<String, String> paging) {
            this.allowed = allowed;
            this.reason = reason;
            this.sql = sql;
            this.summary = summary;
            this.visualization = (visualization == null || visualization.isEmpty()) ? "auto" : visualization;
            this.xAxis = xAxis;
            this.yAxis = yAxis;
            this.buttons = buttons != null ? buttons : java.util.Collections.<String, String>emptyMap();
            this.paging = paging != null ? paging : java.util.Collections.<String, String>emptyMap();
        }
    }

    public static Result check(String sql) {
        if (sql == null || sql.trim().isEmpty()) {
            return new Result(false, "Empty SQL generated", sql);
        }

        String trimmedSql = sql.trim();
        String upperSql = trimmedSql.toUpperCase();

        if (upperSql.equals("REFUSED") || upperSql.startsWith("REFUSED_MODIFY")) {
            return new Result(false, "Question requires modifying data, which is not permitted", sql);
        }

        if (upperSql.startsWith("REFUSED_UNAVAILABLE") || upperSql.startsWith("REFUSED_RESTRICTED") || upperSql.startsWith("REFUSED_TABLE")) {
            return new Result(false, "Requested table or data is restricted or not available", sql);
        }

        if (!SELECT_ONLY.matcher(sql).find()) {
            return new Result(false, "Only SELECT statements are allowed", sql);
        }

        String upper = sql.toUpperCase();

        if (sql.trim().endsWith(";")) {
            sql = sql.trim().substring(0, sql.trim().length() - 1);
        } else if (sql.contains(";")) {
            return new Result(false, "Statement chaining is not allowed", sql);
        }

        for (String keyword : FORBIDDEN_KEYWORDS) {
            if (Pattern.compile("\\b" + keyword + "\\b").matcher(upper).find()) {
                return new Result(false, "Forbidden keyword: " + keyword, sql);
            }
        }

        Matcher tableMatcher = TABLE_PATTERN.matcher(sql);
        boolean foundAny = false;
        while (tableMatcher.find()) {
            foundAny = true;
            String table = tableMatcher.group(1) != null ? tableMatcher.group(1) : tableMatcher.group(2);
            try {
                if (!AiBridge.isTableAllowed(table)) {
                    return new Result(false, "Table not allowed: " + table, sql);
                }
            } catch (java.sql.SQLException e) {
                return new Result(false, "Unable to verify table authorization", sql);
            }
        }
        if (!foundAny) {
            return new Result(false, "Could not identify a double-quoted table in the query", sql);
        }

        return new Result(true, "OK", sql);
    }
}
