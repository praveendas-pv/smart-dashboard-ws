# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Full-stack macOS desktop application with SwiftUI client and FastAPI Python backend. Multi-repo structure using Git submodules.

## Build & Run Commands

### Full Stack Quick Start
```bash
# Terminal 1: Start database
docker compose up -d

# Terminal 2: Start API server
cd services/api && uv run fastapi dev

# Terminal 3: Run macOS client
cd apps/macos-client && swift run SmartDashboardClient
```

### SwiftUI Client (`apps/macos-client/`)
- Build: `swift build`
- Run: `swift run SmartDashboardClient`
- Test: `swift test`

### FastAPI Backend (`services/api/`)
- Run dev server: `uv run fastapi dev`
- Run tests: `uv run pytest`
- Sync dependencies: `uv sync`
- Add dependency: `uv add <package>`

### Database
- Start: `docker compose up -d`
- Stop: `docker compose down`
- Connection: `postgresql://postgres:postgres@localhost:5432/hackathon`

## Architecture

### Repository Structure
- `apps/macos-client/` - SwiftUI macOS client (submodule)
- `services/api/` - FastAPI Python backend (submodule)
- `docker-compose.yml` - PostgreSQL database service
- `.claude/agents/` - Claude Code agent definitions

### API Contract
Base URL: `http://localhost:8000`

| Endpoint | Method | Response |
|----------|--------|----------|
| `/health` | GET | `{"status": "healthy"}` |
| `/items` | GET | `[Item]` |
| `/items/{id}` | GET | `Item` or 404 |
| `/docs` | GET | Swagger UI |

### Data Models
Both client and server share the same Item structure:
- `id: Int`
- `name: String`
- `description: String`
- `price: Double/Float`

### Client-Server Integration
- SwiftUI uses async/await with URLSession for HTTP requests
- Backend auto-seeds 3 sample items on first startup
- CORS enabled for all origins (development only)

## Key Patterns

### Swift
- App requires `NSApplication.shared.setActivationPolicy(.regular)` for GUI window with `swift run`
- Use `URLSession.shared.data(from:)` for GET, `URLSession.shared.data(for:)` for POST/PUT
- Models use Codable + Identifiable protocols

### Python
- SQLAlchemy 2.0 ORM with Pydantic schemas
- FastAPI lifespan context manager for startup/shutdown
- Dependency injection via `Depends(get_db)` for database sessions

## Adding Features

### New API Endpoint
1. Create model in `services/api/app/models/`
2. Create schemas in `services/api/app/schemas/`
3. Create router in `services/api/app/routers/`
4. Register router in `services/api/app/main.py`

### New Client Feature
1. Add data model in `apps/macos-client/Sources/Models.swift`
2. Create SwiftUI view in `apps/macos-client/Sources/`
3. Add async API call function
