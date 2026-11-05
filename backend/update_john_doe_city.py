import asyncio
from app.db.session import engine
from sqlalchemy import text

async def run():
    async with engine.begin() as conn:
        await conn.execute(text("UPDATE bills SET client_city = 'Mumbai' WHERE customer_name = 'John Doe';"))
        print('Updated John Doe bills with city')

if __name__ == '__main__':
    asyncio.run(run())

