@IsTest
private class MaskRunNotifierTest {
    @IsTest
    static void summarizesEveryObjectInTheRun() {
        insert new List<Mask_Run__c>{
            new Mask_Run__c(Run_Group__c = 'g1', Object_API_Name__c = 'Contact', Status__c = 'Completed', Records_Processed__c = 1200, Records_Failed__c = 0, Batch_Failures__c = 0),
            new Mask_Run__c(Run_Group__c = 'g1', Object_API_Name__c = 'Lead', Status__c = 'Completed with errors', Records_Processed__c = 300, Records_Failed__c = 4, Batch_Failures__c = 0),
            new Mask_Run__c(Run_Group__c = 'other', Object_API_Name__c = 'Case', Status__c = 'Completed', Records_Processed__c = 999, Records_Failed__c = 0, Batch_Failures__c = 0)
        };

        MaskRunNotifier.runFinished('g1');

        Assert.areEqual('Sandbox data mask finished with errors', MaskRunNotifier.lastTitle, 'errors in the title');
        Assert.isTrue(MaskRunNotifier.lastBody.contains('2 objects'), 'objects counted: ' + MaskRunNotifier.lastBody);
        Assert.isTrue(MaskRunNotifier.lastBody.contains('1,500 records masked'), 'records summed: ' + MaskRunNotifier.lastBody);
        Assert.isTrue(MaskRunNotifier.lastBody.contains('4 failed'), 'failures summed: ' + MaskRunNotifier.lastBody);
        Assert.isFalse(MaskRunNotifier.lastBody.contains('999'), 'other runs excluded');
        Assert.isNull(MaskRunNotifier.lastError, 'notification sent: ' + MaskRunNotifier.lastError);
    }

    @IsTest
    static void cleanRunGetsACleanTitle() {
        insert new Mask_Run__c(Run_Group__c = 'g2', Object_API_Name__c = 'Contact', Status__c = 'Completed', Records_Processed__c = 1, Records_Failed__c = 0, Batch_Failures__c = 0);

        MaskRunNotifier.runFinished('g2');

        Assert.areEqual('Sandbox data mask finished', MaskRunNotifier.lastTitle, 'no errors');
        Assert.isTrue(MaskRunNotifier.lastBody.startsWith('1 object, 1 records masked'), 'singular object: ' + MaskRunNotifier.lastBody);
    }

    @IsTest
    static void unknownGroupSendsNothing() {
        MaskRunNotifier.runFinished('nope');
        MaskRunNotifier.runFinished(null);

        Assert.isNull(MaskRunNotifier.lastTitle, 'nothing to say');
    }
}
