#!/bin/bash
# Linux Performance Autopilot - System Stress Test
# Simulates various system resource issues to validate monitoring and remediation

echo "Linux Performance Autopilot - Stress Test"
echo "=========================================="
echo ""
echo "This test will simulate various system resource issues:"
echo "1. High CPU utilization"
echo "2. Memory consumption spike"
echo "3. Disk space exhaustion"
echo "4. Runaway process creation"
echo ""
read -p "Proceed with stress test? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Test cancelled by user"
    exit 0
fi

# Simulate high CPU utilization
test_cpu_spike() {
    echo ""
    echo "TEST: High CPU Utilization"
    echo "Starting CPU stress test for 60 seconds..."
    stress-ng --cpu 0 --cpu-load 95 --timeout 60s &
    echo "CPU stress test initiated - Monitor Autopilot detection"
}

# Simulate memory pressure
test_memory_leak() {
    echo ""
    echo "TEST: Memory Consumption Spike"
    echo "Allocating system memory..."
    stress-ng --vm 1 --vm-bytes 80% --timeout 60s &
    echo "Memory stress test initiated"
}

# Simulate disk space consumption
test_disk_fill() {
    echo ""
    echo "TEST: Disk Space Exhaustion"
    echo "Creating temporary large files..."
    for i in {1..5}; do
        dd if=/dev/zero of=/tmp/stress_file_$i.tmp bs=1M count=500 2>/dev/null &
    done
    echo "Disk space stress test initiated"
    echo "Cleanup command: rm /tmp/stress_file_*.tmp"
}

# Simulate runaway process behavior
test_rogue_process() {
    echo ""
    echo "TEST: Runaway Process"
    echo "Starting high-CPU process..."
    bash -c 'while true; do :; done' &
    local pid=$!
    echo "Runaway process started (PID: $pid)"
    echo "Autopilot should terminate process within 30-60 seconds"
}

echo ""
echo "Select test scenario:"
echo "1) High CPU Utilization"
echo "2) Memory Consumption Spike"
echo "3) Disk Space Exhaustion"
echo "4) Runaway Process"
echo "5) Comprehensive Test (All Scenarios)"
echo ""
read -p "Enter selection (1-5): " choice

case $choice in
    1) test_cpu_spike ;;
    2) test_memory_leak ;;
    3) test_disk_fill ;;
    4) test_rogue_process ;;
    5)
        echo ""
        echo "Comprehensive System Stress Test Starting"
        test_cpu_spike
        sleep 5
        test_memory_leak
        sleep 5
        test_disk_fill
        sleep 5
        test_rogue_process
        ;;
    *)
        echo "Invalid selection"
        exit 1
        ;;
esac

echo ""
echo "======================================"
echo "Stress test sequence initiated"
echo ""
echo "Monitoring commands:"
echo "  sudo journalctl -u autopilot -f"
echo "  sudo tail -f /var/log/autopilot/incidents.log"
echo "  htop"
echo "  df -h"
echo "  free -h"
echo ""
echo "Allow 1-2 minutes for Autopilot to detect and remediate issues"
echo "Check logs for automated remediation actions"
