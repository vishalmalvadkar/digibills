from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.db.session import get_db
from app.models.entities import User, Setting, Client
from app.schemas.schemas import Token, LoginRequest, UserCreate, UserOut
from app.core.security import verify_password, get_password_hash, create_access_token
from app.api.deps import get_current_user

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/token", response_model=Token)
async def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db)
):
    """
    Standard OAuth2 password flow endpoint used by Swagger UI Authorize button.
    """
    result = await db.execute(select(User).where(User.email == form_data.username))
    user = result.scalars().first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Check if there is a client record provisioned by SuperAdmin for this email/tenant
    client_res = await db.execute(
        select(Client).where((Client.email == user.email) | (Client.client_id == user.tenant_id) | (Client.tenant_id == user.tenant_id))
    )
    client_obj = client_res.scalars().first()
    if client_obj and client_obj.business_name:
        user.name = client_obj.business_name
        setting = await db.get(Setting, user.tenant_id)
        if setting:
            setting.tenant_name = client_obj.business_name
        else:
            db.add(Setting(
                tenant_id=user.tenant_id,
                tenant_name=client_obj.business_name,
                contact_email=user.email
            ))
        await db.commit()
        await db.refresh(user)

    access_token = create_access_token(subject=user.uid)
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": {
            "uid": user.uid,
            "email": user.email,
            "name": user.name,
            "role": user.role,
            "tenant_id": user.tenant_id,
            "license": user.license,
            "mou_accepted": user.mou_accepted,
            "permissions": user.permissions
        }
    }

@router.post("/login", response_model=Token)
async def login(
    req: LoginRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Standard JSON login endpoint for the Flutter application.
    """
    result = await db.execute(select(User).where(User.email == req.email))
    user = result.scalars().first()
    if not user or not verify_password(req.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    
    # Check if there is a client record provisioned by SuperAdmin for this email/tenant
    client_res = await db.execute(
        select(Client).where((Client.email == user.email) | (Client.client_id == user.tenant_id) | (Client.tenant_id == user.tenant_id))
    )
    client_obj = client_res.scalars().first()
    if client_obj and client_obj.business_name:
        # Guarantee user's name is set to the exact business_name
        user.name = client_obj.business_name
        # Guarantee tenant setting has the exact business_name
        setting = await db.get(Setting, user.tenant_id)
        if setting:
            setting.tenant_name = client_obj.business_name
        else:
            db.add(Setting(
                tenant_id=user.tenant_id,
                tenant_name=client_obj.business_name,
                contact_email=user.email
            ))
        await db.commit()
        await db.refresh(user)

    access_token = create_access_token(subject=user.uid)
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": {
            "uid": user.uid,
            "email": user.email,
            "name": user.name,
            "role": user.role,
            "tenant_id": user.tenant_id,
            "license": user.license,
            "mou_accepted": user.mou_accepted,
            "permissions": user.permissions
        }
    }

@router.post("/signup", response_model=Token)
async def signup(
    req: UserCreate,
    db: AsyncSession = Depends(get_db)
):
    """
    Register a new tenant user and initialize default settings.
    """
    result = await db.execute(select(User).where(User.email == req.email))
    if result.scalars().first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="An account with this email already exists."
        )
    
    import uuid
    new_uid = str(uuid.uuid4())
    tenant_id = req.tenant_id or new_uid

    # Check if there is an existing client record created by SuperAdmin for this email
    client_res = await db.execute(select(Client).where(Client.email == req.email))
    client_obj = client_res.scalars().first()
    business_title = client_obj.business_name if (client_obj and client_obj.business_name) else (req.name or "My Business")
    if client_obj:
        tenant_id = client_obj.tenant_id or client_obj.client_id or tenant_id

    new_user = User(
        uid=new_uid,
        email=req.email,
        hashed_password=get_password_hash(req.password),
        name=business_title,
        role=req.role or "client",
        tenant_id=tenant_id,
        license=client_obj.license if (client_obj and client_obj.license) else {
            "isActive": True,
            "plan": "premium",
            "startDate": "2026-01-01T00:00:00.000Z",
            "endDate": "2030-01-01T00:00:00.000Z"
        }
    )
    db.add(new_user)

    # Initialize or update settings for tenant with the exact business name
    existing_setting = await db.get(Setting, tenant_id)
    if not existing_setting:
        db.add(Setting(
            tenant_id=tenant_id,
            tenant_name=business_title,
            contact_email=req.email,
            state=client_obj.state if (client_obj and client_obj.state) else "",
            gst_number=client_obj.gst_number if (client_obj and client_obj.gst_number) else "",
            contact_phone=client_obj.whatsapp_number if (client_obj and hasattr(client_obj, 'whatsapp_number')) else ""
        ))
    else:
        existing_setting.tenant_name = business_title

    await db.commit()
    await db.refresh(new_user)

    access_token = create_access_token(subject=new_user.uid)
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": {
            "uid": new_user.uid,
            "email": new_user.email,
            "name": new_user.name,
            "role": new_user.role,
            "tenant_id": new_user.tenant_id,
            "license": new_user.license,
            "mou_accepted": new_user.mou_accepted,
            "permissions": new_user.permissions
        }
    }

@router.get("/me", response_model=UserOut)
async def get_me(current_user: User = Depends(get_current_user)):
    return current_user
