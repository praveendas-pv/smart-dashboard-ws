#!/bin/bash
set -e  # Exit on any error

PROJECT_NAME="smart-dashboard"
PROJECT_NAME_PASCAL="SmartDashboard"
WORKSPACE_ROOT="$(pwd)"

echo "🚀 Starting Hackathon Setup for: $PROJECT_NAME"
echo "📁 Workspace: $WORKSPACE_ROOT"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}==== $1 ====${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# STEP 1: Verify Prerequisites
print_step "STEP 1: Verifying Prerequisites"
git --version
gh --version | head -1
docker --version
python3 --version
swift --version | head -1
print_success "All prerequisites installed"

# STEP 2: Authenticate GitHub CLI
print_step "STEP 2: Checking GitHub Authentication"
if ! gh auth status &> /dev/null; then
    echo "Please authenticate with GitHub..."
    gh auth login
fi
gh auth setup-git
print_success "GitHub CLI authenticated"

# Verify access to ombori-hackathon org
if gh api orgs/ombori-hackathon --silent; then
    print_success "Access to ombori-hackathon org confirmed"
else
    echo "❌ No access to ombori-hackathon org - contact organizer"
    exit 1
fi

# STEP 3: Check Docker is running
print_step "STEP 3: Checking Docker"
if ! docker info &> /dev/null; then
    echo "Starting Docker Desktop..."
    open -a Docker
    echo "Waiting for Docker to start..."
    while ! docker info &> /dev/null; do
        sleep 2
    done
fi
print_success "Docker is running"

# STEP 4: Create workspace structure
print_step "STEP 4: Creating Workspace Structure"
mkdir -p apps/macos-client
mkdir -p services/api
print_success "Workspace structure created"

# STEP 5: Create SwiftUI App
print_step "STEP 5: Creating SwiftUI App"
cd apps/macos-client
swift package init --name ${PROJECT_NAME_PASCAL}Client --type executable

# IMPORTANT: Remove the auto-generated main file FIRST
rm -rf Sources/SmartDashboardClient/
rm -f Sources/main.swift

# Replace Package.swift
cat > Package.swift << 'EOF'
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SmartDashboardClient",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SmartDashboardClient",
            path: "Sources"
        ),
    ]
)
EOF

# Create SmartDashboardApp.swift
cat > Sources/SmartDashboardApp.swift << 'EOF'
import SwiftUI
import AppKit

@main
struct SmartDashboardApp: App {
    init() {
        // Required for swift run to show GUI window
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)
    }
}
EOF

# Create ContentView.swift
cat > Sources/ContentView.swift << 'EOF'
import SwiftUI

struct ContentView: View {
    @State private var items: [Item] = []
    @State private var isLoading = false
    @State private var apiStatus = "Checking..."
    @State private var errorMessage: String?

    private let baseURL = "http://localhost:8000"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("smart-dashboard")
                    .font(.title.bold())
                Spacer()
                Circle()
                    .fill(apiStatus == "healthy" ? .green : .red)
                    .frame(width: 12, height: 12)
                Text(apiStatus)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.bar)

            Divider()

            // Content
            if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(error)
                        .foregroundStyle(.secondary)
                    Text("Start API: cd services/api && uv run fastapi dev")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                ProgressView("Loading items...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ItemsTable(items: items)
            }
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        // Check health
        do {
            let url = URL(string: "\(baseURL)/health")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let health = try JSONDecoder().decode(HealthResponse.self, from: data)
            apiStatus = health.status
        } catch {
            apiStatus = "offline"
            errorMessage = "API not running"
            isLoading = false
            return
        }

        // Fetch items
        do {
            let url = URL(string: "\(baseURL)/items")!
            let (data, _) = try await URLSession.shared.data(from: url)
            items = try JSONDecoder().decode([Item].self, from: data)
        } catch {
            errorMessage = "Failed to load items"
        }

        isLoading = false
    }
}
EOF

# Create ItemsTable.swift
cat > Sources/ItemsTable.swift << 'EOF'
import SwiftUI

struct ItemsTable: View {
    let items: [Item]

