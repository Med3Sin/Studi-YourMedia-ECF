package com.yourmedia.backend.controller;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests unitaires pour le contrôleur HealthController.
 */
@SpringBootTest
public class HealthControllerTest {

    @Autowired
    private HealthController healthController;

    /**
     * Vérifie que le contrôleur de santé renvoie le statut "UP".
     */
    @Test
    public void testHealthEndpoint() {
        Map<String, Object> response = healthController.health();
        
        assertNotNull(response, "La réponse ne devrait pas être null");
        assertEquals("UP", response.get("status"), "Le statut devrait être 'UP'");
        assertNotNull(response.get("timestamp"), "Le timestamp ne devrait pas être null");
        assertEquals("YourMedia Hello World", response.get("application"), "Le nom de l'application est incorrect");
    }
}
