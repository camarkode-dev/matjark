# Firebase Admin Scripts

## Setup

1. Go to [Firebase Console](https://console.firebase.google.com/project/matjark-7ebc7/settings/serviceaccounts/adminsdk)
2. Click "Generate new private key"
3. Download the JSON file and rename it to `serviceAccountKey.json`
4. Place it in this `scripts` directory

## Create Admin User

Run the following command to create the first admin user:

```bash
node create-admin.js admin@matjark.com mypassword123 "Admin User"
```

This will:
- Create a new user in Firebase Auth
- Set admin custom claims
- Create the user document in Firestore

## Important Notes

- Change the password after first login
- Keep the serviceAccountKey.json file secure and never commit it to version control
- Add `serviceAccountKey.json` to your `.gitignore` file