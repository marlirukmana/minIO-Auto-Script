#!/bin/bash

# Konfigurasi MinIO
MINIO_ALIAS="local"
MINIO_ENDPOINT="http://127.0.0.1:9000"

# Minta kredensial MinIO dari user
read -p "Enter MinIO Access Key: " MINIO_ACCESS_KEY
read -s -p "Enter MinIO Secret Key: " MINIO_SECRET_KEY
echo ""

# Fungsi: Install mc
install_mc() {
    echo "[+] Installing mc..."
    curl -O https://dl.min.io/client/mc/release/linux-amd64/mc
    chmod +x mc
    sudo mv mc /usr/local/bin/
    echo "[+] mc installed at /usr/local/bin/mc"
}

# Fungsi: Setup alias
setup_mc_alias() {
    echo "[*] Setting mc alias..."
    mc alias set "$MINIO_ALIAS" "$MINIO_ENDPOINT" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY"
    echo "[+] Alias '$MINIO_ALIAS' configured."
}

# Fungsi: Create user
create_user() {
    read -p "Enter new username: " USERNAME
    read -p "Enter password for $USERNAME: " PASSWORD
    mc admin user add "$MINIO_ALIAS" "$USERNAME" "$PASSWORD"
    echo "[+] User '$USERNAME' created."
}

# Fungsi: Remove user
remove_user() {
    read -p "Enter username to remove: " USERNAME
    mc admin user remove "$MINIO_ALIAS" "$USERNAME"
    echo "[+] User '$USERNAME' removed."
}

# Fungsi: List users
list_users() {
    mc admin user list "$MINIO_ALIAS"
}

# Fungsi: Create policy
create_policy() {
    read -p "Enter policy name: " POLICYNAME
    read -p "Enter bucket name to allow full access: " BUCKETNAME

    POLICYFILE="/tmp/$POLICYNAME.json"
    cat > "$POLICYFILE" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetBucketLocation",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::$BUCKETNAME"
      ]
    },
    {
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::$BUCKETNAME/*"
      ]
    }
  ]
}
EOF

    mc admin policy create "$MINIO_ALIAS" "$POLICYNAME" --file "$POLICYFILE"
    echo "[+] Policy '$POLICYNAME' created for bucket '$BUCKETNAME'."
}

# Fungsi: Attach policy ke user
attach_policy() {
    read -p "Enter policy name: " POLICYNAME
    read -p "Enter username: " USERNAME
    mc admin policy attach "$MINIO_ALIAS" --user "$USERNAME" "$POLICYNAME"
    echo "[+] Policy '$POLICYNAME' attached to user '$USERNAME'."
}

# Fungsi: Delete policy
delete_policy() {
    read -p "Enter policy name to delete: " POLICYNAME
    echo "[*] Checking if policy '$POLICYNAME' is in use..."

    USERS=$(mc admin user list "$MINIO_ALIAS" | awk '{print $1}')
    IN_USE_USERS=()

    for USER in $USERS; do
        ATTACHED_POLICY=$(mc admin policy info "$MINIO_ALIAS" --user "$USER" 2>/dev/null | grep -o "$POLICYNAME")
        if [[ "$ATTACHED_POLICY" == "$POLICYNAME" ]]; then
            IN_USE_USERS+=("$USER")
        fi
    done

    if [[ ${#IN_USE_USERS[@]} -gt 0 ]]; then
        echo "[!] Policy '$POLICYNAME' is in use by the following users:"
        for U in "${IN_USE_USERS[@]}"; do
            echo "  - $U"
        done

        read -p "Do you want to detach this policy from all users? [y/N]: " CONFIRM
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            for U in "${IN_USE_USERS[@]}"; do
                mc admin policy detach "$MINIO_ALIAS" --user "$U" "$POLICYNAME"
                echo "[*] Detached policy '$POLICYNAME' from user '$U'."
            done
        else
            echo "[!] Policy delete cancelled."
            return
        fi
    fi

    mc admin policy remove "$MINIO_ALIAS" "$POLICYNAME"
    if [[ $? -eq 0 ]]; then
        echo "[+] Policy '$POLICYNAME' deleted."
    else
        echo "[!] Failed to delete policy '$POLICYNAME'."
    fi
}

# Fungsi: List all policies
list_policies() {
    mc admin policy list "$MINIO_ALIAS"
}

# Fungsi: Create bucket
create_bucket() {
    read -p "Enter bucket name to create: " BUCKETNAME
    if mc ls "$MINIO_ALIAS/$BUCKETNAME" > /dev/null 2>&1; then
        echo "[*] Bucket '$BUCKETNAME' already exists."
    else
        mc mb "$MINIO_ALIAS/$BUCKETNAME"
        echo "[+] Bucket '$BUCKETNAME' created."
    fi
}

# Fungsi: Cek alias
check_alias() {
    if ! mc alias list | grep -q "$MINIO_ALIAS"; then
        echo "[!] Alias '$MINIO_ALIAS' not found. Setting it up..."
        setup_mc_alias
    fi
}

# Menu utama
while true; do
    echo ""
    echo "========== MinIO Admin Script =========="
    echo "1. Install mc client"
    echo "2. Set up mc alias (connect to MinIO)"
    echo "3. Create user"
    echo "4. Remove user"
    echo "5. List users"
    echo "6. Create policy for bucket access"
    echo "7. Attach policy to user"
    echo "8. Delete policy"
    echo "9. List policies"
    echo "10. Create bucket if not exists"
    echo "0. Exit"
    echo "========================================"
    read -p "Select an option: " OPTION

    if [[ "$OPTION" =~ ^[3-9]|10$ ]]; then
        check_alias
    fi

    case $OPTION in
        1) install_mc ;;
        2) setup_mc_alias ;;
        3) create_user ;;
        4) remove_user ;;
        5) list_users ;;
        6) create_policy ;;
        7) attach_policy ;;
        8) delete_policy ;;
        9) list_policies ;;
        10) create_bucket ;;
        0) echo "Goodbye!"; exit 0 ;;
        *) echo "[!] Invalid option." ;;
    esac
done
