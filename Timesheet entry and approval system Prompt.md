# Role

Act as a Senior Java Full Stack Architect. I need to scaffold a Timesheet MVP.

# 总体目标

Timesheet entry and approval system and Query to download a csv file export on TS Entries table.
Targeting an aggressive MVP release with a focus on speed, stability, and core functionality.

# 界面元素

## Login Screen

- **Integration:** Use AWS Amplify UI Authenticator connected to AWS Cognito.
- **Roles:**
  - **TS Entry:** Can enter, save, and submit only their own time.
  - **Approver:** TS Entry roles, plus can view, approve, or reject timesheets for assigned users.
  - **Admin:** Full access to everything (handled via Database scripts for MVP).

## Screen: Timesheet entry

Allows users to enter, modify or remove TS entries. Displays all their TS entries except approved entries.

1. **User name:** Display of username for TS Entry Role. Selection of usernames for all other roles (if applicable).
2. **Week start date:** Select from calendar or manual entry (Default to current week Monday).
3. **A Table (Data Grid):**
   - **Columns:**
     1. **TS Entries (Task):**
        - Task description selection from a list.
        - Valid Task Descriptions are: `select from Task Code from User Tasks where User Name = sys.username`.
        - Validation: People cannot add the same task on different rows for the same date.
     2. **Date:** Drop down list with 7 days in it (Mon-Sun) OR a Matrix view (Tasks x Days) if technically more efficient for entry.
     3. **Hours:** >0, <=24, whole or quarter hours (0.25). Validation: All of day total hours <= 24.
     4. **Notes:** Required field.
     5. **Status:** Read-only display.
4. **Save Button:**
   - Save the TS Entries as records.
   - Logic: Each entered value inserts, updates, or deletes a row in the `TS Entries` table.
   - Status set to "Draft".
5. **Submit Button:**
   - Saves the changes made.
   - Updates all `TS Entries` records for that week with `submitted_by` and `submitted_date`.
   - Logic: Locks the entries from further editing unless rejected.

## Timesheet Approval Screen

Timesheets to be approved by the approver listed in the task table.

1. **Master block:**
   - List of users with TS waiting for approval.
   - Display one line per user/week.
2. **Detail block:**
   - When person/week is selected, list each TS entry.
   - Display: Task description, hours, notes, and rejection reason.
   - Controls: Approval or Reject button for the TS Entry.
   - Sorting: Sort in order of Task description then date.
3. **Submit All button:**
   - Submits anything that has not been already approved or rejected in the currently selected detail block.

## Query Screen: Export TS Entries to CSV

Query to download a csv file export on TS Entries table. Backend should stream this data.

- **Columns:**
  - Staff_Name (Users:name)
  - Task_Code (Task:Code)
  - Date
  - Note
  - Week Start (Monday)
  - Hours (0 to 24, quarter hour intervals)
  - Status (Draft, Submitted, Rejected, Approved)
- **Filters (Any filter left blank means no filter):**
  - Staff_Name
  - Task_Code (Tasks:Code)
  - Task Description (Tasks: description, queried by Task code)
  - Date range
  - Week Start range
  - Status (Draft, Submitted, Rejected, Approved)

# 功能与交互逻辑

1. **保存 vs 提交 (Save vs Submit)**

   - **保存按钮:** 允许用户保存他们的时间条目而不提交审核 (Status = Draft)。
   - **提交按钮:** 将保存更改并将条目标记为已提交 (Status = Submitted)，触发审批流程，并锁定前端编辑权限。

2. **审批流程 (Approval Workflow)**

   - **查看:** 审批者可以查看待审批的时间条目 (Status = Submitted)。
   - **操作:** 逐条批准 (Status = Approved) 或拒绝 (Status = Rejected)。
   - **拒绝逻辑:** 拒绝时必须记录 Rejection Reason。状态变更为 Rejected 后，填报人可以在“填报页面”看到该条目重新变为可编辑状态，修改后可再次提交。

3. **数据导出 (Data Export)**
   - 用户可以通过查询界面导出符合条件的时间条目为 CSV 文件。
   - 后端 API (Spring Boot) 应处理流式响应以支持大量数据导出。

