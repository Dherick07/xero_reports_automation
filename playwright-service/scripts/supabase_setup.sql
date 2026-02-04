-- ===========================================
-- Xero Reports Automation - Supabase Setup
-- ===========================================
-- Run this script in Supabase SQL Editor to set up all required tables
-- This script is idempotent (safe to run multiple times)

-- =====================
-- 1. CLIENTS TABLE
-- =====================
CREATE TABLE IF NOT EXISTS clients (
    id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(255) UNIQUE NOT NULL,
    tenant_name VARCHAR(255) NOT NULL,
    tenant_shortcode VARCHAR(50) UNIQUE,  -- URL shortcode for fast switching (e.g., "mkK34")
    is_active BOOLEAN DEFAULT true,
    onedrive_folder VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add missing columns if table already exists
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'clients' AND column_name = 'tenant_shortcode') THEN
        ALTER TABLE clients ADD COLUMN tenant_shortcode VARCHAR(50) UNIQUE;
    END IF;
END $$;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_clients_active ON clients(is_active);
CREATE INDEX IF NOT EXISTS idx_clients_tenant_id ON clients(tenant_id);
CREATE INDEX IF NOT EXISTS idx_clients_shortcode ON clients(tenant_shortcode);

-- =====================
-- 2. XERO_SESSIONS TABLE
-- =====================
CREATE TABLE IF NOT EXISTS xero_sessions (
    id INTEGER PRIMARY KEY DEFAULT 1,
    cookies TEXT NOT NULL,           -- Encrypted JSON
    oauth_tokens TEXT,               -- Optional: encrypted OAuth tokens
    expires_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT single_session CHECK (id = 1)
);

-- Add missing columns if table already exists
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'xero_sessions' AND column_name = 'oauth_tokens') THEN
        ALTER TABLE xero_sessions ADD COLUMN oauth_tokens TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'xero_sessions' AND column_name = 'expires_at') THEN
        ALTER TABLE xero_sessions ADD COLUMN expires_at TIMESTAMP WITH TIME ZONE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'xero_sessions' AND column_name = 'updated_at') THEN
        ALTER TABLE xero_sessions ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
END $$;

-- =====================
-- 3. DOWNLOAD_LOGS TABLE
-- =====================
CREATE TABLE IF NOT EXISTS download_logs (
    id SERIAL PRIMARY KEY,
    client_id INTEGER REFERENCES clients(id),
    report_type VARCHAR(50) NOT NULL,  -- 'activity_statement', 'payroll_summary', 'consolidated_report'
    status VARCHAR(20) NOT NULL,       -- 'success', 'failed', 'pending'
    file_path VARCHAR(500),
    file_name VARCHAR(255),
    file_size INTEGER,
    error_message TEXT,
    screenshot_path VARCHAR(500),
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    uploaded_to_onedrive BOOLEAN DEFAULT false,
    onedrive_path VARCHAR(500)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_download_logs_client ON download_logs(client_id);
CREATE INDEX IF NOT EXISTS idx_download_logs_status ON download_logs(status);
CREATE INDEX IF NOT EXISTS idx_download_logs_date ON download_logs(started_at);
CREATE INDEX IF NOT EXISTS idx_download_logs_report_type ON download_logs(report_type);

-- =====================
-- 4. AUTO-UPDATE TRIGGER
-- =====================
-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers to auto-update updated_at
DROP TRIGGER IF EXISTS update_clients_updated_at ON clients;
CREATE TRIGGER update_clients_updated_at
    BEFORE UPDATE ON clients
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_xero_sessions_updated_at ON xero_sessions;
CREATE TRIGGER update_xero_sessions_updated_at
    BEFORE UPDATE ON xero_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================
-- 5. COMMENTS (Documentation)
-- =====================
COMMENT ON TABLE clients IS 'Xero client tenants to process for report downloads';
COMMENT ON TABLE xero_sessions IS 'Encrypted Xero session cookies (single row, id=1 always)';
COMMENT ON TABLE download_logs IS 'Audit log of all report download attempts';

COMMENT ON COLUMN clients.tenant_id IS 'Xero tenant/organization ID';
COMMENT ON COLUMN clients.tenant_shortcode IS 'Short URL code for fast Xero tenant switching (from Xero URL)';
COMMENT ON COLUMN xero_sessions.cookies IS 'Encrypted browser cookies for Xero authentication';
COMMENT ON COLUMN xero_sessions.oauth_tokens IS 'Optional encrypted OAuth tokens';

-- =====================
-- VERIFICATION QUERY
-- =====================
-- Run this to verify all tables and columns exist:
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name IN ('clients', 'xero_sessions', 'download_logs')
ORDER BY table_name, ordinal_position;
