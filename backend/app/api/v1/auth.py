from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.db.session import get_db
from app.models.entities import User, Setting
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

    new_user = User(
        uid=new_uid,
        email=req.email,
        hashed_password=get_password_hash(req.password),
        name=req.name or req.email.split("@")[0],
        role=req.role or "client",
        tenant_id=tenant_id,
        license={
            "isActive": True,
            "plan": "premium",
            "startDate": "2026-01-01T00:00:00.000Z",
            "endDate": "2030-01-01T00:00:00.000Z"
        }
    )
    db.add(new_user)

    # Initialize default settings for new tenant
    existing_setting = await db.get(Setting, tenant_id)
    if not existing_setting:
        db.add(Setting(
            tenant_id=tenant_id,
            tenant_name=req.name or "My Business",
            contact_email=req.email
        ))

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