**Core Tech Stack**

- **Frontend:** React (Vite) + TypeScript + MUI (Material UI v5).
- **Backend:** Spring Boot 3.x (Java 17+) + Spring Data JPA + Spring Security (OAuth2 Resource Server).
- **Database:** PostgreSQL 15+ (Dockerized).
- **Auth:** AWS Cognito (Authentication) + AWS Amplify (Frontend SDK). Backend must validate JWT and map Cognito Groups to Spring Roles.
- **Deployment:** AWS S3 (Frontend) + AWS EC2 (Backend/DB).

**Non-functional Requirements**

- **User Base:** Up to 60 users, 40 concurrent logged on, 5 concurrent transactions.
- **Availability:** 98% uptime. System can be taken offline for maintenance (No maintenance page required for MVP).
- **Concurrency:** Database must support Row Level Locking (Postgres supports this natively).
- **Backup:** Data must be backed up daily (via Docker volume dump script).
- **Security:**
  - Stateless JWT Authentication via Cognito.
  - Roles managed via Cognito Groups (User, Approver, Admin).
- **Operations:**
  - Cloud base, budget operational costs (AWS Free Tier eligible services where possible).
  - No data load screens for MVP. All data (Users, Tasks, Assignments) is loaded directly to the database from CSV files/SQL scripts by Admin.
  - `TS Entries` is the only table that gets records inserted by the system app.
- **Future Proofing:** Code structure should support adding Scheduled Jobs (Email/Extracts) in future versions.

# 界面风格

- **Reference:** BigTime Enterprise PSA style (Professional, Clean, B2B SaaS look).
- **Language:** English interface.
- **Layout:**
  - Clean navigation bar (Left or Top).
  - High visual feedback for interactive elements (Buttons, Inputs).
  - Clear error toasts (Red) and success messages (Green).
- **Performance:** Optimistic UI updates where possible.
- **Responsiveness:** Primary focus on Desktop/Laptop web usage.

# Integration Logic (Cognito -> Spring Boot)

- The backend must be configured as an OAuth2 Resource Server.
- It must validate JWT tokens issued by AWS Cognito.
- **Role Mapping:** Implement a `JwtAuthenticationConverter` to map "Cognito Groups" (claims) to Spring Security Roles:
  - Cognito Group `Admin` -> `ROLE_ADMIN`
  - Cognito Group `Approver` -> `ROLE_APPROVER`
  - Default -> `ROLE_USER`

# Database Schema (Postgres)

1. **Users:** (Optional, mainly for local linking) id (UUID), email, username.
   _Note: Auth is handled by Cognito, but we may need a local reference for foreign keys._
2. **Tasks:** code (PK), description.
3. **UserTasks:** Mapping table (user_email -> task_code).
4. **TimesheetEntries:** id, user_email, task_code, week_start_date, entry_date, hours, notes, status, rejection_reason.

# Feature Requirements (MVP)

1. **Login:** Use AWS Amplify UI components (`<Authenticator>`) in React.
2. **Entry Screen:**
   - Fetch tasks assigned to the logged-in user (JWT Email claim).
   - Grid view for Monday-Sunday entry.
   - Save (Draft) vs Submit (Update status to SUBMITTED).
3. **Approval Screen:**
   - `@PreAuthorize("hasRole('APPROVER')")`
   - View pending submissions.
   - Batch Approve/Reject logic.
4. **Export:**
   - Endpoint to stream CSV data based on filters.

# Deliverables

1. **Spring Boot Security Config:** The `SecurityFilterChain` Java code specifically for Cognito JWT validation and Role Mapping.
2. **PostgreSQL DDL:** Init SQL script.
3. **React API Client:** An Axios instance setup that automatically attaches the `Authorization: Bearer token` from the Amplify current session.
4. **Docker Compose:** Setup for PostgreSQL and the App.

# Context

We are experienced devs. Focus on the configuration code (Security, Axios Interceptors, Database properties) rather than basic boilerplate.
