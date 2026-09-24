import java.io.*;
import java.net.*;
import javax.net.ssl.HttpsURLConnection;
import java.nio.charset.StandardCharsets;
import java.sql.*;
import java.time.LocalDate;
import java.util.*;

public class AiBridge {

    private static volatile Set<String> allowedTables = Collections.emptySet();

    private static class AiConfig {
        String provider = "";
        String apiKey = "";
        String model = "";
        String url = "";
    }

    private static final String BASE_RULES =
        "You translate a user's natural language question into ONE read-only SQL statement for a c-treeACE SQL database.\n\n";

    public static void main(String[] args) {
        if (args.length == 0) return;
        String question = args[0];
        String sqlFile = (args.length > 1) ? args[1] : "/z/sp6ai/v2/temp/ai_sql.txt";
        String resFile = (args.length > 2) ? args[2] : "/z/sp6ai/v2/temp/ai_res.txt";
        String cfgFile = (args.length > 3) ? args[3] : "/z/sp6ai/v2/temp/ai_cfg.txt";

        AiConfig config;
        try {
            config = loadConfigFromDb();
        } catch (Exception e) {
            try (FileWriter fw = new FileWriter(sqlFile)) { fw.write(""); } catch (Exception ignored) {}
            try (FileWriter fw = new FileWriter(resFile)) {
                fw.write("ERROR: Unable to read AI Engine Configuration from DBLCF: " + e.getMessage());
            } catch (Exception ignored) {}
            return;
        }

        String[] out = ask(question, config.provider, config.apiKey, config.model, config.url);

        try (FileWriter fw = new FileWriter(sqlFile)) {
            fw.write(out[0]);
        } catch (Exception e) {}

        try (FileWriter fw = new FileWriter(resFile)) {
            fw.write(out[1]);
        } catch (Exception e) {}
    }

    public static String[] ask(String question, String provider, String apiKey, String model, String url) {
        String sql = "";
        StringBuilder res = new StringBuilder();

        try (Connection conn = openConnection()) {
            String englishQuery = question;
            String userLanguage = "EN";

            // Dynamically load schema, tables, columns, relationships, and dictionary from database
            String dynamicSchema = loadDynamicSchema(conn);
            SqlGuard.Result guard = generateValidatedSql(englishQuery, provider, apiKey, model, url, dynamicSchema);
            sql = guard.sql;
            if (!guard.allowed) {
                return new String[]{sql, "Security Error: " + guard.reason};
            }

            // Execute SQL query against c-treeRTG
            try (Statement stmt = conn.createStatement()) {
                ResultSet rs = stmt.executeQuery(sql);
                ResultSetMetaData md = rs.getMetaData();
                int cols = md.getColumnCount();

                // Header
                for (int i = 1; i <= cols; i++) {
                    if (i > 1) res.append(" | ");
                    res.append(String.format("%-18s", padRight(md.getColumnName(i), 18)));
                }
                res.append("\n");

                // Divider
                for (int i = 1; i <= cols; i++) {
                    if (i > 1) res.append("-+-");
                    res.append("------------------");
                }
                res.append("\n");

                // Data Rows
                int count = 0;
                while (rs.next()) {
                    count++;
                    for (int i = 1; i <= cols; i++) {
                        if (i > 1) res.append(" | ");
                        Object val = rs.getObject(i);
                        String s = "";
                        if (val != null) {
                            String rawVal = val.toString().trim();
                            if (rawVal.matches("^-?\\d+\\.\\d{3,}$")) {
                                try {
                                    double d = Double.parseDouble(rawVal);
                                    s = String.format(Locale.US, "%.2f", d);
                                } catch (Exception ex) {
                                    s = rawVal;
                                }
                            } else {
                                s = rawVal;
                            }
                        }
                        res.append(String.format("%-18s", padRight(s, 18)));
                    }
                    res.append("\n");
                }
                if (count == 0) {
                    res.append("(No matching records found)\n");
                } else {
                    res.append("\nTotal: ").append(count).append(" record(s) retrieved.");
                }
            }
        } catch (Exception e) {
            res.append("Error: ").append(userFriendlyError(e));
        }
        return new String[]{sql, res.toString()};
    }

