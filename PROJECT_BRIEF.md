# Project: Timesheet MVP (Aggressive Deadline)

**Role:** Act as a Senior Full Stack Architect & Developer.
**Objective:** Build a Timesheet Entry & Approval System MVP.
**Timeline:** 1.5 Weeks (Hackathon Mode).
**Principles:**
1.  **Pragmatic Code:** No over-engineering. Use standard libraries.
2.  **Minimal Boilerplate:** Focus on business logic.
3.  **Manual Deployment Ready:** The output must be ready to build locally and SCP to AWS.

---

## 1. Technical Stack (Strict)

*   **Frontend:**
    *   **Framework:** React 18+ (Vite) + TypeScript.
    *   **UI Library:** Material UI (MUI) v7+.
    *   **Auth Client:** AWS Amplify UI (`@aws-amplify/ui-react`) for Login screens.
    *   **State/Network:** Axios (with Interceptors for Bearer Token).
    *   **Dates:** `date-fns`.
*   **Backend:**
    *   **Framework:** Spring Boot 4.0.0 (Java 25).
    *   **Security:** Spring Security 7 (OAuth2 Resource Server).
    *   **Database:** PostgreSQL 16 (Dockerized).
    *   **ORM:** Spring Data JPA 4.0.x.
    *   **Utils:** Apache Commons CSV (for export), Lombok.
*   **Infrastructure:**
    *   **Auth Provider:** AWS Cognito (User Pool & Groups).
    *   **Hosting:** AWS S3 (Frontend) + AWS EC2 (Backend Docker).

---

## 2. Database Schema (PostgreSQL)

*Do not create migration tools yet. Provide `init.sql` script.*

1.  **`tasks`**: `code` (PK, VARCHAR), `description` (VARCHAR).
2.  **`users`**: `email` (PK, VARCHAR), `username` (VARCHAR), `role` (VARCHAR - 'USER', 'APPROVER', 'ADMIN').
    *   *Note:* Auth is handled by Cognito. This table is for foreign keys and display names only.
3.  **`user_tasks`**: `id` (PK), `user_email` (FK -> users.email), `task_code` (FK -> tasks.code).
4.  **`timesheet_entries`**:
    *   `id` (UUID, PK)
    *   `user_email` (FK -> users.email)
    *   `task_code` (FK -> tasks.code)
    *   `week_start_date` (DATE - Constraint: Must be Monday)
    *   `entry_date` (DATE)
    *   `hours` (DECIMAL 4,2 - Constraint: 0 to 24, 0.25 increments)
    *   `notes` (TEXT)
    *   `status` (VARCHAR - 'DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED')
    *   `rejection_reason` (TEXT, Nullable)
    *   *Constraint:* Unique index on (`user_email`, `task_code`, `entry_date`).

---

## 3. Core Logic & Security Spec

### A. Authentication & Authorization
*   **Frontend:** Amplify handles login. Axios interceptor injects `Authorization: Bearer <JWT>` on every request.
*   **Backend:**
    *   Validate JWT signature against AWS Cognito JWK Set.
    *   **Crucial:** Implement a `JwtAuthenticationConverter` to map **Cognito Groups** to **Spring Roles**:
        *   Cognito `Approver` -> `ROLE_APPROVER`
        *   Cognito `Admin` -> `ROLE_ADMIN`
        *   Default -> `ROLE_USER`

### B. Feature Logic
1.  **Timesheet Entry (User):**
    *   **Grid UI:** Matrix of Rows (Tasks) x Columns (Mon-Sun).
    *   **Logic:**
        *   `Save` -> Upsert records with status `DRAFT`.
        *   `Submit` -> Update all records for that week to `SUBMITTED`. Lock UI.
        *   **Validation:** Daily total <= 24 hours.
2.  **Approval (Approver):**
    *   **Master View:** List of `(User, WeekStart)` pairs with status `SUBMITTED`.
    *   **Detail View:** Read-only Grid.
    *   **Action:** `Approve` (Set status `APPROVED`) or `Reject` (Set status `REJECTED` + Require Reason).
    *   *Rejection Loop:* If Rejected, User sees status `REJECTED` and can edit/re-submit.
3.  **Export (All):**
    *   Stream CSV download via `HttpServletResponse`.
    *   Columns: Staff Name, Week Start, Date, Task, Hours, Notes, Status.

---

## 4. Implementation Plan (Step-by-Step)

**Copilot, please follow this execution order. Do not generate everything at once. Wait for my confirmation after each step.**

*   **Step 1: Frontend Scaffold & Pages.** Generate the React Vite structure, `App.tsx` with Amplify Auth Wrapper, `axios.ts` config, and scaffold all main pages (Timesheet Entry, Approval Dashboard).
*   **Step 2: Frontend Grid Component.** Generate the `TimesheetGrid` component using HTML Tables (for performance) mapped to MUI styles.
*   **Step 3: Infrastructure & DB.** Generate the `docker-compose.yml` for Postgres and the `init.sql` schema script (including seed data for 3 users and 5 tasks).
*   **Step 4: Backend Scaffold.** Generate the Spring Boot Project structure (Controller, Service, Repository packages) and the `SecurityConfig.java` + `JwtConverter.java` for Cognito.
*   **Step 5: Backend API Implementation.** Generate the `TimesheetController` and `ApprovalController` with the Upsert and State Machine logic.

---

**Instruction to Copilot:**
Read the above specification. Start by generating **Step 1** (Frontend Scaffold & Pages).
