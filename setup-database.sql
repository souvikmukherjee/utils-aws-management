-- Database setup script for aws-management dev
-- Run this script to initialize the database schema

-- Create database if it doesn't exist
SELECT 'CREATE DATABASE aws-management_dev'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'aws-management_dev')\gexec

-- Connect to the database
\c aws-management_dev

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create aws_resources table
CREATE TABLE IF NOT EXISTS aws_resources (
    id SERIAL PRIMARY KEY,
    resource_id VARCHAR(255) UNIQUE NOT NULL,
    resource_type VARCHAR(100) NOT NULL,
    resource_name VARCHAR(255),
    region VARCHAR(50),
    tags JSONB,
    cost_per_hour DECIMAL(10,4),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create cost_analytics table
CREATE TABLE IF NOT EXISTS cost_analytics (
    id SERIAL PRIMARY KEY,
    resource_id VARCHAR(255) NOT NULL,
    date DATE NOT NULL,
    cost DECIMAL(10,4) NOT NULL,
    usage_hours DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (resource_id) REFERENCES aws_resources(resource_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_aws_resources_type ON aws_resources(resource_type);
CREATE INDEX IF NOT EXISTS idx_aws_resources_region ON aws_resources(region);
CREATE INDEX IF NOT EXISTS idx_cost_analytics_date ON cost_analytics(date);
CREATE INDEX IF NOT EXISTS idx_cost_analytics_resource ON cost_analytics(resource_id);

-- Insert sample data
INSERT INTO users (email, name) VALUES 
    ('demo@example.com', 'Demo User'),
    ('test@example.com', 'Test User')
ON CONFLICT (email) DO NOTHING;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_aws_resources_updated_at BEFORE UPDATE ON aws_resources FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_cost_analytics_updated_at BEFORE UPDATE ON cost_analytics FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;
