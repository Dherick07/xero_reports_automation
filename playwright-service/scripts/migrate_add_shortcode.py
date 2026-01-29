"""Migration script to add tenant_shortcode column to clients table."""
import asyncio
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import text
from app.db.connection import engine


async def migrate():
    """Add tenant_shortcode column if it doesn't exist."""
    async with engine.begin() as conn:
        # Add the column
        await conn.execute(text(
            "ALTER TABLE clients ADD COLUMN IF NOT EXISTS tenant_shortcode VARCHAR(50) UNIQUE"
        ))
        # Create index
        await conn.execute(text(
            "CREATE INDEX IF NOT EXISTS idx_clients_shortcode ON clients(tenant_shortcode)"
        ))
        print("Migration complete: tenant_shortcode column added")


if __name__ == "__main__":
    asyncio.run(migrate())
