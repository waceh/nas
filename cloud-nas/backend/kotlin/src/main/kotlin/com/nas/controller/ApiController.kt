package com.nas.controller

import com.nas.entity.Product
import com.nas.repository.ProductRepository
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import java.time.LocalDateTime

@RestController
@RequestMapping("/api/kotlin")
class ApiController(
    private val productRepository: ProductRepository
) {

    @GetMapping("/health")
    fun health(): Map<String, Any> {
        return mapOf(
            "status" to "UP",
            "service" to "Kotlin Backend",
            "timestamp" to LocalDateTime.now()
        )
    }

    @GetMapping("/hello")
    fun hello(): Map<String, String> {
        return mapOf("message" to "Hello from Kotlin Backend!")
    }

    @GetMapping("/products")
    fun getProducts(): ResponseEntity<Map<String, Any>> {
        return try {
            val products = productRepository.findAll()
            val response = mapOf(
                "success" to true,
                "service" to "Kotlin Backend",
                "count" to products.size,
                "data" to products,
                "timestamp" to LocalDateTime.now()
            )
            ResponseEntity.ok(response)
        } catch (e: Exception) {
            val response = mapOf(
                "success" to false,
                "error" to (e.message ?: "Unknown error"),
                "timestamp" to LocalDateTime.now()
            )
            ResponseEntity.internalServerError().body(response)
        }
    }
}

