from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List, Optional
from datetime import datetime
import uuid

from app.db.session import get_db
from app.models.entities import Bill, SequenceCounter
from app.schemas.schemas import BillCreate, BillUpdate
from app.api.deps import get_current_user
from app.models.entities import User
from app.core.websockets import manager

router = APIRouter(prefix="/bills", tags=["Bills"])

@router.get("", response_model=List[dict])
async def get_bills(
    client_id: Optional[str] = Query(None),
    created_by: Optional[str] = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    query = select(Bill).where(Bill.tenant_id == current_user.tenant_id)
    if client_id:
        query = query.where(Bill.client_id == client_id)
    if created_by:
        query = query.where(Bill.created_by == created_by)
    
    query = query.order_by(Bill.bill_date.desc(), Bill.created_at.desc())
    result = await db.execute(query)
    bills = result.scalars().all()
    
    # Return as list of dicts formatted matching Flutter BillModel
    return [
        {
            "bill_id": b.bill_id,
            "tenant_id": b.tenant_id,
            "invoice_number": b.invoice_number,
            "customer_name": b.customer_name,
            "client_id": b.client_id,
            "service_name": b.service_name,
            "bill_date": b.bill_date.isoformat() if b.bill_date else None,
            "price": b.price,
            "tax_percentage": b.tax_percentage,
            "tax_amount": b.tax_amount,
            "cgst_amount": b.cgst_amount,
            "sgst_amount": b.sgst_amount,
            "igst_amount": b.igst_amount,
            "place_of_supply": b.place_of_supply,
            "advance_amount": b.advance_amount,
            "total_amount": b.total_amount,
            "payment_status": b.payment_status,
            "payment_received_date": b.payment_received_date.isoformat() if b.payment_received_date else None,
            "whatsapp_number": b.whatsapp_number,
            "client_address": b.client_address,
            "gst_number": b.gst_number,
            "items": b.items,
            "payments": b.payments,
            "created_by": b.created_by,
            "created_at": b.created_at.isoformat() if b.created_at else None,
        }
        for b in bills
    ]

@router.post("", response_model=dict)
async def create_bill(
    bill_in: BillCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    bill_data = bill_in.model_dump()
    bill_id = str(uuid.uuid4())
    bill_data["bill_id"] = bill_id
    bill_data["tenant_id"] = current_user.tenant_id
    
    # Transform items & payments to dicts with serializable dates
    bill_data["items"] = [item if isinstance(item, dict) else item.model_dump() for item in bill_in.items]
    
    payments_list = []
    for p in bill_in.payments:
        p_dict = p if isinstance(p, dict) else p.model_dump()
        if isinstance(p_dict.get("date"), datetime):
            p_dict["date"] = p_dict["date"].isoformat()
        payments_list.append(p_dict)
    bill_data["payments"] = payments_list

    new_bill = Bill(**bill_data)
    db.add(new_bill)
    await db.commit()
    await db.refresh(new_bill)

    response_dict = {
        "bill_id": new_bill.bill_id,
        "tenant_id": new_bill.tenant_id,
        "invoice_number": new_bill.invoice_number,
        "customer_name": new_bill.customer_name,
        "client_id": new_bill.client_id,
        "service_name": new_bill.service_name,
        "bill_date": new_bill.bill_date.isoformat() if new_bill.bill_date else None,
        "price": new_bill.price,
        "tax_percentage": new_bill.tax_percentage,
        "tax_amount": new_bill.tax_amount,
        "cgst_amount": new_bill.cgst_amount,
        "sgst_amount": new_bill.sgst_amount,
        "igst_amount": new_bill.igst_amount,
        "place_of_supply": new_bill.place_of_supply,
        "advance_amount": new_bill.advance_amount,
        "total_amount": new_bill.total_amount,
        "payment_status": new_bill.payment_status,
        "payment_received_date": new_bill.payment_received_date.isoformat() if new_bill.payment_received_date else None,
        "whatsapp_number": new_bill.whatsapp_number,
        "client_address": new_bill.client_address,
        "gst_number": new_bill.gst_number,
        "items": new_bill.items,
        "payments": new_bill.payments,
        "created_by": new_bill.created_by,
        "created_at": new_bill.created_at.isoformat() if new_bill.created_at else None,
    }

    # Real-time WebSocket Broadcast
    await manager.broadcast_to_tenant(
        current_user.tenant_id,
        {"table": "bills", "action": "INSERT", "data": response_dict}
    )

    return response_dict

@router.put("/{bill_id}", response_model=dict)
async def update_bill(
    bill_id: str,
    bill_in: BillUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Bill).where(Bill.bill_id == bill_id, Bill.tenant_id == current_user.tenant_id)
    )
    bill = result.scalars().first()
    if not bill:
        raise HTTPException(status_code=404, detail="Bill not found")

    update_data = bill_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if field == "items" and value is not None:
            value = [i if isinstance(i, dict) else i.model_dump() for i in value]
        elif field == "payments" and value is not None:
            value = [p if isinstance(p, dict) else p.model_dump() for p in value]
        setattr(bill, field, value)

    await db.commit()
    await db.refresh(bill)

    response_dict = {
        "bill_id": bill.bill_id,
        "tenant_id": bill.tenant_id,
        "invoice_number": bill.invoice_number,
        "customer_name": bill.customer_name,
        "client_id": bill.client_id,
        "service_name": bill.service_name,
        "bill_date": bill.bill_date.isoformat() if bill.bill_date else None,
        "price": bill.price,
        "tax_percentage": bill.tax_percentage,
        "tax_amount": bill.tax_amount,
        "cgst_amount": bill.cgst_amount,
        "sgst_amount": bill.sgst_amount,
        "igst_amount": bill.igst_amount,
        "place_of_supply": bill.place_of_supply,
        "advance_amount": bill.advance_amount,
        "total_amount": bill.total_amount,
        "payment_status": bill.payment_status,
        "payment_received_date": bill.payment_received_date.isoformat() if bill.payment_received_date else None,
        "whatsapp_number": bill.whatsapp_number,
        "client_address": bill.client_address,
        "gst_number": bill.gst_number,
        "items": bill.items,
        "payments": bill.payments,
        "created_by": bill.created_by,
        "created_at": bill.created_at.isoformat() if bill.created_at else None,
    }

    # Real-time WebSocket Broadcast
    await manager.broadcast_to_tenant(
        current_user.tenant_id,
        {"table": "bills", "action": "UPDATE", "data": response_dict}
    )

    return response_dict

@router.delete("/{bill_id}")
async def delete_bill(
    bill_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Bill).where(Bill.bill_id == bill_id, Bill.tenant_id == current_user.tenant_id)
    )
    bill = result.scalars().first()
    if not bill:
        raise HTTPException(status_code=404, detail="Bill not found")

    await db.delete(bill)
    await db.commit()

    # Real-time WebSocket Broadcast
    await manager.broadcast_to_tenant(
        current_user.tenant_id,
        {"table": "bills", "action": "DELETE", "data": {"bill_id": bill_id}}
    )

    return {"message": "Bill deleted successfully"}
