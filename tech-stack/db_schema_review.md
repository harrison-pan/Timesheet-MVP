# Database Schema Review & Recommendations

## Overview
This document reviews the proposed database schema against the original PROJECT_BRIEF requirements and provides recommendations for optimization and consistency.

---

## Schema Comparison

### Original PROJECT_BRIEF Schema vs. Proposed Schema

| Aspect | PROJECT_BRIEF | Proposed Schema | Status |
|--------|---------------|-----------------|--------|
| Primary Key for Users | `email` | Not specified (implied `name`) | ⚠️ **Issue** |
| User identification | Email-based | Name-based | ⚠️ **Issue** |
| Approval tracking | Not specified | `approver_name`, `approved_date_time` | ✅ **Enhancement** |
| Submission tracking | Not specified | `submitted_by_name`, `submitted_date_time` | ✅ **Enhancement** |
| Task approver | Not in Tasks table | `approver` field in Tasks | ✅ **Enhancement** |
| Astute integration | Not specified | `astute_code`, `project_or_task` | ✅ **Enhancement** |
| Hours per week | Not specified | Added to Users | ✅ **Enhancement** |

---

## Critical Issues

### 1. **User Identification: Email vs. Name**

> [!CAUTION]
> Using `name` as a primary key is problematic and creates inconsistency with the authentication system.

**Problem:**
- PROJECT_BRIEF uses `email` as PK for Users table
- AWS Cognito authentication is email-based
- Proposed schema uses `name` as identifier
- Names are not guaranteed to be unique

**Recommendation:**
```sql
-- Use email as primary key, add name as display field
CREATE TABLE users (
    email VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    hrs_per_week DECIMAL(5,2),
    role VARCHAR(20) NOT NULL CHECK (role IN ('USER', 'APPROVER', 'ADMIN'))
);
```

### 2. **Foreign Key Consistency**

> [!WARNING]
> All foreign keys referencing users should use `email`, not `name`.

**Current Issues:**
- `TS Entries` references `Staff Name (Users:name)`
- `Tasks` references `Approver (Users:name)`
- `User Tasks` references `User Name (Users:name)`

**Recommendation:**
Update all FK references to use `user_email` instead of `user_name`.

---

## Recommended Schema

### Table: `users`

```sql
CREATE TABLE users (
    email VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    hrs_per_week DECIMAL(5,2) DEFAULT 40.00,
    role VARCHAR(20) NOT NULL CHECK (role IN ('USER', 'APPROVER', 'ADMIN')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_role ON users(role);
```

**Changes from Proposed:**
- ✅ Use `email` as PK (aligns with Cognito)
- ✅ Add `created_at`, `updated_at` for audit trail
- ✅ Add index on `role` for approval queries

---

### Table: `tasks`

```sql
CREATE TABLE tasks (
    code VARCHAR(50) PRIMARY KEY,
    project_or_task VARCHAR(255) NOT NULL,
    astute_code VARCHAR(100),
    approver_email VARCHAR(255),
    description VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (approver_email) REFERENCES users(email) ON DELETE SET NULL
);

CREATE INDEX idx_tasks_approver ON tasks(approver_email);
```

**Changes from Proposed:**
- ✅ Renamed `Approver` to `approver_email` for consistency
- ✅ Added `description` field (was in PROJECT_BRIEF)
- ✅ Added FK constraint with `ON DELETE SET NULL`
- ✅ Add index on `approver_email` for approval queries

---

### Table: `user_tasks`

```sql
CREATE TABLE user_tasks (
    id SERIAL PRIMARY KEY,
    user_email VARCHAR(255) NOT NULL,
    task_code VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_email) REFERENCES users(email) ON DELETE CASCADE,
    FOREIGN KEY (task_code) REFERENCES tasks(code) ON DELETE CASCADE,
    UNIQUE (user_email, task_code)
);

CREATE INDEX idx_user_tasks_user ON user_tasks(user_email);
CREATE INDEX idx_user_tasks_task ON user_tasks(task_code);
```

**Changes from Proposed:**
- ✅ Added `id` as surrogate PK
- ✅ Renamed `User Name` to `user_email`
- ✅ Renamed `Task code` to `task_code` (snake_case)
- ✅ Added UNIQUE constraint to prevent duplicates
- ✅ Added indexes for both FKs

---

### Table: `timesheet_entries`

