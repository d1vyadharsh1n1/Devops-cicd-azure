const API_URL = "/api/todos";

let todos = [];
let currentFilter = "all";
let editingId = null;

const todoForm = document.getElementById("todoForm");
const titleInput = document.getElementById("title");
const descriptionInput = document.getElementById("description");
const taskList = document.getElementById("taskList");
const message = document.getElementById("message");

document.getElementById("today").textContent = new Date().toLocaleDateString(
  "en-IN",
  {
    day: "numeric",
    month: "short",
    year: "numeric",
  },
);

// Fetch all tasks
async function loadTodos() {
  try {
    const response = await fetch(API_URL);

    if (!response.ok) {
      throw new Error("Could not load tasks");
    }

    todos = await response.json();
    renderTodos();
  } catch (error) {
    message.textContent = error.message;
  }
}

// Display tasks
function renderTodos() {
  taskList.replaceChildren();

  const filteredTodos = todos.filter((todo) => {
    if (currentFilter === "pending") return !todo.completed;
    if (currentFilter === "completed") return todo.completed;
    return true;
  });

  document.getElementById("totalCount").textContent = todos.length;
  document.getElementById("pendingCount").textContent = todos.filter(
    (todo) => !todo.completed,
  ).length;
  document.getElementById("completedCount").textContent = todos.filter(
    (todo) => todo.completed,
  ).length;

  message.textContent = "";

  if (filteredTodos.length === 0) {
    message.textContent =
      todos.length === 0
        ? "No tasks yet. Add your first task!"
        : "No tasks in this category.";
    return;
  }

  filteredTodos.forEach((todo) => {
    const card = document.createElement("div");
    card.className = "task-card";

    const checkbox = document.createElement("input");
    checkbox.type = "checkbox";
    checkbox.className = "task-check";
    checkbox.checked = todo.completed;
    checkbox.setAttribute("aria-label", "Mark task completed");
    checkbox.addEventListener("change", () => toggleTodo(todo.id));

    const info = document.createElement("div");
    info.className = "task-info";

    const heading = document.createElement("h3");
    heading.textContent = todo.title;
    if (todo.completed) heading.classList.add("done");

    const description = document.createElement("p");
    description.textContent = todo.description || "No description";
    if (todo.completed) description.classList.add("done");

    info.append(heading, description);

    const actions = document.createElement("div");
    actions.className = "task-actions";

    const editButton = document.createElement("button");
    editButton.textContent = "Edit";
    editButton.addEventListener("click", () => editTodo(todo));

    const deleteButton = document.createElement("button");
    deleteButton.textContent = "Delete";
    deleteButton.addEventListener("click", () => deleteTodo(todo.id));

    actions.append(editButton, deleteButton);
    card.append(checkbox, info, actions);
    taskList.appendChild(card);
  });
}

// Create or update a task
todoForm.addEventListener("submit", async (event) => {
  event.preventDefault();

  const todoData = {
    title: titleInput.value.trim(),
    description: descriptionInput.value.trim(),
  };

  if (!todoData.title) return;

  const url = editingId ? `${API_URL}/${editingId}` : API_URL;

  const method = editingId ? "PUT" : "POST";

  try {
    const response = await fetch(url, {
      method,
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(todoData),
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error.detail || error.message || "Unable to save task");
    }

    resetForm();
    await loadTodos();
  } catch (error) {
    alert(error.message);
  }
});

// Load task details into the form
function editTodo(todo) {
  editingId = todo.id;

  titleInput.value = todo.title;
  descriptionInput.value = todo.description || "";

  document.getElementById("formHeading").textContent = "Edit task";
  document.getElementById("submitButton").textContent = "Save changes";
  document.getElementById("cancelButton").classList.remove("hidden");

  titleInput.focus();
}

// Reset the form
function resetForm() {
  editingId = null;
  todoForm.reset();

  document.getElementById("formHeading").textContent = "Create a task";
  document.getElementById("submitButton").textContent = "+ Add task";
  document.getElementById("cancelButton").classList.add("hidden");
}

document.getElementById("cancelButton").addEventListener("click", resetForm);

// Toggle completion
async function toggleTodo(id) {
  try {
    const response = await fetch(`${API_URL}/${id}/complete`, {
      method: "PATCH",
    });

    if (!response.ok) {
      throw new Error("Unable to update task status");
    }

    await loadTodos();
  } catch (error) {
    alert(error.message);
  }
}

// Delete task
async function deleteTodo(id) {
  if (!confirm("Are you sure you want to delete this task?")) {
    return;
  }

  try {
    const response = await fetch(`${API_URL}/${id}`, {
      method: "DELETE",
    });

    if (!response.ok) {
      throw new Error("Unable to delete task");
    }

    if (editingId === id) resetForm();

    await loadTodos();
  } catch (error) {
    alert(error.message);
  }
}

// Filter tasks
document.querySelectorAll(".filter").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll(".filter").forEach((item) => {
      item.classList.remove("active");
    });

    button.classList.add("active");
    currentFilter = button.dataset.filter;

    renderTodos();
  });
});

// Show deployment version
async function loadVersion() {
  try {
    const response = await fetch("/api/version");

    if (response.ok) {
      const data = await response.json();
      document.getElementById("version").textContent =
        `Version: ${data.version}`;
    }
  } catch (error) {
    console.error("Could not load app version:", error);
  }
}

// Initialize application
loadTodos();
loadVersion();
