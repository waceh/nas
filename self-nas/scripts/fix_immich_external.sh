#!/usr/bin/env bash
# Immich External Library Volume Fixer
set -e

echo "[INFO] Immich docker-compose.yml 업데이트 중..."
pct exec 103 -- bash -c '
cd /opt/immich
curl -fsSL https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml -o docker-compose.yml

# Python으로 정확한 들여쓰기로 외부 라이브러리 볼륨 추가
python3 -c "
with open(\"docker-compose.yml\", \"r\") as f:
    text = f.read()
text = text.replace(\"\${UPLOAD_LOCATION}:/usr/src/app/upload\", \"\${UPLOAD_LOCATION}:/usr/src/app/upload\n      - /mnt/photo:/mnt/media/photos:ro\")
with open(\"docker-compose.yml\", \"w\") as f:
    f.write(text)
" 2>/dev/null || sed -i "s|\${UPLOAD_LOCATION}:/usr/src/app/upload|\${UPLOAD_LOCATION}:/usr/src/app/upload\n      - /mnt/photo:/mnt/media/photos:ro|g" docker-compose.yml

docker compose up -d
'

echo "===================================================="
echo "🎉 외부 라이브러리 통로(/mnt/media/photos) 연동 완료!"
echo "===================================================="
echo "1. Immich 웹: http://192.168.1.103:2283 접속"
echo "2. Administration ➔ External Libraries ➔ Create Library"
echo "3. Import Path 에 /mnt/media/photos 입력 후 스캔!"
echo "===================================================="
