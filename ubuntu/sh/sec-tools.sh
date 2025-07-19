#!/usr/bin/env bash
# sec-tools.sh
# 自动安装 lynis、rkhunter、chkrootkit 并设置每周自动巡检

set -eu

logdir="/var/log/weekly-sec"
script_path="/usr/local/bin/weekly-sec.sh"

# 安装工具
sudo apt-get update
sudo apt-get install -y lynis rkhunter chkrootkit

# 创建自动巡检脚本
sudo tee "$script_path" > /dev/null <<'EOF'
#!/bin/bash
LOGDIR=/var/log/weekly-sec
sudo mkdir -p "$LOGDIR"
DATE=$(date +%F)

# Lynis
sudo lynis audit system > "$LOGDIR/lynis-${DATE}.log"

# rkhunter
sudo rkhunter --update --quiet
sudo rkhunter --check --skip-keypress --report-warnings-only --logfile "$LOGDIR/rkhunter-${DATE}.log"

# chkrootkit
sudo chkrootkit > "$LOGDIR/chkrootkit-${DATE}.log"

# 清理旧日志（保留 1 周）
sudo find "$LOGDIR" -type f -mtime +7 -delete
EOF

sudo chmod +x "$script_path"

# 设置每周日凌晨 2:00 自动巡检
(sudo crontab -l 2>/dev/null | grep -v "$script_path" ; echo "0 2 * * 0 $script_path") | sudo crontab -

# 立即手动执行一次巡检
sudo "$script_path"

echo "自动巡检已配置完成。日志目录：$logdir"