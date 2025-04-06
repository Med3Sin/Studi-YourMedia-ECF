package com.yourmedia;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.servlet.support.SpringBootServletInitializer;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@SpringBootApplication
public class AppJavaApplication extends SpringBootServletInitializer {

    // Nécessaire pour le déploiement en WAR dans un conteneur de servlet externe comme Tomcat
    @Override
    protected SpringApplicationBuilder configure(SpringApplicationBuilder application) {
        return application.sources(AppJavaApplication.class);
    }

    public static void main(String[] args) {
        SpringApplication.run(AppJavaApplication.class, args);
    }

}

// Simple contrôleur pour tester
@RestController
class HelloWorldController {

    @GetMapping("/")
    public Map<String, String> hello() {
        return Map.of("message", "Hello World from Spring Boot!");
    }
}
