# 1. 下载脚本（任选其一）
curl -fsSL https://raw.githubusercontent.com/zatteflow/tools/main/ubuntu/sh/sec-tools.sh | sudo bash
# 或本地保存上方内容

# 清理系统
curl -fsSL https://raw.githubusercontent.com/zatteflow/tools/main/ubuntu/sh/clear.sh | sudo bash

# 2. 赋权 & 执行
chmod +x sec-tools.sh
sudo ./sec-tools.sh

# 卸载
```
sudo apt-get purge -y wazuh-agent lynis rkhunter chkrootkit && sudo rm -rf /var/ossec /etc/ossec-init.conf /var/log/weekly-sec /usr/local/bin/weekly-sec.sh && sudo rm -f /etc/apt/sources.list.d/wazuh.list /etc/apt/trusted.gpg.d/wazuh.gpg && sudo crontab -l 2>/dev/null | grep -v '/usr/local/bin/weekly-sec.sh' | sudo crontab - || true
```
