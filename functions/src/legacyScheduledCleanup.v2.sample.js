import * as logger from "firebase-functions/logger";
import { onSchedule } from "firebase-functions/v2/scheduler";

// Optional placeholder only.
// Firebase does not support deploying this under the same name as an existing
// gen1 function. Use a different export name until the gen1 function is deleted.

export const ensureDefaultAdminDailyCleanupV2 = onSchedule(
  {
    region: "us-central1",
    schedule: "0 0 1 1 *",
    timeZone: "Etc/UTC",
    memory: "256MiB",
    maxInstances: 1,
    timeoutSeconds: 60,
  },
  async () => {
    logger.info("Temporary v2 cleanup placeholder invoked.", {
      functionName: "ensureDefaultAdminDailyCleanupV2",
    });
  },
);
