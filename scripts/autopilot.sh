#!/bin/bash
# Linux Performance Autopilot - Main Monitoring Daemon
# System performance monitoring and automated remediation service

CONFIG_FILE="/opt/autopilot/config/autopilot.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "❌ Error: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

source /opt/autopilot/scripts/remediation.sh

PID_FILE="/var/run/autopilot.pid"
echo $$ > "$PID_FILE"

trap cleanup EXIT INT TERM

cleanup() {
    echo "Autopilot service stopping..."
    rm -f "$PID_FILE"
    exit 0
}

# Logging functions
log_performance() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp|$1|$2|$3|$4|$5" >> "$PERFORMANCE_LOG"
}

log_incident() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp|$1|$2|$3" >> "$INCIDENTS_LOG"
}

log_action() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp|$level|$message" >> "$ACTIONS_LOG"
    echo "[$level] $message"
}

# Webhook notification service
send_webhook() {
    local title=$1
    local message=$2
    local color=$3
    
    if [ "$WEBHOOK_ENABLED" != "true" ]; then
        return
    fi
    
    local payload=$(cat <<EOF
{
  "embeds": [{
    "title": "🤖 Autopilot Alert",
    "description": "**$title**\n$message",
    "color": $([ "$color" == "error" ] && echo "15158332" || echo "3066993"),
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
  }]
}
EOF
)
    
    curl -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" -d "$payload" &>/dev/null &
}

# System metric collection functions
check_cpu() {
    top -bn2 -d 0.5 | grep "Cpu(s)" | tail -n1 | awk '{print 100-$8}' | cut -d'.' -f1
}

check_memory() {
    free | grep Mem | awk '{printf "%.0f", ($3/$2) * 100}'
}

check_disk() {
    df -h / | tail -n1 | awk '{print $5}' | sed 's/%//'
}

check_load() {
    uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//'
}

get_top_cpu_process() {
    ps aux --sort=-%cpu | head -n2 | tail -n1 | awk '{print $2"|"$11"|"$3}'
}

# Main monitoring loop
main_loop() {
    log_action "INFO" "Autopilot monitoring service started successfully"
    send_webhook "System Started" "Autopilot monitoring is now active" "success"
    
    local report_counter=0
    
    while true; do
        # Collect system metrics
        CPU=$(check_cpu)
        MEMORY=$(check_memory)
        DISK=$(check_disk)
        LOAD=$(check_load)
        TIMESTAMP=$(date '+%s')
        
        # Log performance metrics
        log_performance "$TIMESTAMP" "$CPU" "$MEMORY" "$DISK" "$LOAD"
        
        # CPU threshold monitoring
        if [ "$CPU" -gt "$CPU_THRESHOLD" ]; then
            log_incident "CPU_HIGH" "$CPU%" "CPU usage above ${CPU_THRESHOLD}%"
            log_action "WARN" "CPU utilization threshold exceeded: ${CPU}%"
            
            TOP_PROCESS=$(get_top_cpu_process)
            PID=$(echo "$TOP_PROCESS" | cut -d'|' -f1)
            NAME=$(echo "$TOP_PROCESS" | cut -d'|' -f2)
            USAGE=$(echo "$TOP_PROCESS" | cut -d'|' -f3 | cut -d'.' -f1)
            
            if [ "$USAGE" -gt "$KILL_CPU_THRESHOLD" ] && [ "$KILL_HIGH_CPU" == "true" ]; then
                handle_high_cpu_process "$PID" "$NAME" "$USAGE"
                send_webhook "CPU Alert" "Terminated high-CPU process: $NAME (PID: $PID, CPU: ${USAGE}%)" "error"
            fi
        fi
        
        # Memory threshold monitoring
        if [ "$MEMORY" -gt "$MEMORY_THRESHOLD" ]; then
            log_incident "MEMORY_HIGH" "$MEMORY%" "Memory usage above ${MEMORY_THRESHOLD}%"
            log_action "WARN" "Memory pressure detected: ${MEMORY}%"
            
            if [ "$CLEAR_CACHE" == "true" ]; then
                clear_system_cache
                send_webhook "Memory Alert" "System cache cleared at ${MEMORY}% memory utilization" "warning"
            fi
        fi
        
        # Disk space monitoring
        if [ "$DISK" -gt "$DISK_THRESHOLD" ]; then
            log_incident "DISK_HIGH" "$DISK%" "Disk usage above ${DISK_THRESHOLD}%"
            log_action "WARN" "Disk space critical: ${DISK}% utilized"
            
            clean_old_logs
            send_webhook "Disk Alert" "Disk utilization critical: ${DISK}%" "error"
        fi
        
        # Service health monitoring
        if [ "$RESTART_SERVICES" == "true" ]; then
            check_services
        fi
        
        # Periodic report generation
        ((report_counter++))
        if [ $report_counter -ge $(($REPORT_INTERVAL / $CHECK_INTERVAL)) ]; then
            if [ "$GENERATE_REPORTS" == "true" ]; then
                log_action "INFO" "Generating performance analytics report"
                /opt/autopilot/scripts/analytics.sh &
            fi
            report_counter=0
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

main_loop
