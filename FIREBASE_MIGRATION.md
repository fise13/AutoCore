## CloudKit → Firebase migration

This document describes how to migrate existing data from CloudKit to Firebase Firestore and then remove CloudKit from the app.

### 1. What to migrate

- **User roles**: records that currently define `role` and `companyId` per user in CloudKit should become documents in `users/{userId}` in Firestore.
- **Financial operations**: records synced via `CloudKitDataSyncService` can be copied into a new Firestore collection (for example, `financialOperations`) keyed by `companyId`.

### 2. Suggested migration approach

1. **Prepare Firebase**:
   - Deploy `firebase/firestore.rules` and `firebase/functions/index.js`.
   - Ensure the `users`, `companies`, `tasks`, and `invites` collections work for new data.
2. **Add a temporary migration mode** in a debug-only build of the macOS app:
   - Create a small service that:
     - Uses existing `CloudKitAuthService.fetchRole` logic to read role and companyId for known users.
     - Writes corresponding `UserDocument` instances via `Firestore.firestore().collection("users")`.
   - For financial operations:
     - Use `CloudKitDataSyncService.pullAndMergeFinancialOperations(companyId:)` to materialize all operations into the local SQLite DB.
     - Iterate over local operations and write them into a Firestore collection (e.g. `financialOperations`) with a `companyId` field.
3. **Run migration once**:
   - Ship a debug build or internal tool that runs the migration on developer machines (or a small number of test users).
   - Verify that:
     - All users have Firestore `users/{userId}` docs with correct `role` and `companyId`.
     - Financial data is present per company in Firestore.

### 3. Switching clients to Firebase

1. Release a version of the app that:
   - Uses `FirebaseAuthService` for authentication.
   - Uses Firestore-backed services for new multi-company features.
2. Ask existing users to sign in again so that:
   - `syncUserClaims` Cloud Function runs for their `users/{userId}` document.
   - Their ID token contains `companyId` and `role` for Firestore security rules.

### 4. Removing CloudKit

After you are satisfied that all relevant data is available in Firestore and clients are working correctly:

1. Delete or exclude from the build:
   - `AutoCore/Infrastructure/Auth/CloudKitAuthService.swift`
   - `AutoCore/Infrastructure/CloudKit/CloudKitDataSyncService.swift`
   - `AutoCore/Infrastructure/CloudKit/CloudKitRoleSeeder.swift`
2. Remove CloudKit capabilities from the Xcode targets:
   - In **Signing & Capabilities**, remove the iCloud / CloudKit capability.
3. Clean up any CloudKit-specific documentation (`APP_STORE_DEPLOY.md` sections about CloudKit roles) or update them to reference Firebase.

