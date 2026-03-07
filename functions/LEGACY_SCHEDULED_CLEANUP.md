# Legacy Scheduled Function Cleanup

## Constraint

Firebase still does not support a same-name direct upgrade from gen1 to gen2. For an orphaned scheduled gen1 function such as `ensureDefaultAdminDaily`, the safe cleanup path is:

1. Recreate the missing scheduler wiring with a temporary no-op gen1 shim using the exact legacy export name.
2. Deploy only that single shim with Firebase CLI.
3. Delete the legacy function with Firebase CLI.
4. Restore local source so no temporary shim remains in your codebase.

The existing gen2 functions remain untouched because the deploy step is always scoped to `--only functions:<name>`.

## Automated PowerShell

Run this from the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\functions\cleanup-legacy.ps1 `
  -ProjectId matjark-7ebc7 `
  -Region us-central1 `
  -FunctionNames ensureDefaultAdminDaily
```

Dry run:

```powershell
powershell -ExecutionPolicy Bypass -File .\functions\cleanup-legacy.ps1 `
  -ProjectId matjark-7ebc7 `
  -Region us-central1 `
  -FunctionNames ensureDefaultAdminDaily `
  -DryRun
```

Multiple orphaned scheduled gen1 functions:

```powershell
powershell -ExecutionPolicy Bypass -File .\functions\cleanup-legacy.ps1 `
  -ProjectId matjark-7ebc7 `
  -Region us-central1 `
  -FunctionNames ensureDefaultAdminDaily,anotherLegacyDailyJob,oldHourlySync
```

## Manual Equivalent

If you need to do the same flow manually for `ensureDefaultAdminDaily`, the exact Firebase CLI steps are:

```powershell
firebase deploy --only functions:ensureDefaultAdminDaily --project matjark-7ebc7
firebase functions:delete ensureDefaultAdminDaily --region us-central1 --project matjark-7ebc7 --force
```

The script wraps those commands and temporarily injects the cleanup shim so the first deploy is valid.

## Sample Cleanup Shim

Supported same-name cleanup shim:

```js
import * as logger from "firebase-functions/logger";
import * as functionsV1 from "firebase-functions/v1";

export const ensureDefaultAdminDaily = functionsV1
  .region("us-central1")
  .pubsub.schedule("0 0 1 1 *")
  .timeZone("Etc/UTC")
  .onRun(async () => {
    logger.info("Temporary legacy scheduled cleanup shim invoked.");
    return null;
  });
```

Optional gen2 placeholder with a different name:

```js
import * as logger from "firebase-functions/logger";
import { onSchedule } from "firebase-functions/v2/scheduler";

export const ensureDefaultAdminDailyCleanupV2 = onSchedule(
  {
    region: "us-central1",
    schedule: "0 0 1 1 *",
    timeZone: "Etc/UTC",
  },
  async () => {
    logger.info("Temporary v2 cleanup placeholder invoked.");
  },
);
```

## Safety Notes

- The shim uses `0 0 1 1 *` in `Etc/UTC`, so it is extremely unlikely to execute before deletion.
- The script validates that each target currently appears as a deployed `v1` `scheduled` function before it changes anything.
- Local source is restored in a `finally` block even if deploy or delete fails.
- Existing gen2 functions such as `dailyAdminMaintenanceV2` are not redeployed or modified.