```sql
CREATE TABLE timesheet_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_email VARCHAR(255) NOT NULL,
    task_code VARCHAR(50) NOT NULL,
    week_start_date DATE NOT NULL,
    entry_date DATE NOT NULL,
    hours DECIMAL(4,2) NOT NULL CHECK (hours >= 0 AND hours <= 24 AND MOD(hours * 4, 1) = 0),
    notes TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED')),
    rejection_reason TEXT,
    approver_email VARCHAR(255),
    approved_at TIMESTAMP,
    submitted_by_email VARCHAR(255),
    submitted_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_email) REFERENCES users(email) ON DELETE CASCADE,
    FOREIGN KEY (task_code) REFERENCES tasks(code) ON DELETE RESTRICT,
    FOREIGN KEY (approver_email) REFERENCES users(email) ON DELETE SET NULL,
    FOREIGN KEY (submitted_by_email) REFERENCES users(email) ON DELETE SET NULL,
    CONSTRAINT week_start_is_monday CHECK (EXTRACT(DOW FROM week_start_date) = 1),
    CONSTRAINT entry_within_week CHECK (entry_date >= week_start_date AND entry_date <= week_start_date + INTERVAL '6 days'),
    UNIQUE (user_email, task_code, entry_date)
);

CREATE INDEX idx_ts_user_week ON timesheet_entries(user_email, week_start_date);
CREATE INDEX idx_ts_status ON timesheet_entries(status);
CREATE INDEX idx_ts_approver ON timesheet_entries(approver_email) WHERE status = 'SUBMITTED';
```

**Changes from Proposed:**
- ✅ Renamed all `*_name` fields to `*_email`
- ✅ Renamed `Approved Date Time` to `approved_at` (snake_case)
- ✅ Renamed `Submitted Date Time` to `submitted_at` (snake_case)
- ✅ Added constraint for quarter-hour increments
- ✅ Added constraint to ensure `entry_date` is within the week
- ✅ Added `created_at`, `updated_at` for audit trail
- ✅ Added strategic indexes for common queries
- ✅ Added partial index on `approver_email` for pending approvals

---

## Additional Recommendations

### 1. **Naming Conventions**

> [!TIP]
> Use consistent snake_case for all column names to match PostgreSQL conventions.

**Apply to all tables:**
- `Week Start` → `week_start_date`
- `Staff Name` → `user_email`
- `Task Code` → `task_code`
- `Approver Name` → `approver_email`

### 2. **Audit Trail**

> [!IMPORTANT]
> Add `created_at` and `updated_at` to all tables for debugging and compliance.

### 3. **Data Integrity**

**Add constraints:**
- ✅ `CHECK` constraints for enums (role, status)
- ✅ `CHECK` constraint for hours (0-24, 0.25 increments)
- ✅ `CHECK` constraint for week_start_date (must be Monday)
- ✅ `UNIQUE` constraint on `(user_email, task_code, entry_date)`

### 4. **Performance Indexes**

**Critical indexes for common queries:**
```sql
-- For approval dashboard (submitted timesheets)
CREATE INDEX idx_ts_approval_dashboard 
ON timesheet_entries(status, approver_email, week_start_date) 
WHERE status = 'SUBMITTED';

-- For user timesheet view
CREATE INDEX idx_ts_user_view 
ON timesheet_entries(user_email, week_start_date, status);

-- For export queries
CREATE INDEX idx_ts_export 
ON timesheet_entries(week_start_date, status);
```

### 5. **Missing Fields Consideration**

> [!NOTE]
> Consider adding these optional fields for future enhancements:

- `users.is_active` (BOOLEAN) - for soft deletion
- `tasks.is_active` (BOOLEAN) - for archiving tasks
- `timesheet_entries.last_modified_by_email` - for audit trail

---

## Migration Path from PROJECT_BRIEF Schema

If you've already implemented the PROJECT_BRIEF schema:

1. **Add new columns** to existing tables
2. **Migrate data** from `name` references to `email` references
3. **Add constraints** and indexes
4. **Update application code** to use new field names

---

## Summary of Key Changes

| Change | Reason | Impact |
|--------|--------|--------|
| Use `email` as user identifier | Aligns with Cognito auth | **High** - Affects all FKs |
| Snake_case naming | PostgreSQL convention | **Medium** - Code updates needed |
| Add audit timestamps | Debugging & compliance | **Low** - Non-breaking addition |
| Add strategic indexes | Query performance | **Medium** - Improves performance |
| Add data constraints | Data integrity | **Medium** - Prevents bad data |