    private static String userFriendlyError(Exception error) {
        String technicalMessage = error.getMessage();
        if (technicalMessage != null && technicalMessage.toLowerCase().contains("inconsistent type")) {
            return "The question compares values that the database stores in different formats. "
                    + "Try asking for a birth-year range, or specify a numeric field for the range.";
        }
        return technicalMessage == null || technicalMessage.trim().isEmpty()
                ? "The request could not be completed."
                : technicalMessage;
    }

    public static String generateSql(String question) throws IOException {
        SqlGuard.Result result = generateValidatedSql(question);
        if (!result.allowed) {
            throw new IOException("Generated SQL rejected: " + result.reason);
        }
        return result.sql;
    }

    public static SqlGuard.Result generateValidatedSql(String question) throws IOException {
        if (question == null || question.trim().isEmpty()) {
            throw new IllegalArgumentException("Question is required");
        }

        AiConfig config;
        try {
            config = loadConfigFromDb();
        } catch (SQLException e) {
            throw new IOException("Unable to load AI configuration from DBLCF: " + detail(e), e);
        }

        try {
            String dynamicSchema = loadDynamicSchema();
            return generateValidatedSql(question, config.provider, config.apiKey, config.model, config.url, dynamicSchema);
        } catch (SQLException e) {
            throw new IOException("Unable to load authorized database schema: " + detail(e), e);
        } catch (IllegalArgumentException e) {
            throw new IOException(e.getMessage(), e);
        } catch (IOException e) {
            throw e;
        } catch (Exception e) {
            throw new IOException("AI provider request failed: " + detail(e), e);
        }
    }

    private static SqlGuard.Result generateValidatedSql(String question, String provider, String apiKey,
            String model, String url, String dynamicSchema) throws IOException {
        try {
            String systemPrompt = buildSystemPrompt(dynamicSchema);
            String raw = generateSqlWithConfig(question.trim(), provider, apiKey, model, url, systemPrompt);
            if (raw != null) {
                raw = raw.replace("\\n", "\n").replace("\\r", "");
                System.out.println("[AiBridge DEBUG raw]:\n" + raw);
            }
            String summary = null;
            String visualization = "auto";
            String xAxis = null;
            String yAxis = null;
            Map<String, String> buttons = new LinkedHashMap<>();
            Map<String, String> paging = new LinkedHashMap<>();

            if (raw != null) {
                String[] lines = raw.split("\r?\n");
                StringBuilder sqlBuilder = new StringBuilder();
                for (String line : lines) {
                    String trimmed = line.trim();
                    if (trimmed.startsWith("SUMMARY:")) {
                        summary = trimmed.substring(8).trim();
                    } else if (trimmed.startsWith("VISUALIZATION:")) {
                        visualization = trimmed.substring(14).trim().toLowerCase(Locale.ROOT);
                    } else if (trimmed.startsWith("X_AXIS:")) {
                        xAxis = trimmed.substring(7).trim();
                        if ("none".equalsIgnoreCase(xAxis)) xAxis = null;
                    } else if (trimmed.startsWith("Y_AXIS:")) {
                        yAxis = trimmed.substring(7).trim();
                        if ("none".equalsIgnoreCase(yAxis)) yAxis = null;
                    } else if (trimmed.startsWith("BUTTONS:")) {
                        String btnLine = trimmed.substring(8).trim();
                        String[] parts = btnLine.split("\\|");
                        if (parts.length >= 4) {
                            buttons.put("bar", parts[0].trim());
                            buttons.put("line", parts[1].trim());
                            buttons.put("donut", parts[2].trim());
                            buttons.put("table", parts[3].trim());
                        }
                    } else if (trimmed.startsWith("PAGING:")) {
                        String pageLine = trimmed.substring(7).trim();
                        String[] parts = pageLine.split("\\|");
                        for (int i = 0; i < parts.length; i++) {
                            String p = parts[i].trim();
                            if (p.contains("{visible}")) {
                                paging.put("showingRange", p);
                            } else if (i == 0 && !paging.containsKey("showingAll")) {
                                paging.put("showingAll", p);
                            } else if (i == 1 && !paging.containsKey("showingRange")) {
                                paging.put("showingRange", p);
                            } else if (i == 2 && !paging.containsKey("more")) {
                                paging.put("more", p);
                            } else if (i == 3 && !paging.containsKey("showAll")) {
                                paging.put("showAll", p);
                            } else if (i == 4 && !paging.containsKey("showLess")) {
                                paging.put("showLess", p);
                            }
                        }
                        if (parts.length >= 1 && !paging.containsKey("showingAll") && !parts[0].contains("{visible}")) {
                            paging.put("showingAll", parts[0].trim());
                        }
                    } else if (trimmed.startsWith("SQL:")) {
                        sqlBuilder.append(trimmed.substring(4).trim()).append(" ");
                    } else if (!trimmed.startsWith("```") && !trimmed.isEmpty()) {
                        sqlBuilder.append(trimmed).append(" ");
                    }
                }
                raw = sqlBuilder.toString().trim();
            }

            String sql = cleanSql(raw);
            String sqlWithRuntimeDate = injectRuntimeDateValues(sql);
            SqlGuard.Result guard = SqlGuard.check(sqlWithRuntimeDate);
            return new SqlGuard.Result(guard.allowed, guard.reason, guard.sql, summary, visualization, xAxis, yAxis, buttons, paging);
        } catch (IllegalArgumentException e) {
            throw new IOException(e.getMessage(), e);
        } catch (IOException e) {
            throw e;
        } catch (Exception e) {
            throw new IOException("AI provider request failed: " + detail(e), e);
        }
    }

