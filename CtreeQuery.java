import java.sql.*;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Executes an already-validated, read-only SELECT against c-tree via the
 * FairCom JDBC driver. Assumes SqlGuard has already approved the SQL -
 * this class does no further safety checks besides a read-only connection
 * as defense in depth.
 *
 * Connection details come from environment variables:
 *   CTREE_JDBC_URL, CTREE_JDBC_USER, CTREE_JDBC_PASSWORD
 */
public class CtreeQuery {

    private static final int MAX_ROWS = 200;

    public static List<Map<String, Object>> execute(String sql) throws SQLException {
        String url = requireEnv("CTREE_JDBC_URL");
        String user = requireEnv("CTREE_JDBC_USER");
        String password = requireEnv("CTREE_JDBC_PASSWORD");

        List<Map<String, Object>> rows = new ArrayList<Map<String, Object>>();

        Connection conn = DriverManager.getConnection(url, user, password);
        try {
            conn.setReadOnly(true); // defense in depth, on top of SqlGuard

            Statement stmt = conn.createStatement();
            try {
                // This c-tree SQL dialect has no FETCH FIRST/LIMIT, so the
                // row cap is enforced at the JDBC level instead.
                stmt.setMaxRows(MAX_ROWS);

                ResultSet rs = stmt.executeQuery(sql);
                try {
                    ResultSetMetaData meta = rs.getMetaData();
                    int columnCount = meta.getColumnCount();

                    while (rs.next()) {
                        Map<String, Object> row = new LinkedHashMap<String, Object>();
                        for (int i = 1; i <= columnCount; i++) {
                            row.put(meta.getColumnLabel(i), rs.getObject(i));
                        }
                        rows.add(row);
                    }
                } finally {
                    rs.close();
                }
            } finally {
                stmt.close();
            }
        } finally {
            conn.close();
        }

        return rows;
    }

    public static int executeUpdate(String sql) throws SQLException {
        String url = requireEnv("CTREE_JDBC_URL");
        String user = requireEnv("CTREE_JDBC_USER");
        String password = requireEnv("CTREE_JDBC_PASSWORD");

        try (Connection conn = DriverManager.getConnection(url, user, password);
             Statement stmt = conn.createStatement()) {
            return stmt.executeUpdate(sql);
        }
    }

    public static void main(String[] args) throws Exception {
        if (args.length == 0) {
            System.out.println("Usage: java CtreeQuery <SQL>");
            return;
        }
        String sql = args[0];
        if (sql.trim().toUpperCase().startsWith("SELECT")) {
            List<Map<String, Object>> rows = execute(sql);
            for (Map<String, Object> row : rows) {
                System.out.println(row);
            }
        } else {
            int affected = executeUpdate(sql);
            System.out.println("Rows affected: " + affected);
        }
    }

    private static String requireEnv(String name) {
        String value = System.getenv(name);
        if (value == null || value.trim().isEmpty()) {
            throw new IllegalStateException(name + " environment variable is not set");
        }
        return value;
    }
}
