from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from app.db import Base, engine, get_db
from app.models.item import Item as ItemModel
from app.models.task import Task as TaskModel
from app.routers import items, tasks


def seed_database(db: Session):
    """Seed the database with sample items if empty"""
    if db.query(ItemModel).count() == 0:
        sample_items = [
            ItemModel(name="Widget", description="A useful widget for your desk", price=9.99),
            ItemModel(name="Gadget", description="A fancy gadget with buttons", price=19.99),
            ItemModel(name="Gizmo", description="An amazing gizmo that does things", price=29.99),
        ]
        db.add_all(sample_items)
        db.commit()
        print("Database seeded with sample items")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: create tables and seed data
    Base.metadata.create_all(bind=engine)
    db = next(get_db())
    seed_database(db)
    db.close()
    yield
    # Shutdown: cleanup if needed


app = FastAPI(
    title="Hackathon API",
    description="Backend API for Ombori Hackathon",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(items.router)
app.include_router(tasks.router)


@app.get("/")
async def root():
    return {"message": "Hackathon API is running!", "docs": "/docs"}


@app.get("/health")
async def health():
    return {"status": "healthy"}