    private static String detail(Exception error) {
        String message = error.getMessage();
        return message == null || message.trim().isEmpty() ? error.getClass().getSimpleName() : message;
    }

    private static AiConfig loadConfigFromDb() throws SQLException {
        AiConfig config = new AiConfig();
        String sql = "SELECT " +
                "dblcf_key, " +
                "dblcf_openai_flag, dblcf_openai_api_link, dblcf_openai_api_key, dblcf_openai_api_model, " +
                "dblcf_meta_flag, dblcf_meta_api_link, dblcf_meta_api_key, dblcf_meta_api_model, " +
                "dblcf_ds_flag, dblcf_ds_api_link, dblcf_ds_api_key, dblcf_ds_api_model, " +
                "dblcf_gm_flag, dblcf_gm_api_link, dblcf_gm_api_key, dblcf_gm_api_model " +
                "FROM \"dblcf.db\" WHERE dblcf_key = '1'";

        try (Connection conn = openConnection();
             Statement st = conn.createStatement();
             ResultSet rs = st.executeQuery(sql)) {
            if (!rs.next()) {
                throw new IllegalStateException("No DBLCF configuration record found for key '1'.");
            }

            if (isYes(rs.getString("dblcf_openai_flag"))) {
                config.provider = "openai";
                config.url = trimOrEmpty(rs.getString("dblcf_openai_api_link"));
                config.apiKey = trimOrEmpty(rs.getString("dblcf_openai_api_key"));
                config.model = trimOrEmpty(rs.getString("dblcf_openai_api_model"));
            } else if (isYes(rs.getString("dblcf_meta_flag"))) {
                config.provider = "meta";
                config.url = trimOrEmpty(rs.getString("dblcf_meta_api_link"));
                config.apiKey = trimOrEmpty(rs.getString("dblcf_meta_api_key"));
                config.model = trimOrEmpty(rs.getString("dblcf_meta_api_model"));
            } else if (isYes(rs.getString("dblcf_ds_flag"))) {
                config.provider = "deepseek";
                config.url = trimOrEmpty(rs.getString("dblcf_ds_api_link"));
                config.apiKey = trimOrEmpty(rs.getString("dblcf_ds_api_key"));
                config.model = trimOrEmpty(rs.getString("dblcf_ds_api_model"));
            } else if (isYes(rs.getString("dblcf_gm_flag"))) {
                config.provider = "gemini";
                config.url = trimOrEmpty(rs.getString("dblcf_gm_api_link"));
                config.apiKey = trimOrEmpty(rs.getString("dblcf_gm_api_key"));
                config.model = trimOrEmpty(rs.getString("dblcf_gm_api_model"));
            } else {
                throw new IllegalStateException("No active AI provider is enabled in DBLCF.");
            }
        }

        if (config.provider.isEmpty() || config.apiKey.isEmpty() || config.model.isEmpty() || config.url.isEmpty()) {
            throw new IllegalStateException("AI engine configuration is incomplete in DBLCF: provider, api key, model, and URL must all be set.");
        }
        return config;
    }

