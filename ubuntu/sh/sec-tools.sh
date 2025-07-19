#!/usr/bin/env bash
# sec-tools.sh
# 一键安装并配置 Lynis rkhunter chkrootkit Wazuh-Agent
# 并设置每周日凌晨 02:00 自动安全扫描
# 2025-07-19 更新

set -eu

# 颜色输出
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# 检查 sudo
if ! command -v sudo >/dev/null 2>&1; then
    err "无法找到 sudo，请先安装 sudo 并配置当前用户为管理员（sudoers）。"
    exit 1
fi

# 检测发行版
if command -v apt-get >/dev/null 2>&1; then
    PKG="apt-get -y"
elif command -v yum >/dev/null 2>&1; then
    PKG="yum -y"
elif command -v dnf >/dev/null 2>&1; then
    PKG="dnf -y"
else
    err "暂不支持此发行版"; exit 1
fi

# 安装工具
log ">>> 安装安全工具 ..."
sudo $PKG update
sudo $PKG install lynis rkhunter chkrootkit wazuh-agent

# Wazuh-Agent 配置（无自建 Manager 时本地日志）
log ">>> 配置 Wazuh-Agent ..."
CONF_FILE=/var/ossec/etc/ossec.conf
if sudo test -f "$CONF_FILE"; then
    # 如果存在 <server-ip>127.0.0.1</server-ip> 则不重复操作
    if ! sudo grep -q '<server-ip>127.0.0.1</server-ip>' "$CONF_FILE"; then
        sudo sed -i 's|<server-ip>.*</server-ip>|<server-ip>127.0.0.1</server-ip>|g' "$CONF_FILE"
    fi
fi
sudo systemctl enable --now wazuh-agent

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