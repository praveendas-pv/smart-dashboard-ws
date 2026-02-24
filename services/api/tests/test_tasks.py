from app.models.task import Task


def test_get_tasks_empty(client):
    """Test GET /tasks returns empty list when no tasks exist"""
    response = client.get("/tasks")
    assert response.status_code == 200
    assert response.json() == []


def test_get_tasks_with_data(client, db_session):
    """Test GET /tasks returns list of tasks"""
    task = Task(title="Test Task", description="A test task")
    db_session.add(task)
    db_session.commit()

    response = client.get("/tasks")
    assert response.status_code == 200

    tasks = response.json()
    assert len(tasks) == 1
    assert tasks[0]["title"] == "Test Task"
    assert tasks[0]["description"] == "A test task"
    assert tasks[0]["completed"] is False
    assert "id" in tasks[0]
    assert "created_at" in tasks[0]


def test_get_tasks_multiple(client, db_session):
    """Test GET /tasks returns multiple tasks"""
    task1 = Task(title="Task 1", description="First task")
    task2 = Task(title="Task 2", description="Second task", completed=True)
    db_session.add_all([task1, task2])
    db_session.commit()

    response = client.get("/tasks")
    assert response.status_code == 200

    tasks = response.json()
    assert len(tasks) == 2


def test_task_response_fields(client, db_session):
    """Test that task response contains all required fields"""
    task = Task(title="Field Test", description="Testing fields")
    db_session.add(task)
    db_session.commit()

    response = client.get("/tasks")
    task_data = response.json()[0]

    assert "id" in task_data
    assert "title" in task_data
    assert "description" in task_data
    assert "completed" in task_data
    assert "created_at" in task_data
    assert "updated_at" in task_data


def test_delete_task(client, db_session):
    """Test DELETE /tasks/{id} removes a task"""
    task = Task(title="To Delete", description="Will be deleted")
    db_session.add(task)
    db_session.commit()
    db_session.refresh(task)

    response = client.delete(f"/tasks/{task.id}")
    assert response.status_code == 204

    # Verify it's gone
    response = client.get(f"/tasks/{task.id}")
    assert response.status_code == 404


def test_delete_task_not_found(client):
    """Test DELETE /tasks/{id} returns 404 for non-existent task"""
    response = client.delete("/tasks/999")
    assert response.status_code == 404
