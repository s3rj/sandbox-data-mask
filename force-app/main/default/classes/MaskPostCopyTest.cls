@IsTest
private class MaskPostCopyTest {
    @IsTest
    static void masksAsSoonAsTheSandboxCopyFinishes() {
        MaskRuleRepository.ruleOverride = new List<MaskRule>{ new MaskRule('Contact', 'Email', 'Email') };
        MaskRuleRepository.scopeOverride = new List<MaskRuleRepository.ObjectScope>();
        OrgGuard.isSandboxOverride = true;
        Contact copied = new Contact(LastName = 'Copied', Email = 'copied@customer.test');
        insert copied;

        Test.startTest();
        Test.testSandboxPostCopyScript(new MaskPostCopy(), UserInfo.getOrganizationId(), UserInfo.getOrganizationId(), 'masked-sandbox');
        Test.stopTest();

        Assert.areNotEqual('copied@customer.test', [SELECT Email FROM Contact WHERE Id = :copied.Id].Email, 'post-copy run masked the email');
        Assert.areEqual(1, [SELECT COUNT() FROM Mask_Run__c WHERE Status__c = 'Completed'], 'the run was logged');
    }
}
