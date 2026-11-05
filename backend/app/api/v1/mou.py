from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List, Optional, Dict, Any
from datetime import datetime
import uuid

from app.db.session import get_db
from app.models.entities import User, Client
from app.api.deps import get_current_user
from sqlalchemy import text

router = APIRouter(prefix="/mou", tags=["MOU"])

@router.get("/templates", response_model=List[Dict[str, Any]])
async def get_all_mou_templates(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    query = text("SELECT id, version, is_active, updated_at, content FROM public.mou_templates ORDER BY updated_at DESC")
    res = await db.execute(query)
    rows = res.fetchall()
    return [
        {
            "id": str(r[0]),
            "version": r[1],
            "is_active": r[2],
            "updated_at": r[3].isoformat() if r[3] else None,
            "content": r[4] or {},
        }
        for r in rows
    ]

@router.post("/templates", response_model=Dict[str, Any])
async def save_mou_template(
    payload: Dict[str, Any],
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    template_id = payload.get("id")
    version = payload.get("version", "1.0")
    is_active = payload.get("is_active", False)
    content = payload.get("content", {})

    if template_id:
        update_q = text("""
            UPDATE public.mou_templates
            SET version = :version, is_active = :is_active, content = :content, updated_at = now()
            WHERE id = :id
            RETURNING id, version, is_active, updated_at, content
        """)
        res = await db.execute(update_q, {
            "id": template_id,
            "version": version,
            "is_active": is_active,
            "content": content
        })
        row = res.first()
    else:
        insert_q = text("""
            INSERT INTO public.mou_templates (version, is_active, content, updated_at)
            VALUES (:version, :is_active, :content, now())
            RETURNING id, version, is_active, updated_at, content
        """)
        res = await db.execute(insert_q, {
            "version": version,
            "is_active": is_active,
            "content": content
        })
        row = res.first()

    await db.commit()
    return {
        "id": str(row[0]),
        "version": row[1],
        "is_active": row[2],
        "updated_at": row[3].isoformat() if row[3] else None,
        "content": row[4] or {},
    }

@router.post("/templates/{template_id}/publish", response_model=Dict[str, Any])
async def publish_mou_template(
    template_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Deactivate all
    await db.execute(text("UPDATE public.mou_templates SET is_active = false"))
    # Activate target
    res = await db.execute(
        text("UPDATE public.mou_templates SET is_active = true, updated_at = now() WHERE id = :id RETURNING id, version, is_active, updated_at, content"),
        {"id": template_id}
    )
    row = res.first()
    await db.commit()
    if not row:
        raise HTTPException(status_code=404, detail="Template not found")
    return {
        "id": str(row[0]),
        "version": row[1],
        "is_active": row[2],
        "updated_at": row[3].isoformat() if row[3] else None,
        "content": row[4] or {},
    }

@router.get("/templates/active", response_model=Dict[str, Any])
async def get_active_mou_template(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    query = text("SELECT id, version, is_active, updated_at, content FROM public.mou_templates WHERE is_active = true LIMIT 1")
    res = await db.execute(query)
    row = res.first()
    if not row:
        # Fallback to any template
        res_any = await db.execute(text("SELECT id, version, is_active, updated_at, content FROM public.mou_templates LIMIT 1"))
        row = res_any.first()

    if not row:
        # Insert default if completely empty
        default_content = {
            "en": "# Memorandum of Understanding\n\nThis Memorandum of Understanding is entered into by and between the Service Provider and the Client.\n\n1. SCOPE OF SERVICES\nSoftware subscription services including invoicing, expense tracking, and management.\n\n2. TERM\nValid for active subscription duration.\n\n3. DATA PRIVACY\nStrict confidentiality maintained.",
            "hi": "# समझौता ज्ञापन\n\nयह समझौता ज्ञापन सेवा प्रदाता और ग्राहक के बीच निष्पादित किया गया है।"
        }
        ins_q = text("""
            INSERT INTO public.mou_templates (version, is_active, content)
            VALUES ('1.0', true, :content)
            RETURNING id, version, is_active, updated_at, content
        """)
        ins_res = await db.execute(ins_q, {"content": default_content})
        await db.commit()
        row = ins_res.first()

    return {
        "id": str(row[0]),
        "version": row[1],
        "is_active": row[2],
        "updated_at": row[3].isoformat() if row[3] else None,
        "content": row[4] or {},
    }

@router.get("/templates/version/{version}", response_model=Dict[str, Any])
async def get_mou_template_by_version(
    version: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    query = text("SELECT id, version, is_active, updated_at, content FROM public.mou_templates WHERE version = :version LIMIT 1")
    res = await db.execute(query, {"version": version})
    row = res.first()
    if not row:
        return await get_active_mou_template(current_user=current_user, db=db)
    return {
        "id": str(row[0]),
        "version": row[1],
        "is_active": row[2],
        "updated_at": row[3].isoformat() if row[3] else None,
        "content": row[4] or {},
    }

@router.post("/accept", response_model=Dict[str, Any])
async def accept_mou(
    payload: Dict[str, Any],
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    client_id = payload.get("client_id")
    version = payload.get("version", "1.0")
    language = payload.get("language", "en")
    signature = payload.get("signature_data")

    # Find client by client_id or user.tenant_id or user.email
    query = select(Client).where(
        (Client.client_id == client_id) |
        (Client.tenant_id == current_user.tenant_id) |
        (Client.email == current_user.email)
    )
    res = await db.execute(query)
    client = res.scalars().first()
    if not client:
        raise HTTPException(status_code=404, detail="Client record not found")

    mou_meta = {
        "version": version,
        "language": language,
        "signedAt": datetime.utcnow().isoformat(),
        "signature": signature,
    }
    client.mou_accepted = True
    client.mou_meta = mou_meta

    # Also update user mou_accepted
    current_user.mou_accepted = True

    await db.commit()
    await db.refresh(client)

    return {
        "status": "success",
        "message": "MOU accepted successfully",
        "mou_accepted": True,
        "client_id": client.client_id,
        "tenant_id": client.tenant_id,
    }

@router.get("/signature/{client_id}")
async def get_signature(
    client_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    query = select(Client).where(
        (Client.client_id == client_id) |
        (Client.tenant_id == current_user.tenant_id) |
        (Client.email == current_user.email)
    )
    res = await db.execute(query)
    client = res.scalars().first()
    if client and client.mou_meta and "signature" in client.mou_meta:
        return {"signature": client.mou_meta["signature"]}
    return {"signature": None}

