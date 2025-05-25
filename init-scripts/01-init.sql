-- ===========================================
-- N8N Automation Stack with Caddy - Database Initialization
-- ===========================================

-- Create n8n database
CREATE DATABASE n8n;

-- Create extensions for better functionality
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE n8n TO postgres;

-- Connect to n8n database for additional setup
\c n8n;

-- Create schema for application data
CREATE SCHEMA IF NOT EXISTS app;

-- Create basic logging table for monitoring
CREATE TABLE IF NOT EXISTS app.system_logs (
    id SERIAL PRIMARY KEY,
    level VARCHAR(10) NOT NULL,
    message TEXT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_system_logs_created_at ON app.system_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_system_logs_level ON app.system_logs(level);

-- Insert initial log entry
INSERT INTO app.system_logs (level, message, metadata) 
VALUES ('INFO', 'N8N Automation Stack with Caddy initialized', '{"version": "1.0.0", "reverse_proxy": "caddy", "ssl": "automatic", "timestamp": "' || NOW() || '"}');

-- Create function for automatic log cleanup (keeps last 30 days)
CREATE OR REPLACE FUNCTION app.cleanup_old_logs()
RETURNS void AS $$
BEGIN
    DELETE FROM app.system_logs 
    WHERE created_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

-- Create table for SSL certificate monitoring
CREATE TABLE IF NOT EXISTS app.ssl_certificates (
    id SERIAL PRIMARY KEY,
    domain VARCHAR(255) NOT NULL,
    issuer VARCHAR(255),
    valid_from TIMESTAMP WITH TIME ZONE,
    valid_until TIMESTAMP WITH TIME ZONE,
    auto_renewed BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for SSL monitoring
CREATE INDEX IF NOT EXISTS idx_ssl_certificates_domain ON app.ssl_certificates(domain);
CREATE INDEX IF NOT EXISTS idx_ssl_certificates_valid_until ON app.ssl_certificates(valid_until);

-- Success notification
DO $$
BEGIN
    RAISE NOTICE 'N8N Automation Stack with Caddy database initialized successfully!';
    RAISE NOTICE 'Database: n8n';
    RAISE NOTICE 'Schema: app (for custom application data)';
    RAISE NOTICE 'Extensions: uuid-ossp, pgcrypto';
    RAISE NOTICE 'SSL: Automatic certificate management with Caddy';
    RAISE NOTICE 'Reverse Proxy: Caddy with Let''s Encrypt integration';
END $$;
