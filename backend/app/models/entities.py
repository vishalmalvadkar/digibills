import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Boolean, DateTime, Float, Integer, JSON, Text, ForeignKey, Index
)
from app.db.session import Base

def gen_uuid():
    return str(uuid.uuid4())

class User(Base):
    __tablename__ = "users"

    uid = Column(String, primary_key=True, default=gen_uuid)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    name = Column(String, nullable=True)
    role = Column(String, default="client")  # 'client' or 'superAdmin'
    tenant_id = Column(String, index=True, nullable=False)
    mou_accepted = Column(Boolean, default=False)
    permissions = Column(JSON, default=list)
    license = Column(JSON, default=dict)
    app_version = Column(String, nullable=True)
    last_active_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class Client(Base):
    __tablename__ = "clients"

    client_id = Column(String, primary_key=True, default=gen_uuid)
    tenant_id = Column(String, index=True, nullable=False)
    business_name = Column(String, nullable=False)
    owner_name = Column(String, nullable=False)
    email = Column(String, index=True, nullable=False)
    whatsapp_number = Column(String, default="")
    state = Column(String, default="")
    gst_number = Column(String, default="")
    status = Column(String, default="active")  # 'pending', 'active', 'blocked'
    license = Column(JSON, default=dict)
    mou_accepted = Column(Boolean, default=False)
    mou_meta = Column(JSON, nullable=True)
    amount = Column(Float, default=0.0)
    payment_mode = Column(String, default="Cash")
    payment_status = Column(String, default="Pending")
    tax_percentage = Column(Float, default=0.0)
    created_at = Column(DateTime, default=datetime.utcnow)

class Bill(Base):
    __tablename__ = "bills"

    bill_id = Column(String, primary_key=True, default=gen_uuid)
    tenant_id = Column(String, index=True, nullable=False)
    invoice_number = Column(String, index=True, nullable=False)
    customer_name = Column(String, nullable=False)
    client_id = Column(String, index=True, nullable=False)
    service_name = Column(String, default="")
    bill_date = Column(DateTime, default=datetime.utcnow)
    price = Column(Float, default=0.0)
    tax_percentage = Column(Float, default=0.0)
    tax_amount = Column(Float, default=0.0)
    cgst_amount = Column(Float, default=0.0)
    sgst_amount = Column(Float, default=0.0)
    igst_amount = Column(Float, default=0.0)
    place_of_supply = Column(String, default="")
    advance_amount = Column(Float, default=0.0)
    total_amount = Column(Float, default=0.0)
    payment_status = Column(String, default="Pending")
    payment_received_date = Column(DateTime, nullable=True)
    whatsapp_number = Column(String, default="")
    client_address = Column(String, default="")
    gst_number = Column(String, nullable=True)
    items = Column(JSON, default=list)        # List of BillItem dicts
    payments = Column(JSON, default=list)     # List of PaymentRecord dicts
    created_by = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class Product(Base):
    __tablename__ = "products"

    product_id = Column(String, primary_key=True, default=gen_uuid)
    tenant_id = Column(String, index=True, nullable=False)
    name = Column(String, nullable=False)
    description = Column(String, nullable=True)
    scancode = Column(String, default="")
    unit_price = Column(Float, default=0.0)
    unit = Column(String, default="qty")
    stock_quantity = Column(Float, default=0.0)
    alert_threshold = Column(Float, default=5.0)
    is_stock_tracked = Column(Boolean, default=True)
    hsn_code = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class Expense(Base):
    __tablename__ = "expenses"

    id = Column(String, primary_key=True, default=gen_uuid)
    tenant_id = Column(String, index=True, nullable=False)
    user_id = Column(String, nullable=True)
    title = Column(String, nullable=False)
    amount = Column(Float, default=0.0)
    category = Column(String, default="Other")
    date = Column(DateTime, default=datetime.utcnow)
    notes = Column(String, nullable=True)
    supplier_gst_number = Column(String, nullable=True)
    invoice_number = Column(String, nullable=True)
    tax_amount = Column(Float, default=0.0)
    tax_type = Column(String, nullable=True)
    hsn_code = Column(String, nullable=True)
    is_itc_eligible = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

class Quotation(Base):
    __tablename__ = "quotations"

    quote_id = Column(String, primary_key=True, default=gen_uuid)
    tenant_id = Column(String, index=True, nullable=False)
    quote_number = Column(String, index=True, nullable=False)
    customer_name = Column(String, nullable=False)
    customer_phone = Column(String, default="")
    customer_email = Column(String, default="")
    quote_date = Column(DateTime, default=datetime.utcnow)
    valid_until = Column(DateTime, nullable=True)
    items = Column(JSON, default=list)
    subtotal = Column(Float, default=0.0)
    tax_rate = Column(Float, default=0.0)
    tax_amount = Column(Float, default=0.0)
    total_amount = Column(Float, default=0.0)
    status = Column(String, default="Draft")  # 'Draft', 'Sent', 'Accepted', 'Declined'
    terms_and_conditions = Column(Text, nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class Setting(Base):
    __tablename__ = "settings"

    tenant_id = Column(String, primary_key=True)
    tenant_name = Column(String, default="My Business")
    contact_email = Column(String, default="")
    contact_phone = Column(String, default="")
    bank_name = Column(String, default="")
    account_number = Column(String, default="")
    ifsc_code = Column(String, default="")
    account_holder_name = Column(String, default="")
    upi_id = Column(String, default="")
    payee_name = Column(String, default="")
    gst_number = Column(String, default="")
    address = Column(String, default="")
    city = Column(String, default="")
    district = Column(String, default="")
    pincode = Column(String, default="")
    state = Column(String, default="")
    default_gst_rate = Column(Float, default=18.0)
    print_format = Column(String, default="A4")
    logo_base64 = Column(Text, nullable=True)
    logo_width = Column(Float, default=60.0)
    logo_height = Column(Float, default=60.0)
    mou_pdf_header_title = Column(String, default="Memorandum of Understanding")
    mou_pdf_sub_header = Column(String, default="Technology Solutions Provider")
    show_logo_on_pdf = Column(Boolean, default=True)
    is_audit_trail_enabled = Column(Boolean, default=False)
    invoice_prefix = Column(String, default="INV-")
    invoice_start_number = Column(Integer, default=1)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class SequenceCounter(Base):
    __tablename__ = "sequence_counters"

    id = Column(String, primary_key=True)  # tenant_id + '_' + type (e.g. "tenant123_invoice")
    tenant_id = Column(String, index=True, nullable=False)
    counter_type = Column(String, nullable=False)  # 'invoice', 'quotation', etc.
    last_value = Column(Integer, default=0)
    prefix = Column(String, default="")
    updated_at = Column(DateTime, default=datetime.utcnow)
