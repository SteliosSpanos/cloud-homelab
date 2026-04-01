#!/bin/bash
exec > /var/log/web-app-setup.log 2>&1
set -x

echo "=== Web App Setup Started at $(date) ==="
    
# 1. Install and configure CloudWatch Agent (matching your NAT setup)
dnf install -y amazon-cloudwatch-agent
    
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << CWEOF
{
    "logs": {
        "logs_collected": {
            "files": {
              "collect_list": [
                {
                  "file_path": "/var/log/web-app-setup.log",
                  "log_group_name": "${log_group_name}",
                  "log_stream_name": "{instance_id}/web-app-setup"
                },
                {
                  "file_path": "/var/log/messages",
                  "log_group_name": "${log_group_name}",
                  "log_stream_name": "{instance_id}/messages"
                }
              ]
            }
        }
    }
}
CWEOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
   
# 2. Install Docker
dnf update -y
dnf install -y docker
systemctl enable --now docker
   
# 3. Create the app directory and .env file
mkdir -p /home/ec2-user/app
cd /home/ec2-user/app

cat <<EOF > .env
AWS_REGION=${region}
DB_SECRET_ID=${db_secret_arn}
DB_HOST=${db_host}
DB_PORT=5432
DB_NAME=${db_name}
EOF