    var body: some View {
        Table(items) {
            TableColumn("ID") { item in
                Text("\(item.id)")
                    .monospacedDigit()
            }
            .width(50)

            TableColumn("Name", value: \.name)
                .width(min: 100, ideal: 150)

            TableColumn("Description", value: \.description)

            TableColumn("Price") { item in
                Text(item.price, format: .currency(code: "USD"))
                    .monospacedDigit()
            }
            .width(80)
        }
    }
}
EOF

# Create Models.swift
cat > Sources/Models.swift << 'EOF'
import Foundation

struct Item: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String
    let price: Double
}

struct HealthResponse: Codable {
    let status: String
}
EOF

# Create .gitignore for Swift
cat > .gitignore << 'EOF'
.DS_Store
.build/
.swiftpm/
*.xcodeproj
xcuserdata/
EOF

# Create CLAUDE.md for Swift
cat > CLAUDE.md << 'EOF'
# SmartDashboardClient - SwiftUI App

macOS desktop app that communicates with the FastAPI backend.

## Commands
- Build: `swift build`
- Run: `swift run SmartDashboardClient` (opens GUI window)
- Test: `swift test`

## Architecture
- SwiftUI app with native macOS window
- Entry point: Sources/SmartDashboardApp.swift
- Main view: Sources/ContentView.swift
- Data models: Sources/Models.swift
- Uses async/await with URLSession
- Targets macOS 14+

## API Integration
- Backend runs at http://localhost:8000
- Health check: GET /health
- Sample data: GET /items (returns list of items)

## Adding Features
1. Create new SwiftUI views in Sources/
2. Add new async functions for API calls in views or a dedicated APIClient
2. Use `URLSession.shared.data(from:)` for GET requests
3. Use `URLSession.shared.data(for:)` for POST/PUT with URLRequest
EOF

# Test Swift builds
swift build
print_success "SwiftUI app created"

cd "$WORKSPACE_ROOT"

# STEP 6: Create FastAPI Backend
print_step "STEP 6: Creating FastAPI Backend"
cd services/api

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

uv init --app

# Replace pyproject.toml
cat > pyproject.toml << 'EOF'
[project]
name = "hackathon-api"
version = "0.1.0"
description = "Hackathon FastAPI Backend"
readme = "README.md"
requires-python = ">=3.12"
dependencies = [
    "fastapi[standard]>=0.115.0",
    "sqlalchemy>=2.0.0",
    "alembic>=1.13.0",
    "psycopg2-binary>=2.9.0",
    "pydantic-settings>=2.0.0",
]

[dependency-groups]
dev = [
    "pytest>=8.0.0",
    "pytest-asyncio>=0.23.0",
    "httpx>=0.27.0",
]
EOF

# Create app directory structure
mkdir -p app/routers app/models app/schemas
touch app/__init__.py app/routers/__init__.py app/models/__init__.py app/schemas/__init__.py

# Create app/config.py
cat > app/config.py << 'EOF'
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql://postgres:postgres@localhost:5432/hackathon"
    debug: bool = True

    class Config:
        env_file = ".env"


settings = Settings()
EOF

# Create app/db.py
cat > app/db.py << 'EOF'
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

from app.config import settings

engine = create_engine(settings.database_url)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
EOF

# Create app/models/item.py
cat > app/models/item.py << 'EOF'
from sqlalchemy import Column, Integer, String, Float

from app.db import Base


class Item(Base):
    __tablename__ = "items"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    description = Column(String)
    price = Column(Float, nullable=False)
EOF

# Create app/schemas/item.py
cat > app/schemas/item.py << 'EOF'
from pydantic import BaseModel


class ItemBase(BaseModel):
    name: str
    description: str
    price: float


class ItemCreate(ItemBase):
    pass


class Item(ItemBase):
    id: int

    class Config:
        from_attributes = True
EOF

# Create app/main.py
cat > app/main.py << 'EOF'
from contextlib import asynccontextmanager

from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from app.db import Base, engine, get_db
from app.models.item import Item as ItemModel
from app.schemas.item import Item as ItemSchema


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


@app.get("/")
async def root():
    return {"message": "Hackathon API is running!", "docs": "/docs"}


@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.get("/items", response_model=list[ItemSchema])
async def get_items(db: Session = Depends(get_db)):
    """Get all items from the database"""
    return db.query(ItemModel).all()


