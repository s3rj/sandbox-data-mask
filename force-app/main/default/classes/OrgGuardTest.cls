@IsTest
private class OrgGuardTest {
    @IsTest
    static void refusesWhenTheOrgIsNotASandbox() {
        OrgGuard.isSandboxOverride = false;
        try {
            OrgGuard.requireSandbox();
            Assert.fail('expected NotASandboxException');
        } catch (OrgGuard.NotASandboxException e) {
            Assert.isTrue(e.getMessage().contains('not a sandbox'), 'message explains the refusal');
        }
    }

    @IsTest
    static void passesInASandbox() {
        OrgGuard.isSandboxOverride = true;
        OrgGuard.requireSandbox();
        Assert.isTrue(OrgGuard.isSandbox(), 'override honoured');
    }

    @IsTest
    static void readsTheOrganizationRecordOnceWithoutAnOverride() {
        Boolean first = OrgGuard.isSandbox();
        Integer queriesAfterFirst = Limits.getQueries();
        Boolean second = OrgGuard.isSandbox();
        Assert.areEqual(first, second, 'cached answer is consistent');
        Assert.areEqual(queriesAfterFirst, Limits.getQueries(), 'second call does not query again');
    }
}
