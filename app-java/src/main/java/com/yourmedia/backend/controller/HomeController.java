package com.yourmedia.backend.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseBody;

@Controller
public class HomeController {

    @GetMapping("/")
    @ResponseBody
    public String home() {
        return "<html><head><title>YourMedia - Hello World</title>"
             + "<style>"
             + "body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }"
             + ".container { max-width: 800px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }"
             + "h1 { color: #2c3e50; }"
             + "p { color: #34495e; line-height: 1.6; }"
             + ".api-link { display: inline-block; margin-top: 20px; padding: 10px 15px; background-color: #3498db; color: white; text-decoration: none; border-radius: 3px; }"
             + ".api-link:hover { background-color: #2980b9; }"
             + "</style>"
             + "</head><body>"
             + "<div class='container'>"
             + "<h1>Hello World from YourMedia!</h1>"
             + "<p>This is a simple Hello World application built with Spring Boot.</p>"
             + "<p>This message is generated directly from the Java controller.</p>"
             + "<h2>API Endpoints</h2>"
             + "<p>You can check the health of the application by visiting:</p>"
             + "<a href='api/health' class='api-link'>Health Check API</a>"
             + "</div>"
             + "</body></html>";
    }
}
