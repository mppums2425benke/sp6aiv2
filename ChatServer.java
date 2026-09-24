import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;

import java.io.*;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;

public class ChatServer {

    private static final int PORT = getPort();

    private static int getPort() {
        String envPort = System.getenv("CHATSERVER_PORT");
        if (envPort != null && !envPort.trim().isEmpty()) {
            return Integer.parseInt(envPort.trim());
        }
        return 8091;
    }

    public static void main(String[] args) throws IOException {
        requireEnv("CTREE_JDBC_URL");
        requireEnv("CTREE_JDBC_USER");
        requireEnv("CTREE_JDBC_PASSWORD");

        HttpServer server = HttpServer.create(new InetSocketAddress(PORT), 0);
        server.createContext("/ask", new AskHandler());
        server.createContext("/health", new HealthHandler());
        server.setExecutor(null);
        server.start();

        System.out.println("ChatServer listening on port " + PORT);
    }

    private static void requireEnv(String name) {
        if (System.getenv(name) == null || System.getenv(name).trim().isEmpty()) {
            System.err.println("Missing required environment variable: " + name);
            System.exit(1);
        }
    }

    static class HealthHandler implements HttpHandler {
        public void handle(HttpExchange exchange) throws IOException {
            sendJson(exchange, 200, "{\"status\":\"ok\"}");
        }
    }

