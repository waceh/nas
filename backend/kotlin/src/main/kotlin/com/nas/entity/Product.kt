package com.nas.entity

import jakarta.persistence.*
import java.math.BigDecimal
import java.time.LocalDateTime

@Entity
@Table(name = "products")
data class Product(
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,

    @Column(nullable = false, length = 100)
    val name: String = "",

    @Column(nullable = false, precision = 10, scale = 2)
    val price: BigDecimal = BigDecimal.ZERO,

    @Column(columnDefinition = "TEXT")
    val description: String? = null,

    @Column(name = "created_at")
    val createdAt: LocalDateTime? = null,

    @Column(name = "updated_at")
    val updatedAt: LocalDateTime? = null
)

