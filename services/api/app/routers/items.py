from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.item import Item as ItemModel
from app.schemas.item import Item as ItemSchema, ItemCreate, ItemUpdate

router = APIRouter(prefix="/items", tags=["items"])


@router.get("", response_model=list[ItemSchema])
async def get_items(db: Session = Depends(get_db)):
    """Get all items from the database"""
    return db.query(ItemModel).all()


@router.post("", response_model=ItemSchema, status_code=201)
async def create_item(item: ItemCreate, db: Session = Depends(get_db)):
    """Create a new item"""
    db_item = ItemModel(**item.model_dump())
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item


@router.get("/{item_id}", response_model=ItemSchema)
async def get_item(item_id: int, db: Session = Depends(get_db)):
    """Get a specific item by ID"""
    item = db.query(ItemModel).filter(ItemModel.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item


@router.patch("/{item_id}", response_model=ItemSchema)
async def update_item(item_id: int, item_update: ItemUpdate, db: Session = Depends(get_db)):
    """Update an item"""
    item = db.query(ItemModel).filter(ItemModel.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    update_data = item_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(item, field, value)

    db.commit()
    db.refresh(item)
    return item


@router.delete("/{item_id}", status_code=204)
async def delete_item(item_id: int, db: Session = Depends(get_db)):
    """Delete an item"""
    item = db.query(ItemModel).filter(ItemModel.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    db.delete(item)
    db.commit()
