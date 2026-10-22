import json
from typing import Dict, List
from fastapi import WebSocket

class ConnectionManager:
    def __init__(self):
        # Map: tenant_id -> List[WebSocket]
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, tenant_id: str):
        await websocket.accept()
        if tenant_id not in self.active_connections:
            self.active_connections[tenant_id] = []
        self.active_connections[tenant_id].append(websocket)

    def disconnect(self, websocket: WebSocket, tenant_id: str):
        if tenant_id in self.active_connections:
            if websocket in self.active_connections[tenant_id]:
                self.active_connections[tenant_id].remove(websocket)
            if not self.active_connections[tenant_id]:
                del self.active_connections[tenant_id]

    async def broadcast_to_tenant(self, tenant_id: str, message: dict):
        """
        Broadcasts event:
        {
           "table": "bills" | "products" | "clients" | ...,
           "action": "INSERT" | "UPDATE" | "DELETE",
           "data": {...}
        }
        """
        if tenant_id in self.active_connections:
            text_data = json.dumps(message)
            for connection in list(self.active_connections[tenant_id]):
                try:
                    await connection.send_text(text_data)
                except Exception:
                    self.disconnect(connection, tenant_id)

manager = ConnectionManager()
