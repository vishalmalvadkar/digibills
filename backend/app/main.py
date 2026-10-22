import asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.core.config import settings
from app.db.session import engine, Base
import app.models.entities # Register all models with Base
from app.core.websockets import manager

# Import routers
from app.api.v1.auth import router as auth_router
from app.api.v1.bills import router as bills_router
from app.api.v1.products import router as products_router
from app.api.v1.clients import router as clients_router
from app.api.v1.expenses import router as expenses_router
from app.api.v1.settings import router as settings_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Automatically create tables in local PostgreSQL if they don't exist
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Backend REST API & WebSockets for DigiBills local PostgreSQL deployment.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan
)

# CORS setup for Flutter web and mobile
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API v1 Routers
app.include_router(auth_router, prefix=settings.API_V1_STR)
app.include_router(bills_router, prefix=settings.API_V1_STR)
app.include_router(products_router, prefix=settings.API_V1_STR)
app.include_router(clients_router, prefix=settings.API_V1_STR)
app.include_router(expenses_router, prefix=settings.API_V1_STR)
app.include_router(settings_router, prefix=settings.API_V1_STR)

# Realtime WebSocket Endpoint
@app.websocket("/ws/{tenant_id}")
async def websocket_endpoint(websocket: WebSocket, tenant_id: str):
    await manager.connect(websocket, tenant_id)
    try:
        while True:
            # Keep connection open and listen for any client heartbeats or pings
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        manager.disconnect(websocket, tenant_id)
    except Exception:
        manager.disconnect(websocket, tenant_id)

# Supabase Compatibility Layer (Rest & Realtime WebSocket)
# Allows legacy Supabase Flutter client to talk to the local FastAPI backend seamlessly without net::ERR_NAME_NOT_RESOLVED
@app.get("/rest/v1/platform_config")
async def get_platform_config():
    return [{
        "id": 1,
        "maintenance_mode": False,
        "announcement_type": "info",
        "maintenance_message": "System running normally on local backend.",
        "min_app_version": "1.0.0",
        "updated_at": "2026-10-22T00:00:00"
    }]

@app.api_route("/rest/v1/{table_name}", methods=["GET", "POST", "PATCH", "PUT", "DELETE"])
async def get_supabase_rest_compat(table_name: str):
    # Returns empty list or single object for notifications, calendar_events, users, etc.
    return []

@app.websocket("/realtime/v1/websocket")
async def supabase_realtime_websocket(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            # Handle Phoenix channel protocol heartbeat/messages from realtime_client
            msg = await websocket.receive_text()
            if "heartbeat" in msg:
                await websocket.send_text('{"event":"phx_reply","payload":{"response":{},"status":"ok"},"ref":"heartbeat","topic":"phoenix"}')
    except WebSocketDisconnect:
        pass
    except Exception:
        pass

@app.get("/")
def read_root():
    return {
        "app": settings.PROJECT_NAME,
        "status": "online",
        "docs": "/docs",
        "realtime_ws": "/ws/{tenant_id}",
        "supabase_compat": True
    }

