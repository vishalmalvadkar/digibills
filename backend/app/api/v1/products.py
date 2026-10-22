from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List
import uuid

from app.db.session import get_db
from app.models.entities import Product, User
from app.schemas.schemas import ProductCreate, ProductUpdate
from app.api.deps import get_current_user
from app.core.websockets import manager

router = APIRouter(prefix="/products", tags=["Products"])

@router.get("", response_model=List[dict])
async def get_products(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Product).where(Product.tenant_id == current_user.tenant_id).order_by(Product.name.asc())
    )
    products = result.scalars().all()
    return [
        {
            "product_id": p.product_id,
            "tenant_id": p.tenant_id,
            "name": p.name,
            "description": p.description,
            "scancode": p.scancode,
            "unit_price": p.unit_price,
            "unit": p.unit,
            "stock_quantity": p.stock_quantity,
            "alert_threshold": p.alert_threshold,
            "is_stock_tracked": p.is_stock_tracked,
            "hsn_code": p.hsn_code,
            "created_at": p.created_at.isoformat() if p.created_at else None,
        }
        for p in products
    ]

@router.post("", response_model=dict)
async def create_product(
    prod_in: ProductCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    prod_data = prod_in.model_dump()
    prod_id = str(uuid.uuid4())
    prod_data["product_id"] = prod_id
    prod_data["tenant_id"] = current_user.tenant_id

    product = Product(**prod_data)
    db.add(product)
    await db.commit()
    await db.refresh(product)

    res = {
        "product_id": product.product_id,
        "tenant_id": product.tenant_id,
        "name": product.name,
        "description": product.description,
        "scancode": product.scancode,
        "unit_price": product.unit_price,
        "unit": product.unit,
        "stock_quantity": product.stock_quantity,
        "alert_threshold": product.alert_threshold,
        "is_stock_tracked": product.is_stock_tracked,
        "hsn_code": product.hsn_code,
        "created_at": product.created_at.isoformat() if product.created_at else None,
    }

    await manager.broadcast_to_tenant(
        current_user.tenant_id,
        {"table": "products", "action": "INSERT", "data": res}
    )

    return res

@router.put("/{product_id}", response_model=dict)
async def update_product(
    product_id: str,
    prod_in: ProductUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Product).where(Product.product_id == product_id, Product.tenant_id == current_user.tenant_id)
    )
    product = result.scalars().first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    for field, value in prod_in.model_dump(exclude_unset=True).items():
        setattr(product, field, value)

    await db.commit()
    await db.refresh(product)

    res = {
        "product_id": product.product_id,
        "tenant_id": product.tenant_id,
        "name": product.name,
        "description": product.description,
        "scancode": product.scancode,
        "unit_price": product.unit_price,
        "unit": product.unit,
        "stock_quantity": product.stock_quantity,
        "alert_threshold": product.alert_threshold,
        "is_stock_tracked": product.is_stock_tracked,
        "hsn_code": product.hsn_code,
        "created_at": product.created_at.isoformat() if product.created_at else None,
    }

    await manager.broadcast_to_tenant(
        current_user.tenant_id,
        {"table": "products", "action": "UPDATE", "data": res}
    )

    return res

@router.delete("/{product_id}")
async def delete_product(
    product_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Product).where(Product.product_id == product_id, Product.tenant_id == current_user.tenant_id)
    )
    product = result.scalars().first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    await db.delete(product)
    await db.commit()

    await manager.broadcast_to_tenant(
        current_user.tenant_id,
        {"table": "products", "action": "DELETE", "data": {"product_id": product_id}}
    )

    return {"message": "Product deleted successfully"}
