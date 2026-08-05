# Admin account setup (Firestore Database)

The administrator role is **not** added inside `firestore.rules`.  
Rules only **check** the role; you store it in a **user document** in Firestore.

## Step 1 — Create Firebase Auth user

1. Open [Firebase Console](https://console.firebase.google.com/) → your project.
2. **Build** → **Authentication** → **Users** → **Add user**.
3. Email: `admin@neighborhelp.com`  
   Password: `admin123` (or your own; update `lib/config/admin_config.dart` if you change it).
4. After creating, **copy the User UID** (long string like `xYz123AbC...`).

## Step 2 — Create the Firestore user document

1. **Build** → **Firestore Database** → **Data**.
2. Open collection **`users`** (create it if empty).
3. **Add document** with **Document ID** = the UID from Step 1 (must match exactly).
4. Add these fields (use your console’s field types):

| Field | Type | Value |
|-------|------|--------|
| `fullName` | string | `System Administrator` |
| `email` | string | `admin@neighborhelp.com` |
| `role` | string | `Administrator` |
| `accountStatus` | string | `Active` |
| `contactNumber` | null | *(leave empty / null)* |
| `profilePhotoUrl` | null | *(optional)* |
| `address` | null | *(optional)* |
| `location` | null | *(optional)* |
| `country` | null | *(optional)* |
| `marketingOptIn` | boolean | `false` |
| `createdAt` | timestamp | *(now)* |
| `updatedAt` | timestamp | *(now)* |
| `lastActive` | timestamp | *(now)* |

### Example (JSON view)

If your console has “JSON” or you import via CLI, the document looks like:

```json
{
  "fullName": "System Administrator",
  "email": "admin@neighborhelp.com",
  "role": "Administrator",
  "accountStatus": "Active",
  "contactNumber": null,
  "profilePhotoUrl": null,
  "address": null,
  "location": null,
  "country": null,
  "marketingOptIn": false,
  "createdAt": "<server timestamp>",
  "updatedAt": "<server timestamp>",
  "lastActive": "<server timestamp>"
}
```

**Important:** `role` must be exactly `Administrator` (same spelling as in the app).

## Step 3 — Deploy rules (if you changed them)

From the project root:

```bash
firebase deploy --only firestore:rules
```

## Step 4 — Sign in to the app

1. Run the app.
2. Log in with username **`admin`** and password **`admin123`**.
3. You should land in **Admin Console** with live Firestore data (not “Preview only”).

## Troubleshooting

| Problem | Fix |
|---------|-----|
| “Preview only” banner | Auth user missing, wrong password, or `users/{uid}.role` is not `Administrator`. |
| Permission denied in admin tables | UID in `users` doc must match Auth UID; deploy rules; sign out and sign in again. |
| Still routes to Customer/Provider | `role` field typo (e.g. `admin` vs `Administrator`). |

## What `firestore.rules` already does

When `users/{your-uid}.role == 'Administrator'`, `isAdmin()` allows admins to:

- Read/update any **users** document  
- Read/update any **serviceProviders** document  
- Read/update/delete any **services** document  
- Read/update any **bookings** document  
- Update/delete **reviews**

No extra rule entry is required for the JSON above—only the **database document**.
