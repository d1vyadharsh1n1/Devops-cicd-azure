
package com.example.webapp.service;

import com.example.webapp.model.Todo;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

@Service
public class TodoService {

    private final ConcurrentHashMap<Long, Todo> todos =
            new ConcurrentHashMap<>();

    private final AtomicLong idGenerator = new AtomicLong(0);

    public List<Todo> getAllTodos() {
        return todos.values().stream()
                .sorted(Comparator.comparing(Todo::id))
                .toList();
    }

    public Todo getTodo(Long id) {
        Todo todo = todos.get(id);

        if (todo == null) {
            throw new ResponseStatusException(
                    HttpStatus.NOT_FOUND, "Todo not found");
        }

        return todo;
    }

    public Todo createTodo(String title, String description) {
        validateTitle(title);

        Long id = idGenerator.incrementAndGet();

        Todo todo = new Todo(
                id,
                title.trim(),
                description == null ? "" : description.trim(),
                false,
                LocalDateTime.now()
        );

        todos.put(id, todo);
        return todo;
    }

    public Todo updateTodo(Long id, String title, String description) {
        validateTitle(title);

        Todo existing = getTodo(id);

        Todo updated = new Todo(
                id,
                title.trim(),
                description == null ? "" : description.trim(),
                existing.completed(),
                existing.createdAt()
        );

        todos.put(id, updated);
        return updated;
    }

    public Todo completeTodo(Long id) {
        Todo existing = getTodo(id);

        Todo updated = new Todo(
                existing.id(),
                existing.title(),
                existing.description(),
                !existing.completed(),
                existing.createdAt()
        );

        todos.put(id, updated);
        return updated;
    }

    public void deleteTodo(Long id) {
        if (todos.remove(id) == null) {
            throw new ResponseStatusException(
                    HttpStatus.NOT_FOUND, "Todo not found");
        }
    }

    private void validateTitle(String title) {
        if (title == null || title.isBlank()) {
            throw new ResponseStatusException(
                    HttpStatus.BAD_REQUEST, "Title cannot be empty");
        }
    }
}
