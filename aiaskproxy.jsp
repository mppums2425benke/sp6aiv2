<%@ page contentType="application/json" pageEncoding="UTF-8" %>
<%@ page import="java.io.*" %>
<%@ page import="java.net.*" %>
<%@ page import="java.nio.charset.StandardCharsets" %>
<%
    String targetUrl = "http://localhost:8093/ask";

    StringBuilder requestBody = new StringBuilder();
    BufferedReader reader = request.getReader();
    String line;
    while ((line = reader.readLine()) != null) {
        requestBody.append(line);
    }

    try {
        URL url = new URL(targetUrl);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("POST");
        conn.setRequestProperty("Content-Type", "application/json");
        conn.setDoOutput(true);
        conn.setConnectTimeout(5000);
        conn.setReadTimeout(30000);

        OutputStream os = conn.getOutputStream();
        try {
            os.write(requestBody.toString().getBytes(StandardCharsets.UTF_8));
        } finally {
            os.close();
        }

        int status = conn.getResponseCode();
        InputStream is = (status < 400) ? conn.getInputStream() : conn.getErrorStream();

        StringBuilder responseBody = new StringBuilder();
        BufferedReader respReader = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8));
        try {
            String respLine;
            while ((respLine = respReader.readLine()) != null) {
                responseBody.append(respLine);
            }
        } finally {
            respReader.close();
        }

        response.setStatus(status);
        out.print(responseBody.toString());

    } catch (Exception e) {
        response.setStatus(502);
        out.print("{\"error\":\"Could not reach the AI assistant service.\"}");
        e.printStackTrace();
    }
%>