    private static boolean isYes(String value) {
        return value != null && value.toString().trim().equalsIgnoreCase("Y");
    }

    private static String generateSqlWithConfig(String question, String provider, String apiKey,
            String model, String url, String systemPrompt) throws Exception {
        if (provider == null || provider.trim().isEmpty()) {
            throw new IllegalArgumentException("AI provider is required in DBLCF.");
        }
        if (apiKey == null || apiKey.trim().isEmpty()) {
            throw new IllegalArgumentException("API key is required in DBLCF.");
        }
        if (model == null || model.trim().isEmpty()) {
            throw new IllegalArgumentException("Model is required in DBLCF.");
        }
        if (url == null || url.trim().isEmpty()) {
            throw new IllegalArgumentException("AI endpoint URL is required in DBLCF.");
        }

        String normalizedProvider = provider.trim().toLowerCase(Locale.ROOT);
        if ("meta".equals(normalizedProvider) || "deepseek".equals(normalizedProvider) || "openai".equals(normalizedProvider)) {
            return callOpenAiCompatible(question.trim(), apiKey.trim(), model.trim(), url.trim(), systemPrompt);
        }
        if ("gemini".equals(normalizedProvider)) {
            return callGemini(question.trim(), apiKey.trim(), model.trim(), url.trim(), systemPrompt);
        }
        throw new IllegalArgumentException("Unsupported AI provider in DBLCF: " + provider);
    }

    public static String loadDynamicSchema(Connection conn) {
        StringBuilder sb = new StringBuilder();

        try (Statement stmt = conn.createStatement()) {
            appendCompanyRules(sb, stmt);
            // 1. Authorized tables from dblai.db (where dblai_read_flag = 'Y')
            Set<String> authTables = new LinkedHashSet<>();
            Map<String, String> tableDesc = new LinkedHashMap<>();
            Map<String, String> authTableByKey = new HashMap<>();
            ResultSet rs = stmt.executeQuery("SELECT dblai_db, dblai_db_name FROM \"dblai.db\" WHERE dblai_read_flag = 'Y'");
            while (rs.next()) {
                String db = rs.getString(1).trim();
                String desc = rs.getString(2) == null ? "" : rs.getString(2).trim();
                authTables.add(db);
                tableDesc.put(db, desc);
                authTableByKey.put(db.toLowerCase(Locale.ROOT), db);
            }
            Set<String> normalizedTables = new LinkedHashSet<>();
            for (String table : authTables) normalizedTables.add(table.toLowerCase(Locale.ROOT));
            allowedTables = Collections.unmodifiableSet(normalizedTables);

            // 2. Columns & Relationships from dblai2.db
            Map<String, List<String>> tableCols = new LinkedHashMap<>();
            List<String> relationships = new ArrayList<>();

            rs = stmt.executeQuery("SELECT dblai2_db, dblai2_field, dblai2_attribute, dblai2_link_db, dblai2_link_field FROM \"dblai2.db\" ORDER BY dblai2_db, dblai2_field");
            while (rs.next()) {
                String db = rs.getString(1).trim();
                String field = rs.getString(2).trim();
                String attr = rs.getString(3) == null ? "" : rs.getString(3).trim();
                String linkDb = rs.getString(4) == null ? "" : rs.getString(4).trim();
                String linkFld = rs.getString(5) == null ? "" : rs.getString(5).trim();

                String tableKey = authTableByKey.get(db.toLowerCase(Locale.ROOT));
                if (tableKey == null) continue;

                tableCols.computeIfAbsent(tableKey, k -> new ArrayList<>()).add(field + (attr.equals("PK") ? " (PK)" : attr.equals("FK") ? " (FK)" : ""));

                if ("FK".equalsIgnoreCase(attr) && !linkDb.isEmpty() && !linkFld.isEmpty()) {
                    relationships.add("  - \"" + tableKey + "\".\"" + field + "\" joins to \"" + linkDb + "\".\"" + linkFld + "\"");
                }
            }

            sb.append("- Available Tables and Columns (Dynamically loaded from Database):\n");
            for (String t : authTables) {
                sb.append("  \"").append(t).append("\" (").append(tableDesc.getOrDefault(t, "")).append("): ");
                sb.append(String.join(", ", tableCols.getOrDefault(t, Collections.emptyList()))).append("\n");
            }

            if (!relationships.isEmpty()) {
                sb.append("\n- Foreign Key Relationships (Use for JOINs):\n");
                for (String r : relationships) sb.append(r).append("\n");
            }

        } catch (Exception e) {
            allowedTables = Collections.emptySet();
            sb.append("/* Note: Dynamic schema error: ").append(e.getMessage()).append(" */\n");
        }

        return sb.toString();
    }

