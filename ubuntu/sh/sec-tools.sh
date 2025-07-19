#!/usr/bin/env bash
# sec-tools.sh
# 自动安装 lynis、rkhunter、chkrootkit，并设置定期自动巡检
# 已修复：rkhunter SSH 同步、getcwd() 失败
# 2025-07-19

set -eu

LOGDIR="/var/log/weekly-sec"
SCRIPT_PATH="/usr/local/bin/weekly-sec.sh"

# 进入安全目录
cd /root 2>/dev/null || cd /tmp

echo "[INFO] 开始安装安全工具 ..."
sudo apt-get update
sudo apt-get install -y lynis rkhunter chkrootkit

echo "[INFO] 修复 rkhunter 配置 ..."
sudo sed -i 's|^WEB_CMD=.*|WEB_CMD=""|' /etc/rkhunter.conf 2>/dev/null || true
sudo sed -i 's|^WEB_CMD=.*|WEB_CMD=""|' /etc/rkhunter.conf.local 2>/dev/null || true

echo "[INFO] 创建自动巡检脚本 ..."
sudo tee "$SCRIPT_PATH" >/dev/null <<'EOF'
#!/bin/bash
cd /root 2>/dev/null || cd /tmp

LOGDIR=/var/log/weekly-sec
sudo mkdir -p "$LOGDIR"
DATE=$(date +%F)

echo "[巡检] 开始自动安全巡检..."

# 同步 SSH 与 rkhunter
sudo rkhunter --propupd >/dev/null 2>&1
if grep -Eq '^PermitRootLogin\s+(yes|prohibit-password)' /etc/ssh/sshd_config 2>/dev/null; then
    sudo sed -i 's/^ALLOW_SSH_ROOT_USER=.*/ALLOW_SSH_ROOT_USER=yes/' /etc/rkhunter.conf
else
    sudo sed -i 's/^ALLOW_SSH_ROOT_USER=.*/ALLOW_SSH_ROOT_USER=no/' /etc/rkhunter.conf
fi

echo "[巡检] 执行 lynis..."
sudo lynis audit system > "$LOGDIR/lynis-${DATE}.log"
echo "[巡检] lynis 完成"

echo "[巡检] 执行 rkhunter..."
sudo rkhunter --update --quiet
sudo rkhunter --check --skip-keypress --report-warnings-only --logfile "$LOGDIR/rkhunter-${DATE}.log"
echo "[巡检] rkhunter 完成"

echo "[巡检] 执行 chkrootkit..."
sudo chkrootkit > "$LOGDIR/chkrootkit-${DATE}.log"
echo "[巡检] chkrootkit 完成"

echo "[巡检] 清理旧日志..."
sudo find "$LOGDIR" -type f -mtime +7 -delete

echo "[巡检] 本次自动巡检完成，日志保存在 $LOGDIR"
EOF

sudo chmod +x "$SCRIPT_PATH"

echo "[INFO] 设置每周日凌晨 02:00 自动巡检..."
(sudo crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH"; echo "0 2 * * 0 $SCRIPT_PATH") | sudo crontab -

echo "[INFO] 立即手动执行一次巡检..."
sudo "$SCRIPT_PATH"
echo "[INFO] 全部完成！日志目录：$LOGDIR"