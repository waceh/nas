-- 샘플 데이터베이스 초기화 스크립트
-- 이 파일은 MySQL 컨테이너가 처음 시작될 때 자동으로 실행됩니다

USE nas_db;

-- 사용자 테이블 생성
CREATE TABLE IF NOT EXISTS users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 샘플 데이터 삽입
INSERT INTO users (username, email) VALUES
    ('admin', 'admin@example.com'),
    ('user1', 'user1@example.com'),
    ('user2', 'user2@example.com')
ON DUPLICATE KEY UPDATE email=email;

-- 제품 테이블 생성 (Kotlin API용)
CREATE TABLE IF NOT EXISTS products (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 샘플 제품 데이터 삽입
INSERT INTO products (name, price, description) VALUES
    ('노트북', 1200000.00, '고성능 노트북'),
    ('마우스', 50000.00, '무선 마우스'),
    ('키보드', 80000.00, '기계식 키보드')
ON DUPLICATE KEY UPDATE name=name;

