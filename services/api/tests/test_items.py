from app.models.item import Item


def test_get_items_empty(client):
    """Test GET /items returns empty list when no items exist"""
    response = client.get("/items")
    assert response.status_code == 200
    assert response.json() == []


def test_get_items_with_data(client, db_session):
    """Test GET /items returns list of items"""
    item = Item(name="Widget", description="A useful widget", price=9.99)
    db_session.add(item)
    db_session.commit()

    response = client.get("/items")
    assert response.status_code == 200

    items = response.json()
    assert len(items) == 1
    assert items[0]["name"] == "Widget"
    assert items[0]["description"] == "A useful widget"
    assert items[0]["price"] == 9.99
    assert "id" in items[0]


def test_get_item_by_id(client, db_session):
    """Test GET /items/{id} returns a specific item"""
    item = Item(name="Gadget", description="A fancy gadget", price=19.99)
    db_session.add(item)
    db_session.commit()
    db_session.refresh(item)

    response = client.get(f"/items/{item.id}")
    assert response.status_code == 200

    data = response.json()
    assert data["name"] == "Gadget"
    assert data["id"] == item.id


def test_get_item_not_found(client):
    """Test GET /items/{id} returns 404 for non-existent item"""
    response = client.get("/items/999")
    assert response.status_code == 404


def test_delete_item(client, db_session):
    """Test DELETE /items/{id} removes an item"""
    item = Item(name="ToDelete", description="Will be deleted", price=5.00)
    db_session.add(item)
    db_session.commit()
    db_session.refresh(item)

    response = client.delete(f"/items/{item.id}")
    assert response.status_code == 204

    # Verify it's gone
    response = client.get(f"/items/{item.id}")
    assert response.status_code == 404


def test_delete_item_not_found(client):
    """Test DELETE /items/{id} returns 404 for non-existent item"""
    response = client.delete("/items/999")
    assert response.status_code == 404


def test_update_item(client, db_session):
    """Test PATCH /items/{id} updates an item with partial fields"""
    item = Item(name="Original", description="Original desc", price=10.00)
    db_session.add(item)
    db_session.commit()
    db_session.refresh(item)

    response = client.patch(f"/items/{item.id}", json={"name": "Updated", "price": 25.50})
    assert response.status_code == 200

    data = response.json()
    assert data["name"] == "Updated"
    assert data["description"] == "Original desc"
    assert data["price"] == 25.50


def test_update_item_not_found(client):
    """Test PATCH /items/{id} returns 404 for non-existent item"""
    response = client.patch("/items/999", json={"name": "Nope"})
    assert response.status_code == 404
