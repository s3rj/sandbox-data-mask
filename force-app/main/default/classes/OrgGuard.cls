/**
 * The one check that matters most: never rewrite data in production. Organization.IsSandbox is read once
 * per transaction; tests set the override because the test org may not be a sandbox.
 */
public with sharing class OrgGuard {
    public class NotASandboxException extends Exception {
    }

    @TestVisible
    private static Boolean isSandboxOverride;
    private static Boolean cached;

    public static Boolean isSandbox() {
        if (isSandboxOverride != null) {
            return isSandboxOverride;
        }
        if (cached == null) {
            cached = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        }
        return cached;
    }

    public static void requireSandbox() {
        if (!isSandbox()) {
            throw new NotASandboxException('Refusing to mask data: this org is not a sandbox.');
        }
    }
}
