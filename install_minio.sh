#!/bin/bash

# Konfigurasi
MINIO_DIR="/data/minio"
MINIO_BIN="/usr/local/bin/minio"
MINIO_SERVICE="/etc/systemd/system/minio.service"
ENV_FILE="/etc/default/minio"
ACCESS_KEY="admin"
SECRET_KEY="admin123"
CONSOLE_PORT="9001"

# Update sistem
echo "Updating system..."
apt update && apt upgrade -y

# Buat direktori MinIO
echo "Creating data directory..."
mkdir -p $MINIO_DIR
chown -R root:root $MINIO_DIR

# Download binary MinIO
echo "Downloading MinIO binary..."
wget https://dl.min.io/server/minio/release/linux-amd64/minio -O minio
chmod +x minio
mv minio $MINIO_BIN

# Buat file environment
echo "Writing environment config..."
cat <<EOF > $ENV_FILE
MINIO_VOLUMES="$MINIO_DIR"
MINIO_ROOT_USER=$ACCESS_KEY
MINIO_ROOT_PASSWORD=$SECRET_KEY
MINIO_CONSOLE_ADDRESS=":$CONSOLE_PORT"
EOF

# Buat service systemd
echo "Creating systemd service file..."
cat <<EOF > $MINIO_SERVICE
[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
EnvironmentFile=$ENV_FILE
ExecStart=$MINIO_BIN server \$MINIO_VOLUMES
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# Reload dan jalankan service
echo "Enabling and starting MinIO..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable minio
systemctl start minio

# Cek status
echo ""
echo "Checking status..."
systemctl status minio --no-pager

# Info akses
IP=$(hostname -I | awk '{print $1}')
echo ""
echo "✅ MinIO is installed and running!"
echo "🌐 Access Console: http://$IP:$CONSOLE_PORT"
echo "🔑 Username: $ACCESS_KEY"
echo "🔐 Password: $SECRET_KEY"
