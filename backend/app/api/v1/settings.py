from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import Dict, Any

from app.db.session import get_db
from app.models.entities import Setting, User
from app.schemas.schemas import SettingUpdate
from app.api.deps import get_current_user

router = APIRouter(prefix="/settings", tags=["Settings"])

@router.get("", response_model=Dict[str, Any])
async def get_settings(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    setting = await db.get(Setting, current_user.tenant_id)
    if not setting:
        # Create default if not found
        setting = Setting(
            tenant_id=current_user.tenant_id,
            tenant_name=current_user.name or "My Business",
            contact_email=current_user.email
        )
        db.add(setting)
        await db.commit()
        await db.refresh(setting)

    return {
        "tenant_id": setting.tenant_id,
        "tenant_name": setting.tenant_name,
        "contact_email": setting.contact_email,
        "contact_phone": setting.contact_phone,
        "bank_name": setting.bank_name,
        "account_number": setting.account_number,
        "ifsc_code": setting.ifsc_code,
        "account_holder_name": setting.account_holder_name,
        "upi_id": setting.upi_id,
        "payee_name": setting.payee_name,
        "gst_number": setting.gst_number,
        "address": setting.address,
        "city": setting.city,
        "district": setting.district,
        "pincode": setting.pincode,
        "state": setting.state,
        "default_gst_rate": setting.default_gst_rate,
        "print_format": setting.print_format,
        "logo_base64": setting.logo_base64,
        "logo_width": setting.logo_width,
        "logo_height": setting.logo_height,
        "mou_pdf_header_title": setting.mou_pdf_header_title,
        "mou_pdf_sub_header": setting.mou_pdf_sub_header,
        "show_logo_on_pdf": setting.show_logo_on_pdf,
        "is_audit_trail_enabled": setting.is_audit_trail_enabled,
        "invoice_prefix": setting.invoice_prefix,
        "invoice_start_number": setting.invoice_start_number,
    }

@router.put("", response_model=Dict[str, Any])
async def update_settings(
    update_in: SettingUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    setting = await db.get(Setting, current_user.tenant_id)
    if not setting:
        setting = Setting(tenant_id=current_user.tenant_id)
        db.add(setting)

    for field, value in update_in.model_dump(exclude_unset=True).items():
        setattr(setting, field, value)

    await db.commit()
    await db.refresh(setting)

    return {
        "tenant_id": setting.tenant_id,
        "tenant_name": setting.tenant_name,
        "contact_email": setting.contact_email,
        "contact_phone": setting.contact_phone,
        "bank_name": setting.bank_name,
        "account_number": setting.account_number,
        "ifsc_code": setting.ifsc_code,
        "account_holder_name": setting.account_holder_name,
        "upi_id": setting.upi_id,
        "payee_name": setting.payee_name,
        "gst_number": setting.gst_number,
        "address": setting.address,
        "city": setting.city,
        "district": setting.district,
        "pincode": setting.pincode,
        "state": setting.state,
        "default_gst_rate": setting.default_gst_rate,
        "print_format": setting.print_format,
        "logo_base64": setting.logo_base64,
        "logo_width": setting.logo_width,
        "logo_height": setting.logo_height,
        "mou_pdf_header_title": setting.mou_pdf_header_title,
        "mou_pdf_sub_header": setting.mou_pdf_sub_header,
        "show_logo_on_pdf": setting.show_logo_on_pdf,
        "is_audit_trail_enabled": setting.is_audit_trail_enabled,
        "invoice_prefix": setting.invoice_prefix,
        "invoice_start_number": setting.invoice_start_number,
    }