    private static void appendCompanyRules(StringBuilder prompt, Statement stmt) {
        prompt.append("\n- Dynamic Rules (loaded from dblrule.db):\n");
        try (ResultSet rules = stmt.executeQuery(
                "SELECT dblrule_category, dblrule_text FROM \"dblrule.db\" WHERE dblrule_active = 'Y' ORDER BY dblrule_order, dblrule_id")) {
            int ruleCount = 0;
            while (rules.next()) {
                String cat = rules.getString(1);
                String text = rules.getString(2);
                if (text == null || text.trim().isEmpty()) continue;
                prompt.append("  - [").append(cat != null ? cat.trim() : "RULE").append("] ")
                      .append(text.trim()).append("\n");
                ruleCount++;
            }
            if (ruleCount == 0) prompt.append("  (No dynamic rules configured)\n");
        } catch (SQLException e) {
            prompt.append("  (Unable to load dynamic rules: ").append(e.getMessage()).append(")\n");
        }
        prompt.append("\n");
    }

    public static String loadDynamicSchema() throws SQLException {
        try (Connection conn = openConnection()) {
            return loadDynamicSchema(conn);
        }
    }

    public static boolean isTableAllowed(String table) throws SQLException {
        if (table == null || table.trim().isEmpty()) return false;

        loadDynamicSchema();
        String normalized = table.trim().toLowerCase(Locale.ROOT);
        if (allowedTables.contains(normalized)) return true;
        if (normalized.endsWith(".db")) {
            return allowedTables.contains(normalized.substring(0, normalized.length() - 3));
        }
        return allowedTables.contains(normalized + ".db");
    }

    public static Map<String, String> loadDisplayLabels(List<String> columns) throws SQLException {
        return Collections.emptyMap();
    }

    private static String trimOrEmpty(String value) {
        return value == null ? "" : value.trim();
    }

    private static Connection openConnection() throws SQLException {
        String url = requiredEnvironment("CTREE_JDBC_URL");
        String user = requiredEnvironment("CTREE_JDBC_USER");
        String password = requiredEnvironment("CTREE_JDBC_PASSWORD");
        return DriverManager.getConnection(url, user, password);
    }

    private static String requireEnv(String name) {
        String value = System.getenv(name);
        if (value == null || value.trim().isEmpty()) {
            throw new IllegalStateException(name + " environment variable is not set");
        }
        return value.trim();
    }

