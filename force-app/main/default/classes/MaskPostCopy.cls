/**
 * Hook for Setup > Sandboxes. Pick this class in the "Apex Class" field when creating or refreshing a sandbox
 * and the mask runs as soon as the copy finishes, before the first tester logs in.
 */
@SuppressWarnings('PMD.AvoidGlobalModifier') // SandboxPostCopy implementations must be global
global with sharing class MaskPostCopy implements SandboxPostCopy {
    global void runApexClass(SandboxContext context) {
        SandboxDataMaskRunner.run();
    }
}
