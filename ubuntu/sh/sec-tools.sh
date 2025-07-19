#!/usr/bin/env bash
# sec-tools.sh
# 一键安装 Lynis rkhunter chkrootkit 并设置每周日凌晨 02:00 自动安全扫描
# 适用于 Ubuntu/Debian 系统

set -eu

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# 检查 sudo
if ! command -v sudo >/dev/null 2>&1; then
    err "无法找到 sudo，请先安装 sudo 并配置当前用户为管理员（sudoers）。"
    exit 1
fi

# 防止 postfix 交互
echo "postfix postfix/main_mailer_type select No configuration" | sudo debconf-set-selections

# 安装工具
log ">>> 安装 lynis rkhunter chkrootkit ..."
sudo apt-get update
sudo apt-get install -y lynis rkhunter chkrootkit

# 创建每周扫描脚本
SCRIPT_PATH=/usr/local/bin/weekly-sec.sh
log ">>> 创建每周扫描脚本 $SCRIPT_PATH ..."
sudo tee "$SCRIPT_PATH" > /dev/null <<'EOF'
#!/bin/bash
LOGDIR=/var/log/weekly-sec
sudo mkdir -p "$LOGDIR"
DATE=$(date +%F)

# Lynis
sudo lynis audit system > "$LOGDIR/lynis-${DATE}.log"

# rkhunter
sudo rkhunter --update --quiet
sudo rkhunter --check --skip-keypress --report-warnings-only \
              --logfile "$LOGDIR/rkhunter-${DATE}.log"

# chkrootkit
sudo chkrootkit > "$LOGDIR/chkrootkit-${DATE}.log"

# 清理旧日志（保留 4 周）
sudo find "$LOGDIR" -type f -mtime +28 -delete
EOF
sudo chmod +x "$SCRIPT_PATH"

# 添加 cron（写入 root 的 cron，不影响个人 cron）
log ">>> 添加每周日凌晨 02:00 的 cron 任务 ..."
( sudo crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" ; \
  echo "0 2 * * 0 $SCRIPT_PATH" ) | sudo crontab -

# 立即手动跑一次，验证
log ">>> 立即执行一次验证 ..."
sudo "$SCRIPT_PATH"

log ">>> 全部完成！日志目录：/var/log/weekly-sec"