    private static String requiredEnvironment(String name) throws SQLException {
        String value = System.getenv(name);
        if (value == null || value.trim().isEmpty()) {
            throw new SQLException(name + " environment variable is not set");
        }
        return value.trim();
    }

    private static String padRight(String s, int n) {
        if (s == null) s = "";
        if (s.length() > n) return s.substring(0, n);
        return String.format("%-" + n + "s", s);
    }

    private static String buildSystemPrompt(String dynamicSchema) {
        StringBuilder sb = new StringBuilder(BASE_RULES);
        sb.append(dynamicSchema);
        return sb.toString();
    }

    private static String callGemini(String question, String apiKey, String model, String endpointUrl, String systemPrompt) throws Exception {
        String normalizedModel = normalizeGeminiModel(model);
        String urlStr = buildGeminiRequestUrl(endpointUrl, normalizedModel, apiKey);
        String prompt = systemPrompt + "\nQuestion: " + question + "\nOutput:";
        String body = "{\"contents\":[{\"parts\":[{\"text\":\"" + escapeJson(prompt) + "\"}]}]}";

        URL url = new URL(urlStr);
        HttpsURLConnection conn = (HttpsURLConnection) url.openConnection();
        conn.setRequestMethod("POST");
        conn.setRequestProperty("Content-Type", "application/json");
        conn.setConnectTimeout(10000);
        conn.setReadTimeout(35000);
        conn.setDoOutput(true);

        try (OutputStream os = conn.getOutputStream()) {
            os.write(body.getBytes(StandardCharsets.UTF_8));
        }

        int status = conn.getResponseCode();
        InputStream is = (status == 200) ? conn.getInputStream() : conn.getErrorStream();
        StringBuilder sb = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) sb.append(line);
        }

        if (status != 200) throw new RuntimeException("Gemini (" + model + ") HTTP " + status + ": " + sb.toString());

        String resp = sb.toString();
        int idx = resp.indexOf("\"text\": \"");
        if (idx == -1) idx = resp.indexOf("\"text\":\"");
        if (idx == -1) return resp;

        int start = resp.indexOf('\"', idx + 7) + 1;
        int end = resp.indexOf('\"', start);
        while (end > start && resp.charAt(end - 1) == '\\') {
            end = resp.indexOf('\"', end + 1);
        }
        return resp.substring(start, end);
    }

    private static String buildGeminiRequestUrl(String endpointUrl, String model, String apiKey) {
        if (endpointUrl == null || endpointUrl.trim().isEmpty()) {
            throw new IllegalArgumentException("Gemini API endpoint URL is required in DBLCF.");
        }
        if (apiKey == null || apiKey.trim().isEmpty()) {
            throw new IllegalArgumentException("Gemini API key is required in DBLCF.");
        }

        String base = endpointUrl.trim();
        base = base.replaceAll("/+$", "");

        int modelsIndex = base.toLowerCase(Locale.ROOT).indexOf("/models/");
        if (modelsIndex >= 0) {
            base = base.substring(0, modelsIndex);
        } else {
            int v1betaIndex = base.toLowerCase(Locale.ROOT).indexOf("/v1beta");
            if (v1betaIndex >= 0) {
                base = base.substring(0, v1betaIndex);
            }
        }

        base = base.replaceAll("/+$", "");
        if (base.isEmpty()) {
            throw new IllegalArgumentException("Gemini API endpoint URL is invalid in DBLCF.");
        }

        return base + "/v1beta/models/" + model + ":generateContent?key=" + apiKey;
    }

    private static String normalizeGeminiModel(String model) {
        if (model == null) {
            throw new IllegalArgumentException("Gemini model is required in DBLCF.");
        }
        String normalized = model.trim();
        normalized = normalized.replaceFirst("(?i)^models/", "");
        normalized = normalized.replace(":generateContent", "");
        normalized = normalized.replace(":generateText", "");
        normalized = normalized.replace(":streamGenerateContent", "");
        normalized = normalized.trim();
        if (normalized.isEmpty()) {
            throw new IllegalArgumentException("Gemini model is empty in DBLCF.");
        }
        return normalized;
    }

    private static String callOpenAiCompatible(String question, String apiKey, String model, String endpointUrl, String systemPrompt) throws Exception {
        String prompt = systemPrompt + "\nQuestion: " + question + "\nOutput:";
        String body = "{\"model\":\"" + model + "\",\"messages\":[{\"role\":\"user\",\"content\":\"" + escapeJson(prompt) + "\"}]}";

        URL url = new URL(endpointUrl);
        HttpsURLConnection conn = (HttpsURLConnection) url.openConnection();
        conn.setRequestMethod("POST");
        conn.setRequestProperty("Content-Type", "application/json");
        conn.setRequestProperty("Authorization", "Bearer " + apiKey);
        conn.setConnectTimeout(10000);
        conn.setReadTimeout(35000);
        conn.setDoOutput(true);

        try (OutputStream os = conn.getOutputStream()) {
            os.write(body.getBytes(StandardCharsets.UTF_8));
        }

        int status = conn.getResponseCode();
        InputStream is = (status == 200) ? conn.getInputStream() : conn.getErrorStream();
        StringBuilder sb = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) sb.append(line);
        }

        if (status != 200) throw new RuntimeException("AI API error (HTTP " + status + "): " + sb.toString());

        String resp = sb.toString();
        int idx = resp.indexOf("\"content\": \"");
        if (idx == -1) idx = resp.indexOf("\"content\":\"");
        if (idx == -1) return resp;

        int start = resp.indexOf('\"', idx + 10) + 1;
        int end = resp.indexOf('\"', start);
        while (end > start && resp.charAt(end - 1) == '\\') {
            end = resp.indexOf('\"', end + 1);
        }
        return resp.substring(start, end);
    }

    private static String cleanSql(String raw) {
        String s = raw == null ? "" : raw.trim();
        if (s.startsWith("SQL:")) s = s.substring(4).trim();
        if (s.contains("</think>")) {
            s = s.substring(s.indexOf("</think>") + 8);
        } else if (s.contains("\\u003c/think\\u003e")) {
            s = s.substring(s.indexOf("\\u003c/think\\u003e") + 18);
        }
        s = s.replace("```sql", "")
             .replace("```", "")
             .replace("\\u003e", ">")
             .replace("\\u003c", "<")
             .replace("\\u0026", "&")
             .replace("\\n", " ")
             .replace("\\\"", "\"")
             .replace("\\r", "")
             .trim();
        if (s.endsWith(";")) s = s.substring(0, s.length() - 1).trim();

        // Fix duplicate table aliases e.g. s.s.col -> s.col
        s = s.replaceAll("\\b([a-zA-Z_]\\w*)\\.\\1\\.", "$1.");

        // Fix unsupported LIMIT N into c-tree TOP N
        if (s.matches("(?i).*\\bLIMIT\\s+\\d+\\s*$")) {
            java.util.regex.Matcher m = java.util.regex.Pattern.compile("(?i)\\bLIMIT\\s+(\\d+)\\s*$").matcher(s);
            if (m.find()) {
                String limitNum = m.group(1);
                s = s.substring(0, m.start()).trim();
                if (!s.matches("(?i)^SELECT\\s+TOP\\s+\\d+.*")) {
                    s = s.replaceFirst("(?i)^SELECT(\\s+DISTINCT)?\\s+", "SELECT$1 TOP " + limitNum + " ");
                }
            }
        }

        return s;
    }

    private static String injectRuntimeDateValues(String sql) {
        if (sql == null || sql.trim().isEmpty()) {
            return sql;
        }

        LocalDate today = LocalDate.now();
        String year = Integer.toString(today.getYear());
        String month = Integer.toString(today.getMonthValue());
        String day = Integer.toString(today.getDayOfMonth());

        return sql
            .replace("CURRENT_YEAR", year)
            .replace("CURRENT_MONTH", month)
            .replace("CURRENT_DAY", day);
    }

    private static String escapeJson(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n");
    }
}