@app.get("/items/{item_id}", response_model=ItemSchema)
async def get_item(item_id: int, db: Session = Depends(get_db)):
    """Get a specific item by ID"""
    item = db.query(ItemModel).filter(ItemModel.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item
EOF

# Create .gitignore for Python
cat > .gitignore << 'EOF'
__pycache__/
*.py[cod]
.venv/
.env
*.egg-info/
dist/
build/
.pytest_cache/
.ruff_cache/
uv.lock
EOF

# Create .env.example
cat > .env.example << 'EOF'
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/hackathon
DEBUG=true
EOF

# Create CLAUDE.md for Python submodule
cat > CLAUDE.md << 'EOF'
# Hackathon API - FastAPI Backend

Python FastAPI backend with PostgreSQL database.

## Commands
- Run dev server: `uv run fastapi dev`
- Run tests: `uv run pytest`
- Sync dependencies: `uv sync`
- Add dependency: `uv add <package>`

## Project Structure
```
app/
├── main.py          # FastAPI app entry point
├── config.py        # Pydantic settings
├── db.py            # SQLAlchemy database setup
├── models/          # SQLAlchemy ORM models
├── schemas/         # Pydantic request/response schemas
└── routers/         # API route handlers
```

## Database
- PostgreSQL via Docker Compose
- SQLAlchemy 2.0 ORM
- Connection: postgresql://postgres:postgres@localhost:5432/hackathon

## API Docs
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Adding Features
1. Create model in app/models/
2. Create schemas in app/schemas/
3. Create router in app/routers/
4. Register router in app/main.py
EOF

# Install dependencies and test
uv sync
print_success "FastAPI backend created"

cd "$WORKSPACE_ROOT"

# STEP 7: Create GitHub Repos
print_step "STEP 7: Creating GitHub Repositories"
gh repo create ombori-hackathon/${PROJECT_NAME}-ws --public --description "${PROJECT_NAME} - Terminal Velocity workspace" || true
gh repo create ombori-hackathon/${PROJECT_NAME}-macos --public --description "${PROJECT_NAME} - Swift macOS client" || true
gh repo create ombori-hackathon/${PROJECT_NAME}-api --public --description "${PROJECT_NAME} - FastAPI Python backend" || true
print_success "GitHub repos created"

# STEP 8: Push Swift Project and Convert to Submodule
print_step "STEP 8: Setting up Swift submodule"
cd apps/macos-client
git init
git add .
git commit -m "Initial SwiftUI app setup"
git branch -M main
git remote add origin https://github.com/ombori-hackathon/${PROJECT_NAME}-macos.git
git push -u origin main
cd "$WORKSPACE_ROOT"

rm -rf apps/macos-client
git submodule add https://github.com/ombori-hackathon/${PROJECT_NAME}-macos.git apps/macos-client
print_success "Swift repo pushed and converted to submodule"

# STEP 9: Push Python Project and Convert to Submodule
print_step "STEP 9: Setting up Python submodule"
cd services/api
git init
git add .
git commit -m "Initial FastAPI backend setup"
git branch -M main
git remote add origin https://github.com/ombori-hackathon/${PROJECT_NAME}-api.git
git push -u origin main
cd "$WORKSPACE_ROOT"

rm -rf services/api
git submodule add https://github.com/ombori-hackathon/${PROJECT_NAME}-api.git services/api
print_success "Python repo pushed and converted to submodule"

# STEP 10: Create Docker Compose
print_step "STEP 10: Creating Docker Compose"
cat > docker-compose.yml << 'EOF'
services:
  postgres:
    image: postgres:17
    container_name: hackathon-db
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: hackathon
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
EOF

cat > .env << 'EOF'
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/hackathon
EOF

print_success "Docker Compose created"

# STEP 11: Create Claude Code Agents
print_step "STEP 11: Creating Claude Code Agents"
mkdir -p .claude/agents

cat > .claude/agents/architect.md << 'EOF'
---
name: architect
description: System design and cross-repo planning. Use for API contracts, database schemas, architectural decisions.
tools: Read, Grep, Glob, WebSearch, WebFetch
model: opus
---

# Architect Agent

Senior software architect for hackathon project.

## Your Codebase
- Swift CLI client: apps/macos-client/
- FastAPI backend: services/api/
- PostgreSQL database via Docker
- Specs: specs/

## Responsibilities
1. Design API contracts (OpenAPI spec)
2. Plan database schemas (SQLAlchemy models)
3. Ensure client-server compatibility
4. Document architectural decisions
5. **Update CLAUDE.md and agents** with patterns and learnings

## Output Format
Always output GitHub-compatible markdown specs to `specs/` folder with:
- Clear requirements
- API endpoint definitions
- Data models
- Implementation steps

## Continuous Improvement
After completing features, suggest updates to:
- `CLAUDE.md` - New patterns, conventions discovered
- Agent files - Better instructions based on what worked
- Submodule CLAUDE.md files - Tech-specific learnings
EOF

cat > .claude/agents/swift-coder.md << 'EOF'
---
name: swift-coder
description: Swift client development. Use for implementing features in apps/macos-client/.
model: sonnet
---

# Swift Coder Agent

Swift developer for the macOS SwiftUI app.

## Your Codebase
- Location: apps/macos-client/
- Entry point: Sources/SmartDashboardApp.swift
- Main view: Sources/ContentView.swift
- Models: Sources/Models.swift
- Build: swift build
- Run: swift run SmartDashboardClient

## Patterns
- Use async/await for all network calls
- URLSession for HTTP requests
- Codable for JSON parsing
- Print clear status messages

## When Adding Features
1. Add new async functions for API endpoints
2. Update main() to use new features
3. Test with swift run
EOF

cat > .claude/agents/python-coder.md << 'EOF'
---
name: python-coder
description: FastAPI backend development. Use for implementing features in services/api/.
model: sonnet
---

# Python Coder Agent

FastAPI developer for the backend API.

## Your Codebase
- Location: services/api/
- Entry point: app/main.py
- Run: uv run fastapi dev

## Patterns
- Pydantic schemas for request/response
- SQLAlchemy models for database
- Dependency injection with Depends()
- Async endpoints where beneficial

## When Adding Features
1. Create model in app/models/
2. Create schemas in app/schemas/
3. Create router in app/routers/
4. Register router in main.py
5. Test at /docs
EOF

cat > .claude/agents/reviewer.md << 'EOF'
---
name: reviewer
description: Code review across all repos. Use before committing significant changes.
tools: Read, Grep, Glob
model: sonnet
---

# Code Reviewer Agent

Reviews code for quality, security, and consistency.

## Review Checklist
- [ ] No hardcoded secrets
- [ ] Error handling present
- [ ] Types/schemas defined
- [ ] API contracts match between client/server
- [ ] Database queries are safe (no SQL injection)

## Output Format
Provide structured feedback:
1. **Issues** - Must fix before merge
2. **Suggestions** - Recommended improvements
3. **Approval** - Ready to commit or not
EOF

cat > .claude/agents/debugger.md << 'EOF'
---
name: debugger
description: Debug issues across repos. Use when something isn't working.
model: sonnet
---

# Debugger Agent

Investigates and fixes issues.

## Debugging Steps
1. Reproduce the issue
2. Check logs (docker compose logs, uvicorn output, swift build errors)
3. Trace the code path
4. Identify root cause
5. Propose fix

## Common Issues
- API not running: `uv run fastapi dev`
- Database not running: `docker compose up -d`
- Swift build fails: Check Package.swift dependencies
- Connection refused: Check ports (8000 for API, 5432 for DB)
EOF

cat > .claude/agents/tester.md << 'EOF'
---
name: tester
description: Test-driven development. Use to write and run tests.
model: sonnet
---

# Tester Agent

Writes and runs tests for both repos.

## Python Tests
- Location: services/api/tests/
- Run: `uv run pytest`
- Use httpx for API testing
- Use pytest-asyncio for async tests

## Swift Tests
- Location: apps/macos-client/Tests/
- Run: `swift test`

## TDD Workflow
1. Write failing test first
2. Implement feature
3. Run tests until passing
4. Refactor if needed
EOF

print_success "Claude Code agents created"

# STEP 12: Create Skills
print_step "STEP 12: Creating Skills"
mkdir -p .claude/skills/feature

cat > .claude/skills/feature/SKILL.md << 'EOF'
---
name: feature
description: Build a new feature end-to-end. Asks clarifying questions, creates a spec/PRD, then implements using TDD (tests first). Use this to start any new feature.
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# /feature - New Feature Workflow

Build features using test-driven development with a proper spec.

## Usage

```
/feature <brief description of what you want to build>
```

## Workflow

### Step 1: Understand the Feature

Ask the user these questions (wait for answers before proceeding):

1. **What should this feature do?** (one sentence)
2. **Who/what triggers it?** (user action, API call, scheduled, etc.)
3. **What's the expected output/result?**
4. **Any edge cases to handle?**

### Step 2: Identify Affected Repos

Based on the feature, determine scope:
- **API only** → `services/api/`
- **Swift client only** → `apps/macos-client/`
- **Full stack** → Both repos

### Step 3: Enter Plan Mode

**IMPORTANT: Enter plan mode now using the EnterPlanMode tool.**

In plan mode, create the spec file `specs/YYYY-MM-DD-feature-name.md` with this structure:

```markdown
# Feature: [Name]

## Summary
[One sentence from Step 1]

## Trigger
[From Step 1 question 2]

## Expected Result
[From Step 1 question 3]

## Edge Cases
[From Step 1 question 4]

## Technical Design

### API Changes (if applicable)
- Endpoint: `METHOD /path`
- Request: `{ field: type }`
- Response: `{ field: type }`

### Swift Client Changes (if applicable)
- New struct/function: `name`
- Display: [how it shows to user]

### Database Changes (if applicable)
- New table/columns: [describe]

## Implementation Plan
1. [ ] Write API tests (Red)
2. [ ] Implement API endpoint (Green)
3. [ ] Write Swift tests (Red)
4. [ ] Implement Swift code (Green)
5. [ ] Integration test
6. [ ] Commit and push
```

After writing the spec, use ExitPlanMode to present it for user approval.

**Do not proceed to implementation until the user approves the plan.**

### Step 4: TDD Red Phase - Write Failing Tests

**For API (if applicable):**
1. Create `services/api/tests/test_<feature>.py`
2. Write test for the new endpoint
3. Run `uv run pytest` - confirm it FAILS (Red)

**For Swift (if applicable):**
1. Add test in `apps/macos-client/Tests/`
2. Write test for new functionality
3. Run `swift test` - confirm it FAILS (Red)

### Step 5: TDD Green Phase - Implement

Implement minimum code to make tests pass:

**API:**
1. Add endpoint to `services/api/app/main.py` or create router
2. Run `uv run pytest` - should PASS (Green)

**Swift:**
1. Add code to `apps/macos-client/Sources/`
2. Run `swift test` - should PASS (Green)

### Step 6: Refactor (Optional)

Clean up code while keeping tests green.

### Step 7: Create PR

Ask user: "All tests pass. Ready to create a PR?"

If yes, use `gh` CLI to create PRs (never use GitHub web interface):

```bash
# Create feature branch, commit, and open PR for each repo
cd apps/macos-client
git checkout -b feature/<feature-name>
git add .
git commit -m "feat: <description>"
git push -u origin feature/<feature-name>
gh pr create --title "feat: <description>" --body "Implements <feature>"

cd ../../services/api
git checkout -b feature/<feature-name>
git add .
git commit -m "feat: <description>"
git push -u origin feature/<feature-name>
gh pr create --title "feat: <description>" --body "Implements <feature>"
```

Update spec with PR links and completion status.
EOF

print_success "Skills created"

# STEP 13: Create Specs Directory
print_step "STEP 13: Creating Specs Directory"
mkdir -p specs

cat > specs/README.md << 'EOF'
# Feature Specifications

All feature specs live here. Created via plan mode before implementation.

## Naming Convention
`YYYY-MM-DD-feature-name.md`

## Template
See `specs/_template.md`
EOF

cat > specs/_template.md << 'EOF'
# Feature: [Name]

## Summary
Brief description of the feature.

## API Changes
- `POST /endpoint` - Description

## Database Changes
- New table: `table_name`
- New columns: `column_name`

## Swift Client Changes
- New function: `fetchSomething()`

## Implementation Steps
1. [ ] Step 1
2. [ ] Step 2

## Tests
- [ ] API test: description
- [ ] Client test: description
EOF

print_success "Specs directory created"

# STEP 14: Create Workspace CLAUDE.md
print_step "STEP 14: Creating Workspace CLAUDE.md"
cat > CLAUDE.md << 'EOF'
# Hackathon Workspace

Multi-repo workspace for Ombori hackathon.

## Key Rules

1. **Plan-mode-first**: ALL features start with spec creation in `specs/` folder
2. **TDD where applicable**: Write tests before implementation
3. **Specs in workspace**: All specs centralized in `specs/` folder
4. **Evolve the config**: Update CLAUDE.md and agents with learnings as you build

## Continuous Improvement

As you build, update these files with learnings:
- `CLAUDE.md` - Add new patterns, gotchas, project-specific conventions
- `.claude/agents/*.md` - Refine agent instructions based on what works
- `apps/macos-client/CLAUDE.md` - Swift-specific learnings
- `services/api/CLAUDE.md` - Python/FastAPI-specific learnings

Examples of things to capture:
- "Always use X pattern for Y"
- "Don't forget to run Z after changing W"
- "API endpoint naming follows this convention..."
- "Database migrations require this step..."

## Quick Start

```bash
# Start database
docker compose up -d

# Run API (in new terminal)
cd services/api && uv run fastapi dev

# Run Swift client (in new terminal)
cd apps/macos-client && swift run SmartDashboardClient
```

## Structure
- `apps/macos-client/` - SwiftUI desktop app (submodule)
- `services/api/` - FastAPI Python backend (submodule)
- `specs/` - Feature specifications (plan-mode output)
- `docker-compose.yml` - PostgreSQL database

## Skills (Commands)
Available in `.claude/skills/`:
- `/feature` - **Start here!** Asks questions → creates spec → TDD implementation

## Agents
Available in `.claude/agents/`:
- `/architect` - System design, API contracts → outputs to `specs/`
- `/swift-coder` - Swift client development
- `/python-coder` - FastAPI backend development
- `/reviewer` - Code review across all repos
- `/debugger` - Issue investigation
- `/tester` - Test-driven development

## Development Workflow

### New Features (MANDATORY)
1. **Plan mode first** - Create spec in `specs/YYYY-MM-DD-feature-name.md`
2. **Write tests** - TDD: tests before implementation
3. **Implement** - Use coder agents (can run in parallel)
4. **Review** - Use reviewer agent
5. **Commit** - Submodules first, then workspace

### Git Workflow (use `gh` CLI, not GitHub web)
Always use feature branches and `gh pr create`:
```bash
# In each submodule
git checkout -b feature/<name>
git add . && git commit -m "feat: ..."
git push -u origin feature/<name>
gh pr create --title "feat: ..." --body "Description"

# After PRs merged, update workspace
cd ../..
git add . && git commit -m "Update submodules"
git push
```

## API Reference
- Swagger: http://localhost:8000/docs
- Health: http://localhost:8000/health
- Items: http://localhost:8000/items (from database)
EOF

print_success "Workspace CLAUDE.md created"

# STEP 15: Initialize and Push Workspace
print_step "STEP 15: Initializing Workspace Repository"
git init
git add .
git commit -m "Initial workspace setup with submodules"
git branch -M main
git remote add origin https://github.com/ombori-hackathon/${PROJECT_NAME}-ws.git
git push -u origin main
print_success "Workspace repository initialized and pushed"

# STEP 16: Verify Everything Works
print_step "STEP 16: Verifying Setup"
git submodule status
docker compose up -d
sleep 5
docker compose ps

echo ""
echo "🎉 Setup Complete!"
echo ""
echo "Your hackathon workspace is ready:"
echo "  ✅ 3 GitHub repos created and linked"
echo "  ✅ SwiftUI app ready to run"
echo "  ✅ FastAPI backend ready to run"
echo "  ✅ PostgreSQL database via Docker"
echo "  ✅ Claude Code agents and skills configured"
echo ""
echo "📋 Next Steps:"
echo "  1. Start database: docker compose up -d"
echo "  2. Run API: cd services/api && uv run fastapi dev"
echo "  3. Run Swift client: cd apps/macos-client && swift run SmartDashboardClient"
echo ""
echo "🚀 Ready to start building with Claude Code!"
echo "   Use /feature to start your first feature"
echo ""
