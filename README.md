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
