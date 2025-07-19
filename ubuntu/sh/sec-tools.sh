#!/usr/bin/env bash
# sec-tools.sh
# 自动安装 lynis、rkhunter、chkrootkit，并设置定期自动巡检，自动修复配置问题

set -eu

LOGDIR="/var/log/weekly-sec"
SCRIPT_PATH="/usr/local/bin/weekly-sec.sh"

# 进入安全目录，避免 getcwd 报错
cd /tmp 2>/dev/null || cd /  # 修改1：使用更安全的/tmp目录而非/root

echo "[INFO] 开始安装 lynis、rkhunter、chkrootkit..."
sudo apt-get update
sudo apt-get install -y lynis rkhunter chkrootkit

echo "[INFO] 修复 rkhunter WEB_CMD 配置..."
sudo sed -i 's|^WEB_CMD=.*|WEB_CMD=""|' /etc/rkhunter.conf 2>/dev/null || true
sudo sed -i 's|^WEB_CMD=.*|WEB_CMD=""|' /etc/rkhunter.conf.local 2>/dev/null || true

# 修改2：更全面的SSH root登录检测
if grep -Eq '^PermitRootLogin\s+(yes|prohibit-password)' /etc/ssh/sshd_config 2>/dev/null; then
    sudo sed -i 's|^ALLOW_SSH_ROOT_USER.*|ALLOW_SSH_ROOT_USER=yes|' /etc/rkhunter.conf 2>/dev/null || true
    sudo sed -i 's|^ALLOW_SSH_ROOT_USER.*|ALLOW_SSH_ROOT_USER=yes|' /etc/rkhunter.conf.local 2>/dev/null || true
else
    sudo sed -i 's|^ALLOW_SSH_ROOT_USER.*|ALLOW_SSH_ROOT_USER=no|' /etc/rkhunter.conf 2>/dev/null || true
    sudo sed -i 's|^ALLOW_SSH_ROOT_USER.*|ALLOW_SSH_ROOT_USER=no|' /etc/rkhunter.conf.local 2>/dev/null || true
fi

echo "[INFO] 创建自动巡检脚本..."
sudo tee "$SCRIPT_PATH" > /dev/null <<'EOF'
#!/bin/bash
cd /tmp 2>/dev/null || cd /  # 修改3：使用更安全的/tmp目录而非/root

LOGDIR=/var/log/weekly-sec
sudo mkdir -p "$LOGDIR"
DATE=$(date +%F)

# 修改4：更全面的SSH配置同步
if grep -Eq '^PermitRootLogin\s+(yes|prohibit-password)' /etc/ssh/sshd_config 2>/dev/null; then
    [ -f /etc/rkhunter.conf ] && sudo sed -i 's/^ALLOW_SSH_ROOT_USER=.*/ALLOW_SSH_ROOT_USER=yes/' /etc/rkhunter.conf
    [ -f /etc/rkhunter.conf.local ] && sudo sed -i 's/^ALLOW_SSH_ROOT_USER=.*/ALLOW_SSH_ROOT_USER=yes/' /etc/rkhunter.conf.local
else
    [ -f /etc/rkhunter.conf ] && sudo sed -i 's/^ALLOW_SSH_ROOT_USER=.*/ALLOW_SSH_ROOT_USER=no/' /etc/rkhunter.conf
    [ -f /etc/rkhunter.conf.local ] && sudo sed -i 's/^ALLOW_SSH_ROOT_USER=.*/ALLOW_SSH_ROOT_USER=no/' /etc/rkhunter.conf.local
fi

echo "[巡检] 开始自动安全巡检..."

# Lynis
echo "[巡检] 执行 lynis..."
sudo lynis audit system > "$LOGDIR/lynis-${DATE}.log"

# rkhunter
echo "[巡检] 执行 rkhunter..."
sudo rkhunter --update --quiet
sudo rkhunter --check --skip-keypress --report-warnings-only --logfile "$LOGDIR/rkhunter-${DATE}.log"

# 修改5：确保chkrootkit在明确目录下运行
echo "[巡检] 执行 chkrootkit..."
(cd /tmp && sudo chkrootkit) > "$LOGDIR/chkrootkit-${DATE}.log" 2>&1

# 清理旧日志（保留 2 周）
sudo find "$LOGDIR" -type f -mtime +14 -delete

echo "[巡检] 本次自动巡检完成，日志保存在 $LOGDIR"
EOF

sudo chmod +x "$SCRIPT_PATH"

echo "[INFO] 设置每周日凌晨 2:00 自动巡检..."
(sudo crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" ; echo "0 2 * * 0 $SCRIPT_PATH") | sudo crontab -

echo "[INFO] 立即手动执行一次巡检..."
sudo "$SCRIPT_PATH"
echo "[INFO] 自动巡检全部配置完成，日志目录：$LOGDIR"