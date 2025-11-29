#!/bin/bash

# Oracle Cloud 인스턴스 배포 스크립트
# 사용법: ./ci-cd/deploy.sh [environment]
# 예: ./ci-cd/deploy.sh production

set -e

ENVIRONMENT=${1:-production}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=========================================="
echo "NAS 배포 스크립트 시작"
echo "환경: $ENVIRONMENT"
echo "프로젝트 디렉토리: $PROJECT_DIR"
echo "=========================================="

# 환경 변수 파일 확인
if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo "오류: .env 파일이 없습니다."
    echo "env.example을 복사하여 .env 파일을 생성하세요."
    exit 1
fi

# .env 파일 로드
set -a
source "$PROJECT_DIR/.env"
set +a

# Docker 및 Docker Compose 확인
if ! command -v docker &> /dev/null; then
    echo "오류: Docker가 설치되어 있지 않습니다."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "오류: Docker Compose가 설치되어 있지 않습니다."
    exit 1
fi

# Docker Compose 명령어 확인 (docker compose 또는 docker-compose)
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

cd "$PROJECT_DIR"

# 백업 생성 (프로덕션 환경인 경우)
if [ "$ENVIRONMENT" = "production" ]; then
    echo "프로덕션 환경: 백업 생성 중..."
    BACKUP_DIR="$PROJECT_DIR/backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # MySQL 데이터 백업 (컨테이너가 실행 중인 경우)
    if $DOCKER_COMPOSE ps mysql 2>/dev/null | grep -q "Up"; then
        echo "MySQL 데이터 백업 중..."
        $DOCKER_COMPOSE exec -T mysql mysqldump -u root -p"${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}" > "$BACKUP_DIR/mysql_backup.sql" 2>/dev/null || true
        if [ -f "$BACKUP_DIR/mysql_backup.sql" ] && [ -s "$BACKUP_DIR/mysql_backup.sql" ]; then
            echo "MySQL 백업 완료: $BACKUP_DIR/mysql_backup.sql"
        else
            echo "경고: MySQL 백업이 비어있거나 실패했습니다."
        fi
    else
        echo "MySQL 컨테이너가 실행 중이지 않아 백업을 건너뜁니다."
    fi
    
    # Docker 볼륨 백업 (선택사항)
    echo "백업 완료: $BACKUP_DIR"
fi

# 기존 컨테이너 중지 (프로덕션 환경인 경우)
if [ "$ENVIRONMENT" = "production" ]; then
    echo "기존 서비스 중지 중..."
    $DOCKER_COMPOSE down || true
fi

# 이미지 빌드
echo "Docker 이미지 빌드 중..."
if [ "$ENVIRONMENT" = "production" ]; then
    # 프로덕션: 프로덕션 Dockerfile 사용
    $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.prod.yml build --no-cache
else
    # 개발: 개발 Dockerfile 사용
    $DOCKER_COMPOSE build
fi

# 서비스 시작
echo "서비스 시작 중..."
if [ "$ENVIRONMENT" = "production" ]; then
    $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.prod.yml up -d
else
    $DOCKER_COMPOSE up -d
fi

# 헬스 체크
echo "헬스 체크 중..."
sleep 15

MAX_RETRIES=30
RETRY_COUNT=0

check_health() {
    local service=$1
    local url=$2
    
    if curl -f -s "$url" > /dev/null 2>&1; then
        echo "✓ $service 건강 상태 확인 완료"
        return 0
    else
        return 1
    fi
}

# 서버 IP 확인 (환경 변수 또는 localhost)
SERVER_IP=${SERVER_IP:-localhost}
FRONTEND_PORT=${VUE_PORT:-3000}

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    SPRINGBOOT_HEALTHY=false
    KOTLIN_HEALTHY=false
    
    if check_health "Spring Boot API" "http://${SERVER_IP}:${FRONTEND_PORT}/api/springboot/health"; then
        SPRINGBOOT_HEALTHY=true
    fi
    
    if check_health "Kotlin API" "http://${SERVER_IP}:${FRONTEND_PORT}/api/kotlin/health"; then
        KOTLIN_HEALTHY=true
    fi
    
    if [ "$SPRINGBOOT_HEALTHY" = true ] && [ "$KOTLIN_HEALTHY" = true ]; then
        echo "=========================================="
        echo "모든 서비스가 정상적으로 시작되었습니다!"
        echo "=========================================="
        $DOCKER_COMPOSE ps
        echo ""
        echo "프론트엔드 접속: http://${SERVER_IP}:${FRONTEND_PORT}"
        exit 0
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "재시도 중... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 5
done

echo "경고: 일부 서비스가 시작되지 않았습니다."
$DOCKER_COMPOSE ps
$DOCKER_COMPOSE logs --tail=50
exit 1

