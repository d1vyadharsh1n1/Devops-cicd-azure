
package com.example.webapp.controller;

import com.example.webapp.model.Todo;
import com.example.webapp.service.TodoService;

import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/todos")
public class TodoController {

    private final TodoService todoService;

    public TodoController(TodoService todoService) {
        this.todoService = todoService;
    }

    public record TodoRequest(String title, String description) {}

    // Get all todos
    @GetMapping
    public List<Todo> getAllTodos() {
        return todoService.getAllTodos();
    }

    // Get a todo by ID
    @GetMapping("/{id}")
    public Todo getTodo(@PathVariable Long id) {
        return todoService.getTodo(id);
    }

    // Create a todo
    @PostMapping
    public Todo createTodo(@RequestBody TodoRequest request) {
        return todoService.createTodo(
                request.title(),
                request.description()
        );
    }

    // Update a todo
    @PutMapping("/{id}")
    public Todo updateTodo(
            @PathVariable Long id,
            @RequestBody TodoRequest request) {

        return todoService.updateTodo(
                id,
                request.title(),
                request.description()
        );
    }

    // Toggle completion status
    @PatchMapping("/{id}/complete")
    public Todo completeTodo(@PathVariable Long id) {
        return todoService.completeTodo(id);
    }

    // Delete a todo
    @DeleteMapping("/{id}")
    public void deleteTodo(@PathVariable Long id) {
        todoService.deleteTodo(id);
    }
}