    static class AskHandler implements HttpHandler {
        public void handle(HttpExchange exchange) throws IOException {
            // Instantiate PerformanceLog at the beginning of request processing
            PerformanceLog performance = new PerformanceLog();
	    exchange.getResponseHeaders().set("Access-Control-Allow-Origin", "*");
            exchange.getResponseHeaders().set("Access-Control-Allow-Methods", "POST, OPTIONS");
            exchange.getResponseHeaders().set("Access-Control-Allow-Headers", "Content-Type");

            if ("OPTIONS".equalsIgnoreCase(exchange.getRequestMethod())) {
                exchange.sendResponseHeaders(204, -1);
                return;
            }

            if (!"POST".equalsIgnoreCase(exchange.getRequestMethod())) {
                sendJson(exchange, 405, "{\"error\":\"Only POST is supported\"}");
                return;
            }

            String body = readBody(exchange);
            String question = JsonUtil.extractField(body, "question");

            if (question == null || question.trim().isEmpty()) {
                sendJson(exchange, 400, "{\"error\":\"question is required\"}");
                return;
            }

            System.out.println("[ask] question: " + question);

            try {
                // 1. Generate and validate SQL using the shared AiBridge path
                SqlGuard.Result guard = AiBridge.generateValidatedSql(question);
		// === MARK SQL / AI GENERATION TIME ===
                performance.markSql();
                // =====================================
                if (!guard.allowed) {
                    System.out.println("[ask] REJECTED: " + guard.reason + " | sql: " + guard.sql);
                    sendJson(exchange, 422, "{\"error\":\"" + JsonUtil.escape("Query rejected: " + guard.reason) + "\"}");
                    return;
                }

                System.out.println("[ask] approved sql: " + guard.sql);

                // 2. Execute against c-tree
                List<Map<String, Object>> rows = CtreeQuery.execute(guard.sql);
                // === MARK DATABASE EXECUTION TIME ===
                performance.markDatabase();
                // ===================================
		Map<String, String> displayLabels = AiBridge.loadDisplayLabels(
                    rows.isEmpty() ? java.util.Collections.<String>emptyList()
                        : new java.util.ArrayList<String>(rows.get(0).keySet()));

                // 3. Format answer summary: Use AI's localized summary if provided
                String answer;
                if (guard.summary != null && !guard.summary.trim().isEmpty()) {
                    answer = guard.summary.trim();
                    long countValue = rows.size();
                    if (!rows.isEmpty() && guard.sql != null && guard.sql.toUpperCase().contains("GROUP BY")) {
                        String metricCol = null;
                        if (guard.yAxis != null && !guard.yAxis.trim().isEmpty() && !"none".equalsIgnoreCase(guard.yAxis.trim())) {
                            for (String colName : rows.get(0).keySet()) {
                                if (colName.trim().equalsIgnoreCase(guard.yAxis.trim())) {
                                    metricCol = colName;
                                    break;
                                }
                            }
                        }
                        if (metricCol == null) {
                            for (String colName : rows.get(0).keySet()) {
                                Object firstVal = rows.get(0).get(colName);
                                if (firstVal instanceof Number) {
                                    metricCol = colName;
                                    break;
                                }
                            }
                        }
                        if (metricCol != null) {
                            long sum = 0;
                            boolean validSum = false;
                            for (Map<String, Object> r : rows) {
                                Object v = r.get(metricCol);
                                if (v instanceof Number) {
                                    sum += ((Number) v).longValue();
                                    validSum = true;
                                } else if (v != null) {
                                    try {
                                        sum += Long.parseLong(v.toString().trim());
                                        validSum = true;
                                    } catch (NumberFormatException ignored) {}
                                }
                            }
                            if (validSum && sum > 0) {
                                countValue = sum;
                            }
                        }
                    }
                    if (answer.contains("{count}")) {
                        answer = answer.replace("{count}", String.valueOf(countValue));
                    } else if (answer.matches(".*\\b\\d+\\b.*")) {
                        answer = answer.replaceFirst("\\b\\d+\\b", String.valueOf(countValue));
                    }
                    if (rows.isEmpty()) {
                        if (answer.endsWith(":") || answer.endsWith("?")) {
                            answer = answer.substring(0, answer.length() - 1).trim() + ".";
                        } else if (!answer.endsWith(".")) {
                            answer += ".";
                        }
                    } else {
                        if (!answer.endsWith(":") && !answer.endsWith("?")) {
                            answer += ":";
                        }
                    }
                } else {
                    answer = AnswerFormatter.format(rows, displayLabels);
                }
                System.out.println("[ask] summary: " + guard.summary + " | viz: " + guard.visualization + " | answer: " + answer);

                String btnBar = guard.buttons.getOrDefault("bar", "");
                String btnLine = guard.buttons.getOrDefault("line", "");
                String btnDonut = guard.buttons.getOrDefault("donut", "");
                String btnTable = guard.buttons.getOrDefault("table", "");
                String buttonsJson = "{\"bar\":\"" + JsonUtil.escape(btnBar) + "\",\"line\":\"" + JsonUtil.escape(btnLine) + "\",\"donut\":\"" + JsonUtil.escape(btnDonut) + "\",\"table\":\"" + JsonUtil.escape(btnTable) + "\"}";
                String pageAll = guard.paging.getOrDefault("showingAll", "");
                String pageRange = guard.paging.getOrDefault("showingRange", "");
                String pageMore = guard.paging.getOrDefault("more", "");
                String pageShowAll = guard.paging.getOrDefault("showAll", "");
                String pageShowLess = guard.paging.getOrDefault("showLess", "");
                String pagingJson = "{\"showingAll\":\"" + JsonUtil.escape(pageAll) + "\",\"showingRange\":\"" + JsonUtil.escape(pageRange) + "\",\"more\":\"" + JsonUtil.escape(pageMore) + "\",\"showAll\":\"" + JsonUtil.escape(pageShowAll) + "\",\"showLess\":\"" + JsonUtil.escape(pageShowLess) + "\"}";

                String lang = "EN";
                String btnTbl = guard.buttons.getOrDefault("table", "").trim();
                if ("表".equals(btnTbl) || question.matches(".*[\u3040-\u30ff].*")) {
                    lang = "JA";
                } else if ("表格".equals(btnTbl) || question.matches(".*[\u4e00-\u9fa5].*") || (guard.summary != null && guard.summary.matches(".*[\u4e00-\u9fa5].*"))) {
                    lang = "ZH";
                } else if ("Jadual".equalsIgnoreCase(btnTbl) || "Garisan".equalsIgnoreCase(btnLine) || question.matches("(?i).*(pelajar|senarai|maklumat|butiran|rekod|jantina|tinggi|berat|bangsa|agama|negara|semua|berapa|muda|tua|siapa|paling).*")) {
                    lang = "BM";
                }

		// === MARK OUTPUT FORMATTING TIME ===
                performance.markOutput();
                // ===================================
                
		String responseJson = "{"
                        + "\"answer\": \"" + JsonUtil.escape(answer) + "\","
                        + "\"sql\": \"" + JsonUtil.escape(guard.sql) + "\","
                        + "\"visualization\": \"" + JsonUtil.escape(guard.visualization) + "\","
                        + "\"xAxis\": \"" + JsonUtil.escape(guard.xAxis != null ? guard.xAxis : "") + "\","
                        + "\"yAxis\": \"" + JsonUtil.escape(guard.yAxis != null ? guard.yAxis : "") + "\","
                        + "\"buttons\": " + buttonsJson + ","
                        + "\"paging\": " + pagingJson + ","
                        + "\"language\": \"" + lang + "\","
                        + "\"columns\": " + columnsToJson(rows, displayLabels) + ","
                        + "\"rowCount\": " + rows.size() + ","
			+ "\"performance\": " + performance.toJson() + ","
                        + "\"rows\": " + rowsToJson(rows)
                        + "}";

                sendJson(exchange, 200, responseJson);

            } catch (Exception e) {
                e.printStackTrace();
                sendJson(exchange, 500, "{\"error\":\"" + JsonUtil.escape(userFriendlyError(e)) + "\"}");
            }
        }
    }

