from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List
import uuid

from app.db.session import get_db
from app.models.entities import Client, User
from app.schemas.schemas import ClientCreate, ClientUpdate
from app.api.deps import get_current_user
from app.core.websockets import manager

router = APIRouter(prefix="/clients", tags=["Clients"])

@router.get("", response_model=List[dict])
async def get_clients(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Client).where(Client.tenant_id == current_user.tenant_id).order_by(Client.business_name.asc())
    )
    clients = result.scalars().all()
    return [
        {
            "client_id": c.client_id,
            "tenant_id": c.tenant_id,
            "business_name": c.business_name,
            "owner_name": c.owner_name,
            "email": c.email,
            "whatsapp_number": c.whatsapp_number,
            "state": c.state,
            "gst_number": c.gst_number,
            "status": c.status,
            "license": c.license,
            "mou_accepted": c.mou_accepted,
            "mou_meta": c.mou_meta,
            "amount": c.amount,
            "payment_mode": c.payment_mode,
            "payment_status": c.payment_status,
            "tax_percentage": c.tax_percentage,
            "created_at": c.created_at.isoformat() if c.created_at else None,
        }
        for c in clients
    ]

@router.post("", response_model=dict)
async def create_client(
    client_in: ClientCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    c_data = client_in.model_dump()
    client_id = str(uuid.uuid4())
    c_data["client_id"] = client_id
    c_data["tenant_id"] = current_user.tenant_id

    client = Client(**c_data)
    db.add(client)
    await db.commit()
    await db.refresh(client)

    res = {
        "client_id": client.client_id,
        "tenant_id": client.tenant_id,
        "business_name": client.business_name,
        "owner_name": client.owner_name,
        "email": client.email,
        "whatsapp_number": client.whatsapp_number,
        "state": client.state,
        "gst_number": client.gst_number,
        "status": client.status,
        "license": client.license,
        "mou_accepted": client.mou_accepted,
        "mou_meta": client.mou_meta,
        "amount": client.amount,
        "payment_mode": client.payment_mode,
        "payment_status": client.payment_status,
        "tax_percentage": client.tax_percentage,
        "created_at": client.created_at.isoformat() if client.created_at else None,
    }

    await manager.broadcast_to_tenant(
        current_user.tenant_id,
        {"table": "clients", "action": "INSERT", "data": res}
    )

    return res

@router.put("/{client_id}", response_model=dict)
async def update_client(
    client_id: str,
    client_in: ClientUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Client).where(Client.client_id == client_id, Client.tenant_id == current_user.tenant_id)
    )
    client = result.scalars().first()
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")

    for field, value in client_in.model_dump(exclude_unset=True).items():
        setattr(client, field, value)

    await db.commit()
    await db.refresh(client)

    res = {
        "client_id": client.client_id,
        "tenant_id": client.tenant_id,
        "business_name": client.business_name,
        "owner_name": client.owner_name,
        "email": client.email,
        "whatsapp_number": client.whatsapp_number,
        "state": client.state,
        "gst_number": client.gst_number,
        "status": client.status,
        "license": client.license,
        "mou_accepted": client.mou_accepted,
        "mou_meta": client.mou_meta,
        "amount": client.amount,
        "payment_mode": client.payment_mode,
        "payment_status": client.payment_status,
        "tax_percentage": client.tax_percentage,
        "created_at": client.created_at.isoformat() if client.created_at else None,
    }

    await manager.broadcast_to_tenant(
        current_user.tenant_id,
        {"table": "clients", "action": "UPDATE", "data": res}
    )

    return res

@router.delete("/{client_id}")
async def delete_client(
    client_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Client).where(Client.client_id == client_id, Client.tenant_id == current_user.tenant_id)
    )
    client = result.scalars().first()
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")

    await db.delete(client)
    await db.commit()

    await manager.broadcast_to_tenant(
        current_user.tenant_id,
        {"table": "clients", "action": "DELETE", "data": {"client_id": client_id}}
    )

    return {"message": "Client deleted successfully"}
