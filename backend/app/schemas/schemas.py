from pydantic import BaseModel, EmailStr
from typing import Optional, List, Dict, Any
from datetime import datetime

# --- Auth ---
class Token(BaseModel):
    access_token: str
    token_type: str
    user: Dict[str, Any]

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class UserCreate(BaseModel):
    email: EmailStr
    password: str
    name: Optional[str] = None
    role: Optional[str] = "client"
    tenant_id: Optional[str] = None

class UserOut(BaseModel):
    uid: str
    email: str
    name: Optional[str]
    role: str
    tenant_id: str
    mou_accepted: bool = False
    permissions: List[str] = []
    license: Optional[Dict[str, Any]] = None
    app_version: Optional[str] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True

# --- Clients ---
class ClientBase(BaseModel):
    business_name: str
    owner_name: str
    email: str
    whatsapp_number: Optional[str] = ""
    state: Optional[str] = ""
    gst_number: Optional[str] = ""
    status: Optional[str] = "active"
    license: Optional[Dict[str, Any]] = None
    mou_accepted: Optional[bool] = False
    mou_meta: Optional[Dict[str, Any]] = None
    amount: Optional[float] = 0.0
    payment_mode: Optional[str] = "Cash"
    payment_status: Optional[str] = "Pending"
    tax_percentage: Optional[float] = 0.0

class ClientCreate(ClientBase):
    pass

class ClientUpdate(BaseModel):
    business_name: Optional[str] = None
    owner_name: Optional[str] = None
    email: Optional[str] = None
    whatsapp_number: Optional[str] = None
    state: Optional[str] = None
    gst_number: Optional[str] = None
    status: Optional[str] = None
    license: Optional[Dict[str, Any]] = None
    mou_accepted: Optional[bool] = None
    mou_meta: Optional[Dict[str, Any]] = None
    amount: Optional[float] = None
    payment_mode: Optional[str] = None
    payment_status: Optional[str] = None
    tax_percentage: Optional[float] = None

# --- Products ---
class ProductBase(BaseModel):
    name: str
    description: Optional[str] = None
    scancode: Optional[str] = ""
    unit_price: float = 0.0
    unit: Optional[str] = "qty"
    stock_quantity: Optional[float] = 0.0
    alert_threshold: Optional[float] = 5.0
    is_stock_tracked: Optional[bool] = True
    hsn_code: Optional[str] = None

class ProductCreate(ProductBase):
    pass

class ProductUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    scancode: Optional[str] = None
    unit_price: Optional[float] = None
    unit: Optional[str] = None
    stock_quantity: Optional[float] = None
    alert_threshold: Optional[float] = None
    is_stock_tracked: Optional[bool] = None
    hsn_code: Optional[str] = None

# --- Bills ---
class BillItemSchema(BaseModel):
    id: Optional[str] = None
    product_id: Optional[str] = None
    description: str
    amount: float
    quantity: float = 1.0
    unit: str = "qty"
    unit_price: float = 0.0
    hsn_code: Optional[str] = None
    hsn_type: str = "HSN"

class PaymentRecordSchema(BaseModel):
    id: Optional[str] = None
    date: datetime
    amount: float
    mode: str = "Cash"

class BillCreate(BaseModel):
    invoice_number: str
    customer_name: str
    client_id: str
    service_name: Optional[str] = ""
    bill_date: Optional[datetime] = None
    price: float = 0.0
    tax_percentage: float = 0.0
    tax_amount: float = 0.0
    cgst_amount: float = 0.0
    sgst_amount: float = 0.0
    igst_amount: float = 0.0
    place_of_supply: Optional[str] = ""
    advance_amount: float = 0.0
    total_amount: float = 0.0
    payment_status: str = "Pending"
    payment_received_date: Optional[datetime] = None
    whatsapp_number: Optional[str] = ""
    client_address: Optional[str] = ""
    gst_number: Optional[str] = None
    items: List[BillItemSchema] = []
    payments: List[PaymentRecordSchema] = []
    created_by: Optional[str] = None

class BillUpdate(BaseModel):
    customer_name: Optional[str] = None
    service_name: Optional[str] = None
    bill_date: Optional[datetime] = None
    price: Optional[float] = None
    tax_percentage: Optional[float] = None
    tax_amount: Optional[float] = None
    cgst_amount: Optional[float] = None
    sgst_amount: Optional[float] = None
    igst_amount: Optional[float] = None
    place_of_supply: Optional[str] = None
    advance_amount: Optional[float] = None
    total_amount: Optional[float] = None
    payment_status: Optional[str] = None
    payment_received_date: Optional[datetime] = None
    whatsapp_number: Optional[str] = None
    client_address: Optional[str] = None
    gst_number: Optional[str] = None
    items: Optional[List[BillItemSchema]] = None
    payments: Optional[List[PaymentRecordSchema]] = None

# --- Expenses ---
class ExpenseCreate(BaseModel):
    title: str
    amount: float
    category: str = "Other"
    date: Optional[datetime] = None
    notes: Optional[str] = None
    supplier_gst_number: Optional[str] = None
    invoice_number: Optional[str] = None
    tax_amount: float = 0.0
    tax_type: Optional[str] = None
    hsn_code: Optional[str] = None
    is_itc_eligible: bool = False

class ExpenseUpdate(BaseModel):
    title: Optional[str] = None
    amount: Optional[float] = None
    category: Optional[str] = None
    date: Optional[datetime] = None
    notes: Optional[str] = None
    supplier_gst_number: Optional[str] = None
    invoice_number: Optional[str] = None
    tax_amount: Optional[float] = None
    tax_type: Optional[str] = None
    hsn_code: Optional[str] = None
    is_itc_eligible: Optional[bool] = None

# --- Settings ---
class SettingUpdate(BaseModel):
    tenant_name: Optional[str] = None
    contact_email: Optional[str] = None
    contact_phone: Optional[str] = None
    bank_name: Optional[str] = None
    account_number: Optional[str] = None
    ifsc_code: Optional[str] = None
    account_holder_name: Optional[str] = None
    upi_id: Optional[str] = None
    payee_name: Optional[str] = None
    gst_number: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    district: Optional[str] = None
    pincode: Optional[str] = None
    state: Optional[str] = None
    default_gst_rate: Optional[float] = None
    print_format: Optional[str] = None
    logo_base64: Optional[str] = None
    logo_width: Optional[float] = None
    logo_height: Optional[float] = None
    mou_pdf_header_title: Optional[str] = None
    mou_pdf_sub_header: Optional[str] = None
    show_logo_on_pdf: Optional[bool] = None
    is_audit_trail_enabled: Optional[bool] = None
    invoice_prefix: Optional[str] = None
    invoice_start_number: Optional[int] = None
