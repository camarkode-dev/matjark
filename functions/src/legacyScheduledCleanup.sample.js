import * as logger from "firebase-functions/logger";
import * as functionsV1 from "firebase-functions/v1";

// Supported cleanup shim for orphaned gen1 scheduled functions.
// Deploy this under the exact legacy export name, then delete the function.

export const ensureDefaultAdminDaily = functionsV1
  .region("us-central1")
  .runWith({
    memory: "256MB",
    timeoutSeconds: 60,
    maxInstances: 1,
  })
  .pubsub.schedule("0 0 1 1 *")
  .timeZone("Etc/UTC")
  .onRun(async () => {
    logger.info("Temporary legacy scheduled cleanup shim invoked.", {
      functionName: "ensureDefaultAdminDaily",
    });
    return null;
  });
