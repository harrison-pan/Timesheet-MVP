-- Stardust Timesheet - Database Initialization Script
-- Version: 1.3
-- Database: PostgreSQL 16

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Users Table
CREATE TABLE users (
    email VARCHAR(255) PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    hrs_per_week DECIMAL(5,2) DEFAULT 40.00 CHECK (hrs_per_week >= 0 AND hrs_per_week <= 168),
    role VARCHAR(20) NOT NULL CHECK (role IN ('USER', 'APPROVER', 'ADMIN')),
    created_by VARCHAR(255) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(255) NOT NULL,
    updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_role ON users(role);

-- 2. Tasks Table
CREATE TABLE tasks (
    code VARCHAR(50) PRIMARY KEY,
    project_or_task VARCHAR(255) NOT NULL,
    astute_code VARCHAR(100),
    approver_email VARCHAR(255),
    description VARCHAR(500),
    created_by VARCHAR(255) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(255) NOT NULL,
    updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (approver_email) REFERENCES users(email) ON DELETE SET NULL
);

CREATE INDEX idx_tasks_approver ON tasks(approver_email);

-- 3. User Tasks Table
CREATE TABLE user_tasks (
    id SERIAL PRIMARY KEY,
    user_email VARCHAR(255) NOT NULL,
    task_code VARCHAR(50) NOT NULL,
    created_by VARCHAR(255) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_email) REFERENCES users(email) ON DELETE CASCADE,
    FOREIGN KEY (task_code) REFERENCES tasks(code) ON DELETE CASCADE,
    UNIQUE (user_email, task_code)
);

CREATE INDEX idx_user_tasks_user ON user_tasks(user_email);
CREATE INDEX idx_user_tasks_task ON user_tasks(task_code);

-- 4. Timesheet Entries Table
CREATE TABLE timesheet_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_email VARCHAR(255) NOT NULL,
    task_code VARCHAR(50) NOT NULL,
    week_start_date DATE NOT NULL CHECK (EXTRACT(DOW FROM week_start_date) = 1),
    entry_date DATE NOT NULL CHECK (entry_date >= week_start_date AND entry_date <= week_start_date + INTERVAL '6 days'),
    hours DECIMAL(4,2) NOT NULL CHECK (hours >= 0 AND hours <= 24 AND MOD(hours * 4, 1) = 0),
    notes TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED')),
    rejection_reason TEXT,
    approver_email VARCHAR(255),
    approved_at TIMESTAMP,
    submitted_by_email VARCHAR(255),
    submitted_at TIMESTAMP,
    created_by VARCHAR(255) NOT NULL,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(255) NOT NULL,
    updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_email) REFERENCES users(email) ON DELETE CASCADE,
    FOREIGN KEY (task_code) REFERENCES tasks(code) ON DELETE RESTRICT,
    FOREIGN KEY (approver_email) REFERENCES users(email) ON DELETE SET NULL,
    FOREIGN KEY (submitted_by_email) REFERENCES users(email) ON DELETE SET NULL,
    UNIQUE (user_email, task_code, entry_date)
);

CREATE INDEX idx_ts_user_week ON timesheet_entries(user_email, week_start_date);
CREATE INDEX idx_ts_status ON timesheet_entries(status);
CREATE INDEX idx_ts_approver ON timesheet_entries(approver_email) WHERE status = 'SUBMITTED';
CREATE INDEX idx_ts_approval_dashboard ON timesheet_entries(status, approver_email, week_start_date) WHERE status = 'SUBMITTED';
CREATE INDEX idx_ts_user_view ON timesheet_entries(user_email, week_start_date, status);
CREATE INDEX idx_ts_export ON timesheet_entries(week_start_date, status);

-- Seed Data
INSERT INTO users (email, username, name, hrs_per_week, role, created_by, updated_by) VALUES
('user@stardust.com', 'user_standard', 'Standard User', 40.00, 'USER', 'system', 'system'),
('manager@stardust.com', 'manager_one', 'Manager One', 40.00, 'APPROVER', 'system', 'system'),
('admin@stardust.com', 'admin_user', 'Admin User', 40.00, 'ADMIN', 'system', 'system');

INSERT INTO tasks (code, project_or_task, astute_code, approver_email, description, created_by, updated_by) VALUES
('DEV-001', 'Project Alpha | Development', 'AST-1001', 'manager@stardust.com', 'Frontend Development', 'system', 'system'),
('DEV-002', 'Project Alpha | Development', 'AST-1002', 'manager@stardust.com', 'Backend Development', 'system', 'system'),
('MEET-001', 'Internal | Meetings', 'AST-2001', 'manager@stardust.com', 'Team Meetings', 'system', 'system'),
('DES-001', 'Project Alpha | Design', 'AST-1003', 'manager@stardust.com', 'System Design', 'system', 'system'),
('TEST-001', 'Project Alpha | QA', 'AST-1004', 'manager@stardust.com', 'QA & Testing', 'system', 'system');

INSERT INTO user_tasks (user_email, task_code, created_by) VALUES
('user@stardust.com', 'DEV-001', 'system'),
('user@stardust.com', 'DEV-002', 'system'),
('user@stardust.com', 'MEET-001', 'system'),
('manager@stardust.com', 'DEV-001', 'system'),
('manager@stardust.com', 'MEET-001', 'system'),
('manager@stardust.com', 'DES-001', 'system');

INSERT INTO timesheet_entries (
    user_email, task_code, week_start_date, entry_date, 
    hours, notes, status, created_by, updated_by
) VALUES
('user@stardust.com', 'DEV-001', '2025-12-01', '2025-12-01', 8.00, 'Implemented login feature', 'DRAFT', 'user@stardust.com', 'user@stardust.com'),
('user@stardust.com', 'MEET-001', '2025-12-01', '2025-12-01', 1.00, 'Daily standup', 'DRAFT', 'user@stardust.com', 'user@stardust.com');