---

## Local Development Environment

### Cross-Platform PostgreSQL Setup (macOS & Windows 11)

> [!IMPORTANT]
> Use Docker to ensure consistent PostgreSQL environment across all development platforms.

#### Prerequisites

- **Docker Desktop** (macOS or Windows 11)
- **Docker Compose** (included with Docker Desktop)

#### Docker Compose Configuration

**File: `docker-compose.yml`** (in project root)

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    container_name: stardust-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: stardust_timesheet
      POSTGRES_USER: stardust_user
      POSTGRES_PASSWORD: dev_password_123
      POSTGRES_INITDB_ARGS: "-E UTF8 --locale=en_US.UTF-8"
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U stardust_user -d stardust_timesheet"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
    driver: local
```

#### Local Development Commands

```bash
# Start PostgreSQL
docker-compose up -d

# View logs
docker-compose logs -f postgres

# Stop PostgreSQL
docker-compose down

# Stop and remove data (fresh start)
docker-compose down -v

# Access PostgreSQL CLI
docker exec -it stardust-postgres psql -U stardust_user -d stardust_timesheet

# Run SQL script manually
docker exec -i stardust-postgres psql -U stardust_user -d stardust_timesheet < init.sql
```

#### Connection Strings

**Local Development:**
```
postgresql://stardust_user:dev_password_123@localhost:5432/stardust_timesheet
```

**Spring Boot `application-dev.properties`:**
```properties
spring.datasource.url=jdbc:postgresql://localhost:5432/stardust_timesheet
spring.datasource.username=stardust_user
spring.datasource.password=dev_password_123
spring.jpa.hibernate.ddl-auto=validate
spring.jpa.show-sql=true
```

**Production (AWS RDS):**
```
postgresql://<username>:<password>@<rds-endpoint>:5432/stardust_timesheet
```

#### Environment-Specific Configuration

**File: `.env.local`** (for local development, not committed)

```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=stardust_timesheet
DB_USER=stardust_user
DB_PASSWORD=dev_password_123

# Cognito (for local testing with real Cognito)
VITE_USER_POOL_ID=us-east-1_xxxxxxxxx
VITE_USER_POOL_CLIENT_ID=xxxxxxxxxxxxxxxxx
VITE_API_URL=http://localhost:8080/api
```

**File: `.env.production`** (for AWS deployment)

```bash
# Database
DB_HOST=<rds-endpoint>.rds.amazonaws.com
DB_PORT=5432
DB_NAME=stardust_timesheet
DB_USER=<production-user>
DB_PASSWORD=<secure-password>

# Cognito
VITE_USER_POOL_ID=<production-pool-id>
VITE_USER_POOL_CLIENT_ID=<production-client-id>
VITE_API_URL=https://api.yourdomain.com
```

---

## PostgreSQL Version Compatibility

### Target Version: PostgreSQL 16

**Features Used:**
- `gen_random_uuid()` - Built-in UUID generation (Postgres 13+)
- `CHECK` constraints
- Partial indexes
- `ON DELETE CASCADE/SET NULL`

**Compatibility Notes:**
- ✅ Works on PostgreSQL 16 (recommended for AWS RDS compatibility)
- ✅ Compatible with AWS RDS PostgreSQL 16.x
- ✅ Compatible with local Docker PostgreSQL 16-alpine

---

## Database Migration Strategy

### For Local Development

1. **Initial Setup:**
   ```bash
   docker-compose up -d
   # Database auto-initializes with init.sql
   ```

2. **Schema Changes:**
   - Update `init.sql`
   - Recreate database: `docker-compose down -v && docker-compose up -d`

### For Production (AWS RDS)

1. **Initial Deployment:**
   - Create RDS PostgreSQL 15.x instance
   - Run `init.sql` via psql or pgAdmin
   - Configure security groups

2. **Schema Updates:**
   - Use migration scripts (numbered: `001_add_field.sql`, etc.)
   - Apply manually via RDS Query Editor or psql
   - Consider using Flyway/Liquibase for future versions

---

## Next Steps

1. ✅ Review and approve this schema design
2. ⏭️ Create `docker-compose.yml` for local development
3. ⏭️ Generate `init.sql` with recommended schema + seed data
4. ⏭️ Update TypeScript types to match new schema
5. ⏭️ Update `mockStorage.ts` to align with new field names
6. ⏭️ Proceed to Step 3: Infrastructure & DB implementation
