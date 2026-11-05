
package com.example.webapp.model;

import java.time.LocalDateTime;

public record Todo(
        Long id,
        String title,
        String description,
        boolean completed,
        LocalDateTime createdAt
) {
}
