-- Add tenant_shortcode column if it doesn't exist (for existing databases)
ALTER TABLE clients ADD COLUMN IF NOT EXISTS tenant_shortcode VARCHAR(50) UNIQUE;
CREATE INDEX IF NOT EXISTS idx_clients_shortcode ON clients(tenant_shortcode);

-- Insert 4 test tenants for development
-- These are the tenants used during development phase
INSERT INTO clients (tenant_id, tenant_name, tenant_shortcode, onedrive_folder, is_active) VALUES
    ('marsill-pty-ltd', 'Marsill Pty Ltd', 'mkK34', '/Xero Reports/Marsill Pty Ltd', true),
    ('20wad-pty-ltd', '20WAD Pty Ltd', 'WJQR!', '/Xero Reports/20WAD Pty Ltd', true),
    ('earjobs-nz-limited', 'Earjobs NZ Limited Partnership', 'DR0yC', '/Xero Reports/Earjobs NZ Limited Partnership', true),
    ('kotti-capital-ops', 'Kotti Capital Operations Pty Ltd', '23kBq', '/Xero Reports/Kotti Capital Operations Pty Ltd', true)
ON CONFLICT (tenant_id) DO UPDATE SET
    tenant_name = EXCLUDED.tenant_name,
    tenant_shortcode = EXCLUDED.tenant_shortcode,
    onedrive_folder = EXCLUDED.onedrive_folder,
    is_active = EXCLUDED.is_active;

-- Verify the inserts
SELECT id, tenant_id, tenant_name, tenant_shortcode, is_active FROM clients;
