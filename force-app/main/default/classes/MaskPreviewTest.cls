@IsTest
private class MaskPreviewTest {
    private static void useContactRules() {
        MaskRuleRepository.ruleOverride = new List<MaskRule>{
            new MaskRule('Contact', 'Email', 'Email'),
            new MaskRule('Contact', 'Phone', 'Phone')
        };
        MaskRuleRepository.scopeOverride = new List<MaskRuleRepository.ObjectScope>();
        OrgGuard.isSandboxOverride = true;
    }

    @IsTest
    static void showsBeforeAndAfterWithoutWriting() {
        useContactRules();
        insert new List<Contact>{
            new Contact(LastName = 'A', Email = 'a@customer.test', Phone = '602-555-1000'),
            new Contact(LastName = 'B', Email = 'b@customer.test')
        };

        List<MaskPreview.Row> rows = MaskPreview.preview('Contact', 10);

        Assert.areEqual(4, rows.size(), 'two records times two rules');
        Integer blankPhones = 0;
        for (MaskPreview.Row row : rows) {
            if (row.fieldApiName == 'Email') {
                Assert.isTrue(String.valueOf(row.before).endsWith('@customer.test'), 'real value shown');
                Assert.isTrue(String.valueOf(row.after).contains('@example.'), 'fake shown: ' + row.after);
            } else if (row.before == null) {
                blankPhones++;
                Assert.isNull(row.after, 'blank stays blank');
            } else {
                Assert.isTrue(String.valueOf(row.after).contains('555-01'), 'fictional phone: ' + row.after);
            }
        }
        Assert.areEqual(1, blankPhones, 'one contact had no phone');
        Assert.areEqual(2, [SELECT COUNT() FROM Contact WHERE Email LIKE '%@customer.test'], 'nothing was written');

        String report = MaskPreview.report('Contact', 1);
        Assert.isTrue(report.contains('1 record(s), nothing written'), 'sample size honored: ' + report);
        Assert.isTrue(report.contains('->'), 'before and after side by side');
    }

    @IsTest
    static void objectWithoutRulesIsAnError() {
        useContactRules();
        try {
            MaskPreview.preview('Account', 5);
            Assert.fail('expected MaskRunException');
        } catch (SandboxDataMaskRunner.MaskRunException e) {
            Assert.isTrue(e.getMessage().contains('Account'), 'names the object');
        }
    }

    @IsTest
    static void refusesToPreviewOutsideASandbox() {
        useContactRules();
        OrgGuard.isSandboxOverride = false;
        try {
            MaskPreview.preview('Contact', 5);
            Assert.fail('expected NotASandboxException');
        } catch (OrgGuard.NotASandboxException e) {
            Assert.isTrue(e.getMessage().contains('not a sandbox'), 'refusal explained');
        }
    }
}
