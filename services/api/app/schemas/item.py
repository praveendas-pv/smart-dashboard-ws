from pydantic import BaseModel


class ItemBase(BaseModel):
    name: str
    description: str
    price: float


class ItemCreate(ItemBase):
    pass


class ItemUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    price: float | None = None


class Item(ItemBase):
    id: int

    class Config:
        from_attributes = True
