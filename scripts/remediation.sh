#!/bin/bash
# Linux Performance Autopilot - Automated Remediation Functions
# Self-healing and system maintenance operations

KILL_COUNT_FILE="/tmp/autopilot_kills.count"

# Process kill count management
get_kill_count() {
    if [ -f "$KILL_COUNT_FILE" ]; then
        cat "$KILL_COUNT_FILE"
    else
        echo "0"
    fi
}

increment_kill_count() {
    local count=$(get_kill_count)
    echo $((count + 1)) > "$KILL_COUNT_FILE"
}

reset_kill_count() {
    echo "0" > "$KILL_COUNT_FILE"
}

# Validate process termination limits
check_kill_limit() {
    local count=$(get_kill_count)
    local hour=$(date +%H)
    local last_hour_file="/tmp/autopilot_last_hour"
    
    # Reset counter if hour has changed
    if [ -f "$last_hour_file" ]; then
        local last_hour=$(cat "$last_hour_file")
        if [ "$hour" != "$last_hour" ]; then
            reset_kill_count
            echo "$hour" > "$last_hour_file"
        fi
    else
        echo "$hour" > "$last_hour_file"
    fi
    
    # Check against maximum allowed kills
    if [ "$count" -ge "$MAX_KILLS_PER_HOUR" ]; then
        log_action "ERROR" "Process termination limit reached ($count/$MAX_KILLS_PER_HOUR)"
        return 1
    fi
    
    return 0
}

# Terminate high CPU consumption processes
handle_high_cpu_process() {
    local pid=$1
    local name=$2
    local usage=$3
    
    # Critical system process protection
    local protected_processes=("systemd" "init" "kernel" "sshd" "bash")
    for proc in "${protected_processes[@]}"; do
        if [[ "$name" == *"$proc"* ]]; then
            log_action "WARN" "Protected process detected - skipping termination: $name"
            return
        fi
    done
    
    # Validate termination quota
    if ! check_kill_limit; then
        return
    fi
    
    log_action "WARN" "Terminating high-CPU process: $name (PID: $pid, CPU: ${usage}%)"
    
    # Attempt graceful termination first
    kill -15 "$pid" 2>/dev/null
    sleep 2
    
    # Force termination if process persists
    if ps -p "$pid" > /dev/null 2>&1; then
        log_action "WARN" "Process $pid unresponsive to SIGTERM - using SIGKILL"
        kill -9 "$pid" 2>/dev/null
    fi
    
    log_incident "PROCESS_KILLED" "$name" "PID: $pid, CPU: ${usage}%"
    increment_kill_count
    
    log_action "INFO" "Process termination completed: $name"
}

# Clear system memory cache
clear_system_cache() {
    log_action "INFO" "Clearing system memory cache..."
    
    sync
    echo 3 > /proc/sys/vm/drop_caches
    
    log_action "INFO" "System cache clearance completed"
    log_incident "CACHE_CLEARED" "System cache" "Memory pressure remediation"
}

# Remove outdated log files
clean_old_logs() {
    log_action "INFO" "Cleaning outdated log files..."
    
    find "$LOG_DIR" -name "*.log" -type f -mtime +${KEEP_LOGS_DAYS} -delete
    journalctl --vacuum-time=${KEEP_LOGS_DAYS}d 2>/dev/null
    find /tmp -type f -mtime +7 -delete 2>/dev/null
    
    log_action "INFO" "Log file cleanup completed"
    log_incident "LOGS_CLEANED" "Old logs" "Disk space remediation"
}

# Monitor and restart failed services
check_services() {
    IFS=',' read -ra SERVICES <<< "$MONITORED_SERVICES"
    
    for service in "${SERVICES[@]}"; do
        service=$(echo "$service" | xargs)
        
        if ! systemctl is-active --quiet "$service"; then
            log_action "WARN" "Service failure detected: $service - attempting restart"
            
            systemctl restart "$service"
            sleep 2
            
            if systemctl is-active --quiet "$service"; then
                log_action "INFO" "Service recovery successful: $service"
                log_incident "SERVICE_RESTARTED" "$service" "Service was down"
                send_webhook "Service Restart" "Service $service was down and restarted" "warning"
            else
                log_action "ERROR" "Service recovery failed: $service"
                send_webhook "Service Failed" "Service $service cannot restart!" "error"
            fi
        fi
    done
}

# Clean up zombie processes
kill_zombies() {
    log_action "INFO" "Scanning for zombie processes..."
    
    local zombies=$(ps aux | awk '{if ($8=="Z") print $2}')
    
    if [ -n "$zombies" ]; then
        log_action "WARN" "Zombie processes identified: $zombies"
        
        for pid in $zombies; do
            local ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | xargs)
            
            if [ -n "$ppid" ] && [ "$ppid" != "1" ]; then
                log_action "INFO" "Terminating parent process $ppid of zombie $pid"
                kill -15 "$ppid" 2>/dev/null
            fi
        done
        
        log_incident "ZOMBIES_KILLED" "Zombie processes" "Count: $(echo $zombies | wc -w)"
    fi
}
