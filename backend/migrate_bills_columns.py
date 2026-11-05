import asyncio
from app.db.session import engine
from sqlalchemy import text

async def main():
    async with engine.begin() as conn:
        for col, typ in [
            ('client_city', 'VARCHAR'),
            ('eway_bill_no', 'VARCHAR'),
            ('vehicle_no', 'VARCHAR'),
            ('transport_mode', 'VARCHAR'),
            ('shipping_address', 'VARCHAR'),
            ('shipping_name', 'VARCHAR')
        ]:
            try:
                await conn.execute(text(f'ALTER TABLE bills ADD COLUMN IF NOT EXISTS {col} {typ};'))
                print(f'Column {col} ensured')
            except Exception as e:
                print(f'Error for {col}: {e}')

if __name__ == '__main__':
    asyncio.run(main())

