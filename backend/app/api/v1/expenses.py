from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List
import uuid

from app.db.session import get_db
from app.models.entities import Expense, User
from app.schemas.schemas import ExpenseCreate, ExpenseUpdate
from app.api.deps import get_current_user
from app.core.websockets import manager

router = APIRouter(prefix="/expenses", tags=["Expenses"])

@router.get("", response_model=List[dict])
async def get_expenses(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Expense).where(Expense.tenant_id == current_user.tenant_id).order_by(Expense.date.desc())
    )
    expenses = result.scalars().all()
    return [
        {
            "id": e.id,
            "tenant_id": e.tenant_id,
            "user_id": e.user_id,
            "title": e.title,
            "amount": e.amount,
            "category": e.category,
            "date": e.date.isoformat() if e.date else None,
            "notes": e.notes,
            "supplier_gst_number": e.supplier_gst_number,
            "invoice_number": e.invoice_number,
            "tax_amount": e.tax_amount,
            "tax_type": e.tax_type,
            "hsn_code": e.hsn_code,
            "is_itc_eligible": e.is_itc_eligible,
            "created_at": e.created_at.isoformat() if e.created_at else None,
        }
        for e in expenses
    ]

@router.post("", response_model=dict)
async def create_expense(
    exp_in: ExpenseCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    exp_data = exp_in.model_dump()
    exp_id = str(uuid.uuid4())
    exp_data["id"] = exp_id
    exp_data["tenant_id"] = current_user.tenant_id
    exp_data["user_id"] = current_user.uid

    expense = Expense(**exp_data)
    db.add(expense)
    await db.commit()
    await db.refresh(expense)

    res = {
        "id": expense.id,
        "tenant_id": expense.tenant_id,
        "user_id": expense.user_id,
        "title": expense.title,
        "amount": expense.amount,
        "category": expense.category,
        "date": expense.date.isoformat() if expense.date else None,
        "notes": expense.notes,
        "supplier_gst_number": expense.supplier_gst_number,
        "invoice_number": expense.invoice_number,
        "tax_amount": expense.tax_amount,
        "tax_type": expense.tax_type,
        "hsn_code": expense.hsn_code,
        "is_itc_eligible": expense.is_itc_eligible,
        "created_at": expense.created_at.isoformat() if expense.created_at else None,
    }

    await manager.broadcast_to_tenant(
        current_user.tenant_id,
        {"table": "expenses", "action": "INSERT", "data": res}
    )

    return res

@router.put("/{expense_id}", response_model=dict)
async def update_expense(
    expense_id: str,
    exp_in: ExpenseUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Expense).where(Expense.id == expense_id, Expense.tenant_id == current_user.tenant_id)
    )
    expense = result.scalars().first()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    for field, value in exp_in.model_dump(exclude_unset=True).items():
        setattr(expense, field, value)

    await db.commit()
    await db.refresh(expense)

    res = {
        "id": expense.id,
        "tenant_id": expense.tenant_id,
        "user_id": expense.user_id,
        "title": expense.title,
        "amount": expense.amount,
        "category": expense.category,
        "date": expense.date.isoformat() if expense.date else None,
        "notes": expense.notes,
        "supplier_gst_number": expense.supplier_gst_number,
        "invoice_number": expense.invoice_number,
        "tax_amount": expense.tax_amount,
        "tax_type": expense.tax_type,
        "hsn_code": expense.hsn_code,
        "is_itc_eligible": expense.is_itc_eligible,
        "created_at": expense.created_at.isoformat() if expense.created_at else None,
    }

    await manager.broadcast_to_tenant(
        current_user.tenant_id,
        {"table": "expenses", "action": "UPDATE", "data": res}
    )

    return res

@router.delete("/{expense_id}")
async def delete_expense(
    expense_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Expense).where(Expense.id == expense_id, Expense.tenant_id == current_user.tenant_id)
    )
    expense = result.scalars().first()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    await db.delete(expense)
    await db.commit()

    await manager.broadcast_to_tenant(
        current_user.tenant_id,
        {"table": "expenses", "action": "DELETE", "data": {"id": expense_id}}
    )

    return {"message": "Expense deleted successfully"}
