#!/bin/bash
# กำหนดตัวแปร
RANCID_PATH="/var/lib/rancid/devices/configs"
GITHUB_REPO="git@github.com:Narsisus/RANCID.git"
BACKUP_DIR="/tmp/rancid-backup"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
BRANCH_NAME="rancid"
SSH_KEY="/var/lib/rancid/.ssh/id_ed25519"

# Function สำหรับจัดการ error
handle_error() {
    echo "Error: $1"
    cd /tmp
    rm -rf $BACKUP_DIR
    exit 1
}

# ตั้งค่า SSH agent
eval $(ssh-agent -s)
ssh-add $SSH_KEY || handle_error "Failed to add SSH key"

# สร้างหรือตั้งค่า SSH config ถ้ายังไม่มี
mkdir -p ~/.ssh
cat > ~/.ssh/config << EOF
Host github.com
    HostName github.com
    IdentityFile $SSH_KEY
    User git
EOF
chmod 600 ~/.ssh/config

# สร้างโฟลเดอร์ backup ชั่วคราว
mkdir -p $BACKUP_DIR

# Clone repo หรือใช้ repo ที่มีอยู่
if [ -d "$BACKUP_DIR/.git" ]; then
    cd $BACKUP_DIR || handle_error "Cannot change to backup directory"
    GIT_SSH_COMMAND="ssh -i $SSH_KEY" git fetch origin
    git reset --hard origin/$BRANCH_NAME
else
    GIT_SSH_COMMAND="ssh -i $SSH_KEY" git clone $GITHUB_REPO $BACKUP_DIR || handle_error "Failed to clone repository"
    cd $BACKUP_DIR || handle_error "Cannot change to backup directory"
    git checkout $BRANCH_NAME || git checkout -b $BRANCH_NAME
fi

# ตั้งค่า git config
git config user.name "RANCID Backup"
git config user.email "your-email@example.com"

# ลบไฟล์เก่าทั้งหมด (ยกเว้น .git)
find . -not -path "./.git/*" -not -name ".git" -delete

# คัดลอกเฉพาะไฟล์หลัก (ไม่มี .new และ .raw)
for file in "$RANCID_PATH"/*; do
    if [[ -f "$file" && ! "$file" =~ \.(new|raw)$ ]]; then
        cp "$file" "$BACKUP_DIR/" || handle_error "Failed to copy file $file"
    fi
done

# เพิ่มไฟล์ทั้งหมดและลบไฟล์ที่ถูกลบออก
git add --all

# ตรวจสอบว่ามีการเปลี่ยนแปลงหรือไม่
if git diff --staged --quiet; then
    echo "No changes detected"
    cd /tmp
    rm -rf $BACKUP_DIR
    exit 0
fi

# commit การเปลี่ยนแปลง
git commit -m "Backup RANCID configs - $DATE"

# push ขึ้น GitHub โดยใช้ Deploy Key
GIT_SSH_COMMAND="ssh -i $SSH_KEY" git push --force-with-lease origin $BRANCH_NAME || handle_error "Failed to push changes"

# ทำความสะอาด
ssh-agent -k  # ปิด SSH agent
cd /tmp
rm -rf $BACKUP_DIR

echo "Backup completed successfully"
