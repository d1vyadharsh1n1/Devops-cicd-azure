
package com.example.webapp;

import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HomeController {

    private final String message;
    private final String version;

    public HomeController(
            @Value("${app.message}") String message,
            @Value("${app.version}") String version) {
        this.message = message;
        this.version = version;
    }

    @GetMapping(value = "/api/version",
                produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, String> version() {
        return Map.of(
                "version", version,
                "message", message
        );
    }
}
