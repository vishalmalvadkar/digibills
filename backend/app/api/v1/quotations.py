from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List, Optional, Dict, Any
from datetime import datetime
import uuid

from app.db.session import get_db
from app.models.entities import Quotation, User
from app.api.deps import get_current_user
from app.core.websockets import manager

router = APIRouter(prefix="/quotations", tags=["Quotations"])

def quote_to_dict(q: Quotation) -> Dict[str, Any]:
    return {
        "quote_id": q.quote_id,
        "tenant_id": q.tenant_id,
        "quote_number": q.quote_number,
        "customer_name": q.customer_name,
        "client_id": q.client_id or "",
        "customer_phone": q.customer_phone or "",
        "whatsapp_number": q.whatsapp_number or q.customer_phone or "",
        "customer_email": q.customer_email or "",
        "date": q.quote_date.isoformat() if q.quote_date else (q.created_at.isoformat() if q.created_at else None),
        "quote_date": q.quote_date.isoformat() if q.quote_date else None,
        "expiry_date": q.valid_until.isoformat() if q.valid_until else None,
        "valid_until": q.valid_until.isoformat() if q.valid_until else None,
        "items": q.items or [],
        "subtotal": q.subtotal,
        "tax_percentage": q.tax_percentage if q.tax_percentage else q.tax_rate,
        "tax_rate": q.tax_rate,
        "tax_amount": q.tax_amount,
        "total_amount": q.total_amount,
        "status": q.status or "Draft",
        "notes": q.notes or "",
        "terms_and_conditions": q.terms_and_conditions or "",
        "doc_type": q.doc_type or "Quote",
        "created_by": q.created_by,
        "place_of_supply": q.place_of_supply or "",
        "shipping_address": q.shipping_address,
        "shipping_name": q.shipping_name,
        "created_at": q.created_at.isoformat() if q.created_at else None,
    }

@router.get("", response_model=List[Dict[str, Any]])
async def get_quotations(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Quotation).where(Quotation.tenant_id == current_user.tenant_id).order_by(Quotation.quote_date.desc(), Quotation.created_at.desc())
    )
    quotes = result.scalars().all()
    return [quote_to_dict(q) for q in quotes]

@router.get("/{quote_id}", response_model=Dict[str, Any])
async def get_quotation_by_id(
    quote_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Quotation).where(Quotation.quote_id == quote_id, Quotation.tenant_id == current_user.tenant_id)
    )
    quote = result.scalars().first()
    if not quote:
        raise HTTPException(status_code=404, detail="Quotation not found")
    return quote_to_dict(quote)

@router.post("", response_model=Dict[str, Any])
async def create_quotation(
    quote_data: Dict[str, Any],
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    try:
        quote_id = quote_data.get("quote_id") or str(uuid.uuid4())
        
        quote_date_raw = quote_data.get("date") or quote_data.get("quote_date")
        valid_until_raw = quote_data.get("expiry_date") or quote_data.get("valid_until")

        def parse_dt(val):
            if not val or not isinstance(val, str):
                return None
            val_clean = val.replace("Z", "+00:00")
            try:
                dt = datetime.fromisoformat(val_clean)
                return dt.replace(tzinfo=None)
            except Exception:
                return None

        quote_date = parse_dt(quote_date_raw) or datetime.utcnow()
        valid_until = parse_dt(valid_until_raw)

        new_quote = Quotation(
            quote_id=quote_id,
            tenant_id=current_user.tenant_id,
            quote_number=quote_data.get("quote_number", "QT-00001"),
            customer_name=quote_data.get("customer_name", ""),
            client_id=quote_data.get("client_id", ""),
            customer_phone=quote_data.get("whatsapp_number") or quote_data.get("customer_phone", ""),
            whatsapp_number=quote_data.get("whatsapp_number", ""),
            customer_email=quote_data.get("customer_email", ""),
            quote_date=quote_date,
            valid_until=valid_until,
            items=quote_data.get("items", []),
            subtotal=float(quote_data.get("subtotal", 0.0)),
            tax_percentage=float(quote_data.get("tax_percentage", 0.0)),
            tax_rate=float(quote_data.get("tax_percentage", 0.0)),
            tax_amount=float(quote_data.get("tax_amount", 0.0)),
            total_amount=float(quote_data.get("total_amount", 0.0)),
            status=quote_data.get("status", "Draft"),
            terms_and_conditions=quote_data.get("terms_and_conditions"),
            notes=quote_data.get("notes", ""),
            doc_type=quote_data.get("doc_type", "Quote"),
            created_by=current_user.uid,
            place_of_supply=quote_data.get("place_of_supply", ""),
            shipping_address=quote_data.get("shipping_address"),
            shipping_name=quote_data.get("shipping_name"),
        )

        db.add(new_quote)
        await db.commit()
        await db.refresh(new_quote)

        resp = quote_to_dict(new_quote)
        await manager.broadcast_to_tenant(
            current_user.tenant_id,
            {"table": "quotations", "action": "INSERT", "data": resp}
        )
        return resp
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=400, detail=f"Failed to create quotation: {str(e)}")

@router.put("/{quote_id}", response_model=Dict[str, Any])
async def update_quotation(
    quote_id: str,
    update_data: Dict[str, Any],
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Quotation).where(Quotation.quote_id == quote_id, Quotation.tenant_id == current_user.tenant_id)
    )
    quote = result.scalars().first()
    if not quote:
        raise HTTPException(status_code=404, detail="Quotation not found")

    for k, v in update_data.items():
        if k == "date" or k == "quote_date":
            quote.quote_date = datetime.fromisoformat(v) if isinstance(v, str) else v
        elif k == "expiry_date" or k == "valid_until":
            quote.valid_until = datetime.fromisoformat(v) if isinstance(v, str) else v
        elif hasattr(quote, k):
            setattr(quote, k, v)

    await db.commit()
    await db.refresh(quote)

    resp = quote_to_dict(quote)
    await manager.broadcast_to_tenant(
        current_user.tenant_id,
        {"table": "quotations", "action": "UPDATE", "data": resp}
    )
    return resp

@router.delete("/{quote_id}")
async def delete_quotation(
    quote_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Quotation).where(Quotation.quote_id == quote_id, Quotation.tenant_id == current_user.tenant_id)
    )
    quote = result.scalars().first()
    if not quote:
        raise HTTPException(status_code=404, detail="Quotation not found")

    await db.delete(quote)
    await db.commit()

    await manager.broadcast_to_tenant(
        current_user.tenant_id,
        {"table": "quotations", "action": "DELETE", "data": {"quote_id": quote_id}}
    )
    return {"message": "Quotation deleted successfully"}
