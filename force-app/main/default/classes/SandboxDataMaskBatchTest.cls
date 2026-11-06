@IsTest
private class SandboxDataMaskBatchTest {
    private static void useContactRules() {
        MaskRuleRepository.ruleOverride = new List<MaskRule>{
            new MaskRule('Contact', 'FirstName', 'FirstName').withOrder(1),
            new MaskRule('Contact', 'LastName', 'LastName').withOrder(2),
            new MaskRule('Contact', 'Email', 'Email').withOrder(3),
            new MaskRule('Contact', 'Phone', 'Phone').withOrder(4),
            new MaskRule('Contact', 'Description', 'Null').withOrder(5)
        };
        MaskRuleRepository.scopeOverride = new List<MaskRuleRepository.ObjectScope>();
        OrgGuard.isSandboxOverride = true;
    }

    private static List<Contact> insertContacts(Integer count) {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < count; i++) {
            contacts.add(new Contact(
                FirstName = 'Real' + i,
                LastName = 'Person' + i,
                Email = 'real' + i + '@customer.test',
                Phone = '602-555-' + (1000 + i),
                Description = 'notes about a real person'
            ));
        }
        insert contacts;
        return contacts;
    }

    @IsTest
    static void masksEveryConfiguredFieldAndLogsTheRun() {
        useContactRules();
        List<Contact> contacts = insertContacts(25);
        Contact bare = new Contact(LastName = 'NoContactInfo');
        insert bare;

        Test.startTest();
        Id runId = SandboxDataMaskRunner.run();
        Test.stopTest();

        Map<Id, Contact> masked = new Map<Id, Contact>(
            [SELECT FirstName, LastName, Email, Phone, Description FROM Contact WHERE Id IN :contacts]
        );
        for (Contact original : contacts) {
            Contact after = masked.get(original.Id);
            Assert.areNotEqual(original.FirstName, after.FirstName, 'first name masked');
            Assert.areNotEqual(original.LastName, after.LastName, 'last name masked');
            Assert.areNotEqual(original.Email, after.Email, 'email masked');
            Assert.isTrue(after.Email.endsWith('.com') || after.Email.endsWith('.net') || after.Email.endsWith('.org'), 'reserved domain: ' + after.Email);
            Assert.isTrue(after.Phone.contains('555-01'), 'fictional phone: ' + after.Phone);
            Assert.isNull(after.Description, 'Null strategy clears the field');
        }
        Contact bareAfter = [SELECT FirstName, LastName, Email, Phone FROM Contact WHERE Id = :bare.Id];
        Assert.isNull(bareAfter.Email, 'blank email stays blank');
        Assert.isNull(bareAfter.Phone, 'blank phone stays blank');
        Assert.areNotEqual('NoContactInfo', bareAfter.LastName, 'populated field still masked');

        Mask_Run__c run = [
            SELECT Status__c, Object_API_Name__c, Fields_Masked__c, Records_Processed__c, Records_Failed__c, Batch_Failures__c, Batch_Job_Id__c, Started__c, Finished__c, Error_Summary__c, Run_Group__c
            FROM Mask_Run__c
            WHERE Id = :runId
        ];
        Assert.areEqual('Completed', run.Status__c, 'run completed');
        Assert.areEqual(36, run.Run_Group__c.length(), 'run group recorded');
        Assert.areEqual('Sandbox data mask finished', MaskRunNotifier.lastTitle, 'the user was notified');
        Assert.isTrue(MaskRunNotifier.lastBody.contains('26 records masked'), 'totals in the notification: ' + MaskRunNotifier.lastBody);
        Assert.isNull(MaskRunNotifier.lastError, 'notification sent: ' + MaskRunNotifier.lastError);
        Assert.areEqual('Contact', run.Object_API_Name__c, 'object recorded');
        Assert.areEqual('FirstName, LastName, Email, Phone, Description', run.Fields_Masked__c, 'fields recorded');
        Assert.areEqual(26, run.Records_Processed__c.intValue(), 'every record counted');
        Assert.areEqual(0, run.Records_Failed__c.intValue(), 'no failures');
        Assert.areEqual(0, run.Batch_Failures__c.intValue(), 'no batch failures');
        Assert.isNotNull(run.Batch_Job_Id__c, 'job id recorded');
        Assert.isNotNull(run.Started__c, 'start time recorded');
        Assert.isNotNull(run.Finished__c, 'finish time recorded');
        Assert.isNull(run.Error_Summary__c, 'no errors');
    }

    @IsTest
    static void theSameSourceValueGetsTheSameFakeOnDifferentRecords() {
        useContactRules();
        List<Contact> twins = new List<Contact>{
            new Contact(FirstName = 'Jo', LastName = 'Same', Email = 'shared@customer.test'),
            new Contact(FirstName = 'Jo', LastName = 'Same', Email = 'shared@customer.test'),
            new Contact(FirstName = 'Al', LastName = 'Other', Email = 'other@customer.test')
        };
        insert twins;

        Test.startTest();
        SandboxDataMaskRunner.run();
        Test.stopTest();

        Map<Id, Contact> masked = new Map<Id, Contact>([SELECT FirstName, LastName, Email FROM Contact WHERE Id IN :twins]);
        Assert.areEqual(masked.get(twins[0].Id).Email, masked.get(twins[1].Id).Email, 'same source email, same fake');
        Assert.areEqual(masked.get(twins[0].Id).FirstName, masked.get(twins[1].Id).FirstName, 'same source name, same fake');
        Assert.areNotEqual(masked.get(twins[0].Id).Email, masked.get(twins[2].Id).Email, 'different source, different fake');
    }

    @IsTest
    static void whereClauseLimitsTheScope() {
        MaskRuleRepository.ruleOverride = new List<MaskRule>{ new MaskRule('Contact', 'Email', 'Email') };
        MaskRuleRepository.scopeOverride = new List<MaskRuleRepository.ObjectScope>{
            new MaskRuleRepository.ObjectScope('Contact', 'LastName = \'InScope\'', 1, true)
        };
        OrgGuard.isSandboxOverride = true;
        Contact inScope = new Contact(LastName = 'InScope', Email = 'in@customer.test');
        Contact outOfScope = new Contact(LastName = 'OutOfScope', Email = 'out@customer.test');
        insert new List<Contact>{ inScope, outOfScope };

        Test.startTest();
        Id runId = SandboxDataMaskRunner.run();
        Test.stopTest();

        Assert.areNotEqual('in@customer.test', [SELECT Email FROM Contact WHERE Id = :inScope.Id].Email, 'in-scope record masked');
        Assert.areEqual('out@customer.test', [SELECT Email FROM Contact WHERE Id = :outOfScope.Id].Email, 'out-of-scope record untouched');
        Assert.areEqual(1, [SELECT Records_Processed__c FROM Mask_Run__c WHERE Id = :runId].Records_Processed__c.intValue(), 'one record processed');
    }

    @IsTest
    static void refusesToRunOutsideASandbox() {
        useContactRules();
        OrgGuard.isSandboxOverride = false;
        try {
            SandboxDataMaskRunner.run();
            Assert.fail('expected NotASandboxException');
        } catch (OrgGuard.NotASandboxException e) {
            Assert.isTrue(e.getMessage().contains('not a sandbox'), 'refusal explained');
        }
        Assert.areEqual(0, [SELECT COUNT() FROM Mask_Run__c WHERE CreatedDate = TODAY], 'nothing was queued');
    }

    @IsTest
    static void failsFastOnMisconfiguration() {
        MaskRuleRepository.ruleOverride = new List<MaskRule>{ new MaskRule('Contact', 'Not_A_Field__c', 'Email') };
        MaskRuleRepository.scopeOverride = new List<MaskRuleRepository.ObjectScope>();
        OrgGuard.isSandboxOverride = true;
        try {
            SandboxDataMaskRunner.run();
            Assert.fail('expected ConfigException');
        } catch (MaskPlan.ConfigException e) {
            Assert.isTrue(e.getMessage().contains('Not_A_Field__c'), 'names the bad field');
        }
        Assert.areEqual(0, [SELECT COUNT() FROM Mask_Run__c WHERE CreatedDate = TODAY], 'nothing was queued');
    }

    @IsTest
    static void nothingToMaskIsAnError() {
        MaskRuleRepository.ruleOverride = new List<MaskRule>();
        MaskRuleRepository.scopeOverride = new List<MaskRuleRepository.ObjectScope>();
        OrgGuard.isSandboxOverride = true;
        try {
            SandboxDataMaskRunner.run();
            Assert.fail('expected MaskRunException');
        } catch (SandboxDataMaskRunner.MaskRunException e) {
            Assert.isTrue(e.getMessage().contains('no active Mask Rule'), 'explains the empty plan');
        }
    }

    @IsTest
    static void flowEntryPointQueuesTheRun() {
        useContactRules();
        insertContacts(3);
        SandboxDataMaskRunner.Request request = new SandboxDataMaskRunner.Request();
        request.batchSize = 50;

        Test.startTest();
        List<Id> runIds = SandboxDataMaskRunner.runFromFlow(new List<SandboxDataMaskRunner.Request>{ request });
        Test.stopTest();

        Assert.areEqual(1, runIds.size(), 'one run id per invocation');
        Assert.areEqual('Completed', [SELECT Status__c FROM Mask_Run__c WHERE Id = :runIds[0]].Status__c, 'run completed');
    }

    @IsTest
    static void saltIsGeneratedOnceAndReused() {
        String first = SandboxDataMaskRunner.resolveSalt();
        String second = SandboxDataMaskRunner.resolveSalt();
        Assert.areEqual(32, first.length(), '128-bit salt as hex');
        Assert.areEqual(first, second, 'the stored salt is reused');
        Assert.areEqual(first, Mask_Settings__c.getOrgDefaults().Salt__c, 'salt persisted in Mask Settings');
    }
}