    private static String userFriendlyError(Exception error) {
        String technicalMessage = error.getMessage();
        if (technicalMessage != null && technicalMessage.toLowerCase().contains("inconsistent type")) {
            return "The question compares values that the database stores in different formats. "
                    + "Try asking for a birth-year range, or specify a numeric field for the range.";
        }
        if (technicalMessage == null || technicalMessage.trim().isEmpty()) {
            return "The request could not be completed. Please try again with a clearer question.";
        }
        return technicalMessage;
    }

    private static String rowsToJson(List<Map<String, Object>> rows) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < rows.size(); i++) {
            if (i > 0) sb.append(",");
            sb.append("{");
            int j = 0;
            for (Map.Entry<String, Object> e : rows.get(i).entrySet()) {
                if (j > 0) sb.append(",");
                sb.append("\"").append(JsonUtil.escape(e.getKey())).append("\":");
                Object v = e.getValue();
                if (v == null) {
                    sb.append("null");
                } else if (v instanceof Number || v instanceof Boolean) {
                    sb.append(v);
                } else {
                    sb.append("\"").append(JsonUtil.escape(v.toString())).append("\"");
                }
                j++;
            }
            sb.append("}");
        }
        sb.append("]");
        return sb.toString();
    }

    private static String columnsToJson(List<Map<String, Object>> rows, Map<String, String> displayLabels) {
        StringBuilder sb = new StringBuilder("[");
        if (!rows.isEmpty()) {
            int index = 0;
            for (String column : rows.get(0).keySet()) {
                if (index++ > 0) sb.append(",");
                sb.append("{\"name\":\"").append(JsonUtil.escape(column)).append("\",")
                        .append("\"label\":\"").append(JsonUtil.escape(
                                displayLabels.getOrDefault(column, column))).append("\"}");
            }
        }
        return sb.append("]").toString();
    }

    private static String readBody(HttpExchange exchange) throws IOException {
        InputStream in = exchange.getRequestBody();
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] buf = new byte[1024];
        int n;
        while ((n = in.read(buf)) != -1) {
            out.write(buf, 0, n);
        }
        return new String(out.toByteArray(), StandardCharsets.UTF_8);
    }

    private static void sendJson(HttpExchange exchange, int status, String body) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json; charset=utf-8");
        exchange.sendResponseHeaders(status, bytes.length);
        OutputStream os = exchange.getResponseBody();
        os.write(bytes);
        os.close();
    }
}
