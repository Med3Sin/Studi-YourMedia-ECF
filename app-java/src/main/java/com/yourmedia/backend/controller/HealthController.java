package com.yourmedia.backend.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

@RestController
public class HealthController {

    @GetMapping("/api/health")
    public Map<String, Object> health() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "UP");
        response.put("message", "YourMedia Backend is running");
        response.put("timestamp", new Date().toString());
        response.put("version", "1.0.0");
        response.put("application", "YourMedia Hello World");
        response.put("environment", System.getProperty("spring.profiles.active", "default"));
        return response;
    }
}
