package com.nas.repository

import com.nas.entity.Product
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface ProductRepository : JpaRepository<Product, Long> {
    // JpaRepository에 이미 findAll()이 있으므로 별도로 정의할 필요 없음
}

