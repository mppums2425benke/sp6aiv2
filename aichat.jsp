<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%
  response.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
  response.setHeader("Pragma", "no-cache");
  response.setDateHeader("Expires", 0);
%>
<!--
  aichat.jsp
  =====================
  Full-page version of the chat widget - fills the whole browser window
  with support for interactive charts (Bar, Donut, Pie) and tabular data.
-->
<html>
<head>
  <title>SP6 AI Assistant</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
  <link rel="stylesheet" href="css/aichat.css">
</head>
<body>

<div id="ai-chat-page">
  <div id="ai-chat-header">
    <div id="ai-chat-header-text">
      <div id="ai-chat-title">SP6 AI Assistant</div>
      <div id="ai-chat-subtitle">Ask questions about authorized data (Text, Tables, and Charts)</div>
    </div>
  </div>

  <div id="ai-chat-messages"></div>

  <form id="ai-chat-form">
    <input
      type="text"
      id="ai-chat-input"
      placeholder="Ask about the available data"
      autocomplete="off"
    />
    <button type="submit" id="ai-chat-send">Ask</button>
  </form>
</div>

<script>
  var AI_CHAT_ENDPOINT = "aiaskproxy.jsp";

  var messages = document.getElementById("ai-chat-messages");
  var form = document.getElementById("ai-chat-form");
  var input = document.getElementById("ai-chat-input");
  var sendBtn = document.getElementById("ai-chat-send");
  var COLUMN_LABELS = {};
  var CURRENT_RESPONSE_LANGUAGE = "EN";

    function hexToRgba(hex, alpha) {
    if (!hex || hex.indexOf("#") !== 0) return "rgba(31, 78, 121, " + (alpha !== undefined ? alpha : 0.25) + ")";
    var r = parseInt(hex.slice(1, 3), 16) || 0;
    var g = parseInt(hex.slice(3, 5), 16) || 0;
    var b = parseInt(hex.slice(5, 7), 16) || 0;
    return "rgba(" + r + ", " + g + ", " + b + ", " + (alpha !== undefined ? alpha : 0.25) + ")";
  }

  var CHART_PALETTE = [
    "#1f4e79", "#2e75b6", "#5b9bd5", "#ed7d31", "#ffc000",
    "#70ad47", "#264478", "#6366f1", "#ec4899", "#8b5cf6",
    "#10b981", "#f59e0b", "#06b6d4", "#14b8a6", "#84cc16",
    "#e11d48", "#d946ef", "#0284c7", "#f97316", "#84cc16"
  ];

  function addMessage(text, cssClass) {
    var el = document.createElement("div");
    el.className = "ai-msg " + cssClass;
    if (text) {
      var p = document.createElement("div");
      p.textContent = text;
      el.appendChild(p);
    }
    messages.appendChild(el);
    messages.scrollTop = messages.scrollHeight;
    return el;
  }

  function formatColumnHeader(col) {
    if (!col) return "";
    var lower = col.toLowerCase().trim();
    if (COLUMN_LABELS[lower]) return COLUMN_LABELS[lower];
    if (lower.indexOf("scoped_") === 0) lower = lower.substring(7);

    // Handle SQL aggregate functions: min(col), max(col), avg(col), sum(col), count(col)
    var m = lower.match(/^(min|max|avg|sum|count)\((.*?)\)$/);
    if (m) {
      var fn = m[1];
      var inner = m[2].trim();
      var innerLabel = COLUMN_LABELS[inner] || inner.replace(/_/g, " ").replace(/\b\w/g, function (c) { return c.toUpperCase(); });
      if (fn === "min") return "Minimum " + (innerLabel ? innerLabel : "");
      if (fn === "max") return "Maximum " + (innerLabel ? innerLabel : "");
      if (fn === "avg") return "Average " + (innerLabel ? innerLabel : "");
      if (fn === "sum") return "Total " + (innerLabel ? innerLabel : "");
      if (fn === "count") return inner === "*" ? "Count" : "Count (" + innerLabel + ")";
    }

    if (/^min[_\s]/.test(lower)) {
      var inner = lower.replace(/^min[_\s]/, "");
      var innerLabel = COLUMN_LABELS[inner] || inner.replace(/_/g, " ").replace(/\b\w/g, function (c) { return c.toUpperCase(); });
      return "Minimum " + innerLabel;
    }
    if (/^max[_\s]/.test(lower)) {
      var inner = lower.replace(/^max[_\s]/, "");
      var innerLabel = COLUMN_LABELS[inner] || inner.replace(/_/g, " ").replace(/\b\w/g, function (c) { return c.toUpperCase(); });
      return "Maximum " + innerLabel;
    }
    if (/^avg[_\s]/.test(lower)) {
      var inner = lower.replace(/^avg[_\s]/, "");
      var innerLabel = COLUMN_LABELS[inner] || inner.replace(/_/g, " ").replace(/\b\w/g, function (c) { return c.toUpperCase(); });
      return "Average " + innerLabel;
    }

    if (lower.indexOf("count(") === 0) return "Count";
    if (lower.indexOf("sum(") === 0) return "Total";
    if (lower.indexOf("avg(") === 0) return "Average";
    return lower.replace(/_/g, " ").replace(/\b\w/g, function (c) { return c.toUpperCase(); });
  }

  function setColumnLabels(columns) {
    COLUMN_LABELS = {};
    if (!columns) return;
    columns.forEach(function (column) {
      if (column && column.name && column.label) {
        COLUMN_LABELS[String(column.name).toLowerCase()] = String(column.label);
      }
    });
  }

  function formatLabelValue(colName, val) {
    if (val === null || val === undefined) return "";
    if (typeof val === "number" && isFinite(val)) {
      return Number.isInteger(val) ? String(val) : val.toLocaleString(undefined, { maximumFractionDigits: 2 });
    }
    var s = String(val).trim();
    if (colName && colName.toLowerCase().indexOf("gender") !== -1) {
      if (s === "M" || s === "m") return "Male";
      if (s === "F" || s === "f") return "Female";
    }
    return s;
  }

  function extractChartData(rows, question, isChartRequested, sql, aiXAxis, aiYAxis, preferredType) {
    if (!rows || rows.length === 0) return null;
    var keys = Object.keys(rows[0]);
    if (keys.length === 0) return null;

    // If there is only 1 row and 1 column, and it's a numeric scalar (e.g. COUNT(*))
    if (rows.length === 1 && keys.length === 1) {
      var singleVal = rows[0][keys[0]];
      var numVal = Number(singleVal);
      if (!isNaN(numVal)) {
        if (isChartRequested) {
          var lbl = formatColumnHeader(keys[0]);
          return {
            labelKey: keys[0],
            valueKey: keys[0],
            chartTitle: lbl,
            rawItems: [{ label: lbl, value: numVal }],
            items: [{ label: lbl, value: numVal }],
            total: numVal,
            isFrequency: false
          };
        }
        return null;
      }
    }

    // If there is only 1 row with multiple numeric columns (e.g. MIN, MAX, AVG summary query)
    if (rows.length === 1 && keys.length >= 2) {
      var numericKeys = [];
      for (var i = 0; i < keys.length; i++) {
        var k = keys[i];
        var val = rows[0][k];
        if (val !== null && val !== undefined && String(val).trim() !== "" && !isNaN(Number(val))) {
          numericKeys.push(k);
        }
      }

      if (numericKeys.length >= 2) {
        var hasAggOrStats = numericKeys.some(function (k) {
          var lk = k.toLowerCase();
          return lk.indexOf("min") !== -1 || lk.indexOf("max") !== -1 || lk.indexOf("avg") !== -1 || lk.indexOf("sum") !== -1 || lk.indexOf("count") !== -1 || lk.indexOf("total") !== -1;
        });

        if (hasAggOrStats || numericKeys.length === keys.length) {
          var qLower = (question || "").toLowerCase();
          var askedForCount = qLower.indexOf("count") !== -1 || qLower.indexOf("bilangan") !== -1 || qLower.indexOf("jumlah") !== -1 || qLower.indexOf("total") !== -1;

          var colsToPlot = numericKeys.slice();
          var nonCountCols = colsToPlot.filter(function (k) {
            return k.toLowerCase().indexOf("count") === -1;
          });
          if (nonCountCols.length >= 2 && !askedForCount) {
            colsToPlot = nonCountCols;
          }

          colsToPlot.sort(function (a, b) {
            function getOrder(col) {
              var lk = col.toLowerCase();
              if (lk.indexOf("min") !== -1) return 1;
              if (lk.indexOf("avg") !== -1 || lk.indexOf("mean") !== -1) return 2;
              if (lk.indexOf("max") !== -1) return 3;
              if (lk.indexOf("sum") !== -1 || lk.indexOf("total") !== -1) return 4;
              if (lk.indexOf("count") !== -1) return 5;
              return 10;
            }
            return getOrder(a) - getOrder(b);
          });

          var detectedField = "";
          for (var i = 0; i < colsToPlot.length; i++) {
            var m = colsToPlot[i].toLowerCase().match(/\((.*?)\)/);
            if (m && m[1] && m[1] !== "*") {
              detectedField = m[1].trim();
              break;
            }
          }

          var chartTitle = detectedField ? (formatColumnHeader(detectedField) + " Statistics") : "Summary Statistics";

          var items = colsToPlot.map(function (col) {
            var val = Number(rows[0][col]);
            return {
              label: formatColumnHeader(col),
              value: Math.round(val * 100) / 100
            };
          });

          return {
            labelKey: "Metric",
            valueKey: detectedField ? formatColumnHeader(detectedField) : "Value",
            chartTitle: chartTitle,
            rawItems: items,
            items: items,
            total: items.reduce(function (acc, it) { return acc + it.value; }, 0),
            isFrequency: false,
            isMultiMetric: true
          };
        }
      }
    }

    // Case: Multi-metric comparison across categories (e.g. Height & Weight by Gender, or multiple numeric columns)
    if (keys.length >= 3 && rows.length >= 1) {
      var candidateLabelCol = null;

      // 1. Explicit AI Axis
      if (aiXAxis && aiXAxis !== "none" && aiXAxis.trim() !== "") {
        for (var i = 0; i < keys.length; i++) {
          if (keys[i].toLowerCase() === aiXAxis.toLowerCase().trim()) {
            candidateLabelCol = keys[i];
            break;
          }
        }
      }

      // 2. SQL GROUP BY alias or column
      if (!candidateLabelCol && sql) {
        var gbMatch = sql.match(/GROUP\s+BY\s+([^,\r\n;]+)/i);
        if (gbMatch && gbMatch[1]) {
          var rawGb = gbMatch[1].trim().replace(/^[a-zA-Z0-9_]+\./, "").replace(/["']/g, "").toLowerCase();
          for (var i = 0; i < keys.length; i++) {
            var lk = keys[i].toLowerCase();
            if (lk === rawGb || lk.indexOf(rawGb) !== -1 || rawGb.indexOf(lk) !== -1) {
              candidateLabelCol = keys[i];
              break;
            }
          }
        }
      }

      // 3. First non-numeric column across rows
      if (!candidateLabelCol) {
        for (var i = 0; i < keys.length; i++) {
          var k = keys[i];
          var hasNonNum = rows.some(function (r) {
            var v = r[k];
            return v !== null && v !== undefined && String(v).trim() !== "" && isNaN(Number(v));
          });
          if (hasNonNum) {
            candidateLabelCol = k;
            break;
          }
        }
      }

      if (!candidateLabelCol) {
        candidateLabelCol = keys[0];
      }

      // Find all OTHER columns that have numeric data
      var numericMetricCols = [];
      for (var i = 0; i < keys.length; i++) {
        var k = keys[i];
        if (k === candidateLabelCol) continue;
        var hasValidNum = rows.some(function (r) {
          var v = r[k];
          return v !== null && v !== undefined && String(v).trim() !== "" && !isNaN(Number(v));
        });
        if (hasValidNum) {
          numericMetricCols.push(k);
        }
      }

      // If there are 2 or more numeric metrics, create a multi-dataset grouped chart
      if (numericMetricCols.length >= 2) {
        var displayRows = rows;
        if (rows.length > 15) {
          displayRows = rows.slice(0, 15);
        }

        var labels = [];
        for (var i = 0; i < displayRows.length; i++) {
          var rawLabel = displayRows[i][candidateLabelCol];
          labels.push(formatLabelValue(candidateLabelCol, String(rawLabel !== null && rawLabel !== undefined ? rawLabel : "").trim()));
        }

        var datasets = numericMetricCols.map(function (col) {
          var data = displayRows.map(function (r) {
            var val = Number(r[col]);
            return isNaN(val) ? 0 : Math.round(val * 100) / 100;
          });
          return {
            key: col,
            label: formatColumnHeader(col),
            data: data
          };
        });

        var items = labels.map(function (lbl, i) {
          return { label: lbl, value: datasets[0].data[i] };
        });

        var yTitle = (aiYAxis && aiYAxis !== "none" && aiYAxis.trim() !== "")
          ? aiYAxis
          : numericMetricCols.map(formatColumnHeader).join(" & ");

        var chartTitle = formatColumnHeader(candidateLabelCol) + " - " + yTitle;

        return {
          isMultiDataset: true,
          labelKey: candidateLabelCol,
          valueKey: numericMetricCols[0],
          valueKeys: numericMetricCols,
          yAxisTitle: yTitle,
          chartTitle: chartTitle,
          labels: labels,
          datasets: datasets,
          rawItems: items,
          items: items,
          total: 0,
          isFrequency: false
        };
      }
    }

    var valueKey = null;
    var labelKey = null;

    if (keys.length >= 2) {
      // 0. AI Explicit Assignment (highest priority)
      if (aiYAxis && aiYAxis !== "none" && aiYAxis.trim() !== "") {
        for (var i = 0; i < keys.length; i++) {
          if (keys[i].toLowerCase() === aiYAxis.toLowerCase().trim()) {
            valueKey = keys[i];
            break;
          }
        }
      }
      if (aiXAxis && aiXAxis !== "none" && aiXAxis.trim() !== "") {
        for (var i = 0; i < keys.length; i++) {
          if (keys[i].toLowerCase() === aiXAxis.toLowerCase().trim()) {
            labelKey = keys[i];
            break;
          }
        }
      }

      // 1. Universal SQL Syntax Analysis:
      // In SQL, the column with COUNT(...), AVG(...), SUM(...), MIN(...), MAX(...) is 100% the metric (Y-Axis).
      // The other column in GROUP BY is 100% the category / dimension (X-Axis).
      if (!valueKey && sql) {
        var aggMatch = sql.match(/\b(COUNT|AVG|SUM|MIN|MAX)\s*\([^)]*\)\s+(?:AS\s+)?["']?([^,"'\r\n;]+)["']?/i);
        if (aggMatch && aggMatch[2]) {
          var targetAlias = aggMatch[2].trim().toLowerCase();
          for (var i = 0; i < keys.length; i++) {
            if (keys[i].toLowerCase() === targetAlias) {
              valueKey = keys[i];
              break;
            }
          }
        }
      }

      // If valueKey is found from AI or SQL aggregate function, ensure labelKey is the other column (GROUP BY dimension)
      if (valueKey && !labelKey) {
        for (var i = 0; i < keys.length; i++) {
          if (keys[i] !== valueKey) {
            labelKey = keys[i];
            break;
          }
        }
      }

      // 2. Keyword heuristic fallback (for queries without explicit SQL agg function)
      if (!valueKey) {
        for (var i = 0; i < keys.length; i++) {
          var k = keys[i];
          var lk = k.toLowerCase();
          var isCount = (lk.indexOf("count") !== -1 && lk.indexOf("country") === -1) || lk.indexOf("bilangan") !== -1 || lk.indexOf("jumlah") !== -1 || lk.indexOf("数量") !== -1 || lk.indexOf("人数") !== -1 || lk.indexOf("笔数") !== -1 || lk.indexOf("anzahl") !== -1 || lk.indexOf("schüler") !== -1 || lk.indexOf("sayısı") !== -1 || lk.indexOf("sayisi") !== -1;
          var isAgg = isCount || lk.indexOf("sum") !== -1 || lk.indexOf("avg") !== -1 || lk.indexOf("average") !== -1 || lk.indexOf("total") !== -1 || lk.indexOf("purata") !== -1 || lk.indexOf("jumlah") !== -1 || lk.indexOf("bilangan") !== -1 || lk.indexOf("平均") !== -1 || lk.indexOf("总") !== -1 || lk.indexOf("合计") !== -1 || lk.indexOf("率") !== -1 || lk.indexOf("durchschnitt") !== -1 || lk.indexOf("gesamt") !== -1;
          if (isAgg) {
            var hasNumbers = rows.some(function(r) {
              var v = r[k];
              return v !== null && v !== undefined && String(v).trim() !== "" && !isNaN(Number(v));
            });
            if (hasNumbers) {
              valueKey = k;
              break;
            }
          }
        }
      }

      // 2. Secondary: Explicit measurement metrics if no aggregation exists
      if (!valueKey) {
        for (var i = 0; i < keys.length; i++) {
          var k = keys[i];
          var lk = k.toLowerCase();
          var isMetric = lk.indexOf("weight") !== -1 || lk.indexOf("height") !== -1 || lk.indexOf("num") !== -1 || lk.indexOf("ketinggian") !== -1 || lk.indexOf("berat") !== -1 || lk.indexOf("tinggi") !== -1 || lk.indexOf("gaji") !== -1 || lk.indexOf("salary") !== -1 || lk.indexOf("yuran") !== -1 || lk.indexOf("fee") !== -1 || lk.indexOf("身高") !== -1 || lk.indexOf("体重") !== -1 || lk.indexOf("学费") !== -1 || lk.indexOf("薪资") !== -1;
          if (isMetric) {
            var hasNumbers = rows.some(function(r) {
              var v = r[k];
              return v !== null && v !== undefined && String(v).trim() !== "" && !isNaN(Number(v));
            });
            if (hasNumbers) {
              valueKey = k;
              break;
            }
          }
        }
      }

      // 3. Tertiary: Look for numeric column, strictly excluding dimension/timeline columns
      if (!valueKey) {
        for (var i = 0; i < keys.length; i++) {
          var k = keys[i];
          var lk = k.toLowerCase();
          var isDimension = lk.indexOf("id") !== -1 || lk.indexOf("key") !== -1 || lk.indexOf("dob") !== -1 || lk.indexOf("date") !== -1 || lk.indexOf("tarikh") !== -1 || lk.indexOf("mobile") !== -1 || lk.indexOf("phone") !== -1 || lk.indexOf("year") !== -1 || lk.indexOf("tahun") !== -1 || lk.indexOf("age") !== -1 || lk.indexOf("umur") !== -1 || lk.indexOf("年") !== -1 || lk.indexOf("岁") !== -1 || lk.indexOf("龄") !== -1 || lk.indexOf("jahr") !== -1 || lk.indexOf("geburt") !== -1 || lk.indexOf("alter") !== -1;
          if (isDimension) {
            continue;
          }
          var isAllNum = rows.every(function(r) {
            var v = r[k];
            return v !== null && v !== undefined && v !== "" && !isNaN(Number(v));
          });
          if (isAllNum) {
            valueKey = k;
            break;
          }
        }
      }
    }

    // CASE A: The dataset already has a numeric column (aggregate query)
    if (valueKey && keys.length >= 2) {
      var labelCols = [];
      if (labelKey) {
        labelCols.push(labelKey);
      } else {
        for (var i = 0; i < keys.length; i++) {
          var k = keys[i];
          if (k === valueKey) continue;
          // Only include columns that are non-numeric across the dataset as labels
          var isNum = rows.every(function(r) {
            var v = r[k];
            return v !== null && v !== undefined && String(v).trim() !== "" && !isNaN(Number(v));
          });
          if (!isNum) {
            labelCols.push(k);
          }
        }
        if (labelCols.length === 0) {
          for (var i = 0; i < keys.length; i++) {
            if (keys[i] !== valueKey) {
              labelCols.push(keys[i]);
              break;
            }
          }
        }
        labelKey = labelCols[0];
      }

      var rawItems = [];
      var totalVal = 0;
      for (var i = 0; i < rows.length; i++) {
        var rawVal = rows[i][valueKey];
        var numVal = Number(rawVal);
        if (!isNaN(numVal)) {
          var lblParts = [];
          for (var c = 0; c < labelCols.length; c++) {
            var colName = labelCols[c];
            var colVal = rows[i][colName];
            if (colVal !== null && colVal !== undefined && String(colVal).trim() !== "") {
              lblParts.push(formatLabelValue(colName, String(colVal).trim()));
            }
          }
          var lbl = lblParts.length > 0 ? lblParts.join(" - ") : "Unknown";
          var roundedVal = Math.round(numVal * 100) / 100;
          rawItems.push({ label: lbl, value: roundedVal });
          totalVal += roundedVal;
        }
      }

      if (rawItems.length === 0) return null;
      var isTimeline = isSequentialOrTimeline(labelKey, rawItems, question);

      if (isTimeline) {
        rawItems.sort(function (a, b) {
          var numA = Number(a.label);
          var numB = Number(b.label);
          if (!isNaN(numA) && !isNaN(numB)) return numA - numB;
          return String(a.label).localeCompare(String(b.label), undefined, { numeric: true });
        });
      } else {
        rawItems.sort(function (a, b) { return b.value - a.value; });
      }

      var displayItems = rawItems;
      if (!isTimeline && rawItems.length > 10) {
        if (preferredType === "polarArea" || preferredType === "radar") {
          displayItems = rawItems.slice(0, 8);
        } else {
          displayItems = rawItems.slice(0, 9);
          var otherSum = 0;
          var remainingCount = rawItems.length - 9;
          for (var j = 9; j < rawItems.length; j++) {
            otherSum += rawItems[j].value;
          }
          var isAvgQuery = /avg|average|mean|purata|height|weight|tinggi|berat|age|umur|rate|score|percent|平均|身高|体重|年龄/i.test(valueKey);
          var otherVal = isAvgQuery ? (Math.round((otherSum / remainingCount) * 100) / 100) : otherSum;
          displayItems.push({ label: getOthersLabel(CURRENT_RESPONSE_LANGUAGE, remainingCount), value: otherVal });
        }
      }

      var isTrendOrLine = isTimeline || /\b(trend|line|garisan)\b/i.test(question || "");
      var chartTitle = getChartTitleText(CURRENT_RESPONSE_LANGUAGE, labelKey, valueKey, isTrendOrLine);

      return {
        labelKey: labelKey,
        valueKey: valueKey,
        chartTitle: chartTitle,
        rawItems: rawItems,
        items: displayItems,
        total: totalVal,
        isFrequency: false,
        isTimeline: isTimeline
      };
    }

    // CASE B: Categorical column frequency distribution
    var categoryCol = null;

    if (keys.length === 1) {
      categoryCol = keys[0];
    } else {
    // Prefer a non-identifier column for a useful categorical chart.
    if (!categoryCol) {
      for (var i = keys.length - 1; i >= 0; i--) {
        var k = keys[i];
        var lk = k.toLowerCase();
        if (lk.indexOf("id") === -1 && lk.indexOf("key") === -1) {
          categoryCol = k;
          break;
        }
      }
      if (!categoryCol) categoryCol = keys[keys.length - 1];
    }
    }

    // Calculate frequency distribution for categoryCol
    var freq = {};
    var totalCount = 0;
    for (var i = 0; i < rows.length; i++) {
      var rawVal = rows[i][categoryCol];
      if (rawVal !== null && rawVal !== undefined && String(rawVal).trim() !== "") {
        var strVal = formatLabelValue(categoryCol, rawVal);
        freq[strVal] = (freq[strVal] || 0) + 1;
        totalCount++;
      }
    }

    var catKeys = Object.keys(freq);
    if (catKeys.length === 0) return null;

    var rawItems = catKeys.map(function(lbl) {
      return { label: lbl, value: freq[lbl] };
    });
    rawItems.sort(function(a, b) { return b.value - a.value; });

    // Avoid charts with no variation because they add no useful comparison.
    // If every distinct label has a count of 1 and there are multiple rows
    // (e.g. unique labels that each occur once),
    // A one-to-one frequency chart has no useful statistical variation.
    var allFrequenciesAreOne = rawItems.length > 1 && rawItems.every(function(it) { return it.value === 1; });
    if (allFrequenciesAreOne) {
      return null;
    }

    var isTimelineB = isSequentialOrTimeline(categoryCol, rawItems, question);
    if (isTimelineB) {
      rawItems.sort(function (a, b) {
        var numA = Number(a.label);
        var numB = Number(b.label);
        if (!isNaN(numA) && !isNaN(numB)) return numA - numB;
        return String(a.label).localeCompare(String(b.label), undefined, { numeric: true });
      });
    } else {
      rawItems.sort(function(a, b) { return b.value - a.value; });
    }

    var displayItems = rawItems;
    if (!isTimelineB && rawItems.length > 10) {
      if (preferredType === "polarArea" || preferredType === "radar") {
        displayItems = rawItems.slice(0, 8);
      } else {
        displayItems = rawItems.slice(0, 9);
        var otherSum = 0;
        for (var j = 9; j < rawItems.length; j++) {
          otherSum += rawItems[j].value;
        }
        displayItems.push({ label: getOthersLabel(CURRENT_RESPONSE_LANGUAGE, rawItems.length - 9), value: otherSum });
      }
    }

    var isTrendOrLineB = isTimelineB || /\b(trend|line|garisan)\b/i.test(question || "");
    var valKeyB = aiYAxis || "Count";
    var chartTitleB = getChartTitleText(CURRENT_RESPONSE_LANGUAGE, categoryCol, valKeyB, isTrendOrLineB);

    return {
      labelKey: categoryCol,
      valueKey: valKeyB,
      chartTitle: chartTitleB,
      rawItems: rawItems,
      items: displayItems,
      total: totalCount,
      isFrequency: true,
      isTimeline: isTimelineB
    };
  }

  function getTableFooterText(language, aiPaging) {
    var p = aiPaging || {};
    var showingAll = p.showingAll ? String(p.showingAll).trim() : "";
    var showingRange = p.showingRange ? String(p.showingRange).trim() : "";

    // If AI only gave one string and put the range string in showingAll
    if (showingAll && showingAll.indexOf("{visible}") !== -1 && !showingRange) {
      showingRange = showingAll;
      showingAll = "";
    }

    var lang = normalizeResponseLanguage(language);
    var def = {
      BM: {
        all: "Menunjukkan semua {count} rekod",
        range: "Menunjukkan 1 – {visible} daripada {count} rekod",
        more: "+ {count} lagi",
        allBtn: "▼ Lihat semua ({count})",
        lessBtn: "▲ Tunjuk ringkas"
      },
      EN: {
        all: "Showing all {count} records",
        range: "Showing 1 – {visible} of {count} records",
        more: "+ {count} more",
        allBtn: "▼ Show all ({count})",
        lessBtn: "▲ Show less"
      },
      JA: {
        all: "全{count}件を表示中",
        range: "1～{visible}件目を表示中 (全{count}件)",
        more: "+ {count}件",
        allBtn: "▼ すべて表示 ({count})",
        lessBtn: "▲ 折りたたむ"
      },
      ZH: {
        all: "显示全部 {count} 条记录",
        range: "显示第 1 至 {visible} 条记录 (共 {count} 条)",
        more: "+ {count} 条",
        allBtn: "▼ 查看全部 ({count})",
        lessBtn: "▲ 收起"
      }
    };
    var d = def[lang] || def.BM;

    var finalRange = showingRange || (showingAll ? showingAll : d.range);
    var finalAll = showingAll || d.all;
    var finalMore = p.more ? String(p.more).trim() : d.more;
    if (!finalMore.startsWith("+")) finalMore = "+ " + finalMore;

    var finalShowAll = p.showAll ? String(p.showAll).trim() : d.allBtn;
    if (!finalShowAll.startsWith("▼")) finalShowAll = "▼ " + finalShowAll;

    var finalShowLess = p.showLess ? String(p.showLess).trim() : d.lessBtn;
    if (!finalShowLess.startsWith("▲")) finalShowLess = "▲ " + finalShowLess;

    return {
      showingAll: finalAll,
      showingRange: finalRange,
      more: finalMore,
      showAll: finalShowAll,
      showLess: finalShowLess
    };
  }

  function normalizeResponseLanguage(language) {
    var value = String(language || "EN").trim().toUpperCase();
    if (value.length >= 2) return value.substring(0, 2);
    return "EN";
  }

  function replaceTableText(template, count, visible) {
    return String(template || "").replace(/\{count\}/g, count).replace(/\{visible\}/g, visible);
  }

  function getChartActionLabels(language, aiButtons, isPie) {
    if (aiButtons && aiButtons.bar && aiButtons.line && aiButtons.donut && aiButtons.table) {
      var donutText = aiButtons.donut.replace(/^[\uD83D\uDCCA\uD83D\uDCC8\uD83C\uDF69\uD83D\uDCCB\uD83E\uDD67\s]+/, "").trim();
      var donutIcon = isPie ? "\uD83E\uDD67 " : "\uD83C\uDF69 ";
      if (isPie && /^(donut|doughnut|dona)$/i.test(donutText)) {
        donutText = "Pie";
      }
      return {
        bar: "\uD83D\uDCCA " + aiButtons.bar.replace(/^[\uD83D\uDCCA\uD83D\uDCC8\uD83C\uDF69\uD83D\uDCCB\uD83E\uDD67\s]+/, "").trim(),
        line: "\uD83D\uDCC8 " + aiButtons.line.replace(/^[\uD83D\uDCCA\uD83D\uDCC8\uD83C\uDF69\uD83D\uDCCB\uD83E\uDD67\s]+/, "").trim(),
        donut: donutIcon + donutText,
        table: "\uD83D\uDCCB " + aiButtons.table.replace(/^[\uD83D\uDCCA\uD83D\uDCC8\uD83C\uDF69\uD83D\uDCCB\uD83E\uDD67\s]+/, "").trim()
      };
    }
    return { bar: "\uD83D\uDCCA Bar", line: "\uD83D\uDCC8 Line", donut: isPie ? "\uD83E\uDD67 Pie" : "\uD83C\uDF69 Donut", table: "\uD83D\uDCCB Table" };
  }

  function getOthersLabel(language, count) {
    return "(+) " + count;
  }

  function getChartTitleText(language, labelKey, valueKey, isTrend) {
    var l = formatColumnHeader(labelKey);
    var v = formatColumnHeader(valueKey);
    var isPureCount = (!v || v.toLowerCase() === "count" || v === "Bilangan" || v === "Jumlah" || v === "数量" || v === "人数" || v === "Bilangan Pelajar");
    return (!v || isPureCount) ? l : (l + " - " + v);
  }

  function isSequentialOrTimeline(labelKey, items, question) {
    var lk = (labelKey || "").toLowerCase();
    var q = (question || "").toLowerCase();
    var timeKeywords = /(year|tahun|month|bulan|date|tarikh|day|hari|quarter|suku|period|tempoh|time|masa|dob|trend|garisan|line|age|umur|jahr|geburt|alter|datum|linie|diagramm)/i || /年|月|日|期|年龄|岁|出生|趋势|折线/i;
    if (timeKeywords.test(lk) || timeKeywords.test(q)) {
      return true;
    }
    if (items && items.length > 0) {
      var allNum = items.every(function(it) {
        var s = String(it.label).trim();
        return s !== "" && !isNaN(Number(s));
      });
      if (allNum) return true;
    }
    return false;
  }

  function renderChartCard(targetEl, chartData, initialType, fullRows, showTableInitially, language, aiButtons, aiPaging) {
    if (targetEl && targetEl.classList) {
      targetEl.classList.add("has-table");
    }

    if (typeof Chart === 'undefined') {
      addResultTable(targetEl, fullRows, language, aiPaging);
      return;
    }

    var card = document.createElement("div");
    card.className = "ai-chart-card";

    var header = document.createElement("div");
    header.className = "ai-chart-header";

    function getChartIcon(type) {
      if (type === "pie") return "\uD83E\uDD67";
      if (type === "doughnut") return "\uD83C\uDF69";
      if (type === "line") return "\uD83D\uDCC8";
      if (type === "radar") return "\uD83D\uDD78\uFE0F";
      if (type === "polarArea") return "\uD83E\uDDED";
      return "\uD83D\uDCCA";
    }

    var isPie = (initialType === "pie");
    var title = document.createElement("div");
    title.className = "ai-chart-title";
    var titleText = chartData.chartTitle || (formatColumnHeader(chartData.labelKey) + " Distribution");
    title.innerHTML = getChartIcon(initialType || "bar") + " <span>" + titleText + "</span>";
    header.appendChild(title);

    var actions = document.createElement("div");
    actions.className = "ai-chart-actions";

    var currentType = initialType || (chartData.items.length <= 4 ? "doughnut" : "bar");
    var actionLabels = getChartActionLabels(language, aiButtons, isPie);

    var btnBar = document.createElement("button");
    btnBar.type = "button";
    btnBar.className = "ai-chart-btn" + (currentType === "bar" ? " active" : "");
    btnBar.textContent = actionLabels.bar;

    var btnLine = document.createElement("button");
    btnLine.type = "button";
    btnLine.className = "ai-chart-btn" + (currentType === "line" ? " active" : "");
    btnLine.textContent = actionLabels.line;

    var btnDonut = document.createElement("button");
    btnDonut.type = "button";
    btnDonut.className = "ai-chart-btn" + ((currentType === "doughnut" || currentType === "pie") ? " active" : "");
    btnDonut.textContent = actionLabels.donut;

    var btnTable = document.createElement("button");
    btnTable.type = "button";
    btnTable.className = "ai-chart-btn" + (showTableInitially ? " active" : "");
    btnTable.textContent = actionLabels.table;

    actions.appendChild(btnBar);
    actions.appendChild(btnLine);
    actions.appendChild(btnDonut);
    actions.appendChild(btnTable);
    header.appendChild(actions);
    card.appendChild(header);

    var canvasWrap = document.createElement("div");
    canvasWrap.className = "ai-chart-canvas-wrap";
    var canvas = document.createElement("canvas");
    canvasWrap.appendChild(canvas);
    card.appendChild(canvasWrap);

    var tableWrap = document.createElement("div");
    tableWrap.className = "ai-chart-table-wrap";
    tableWrap.style.display = showTableInitially ? "block" : "none";
    addResultTable(tableWrap, fullRows, language, aiPaging);
    card.appendChild(tableWrap);

    targetEl.appendChild(card);
    messages.scrollTop = messages.scrollHeight;

    var chartInstance = null;

    function buildChart(type) {
      if (chartInstance) {
        chartInstance.destroy();
      }

      title.innerHTML = getChartIcon(type) + " <span>" + titleText + "</span>";

      currentType = type;
      [btnBar, btnLine, btnDonut].forEach(function(b) { if (b) b.classList.remove("active"); });
      if (type === "bar" && btnBar) btnBar.classList.add("active");
      if (type === "line" && btnLine) btnLine.classList.add("active");
      if ((type === "doughnut" || type === "pie") && btnDonut) btnDonut.classList.add("active");

      var isLine = (type === "line");
      var isBar = (type === "bar");
      var isRadar = (type === "radar");
      var isPolar = (type === "polarArea");
      var isPieOrDonut = (type === "doughnut" || type === "pie");

      var labels = [];
      var datasets = [];

      if (chartData.isMultiDataset && chartData.datasets) {
        if (isRadar && chartData.datasets.length >= 2) {
          labels = chartData.datasets.map(function(ds) { return formatColumnHeader(ds.label || ds.key); });
          datasets = chartData.labels.map(function(catLabel, rowIdx) {
            var color = CHART_PALETTE[rowIdx % CHART_PALETTE.length];
            var rowValues = chartData.datasets.map(function(ds) { return ds.data[rowIdx]; });
            return {
              label: catLabel,
              data: rowValues,
              backgroundColor: hexToRgba(color, 0.25),
              borderColor: color,
              borderWidth: 2.5,
              fill: true,
              pointBackgroundColor: color,
              pointBorderColor: "#ffffff",
              pointBorderWidth: 2,
              pointRadius: 4,
              pointHoverRadius: 6
            };
          });
        } else {
          labels = chartData.labels;
          datasets = chartData.datasets.map(function(ds, idx) {
            var dsColor = CHART_PALETTE[idx % CHART_PALETTE.length];
            var circleColors = labels.map(function(_, i) { return CHART_PALETTE[(i + idx * labels.length) % CHART_PALETTE.length]; });
            return {
              label: formatColumnHeader(ds.label || ds.key),
              data: ds.data,
              backgroundColor: isPieOrDonut ? circleColors : (isPolar ? circleColors : (isRadar ? hexToRgba(dsColor, 0.25) : (isLine ? "rgba(2, 132, 199, 0.08)" : dsColor))),
              borderColor: (isPieOrDonut || isPolar) ? "#ffffff" : dsColor,
              borderWidth: isLine ? 2.5 : (isBar ? 1 : (isRadar ? 2.5 : 1.5)),
              borderRadius: isBar ? 4 : 0,
              fill: isRadar,
              tension: 0.35,
              pointBackgroundColor: dsColor,
              pointBorderColor: "#ffffff",
              pointBorderWidth: 2,
              pointRadius: (isLine || isRadar) ? 5 : undefined,
              pointHoverRadius: (isLine || isRadar) ? 7 : undefined
            };
          });
        }
      } else {
        var currentItems = chartData.items;
        if ((isPolar || isRadar) && currentItems.length > 8) {
          currentItems = currentItems.filter(function(it) {
            return String(it.label).indexOf("(+)") === -1;
          }).slice(0, 8);
        }
        labels = currentItems.map(function(i) { return i.label; });
        var dataValues = currentItems.map(function(i) { return i.value; });
        var colors = labels.map(function(_, i) { return CHART_PALETTE[i % CHART_PALETTE.length]; });

        var defaultColor = CHART_PALETTE[0];
        datasets = [{
          label: formatColumnHeader(chartData.valueKey),
          data: dataValues,
          backgroundColor: isRadar ? hexToRgba(defaultColor, 0.25) : (isPolar || isPieOrDonut ? colors : (isLine ? "rgba(2, 132, 199, 0.12)" : colors)),
          borderColor: isRadar ? defaultColor : ((isPolar || isPieOrDonut) ? "#ffffff" : (isLine ? "#0284c7" : "#ffffff")),
          borderWidth: (isLine || isRadar) ? 2.5 : (isBar ? 1 : 1.5),
          borderRadius: isBar ? 4 : 0,
          fill: isRadar || isLine,
          tension: 0.35,
          pointBackgroundColor: isRadar ? defaultColor : (isLine ? colors : undefined),
          pointBorderColor: "#ffffff",
          pointBorderWidth: 2,
          pointRadius: (isLine || isRadar) ? 5 : undefined,
          pointHoverRadius: (isLine || isRadar) ? 7 : undefined
        }];
      }

      var config = {
        type: type,
        data: {
          labels: labels,
          datasets: datasets
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              display: (isPieOrDonut || isPolar || isRadar || chartData.isMultiDataset),
              position: "bottom",
              labels: {
                boxWidth: 12,
                font: { size: 12 }
              }
            },
            tooltip: {
              callbacks: {
                label: function (ctx) {
                  var val = ctx.raw || 0;
                  if (chartData.isFrequency) {
                    var pct = chartData.total > 0 ? ((val / chartData.total) * 100).toFixed(1) : 0;
                    return " " + ctx.label + ": " + val + " (" + pct + "%)";
                  }
                  if (chartData.isMultiDataset) {
                    var dsLabel = ctx.dataset && ctx.dataset.label ? ctx.dataset.label : "";
                    return " " + dsLabel + ": " + val;
                  }
                  return " " + ctx.label + ": " + val;
                }
              }
            }
          }
        }
      };

      if (isBar || isLine) {
        config.options.scales = {
          x: {
            title: {
              display: true,
              text: formatColumnHeader(chartData.labelKey),
              color: "#475569",
              font: { size: 12, weight: "bold" },
              padding: { top: 8, bottom: 4 }
            },
            ticks: {
              autoSkip: false,
              maxRotation: 45,
              minRotation: 0,
              font: { size: 11 }
            },
            grid: { display: isLine, color: "#f1f5f9" }
          },
          y: {
            beginAtZero: true,
            title: {
              display: true,
              text: chartData.yAxisTitle || formatColumnHeader(chartData.valueKey),
              color: "#475569",
              font: { size: 12, weight: "bold" },
              padding: { top: 4, bottom: 8 }
            },
            ticks: {
              precision: 0,
              font: { size: 11 }
            },
            grid: { color: "#eef2f6" }
          }
        };
      } else if (isRadar || isPolar) {
        config.options.scales = {
          r: {
            beginAtZero: true,
            grid: { color: "#e2e8f0" },
            pointLabels: {
              font: { size: 11, weight: "bold" },
              color: "#334155"
            },
            ticks: {
              precision: 0,
              backdropColor: "transparent"
            }
          }
        };
      }

      chartInstance = new Chart(canvas.getContext("2d"), config);
    }

    buildChart(currentType);

    btnBar.addEventListener("click", function () { buildChart("bar"); });
    btnLine.addEventListener("click", function () { buildChart("line"); });
    btnDonut.addEventListener("click", function () { buildChart(isPie ? "pie" : "doughnut"); });

    btnTable.addEventListener("click", function () {
      if (tableWrap.style.display === "none") {
        tableWrap.style.display = "block";
        btnTable.classList.add("active");
      } else {
        tableWrap.style.display = "none";
        btnTable.classList.remove("active");
      }
    });
  }

  function addResultTable(containerEl, rows, language, aiPaging) {
    if (!rows || rows.length === 0) return;
    language = normalizeResponseLanguage(language || CURRENT_RESPONSE_LANGUAGE);

    if (containerEl && containerEl.classList) {
      containerEl.classList.add("has-table");
    }

    var wrap = document.createElement("div");
    wrap.className = "ai-table-responsive";

    var table = document.createElement("table");
    table.className = "ai-result-table";

    var columns = Object.keys(rows[0]);

    var thead = document.createElement("thead");
    var headRow = document.createElement("tr");
    columns.forEach(function (col) {
      var th = document.createElement("th");
      th.textContent = formatColumnHeader(col);
      headRow.appendChild(th);
    });
    thead.appendChild(headRow);
    table.appendChild(thead);

    var tbody = document.createElement("tbody");
    var pageSize = 30;
    var currentRendered = 0;

    function renderBatch(startIdx, endIdx) {
      var fragment = document.createDocumentFragment();
      for (var i = startIdx; i < endIdx && i < rows.length; i++) {
        var row = rows[i];
        var tr = document.createElement("tr");
        if (i >= pageSize) {
          tr.className = "ai-extra-row";
        }
        columns.forEach(function (col) {
          var td = document.createElement("td");
          var val = row[col];
          td.textContent = (val === null || val === undefined) ? "" : formatLabelValue(col, val);
          tr.appendChild(td);
        });
        fragment.appendChild(tr);
      }
      tbody.appendChild(fragment);
      currentRendered = Math.min(rows.length, Math.max(currentRendered, endIdx));
    }

    // Initially render first batch (up to 30 rows)
    renderBatch(0, pageSize);
    table.appendChild(tbody);
    wrap.appendChild(table);
    containerEl.appendChild(wrap);

    if (rows.length > pageSize) {
      var footer = document.createElement("div");
      footer.className = "ai-table-footer";

      var note = document.createElement("div");
      note.className = "ai-table-footer-note";

      var btnGroup = document.createElement("div");
      btnGroup.className = "ai-table-btn-group";

      var btnMore = document.createElement("button");
      btnMore.type = "button";
      btnMore.className = "ai-table-btn";

      var btnAll = document.createElement("button");
      btnAll.type = "button";
      btnAll.className = "ai-table-btn";

      var btnLess = document.createElement("button");
      btnLess.type = "button";
      btnLess.className = "ai-table-btn ai-table-btn-less";
      btnLess.style.display = "none";
      var footerText = getTableFooterText(language, aiPaging);
      btnLess.textContent = replaceTableText(footerText.showLess, pageSize, pageSize);

      var visibleCount = pageSize;

      function updateUI() {
        if (visibleCount >= rows.length) {
          note.textContent = replaceTableText(footerText.showingAll, rows.length, visibleCount);
          btnMore.style.display = "none";
          btnAll.style.display = "none";
          btnLess.style.display = "inline-flex";
        } else {
          note.textContent = replaceTableText(footerText.showingRange, rows.length, visibleCount);
          var nextBatchSize = Math.min(pageSize, rows.length - visibleCount);
          btnMore.textContent = replaceTableText(footerText.more, nextBatchSize, visibleCount);
          btnMore.style.display = "inline-flex";
          btnAll.textContent = replaceTableText(footerText.showAll, rows.length, visibleCount);
          btnAll.style.display = "inline-flex";
          if (visibleCount > pageSize) {
            btnLess.style.display = "inline-flex";
          } else {
            btnLess.style.display = "none";
          }
        }
      }

      function showUpTo(targetCount) {
        if (targetCount > currentRendered) {
          renderBatch(currentRendered, targetCount);
        }
        var allTrs = tbody.querySelectorAll("tr");
        for (var i = 0; i < allTrs.length; i++) {
          allTrs[i].style.display = (i < targetCount) ? "" : "none";
        }
        visibleCount = targetCount;
        updateUI();
      }

      btnMore.addEventListener("click", function () {
        showUpTo(Math.min(rows.length, visibleCount + pageSize));
      });

      btnAll.addEventListener("click", function () {
        showUpTo(rows.length);
      });

      btnLess.addEventListener("click", function () {
        showUpTo(pageSize);
        if (wrap && wrap.scrollIntoView) {
          wrap.scrollIntoView({ behavior: "smooth", block: "nearest" });
        }
      });

      btnGroup.appendChild(btnMore);
      btnGroup.appendChild(btnAll);
      btnGroup.appendChild(btnLess);

      footer.appendChild(note);
      footer.appendChild(btnGroup);
      containerEl.appendChild(footer);

      updateUI();
    }
  }

  form.addEventListener("submit", function (e) {
    e.preventDefault();
    var question = input.value.trim();
    if (!question) return;

    addMessage(question, "user");
    input.value = "";
    input.disabled = true;
    sendBtn.disabled = true;

    var pending = addMessage("Thinking……", "pending");
  
    fetch(AI_CHAT_ENDPOINT, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ question: question })
    })
      .then(function (response) {
        return response.json().then(function (data) {
          return { ok: response.ok, data: data };
        });
      })
      .then(function (result) {
        pending.remove();
        if (!result.ok) {
          addMessage(result.data.error || "Something went wrong.", "error");
          return;
        }

        var rows = result.data.rows;
        var detectedLang = "EN";
        if (/[一-龥]/.test(question)) {
          detectedLang = "ZH";
        } else if (/[぀-ヿ]/.test(question)) {
          detectedLang = "JA";
        } else if (/(pelajar|senarai|maklumat|butiran|rekod|jantina|tinggi|berat|bangsa|agama|negara|semua|berapa)/i.test(question)) {
          detectedLang = "BM";
        }
        var responseLanguage = normalizeResponseLanguage(result.data.language || detectedLang);
        CURRENT_RESPONSE_LANGUAGE = responseLanguage;
        console.log("[ask] response language:", result.data.language, "normalized:", responseLanguage);
        setColumnLabels(result.data.columns);
        var text = (result.data.answer || "").trim();

        function appendPerformanceTiming(targetEl, timing) {
          if (!targetEl || !timing) return;
          var timingBox = document.createElement("details");
          timingBox.style.cssText = "margin-top:12px;font-size:12px;color:#64748b;";
          var summary = document.createElement("summary");
          summary.textContent = "Processing time: " + (timing.totalMs || 0) + " ms";
          summary.style.cursor = "pointer";
          timingBox.appendChild(summary);

          var table = document.createElement("table");
          table.style.cssText = "margin-top:6px;border-collapse:collapse;width:100%;max-width:520px;";
          var stages = [
            ["Total", timing.totalMs],
            ["Language detection", timing.detectionMs],
            ["Input translation", timing.translationMs],
            ["SQL generation and validation", timing.sqlMs],
            ["Database", timing.databaseMs],
            ["Output translation / formatting", timing.outputTranslationMs]
          ];
          stages.forEach(function (stage) {
            var row = document.createElement("tr");
            var name = document.createElement("td");
            var value = document.createElement("td");
            name.textContent = stage[0];
            value.textContent = stage[1] === -1 ? "Included in AI request" : (stage[1] === 0 ? "< 1 ms" : String(stage[1]) + " ms");
            name.style.cssText = "padding:3px 12px 3px 0;";
            value.style.cssText = "padding:3px 0;text-align:right;";
            row.appendChild(name);
            row.appendChild(value);
            table.appendChild(row);
          });
          timingBox.appendChild(table);
          targetEl.appendChild(timingBox);
        }

        // 1. Direct AI Intent: If AI model explicitly determined visualization type, use it directly!
        var aiVisualization = (result.data.visualization || "").toLowerCase().trim();
        var needsChart = false;
        var preferredType = "bar";

        var isPieRequested = /\b(pie|pai|pi|kreis|torte)\b/i.test(question) || /饼图|carta pai|carta pi/i.test(question);
        var isDonutRequested = /\b(donut|doughnut|ring)\b/i.test(question) || /甜甜圈/i.test(question);
        var isPolarRequested = /\b(polar|polararea|kutub)\b/i.test(question);
        var isRadarRequested = /\b(radar|spider|labah)\b/i.test(question);

        if (aiVisualization === "pie" || (isPieRequested && !isDonutRequested)) {
          needsChart = true;
          preferredType = "pie";
        } else if (aiVisualization === "polararea" || isPolarRequested) {
          needsChart = true;
          preferredType = "polarArea";
        } else if (aiVisualization === "radar" || isRadarRequested) {
          needsChart = true;
          preferredType = "radar";
        } else if (aiVisualization === "doughnut" || aiVisualization === "donut" || isDonutRequested) {
          needsChart = true;
          preferredType = "doughnut";
        } else if (aiVisualization === "line") {
          needsChart = true;
          preferredType = "line";
        } else if (aiVisualization === "bar") {
          needsChart = true;
          preferredType = "bar";
        } else if (aiVisualization === "table") {
          needsChart = false;
        } else {
          // Fallback if AI returned auto or unspecified
          var isChartExplicitlyRequested = /(chart|carta|graf|graph|plot|diagram|diagramm|kurve|trend|linie|histogram|visualiz|distribution|breakdown|pecahan|agihan|verteilung)/i.test(question) || /图表|饼图|柱状图|条形图|折线图/i.test(question);
          var isStatisticalComparison = /(statistic|statistik|compare|comparison|perbandingan|vergleich)/i.test(question);
          var isPureListingOrDetail = /\b(list|senarai|show|display|tunjuk|find|cari|who|apa|siapa|detail|details|info|maklumat|liste|zeigen)\b/i.test(question) && !isChartExplicitlyRequested;

          needsChart = (isChartExplicitlyRequested || isStatisticalComparison) && !isPureListingOrDetail;

          if (isPieRequested) preferredType = "pie";
          else if (isPolarRequested) preferredType = "polarArea";
          else if (isRadarRequested) preferredType = "radar";
          else if (isDonutRequested) preferredType = "doughnut";
          else if (/(line|trend|garisan|linie|kurve)/i.test(question) || /折线图/i.test(question)) preferredType = "line";
          else if (/(bar|balken|säule)/i.test(question) || /柱状图|条形图/i.test(question)) preferredType = "bar";
        }

        var chartData = needsChart ? extractChartData(rows, question, true, result.data.sql, result.data.xAxis, result.data.yAxis, preferredType) : null;

        var needsTable = false;
        if (rows && rows.length > 0) {
          var colCount = Object.keys(rows[0]).length;
          if (rows.length > 1 || (rows.length === 1 && colCount > 1)) {
            needsTable = true;
          }
        }

        if (needsChart && chartData) {
          // Use the AI's direct localized summary from the response (in user's exact language)
          var countText = text;
          if (countText && countText.indexOf(":") !== -1) {
            countText = countText.substring(0, countText.indexOf(":") + 1);
          }
          if (!countText || countText.trim() === "") {
            countText = rows.length + " record(s):";
          }
          var botMsg = addMessage(countText, "bot");
          appendPerformanceTiming(botMsg, result.data.performance);
	  var showTableInitially = /\b(list|senarai|all|record|semua)\b/i.test(question) || chartData.isFrequency;
          renderChartCard(botMsg, chartData, preferredType, rows, showTableInitially, responseLanguage, result.data.buttons, result.data.paging);
        } else if (needsTable) {
          // Clean table ONLY (no unneeded chart or button)
          var countText = text;
          if (text.indexOf(":") !== -1) {
            countText = text.substring(0, text.indexOf(":") + 1);
          } else if (text.indexOf("\n") !== -1) {
            countText = text.substring(0, text.indexOf("\n"));
          } else if (text.indexOf("\\") !== -1) {
            countText = text.substring(0, text.indexOf("\\"));
          }
          var botMsg = addMessage(countText, "bot");
          appendPerformanceTiming(botMsg, result.data.performance);			
          if (isChartExplicitlyRequested && needsChart && !chartData) {
            var notice = document.createElement("div");
            notice.style.cssText = "margin:6px 0 10px 0;font-size:13px;color:#94a3b8;background:rgba(148,163,184,0.08);padding:8px 12px;border-radius:6px;border-left:3px solid #38bdf8;";
            notice.innerHTML = "📊 <em>Note: Displaying table view. Each returned item is unique (count of 1), so a chart would not add a useful comparison. Ask for grouped or comparative results to see a chart.</em>";
            botMsg.appendChild(notice);
          }
          addResultTable(botMsg, rows, responseLanguage, result.data.paging);
         
          } else {
          // Simple scalar, text response, or fallback table
          var botMsg = addMessage(text, "bot");
          appendPerformanceTiming(botMsg, result.data.performance);
  
          // Fallback: If rows exist, ensure they get rendered as a table
          if (rows && rows.length > 0) {
          addResultTable(botMsg, rows, responseLanguage, result.data.paging);
          }
        }
      })
      .catch(function (err) {
        pending.remove();
        addMessage("Could not reach the AI assistant. Is ChatServer running?", "error");
      })
      .then(function () {
        input.disabled = false;
        sendBtn.disabled = false;
        input.focus();
      });
  });

  addMessage('Hi! Ask a question about the available data. You can request text, tables, or charts.', 'bot');
</script>

</body>
</html>

