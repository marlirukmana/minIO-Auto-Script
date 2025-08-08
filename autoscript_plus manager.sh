#!/bin/bash

# Konfigurasi
MINIO_DIR="/data/minio"
MINIO_BIN="/usr/local/bin/minio"
MC_BIN="/usr/local/bin/mc"
MINIO_SERVICE="/etc/systemd/system/minio.service"
ENV_FILE="/etc/default/minio"
ACCESS_KEY="admin"
SECRET_KEY="admin123"
CONSOLE_PORT="9001"

# Fungsi untuk menginstal MinIO jika belum ada
install_minio() {
    echo "🟡 MinIO tidak ditemukan. Memulai instalasi..."

    # Update sistem
    apt update && apt upgrade -y

    # Buat direktori MinIO
    mkdir -p $MINIO_DIR
    chown -R root:root $MINIO_DIR

    # Download binary MinIO
    wget https://dl.min.io/server/minio/release/linux-amd64/minio -O minio
    chmod +x minio
    mv minio $MINIO_BIN

    # Buat file environment
    cat <<EOF > $ENV_FILE
MINIO_VOLUMES="$MINIO_DIR"
MINIO_ROOT_USER=$ACCESS_KEY
MINIO_ROOT_PASSWORD=$SECRET_KEY
MINIO_CONSOLE_ADDRESS=":$CONSOLE_PORT"
EOF

    # Buat service systemd
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
    systemctl daemon-reexec
    systemctl daemon-reload
    systemctl enable minio
    systemctl start minio

    echo "✅ MinIO telah diinstal dan dijalankan."
}

# Fungsi untuk menginstal mc (MinIO Client)
install_mc() {
    echo "🟡 Menginstal MinIO Client (mc)..."
    wget https://dl.min.io/client/mc/release/linux-amd64/mc -O mc
    chmod +x mc
    mv mc $MC_BIN
    echo "✅ mc telah diinstal ke $MC_BIN"
}

# Fungsi untuk menambahkan alias dan user ke MinIO
setup_mc_alias() {
    $MC_BIN alias set local http://127.0.0.1:9000 "$ACCESS_KEY" "$SECRET_KEY" --api S3v4 >/dev/null 2>&1
}

# Fungsi untuk menampilkan menu mc admin
mc_admin_menu() {
    setup_mc_alias

    while true; do
        echo ""
        echo "🛠️  MC ADMIN MENU"
        echo "1. List users"
        echo "2. Add user"
        echo "3. Remove user"
        echo "4. Exit"
        read -p "Pilih opsi [1-4]: " pilihan

        case $pilihan in
            1)
                $MC_BIN admin user list local
                ;;
            2)
                read -p "Masukkan username: " new_user
                read -p "Masukkan password: " new_pass
                $MC_BIN admin user add local "$new_user" "$new_pass"
                echo "✅ User $new_user telah ditambahkan."
                ;;
            3)
                read -p "Masukkan username yang akan dihapus: " del_user
                $MC_BIN admin user remove local "$del_user"
                echo "❌ User $del_user telah dihapus."
                ;;
            4)
                echo "🚪 Keluar dari MC Admin Menu."
                break
                ;;
            *)
                echo "❗ Pilihan tidak valid."
                ;;
        esac
    done
}

# Cek apakah MinIO sudah terinstal
if [ -f "$MINIO_BIN" ]; then
    echo "✅ MinIO sudah terinstal."
else
    install_minio
fi

# Cek apakah mc sudah terinstal
if [ ! -f "$MC_BIN" ]; then
    install_mc
fi

# Tampilkan status MinIO
systemctl status minio --no-pager

# Tampilkan info akses
IP=$(hostname -I | awk '{print $1}')
echo ""
echo "🌐 Akses MinIO Console: http://$IP:$CONSOLE_PORT"
echo "🔑 Username: $ACCESS_KEY"
echo "🔐 Password: $SECRET_KEY"

# Jalankan menu MC Admin
mc_admin_menu
