#!/bin/bash
# analytics.sh - Generate HTML reports with graphs

CONFIG_FILE="/opt/autopilot/config/autopilot.conf"
source "$CONFIG_FILE"

REPORT_DIR="/opt/autopilot/reports"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
REPORT_FILE="$REPORT_DIR/report_${TIMESTAMP}.html"

parse_logs() {
    local cutoff=$(date -d '24 hours ago' '+%s')
    awk -F'|' -v cutoff="$cutoff" '$1 >= cutoff {print $1,$2,$3,$4,$5}' "$PERFORMANCE_LOG" > /tmp/autopilot_data.txt
}

generate_graphs() {
    local data_file="/tmp/autopilot_data.txt"
    
    gnuplot <<EOF
set terminal png size 800,400
set output '$REPORT_DIR/cpu_graph_${TIMESTAMP}.png'
set title 'CPU Usage (Last 24h)'
set xlabel 'Time'
set ylabel 'CPU %'
set xdata time
set timefmt '%s'
set format x '%H:%M'
set grid
plot '$data_file' using 1:2 with lines title 'CPU' lw 2
EOF
    
    gnuplot <<EOF
set terminal png size 800,400
set output '$REPORT_DIR/mem_graph_${TIMESTAMP}.png'
set title 'Memory Usage (Last 24h)'
set xlabel 'Time'
set ylabel 'Memory %'
set xdata time
set timefmt '%s'
set format x '%H:%M'
set grid
plot '$data_file' using 1:3 with lines title 'Memory' lw 2
EOF
    
    gnuplot <<EOF
set terminal png size 800,400
set output '$REPORT_DIR/disk_graph_${TIMESTAMP}.png'
set title 'Disk Usage (Last 24h)'
set xlabel 'Time'
set ylabel 'Disk %'
set xdata time
set timefmt '%s'
set format x '%H:%M'
set grid
plot '$data_file' using 1:4 with lines title 'Disk' lw 2
EOF
}

calculate_stats() {
    local data_file="/tmp/autopilot_data.txt"
    
    CPU_AVG=$(awk '{sum+=$2; count++} END {printf "%.1f", sum/count}' "$data_file")
    CPU_MAX=$(awk '{if ($2>max) max=$2} END {print max}' "$data_file")
    CPU_MIN=$(awk 'NR==1 {min=$2} {if ($2<min) min=$2} END {print min}' "$data_file")
    
    MEM_AVG=$(awk '{sum+=$3; count++} END {printf "%.1f", sum/count}' "$data_file")
    MEM_MAX=$(awk '{if ($3>max) max=$3} END {print max}' "$data_file")
    
    INCIDENTS_COUNT=$(wc -l < "$INCIDENTS_LOG" 2>/dev/null || echo "0")
    INCIDENTS_24H=$(tail -n 1000 "$INCIDENTS_LOG" 2>/dev/null | grep "$(date -d '24 hours ago' '+%Y-%m-%d')" | wc -l)
}

get_recent_incidents() {
    tail -n 20 "$INCIDENTS_LOG" 2>/dev/null | tac || echo "No incidents"
}

generate_html() {
    cat > "$REPORT_FILE" <<EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Autopilot Report</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; background: #f5f5f5; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 20px; }
        .header h1 { margin: 0; font-size: 2.5em; }
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 20px; }
        .stat-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .stat-card h3 { margin: 0 0 10px 0; color: #667eea; font-size: 0.9em; text-transform: uppercase; }
        .stat-card .value { font-size: 2em; font-weight: bold; color: #333; }
        .graph-section { background: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .graph-section h2 { margin: 0 0 15px 0; }
        .graph-section img { width: 100%; border-radius: 4px; }
        .incident-item { padding: 10px; border-left: 3px solid #667eea; margin-bottom: 10px; background: #f9f9f9; font-family: monospace; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🤖 Linux Performance Autopilot</h1>
        <p>Generated: $(date '+%Y-%m-%d %H:%M:%S')</p>
    </div>

    <div class="stats-grid">
        <div class="stat-card">
            <h3>Average CPU</h3>
            <div class="value">${CPU_AVG}%</div>
            <div>Min: ${CPU_MIN}% | Max: ${CPU_MAX}%</div>
        </div>
        <div class="stat-card">
            <h3>Average Memory</h3>
            <div class="value">${MEM_AVG}%</div>
            <div>Peak: ${MEM_MAX}%</div>
        </div>
        <div class="stat-card">
            <h3>Total Incidents</h3>
            <div class="value">${INCIDENTS_COUNT}</div>
            <div>Last 24h: ${INCIDENTS_24H}</div>
        </div>
    </div>

    <div class="graph-section">
        <h2>📊 CPU Usage</h2>
        <img src="cpu_graph_${TIMESTAMP}.png" alt="CPU Graph">
    </div>

    <div class="graph-section">
        <h2>💾 Memory Usage</h2>
        <img src="mem_graph_${TIMESTAMP}.png" alt="Memory Graph">
    </div>

    <div class="graph-section">
        <h2>💿 Disk Usage</h2>
        <img src="disk_graph_${TIMESTAMP}.png" alt="Disk Graph">
    </div>

    <div class="graph-section">
        <h2>🚨 Recent Incidents</h2>
        $(get_recent_incidents | while IFS='|' read -r timestamp type value action; do
            echo "<div class=\"incident-item\">$timestamp | $type | $value | $action</div>"
        done)
    </div>
</body>
</html>
EOF
}

echo "📊 Generating analytics report..."
parse_logs
calculate_stats
generate_graphs
generate_html

echo "✅ Report generated: $REPORT_FILE"

cd "$REPORT_DIR" || exit
ls -t report_*.html | tail -n +11 | xargs -r rm
ls -t *_graph_*.png | tail -n +31 | xargs -r rm
