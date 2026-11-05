package com.example.webapp;

import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.util.HtmlUtils;

@RestController
public class HomeController {

    private final String message;
    private final String version;

    public HomeController(@Value("${app.message}") String message,
                          @Value("${app.version}") String version) {
        this.message = message;
        this.version = version;
    }

    @GetMapping(value = "/", produces = MediaType.TEXT_HTML_VALUE)
    public String home() {
        return """
                <!doctype html>
                <html lang="en">
                <head><meta charset="utf-8"><title>CI/CD Demo</title></head>
                <body style="font-family:sans-serif;text-align:center;margin-top:15vh">
                  <h1>%s</h1>
                  <p>Deployed version (git SHA): <code>%s</code></p>
                </body>
                </html>
                """.formatted(HtmlUtils.htmlEscape(message), HtmlUtils.htmlEscape(version));
    }

    /** Used by the pipeline's smoke test to prove the NEW build is serving traffic. */
    @GetMapping(value = "/api/version", produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, String> version() {
        return Map.of("version", version, "message", message);
    }
}
