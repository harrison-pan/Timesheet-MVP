# Production Migration Guide: AWS Cognito Integration

This guide details the steps required to move the Stardust Timesheet application from a local development environment (using mock auth) to a production environment using AWS Cognito for authentication.

## 1. AWS Cognito Setup

### 1.1 Create a User Pool
1.  Log in to the AWS Console and navigate to **Amazon Cognito**.
2.  Click **Create user pool**.
3.  **Configure sign-in experience**:
    *   Select **Email** as the sign-in option.
    *   Click Next.
4.  **Configure security requirements**:
    *   Set password policy as needed (e.g., length 8, require numbers/special chars).
    *   Enable MFA if required (optional for now).
    *   Click Next.
5.  **Configure sign-up experience**:
    *   Uncheck "Enable self-registration" if this is an internal app (admins create users).
    *   Add required attributes: `name`, `email`.
    *   Click Next.
6.  **Configure message delivery**:
    *   Select "Send email with Cognito" for testing (limit 50/day) or configure SES for production.
    *   Click Next.
7.  **Integrate your app**:
    *   User pool name: `stardust-users-prod`
    *   Check "Generate a client secret" -> **NO** (Public clients like React apps should NOT use a client secret).
    *   App client name: `stardust-web-client`
    *   Allowed callback URLs: `https://your-production-domain.com`, `http://localhost:5173` (for testing).
    *   Click Next.
8.  **Review and Create**: Review settings and click **Create user pool**.

### 1.2 Create User Groups (Roles)
1.  Go to the newly created User Pool.
2.  Navigate to the **Groups** tab.
3.  Create the following groups (these map to backend roles):
    *   `ADMIN`
    *   `APPROVER`
    *   `TSENTRY` (or `USER`)

### 1.3 Create Users
1.  Go to the **Users** tab.
2.  Click **Create user**.
3.  Enter email (e.g., `admin@example.com`) and temporary password.
4.  After creation, click on the user and add them to the appropriate **Group** (e.g., `ADMIN`).

### 1.4 Get Configuration Values
Note down the following values:
*   **User Pool ID** (e.g., `us-east-1_xxxxxxxxx`)
*   **App Client ID** (e.g., `5xxxxxxxxxxxxxxxxxxxxxxx`)
*   **Region** (e.g., `us-east-1`)
*   **Issuer URI**: `https://cognito-idp.{region}.amazonaws.com/{userPoolId}`

---

## 2. Backend Configuration (`stardust-api`)

The backend is already configured to switch between Dev Mode and Production Mode. You just need to provide the correct configuration.

### 2.1 Update `application-prod.yml`
Create or update `src/main/resources/application-prod.yml`:

```yaml
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}
    username: ${DB_USER}
    password: ${DB_PASS}
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://cognito-idp.${AWS_REGION}.amazonaws.com/${COGNITO_USER_POOL_ID}
          jwk-set-uri: https://cognito-idp.${AWS_REGION}.amazonaws.com/${COGNITO_USER_POOL_ID}/.well-known/jwks.json

app:
  auth:
    dev-mode: false # CRITICAL: Disables the local dev login endpoint
```

### 2.2 Environment Variables
When running the backend in production (e.g., via Docker or EC2), set these environment variables:

*   `SPRING_PROFILES_ACTIVE=prod`
*   `AWS_REGION`: Your AWS region (e.g., `us-east-1`)
*   `COGNITO_USER_POOL_ID`: Your User Pool ID
*   `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASS`: Your RDS database details.
*   `ALLOWED_ORIGINS`: Comma-separated list of allowed frontend domains (e.g., `https://timesheet.stardust.com,http://localhost:5173`).

---

## 3. Frontend Configuration (`stardust-web`)

### 3.1 Environment Variables
Create a `.env.production` file in the project root:

```env
VITE_API_URL=https://api.your-production-domain.com
VITE_USER_POOL_ID=us-east-1_xxxxxxxxx
VITE_USER_POOL_CLIENT_ID=5xxxxxxxxxxxxxxxxxxxxxxx
```

### 3.2 Update `auth.ts` for Production
**Status: ✅ COMPLETED**

The `src/services/auth.ts` file has already been updated to support both Development (localStorage) and Production (AWS Cognito/Amplify) modes.

It automatically detects the mode based on the presence of `VITE_USER_POOL_ID`.

*   **Dev Mode**: Uses `localStorage` for tokens.
*   **Prod Mode**: Uses `aws-amplify/auth` to fetch sessions.

No further code changes are needed here.

### 3.3 Update `axios.ts`
**Status: ✅ COMPLETED**

The `src/api/axios.ts` file has been updated to use `await authService.getToken()`. This ensures it works correctly with both synchronous (localStorage) and asynchronous (Amplify) token retrieval.

No further code changes are needed here.

---

## 4. Database Migration

1.  **Provision RDS**: Create a PostgreSQL instance in AWS RDS.
2.  **Flyway**: The application is configured to run Flyway migrations on startup (`spring.flyway.enabled=true`).
3.  **First Run**: When the backend starts in production for the first time, it will connect to the RDS instance and create all tables automatically.

> **⚠️ Critical Note on Seed Data**: The application currently includes `V2__seed_data.sql` which populates test users (Bill Gates, Elon Musk, etc.). These **WILL** be created in your production database on the first run.
>
> **Action**: If this is a real production deployment, delete `src/main/resources/db/migration/V2__seed_data.sql` before building the backend artifact in Step 5.2.

---

## 5. Deployment Steps

### 5.1 Build Frontend
```bash
cd stardust-web
npm run build
# Output is in /dist folder. Upload this to S3 (Static Website Hosting) or CloudFront.
```

### 5.2 Build Backend
```bash
cd stardust-api
./mvnw clean package -DskipTests
# Output is target/stardust-api-0.0.1-SNAPSHOT.jar
```

### 5.3 Run Backend
```bash
java -jar -Dspring.profiles.active=prod target/stardust-api-0.0.1-SNAPSHOT.jar
```

---

## 6. Architecture & Security Notes

*   **Hybrid Authentication**: The system uses a smart `authService` in the frontend and a conditional `DevAuthController` in the backend.
    *   **Dev Mode**: Uses local mock tokens.
    *   **Prod Mode**: Uses real signed JWTs from AWS Cognito.
*   **Security Context**: In production, `DevAuthController` is completely disabled. The backend validates JWT signatures directly against AWS public keys.
*   **Authorization**: Access control is enforced via data relationships (e.g., "Is this user the assigned approver for this task?") rather than just static role names, ensuring robust security.
*   **User Profiles**: The frontend UI adapts based on the role assigned in the **Database User Profile**, ensuring that UI permissions always match the backend state.

---

## Summary of Effort
*   **Backend**: Minimal changes. Just config. **(Easy)**
*   **Frontend**: Code changes completed. Just need environment variables. **(Easy)**
*   **Infrastructure**: Standard AWS setup (Cognito, RDS, EC2/Fargate). **(Medium)**
