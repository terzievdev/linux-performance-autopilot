# Linux Performance Autopilot

Self-healing Linux monitoring system with auto-remediation.

## Features
- Real-time CPU, Memory, Disk monitoring
- Auto-kill high-CPU processes
- Auto-clear memory cache
- Auto-restart failed services
- HTML reports with graphs
- Webhook notifications

## Installation
```bash
sudo ./scripts/setup.sh
```

## Testing
```bash
sudo ./tests/stress-test.sh
```

## Logs
```bash
sudo journalctl -u autopilot -f
sudo tail -f /var/log/autopilot/incidents.log
```
## Project Results 

### Successfully Tested Features
- CPU spike detection (100% load)
- Automatic process termination
- Memory monitoring
- Disk space monitoring
- Incident logging with timestamps
- HTML analytics reports with graphs

### Test Results
- **CPU Spike Test:** Detected and killed runaway process in 45 seconds
- **Incidents Logged:** 5 total incidents during testing
- **System Uptime:** Maintained stability after auto-remediation

## Architecture
- **Deployment:** AWS EC2 (t3.micro, Ubuntu 22.04)
- **Monitoring Interval:** 30 seconds
- **Auto-remediation:** Enabled
- **Logging:** Multi-tier (perfomance, incidents, actions)
