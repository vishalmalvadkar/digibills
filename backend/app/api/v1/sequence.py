from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from datetime import datetime

from app.db.session import get_db
from app.models.entities import SequenceCounter, User
from app.api.deps import get_current_user

router = APIRouter(prefix="/sequence", tags=["Sequence"])

@router.get("/peek")
async def peek_next_number(
    type: str = Query("invoice"),
    prefix: str = Query("INV-"),
    start: int = Query(1),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    counter_id = f"{current_user.tenant_id}_{type.lower()}"
    query = select(SequenceCounter).where(SequenceCounter.id == counter_id)
    result = await db.execute(query)
    sc = result.scalars().first()

    if sc is None:
        next_val = start
    else:
        next_val = max(sc.last_value + 1, start)

    formatted = f"{prefix}{str(next_val).zfill(3)}"
    return {"number": formatted, "value": next_val}

@router.post("/next")
async def get_next_number(
    type: str = Query("invoice"),
    prefix: str = Query("INV-"),
    start: int = Query(1),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    counter_id = f"{current_user.tenant_id}_{type.lower()}"
    query = select(SequenceCounter).where(SequenceCounter.id == counter_id)
    result = await db.execute(query)
    sc = result.scalars().first()

    if sc is None:
        next_val = start
        sc = SequenceCounter(
            id=counter_id,
            tenant_id=current_user.tenant_id,
            counter_type=type.lower(),
            last_value=next_val,
            prefix=prefix,
            updated_at=datetime.utcnow()
        )
        db.add(sc)
    else:
        next_val = max(sc.last_value + 1, start)
        sc.last_value = next_val
        sc.prefix = prefix
        sc.updated_at = datetime.utcnow()

    await db.commit()
    await db.refresh(sc)

    formatted = f"{prefix}{str(next_val).zfill(3)}"
    return {"number": formatted, "value": next_val}

