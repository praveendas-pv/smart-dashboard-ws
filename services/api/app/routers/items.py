from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.item import Item as ItemModel
from app.schemas.item import Item as ItemSchema

router = APIRouter(prefix="/items", tags=["items"])


@router.get("", response_model=list[ItemSchema])
async def get_items(db: Session = Depends(get_db)):
    """Get all items from the database"""
    return db.query(ItemModel).all()


@router.get("/{item_id}", response_model=ItemSchema)
async def get_item(item_id: int, db: Session = Depends(get_db)):
    """Get a specific item by ID"""
    item = db.query(ItemModel).filter(ItemModel.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item


@router.delete("/{item_id}", status_code=204)
async def delete_item(item_id: int, db: Session = Depends(get_db)):
    """Delete an item"""
    item = db.query(ItemModel).filter(ItemModel.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    db.delete(item)
    db.commit()
