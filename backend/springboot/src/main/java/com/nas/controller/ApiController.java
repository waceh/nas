package com.nas.controller;

import com.nas.entity.User;
import com.nas.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class ApiController {

    @Autowired
    private UserRepository userRepository;

    @GetMapping("/health")
    public Map<String, Object> health() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "UP");
        response.put("service", "Spring Boot Backend");
        response.put("timestamp", LocalDateTime.now());
        return response;
    }

    @GetMapping("/hello")
    public Map<String, String> hello() {
        Map<String, String> response = new HashMap<>();
        response.put("message", "Hello from Spring Boot Backend!");
        return response;
    }

    @GetMapping("/users")
    public ResponseEntity<Map<String, Object>> getUsers() {
        try {
            List<User> users = userRepository.findAll();
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("service", "Spring Boot Backend");
            response.put("count", users.size());
            response.put("data", users);
            response.put("timestamp", LocalDateTime.now());
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> response = new HashMap<>();
            response.put("success", false);
            response.put("error", e.getMessage());
            response.put("timestamp", LocalDateTime.now());
            return ResponseEntity.internalServerError().body(response);
        }
    }
}

