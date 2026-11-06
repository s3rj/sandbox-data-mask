/**
 * Tells the user who started a run that it is finished, with the totals across every object in the run, through
 * a Lightning (bell) notification on desktop and mobile. Email would not arrive from most sandboxes, where
 * deliverability is "System email only" after a refresh; a custom notification does.
 */
public with sharing class MaskRunNotifier {
    public static final String NOTIFICATION_TYPE = 'Mask_Run_Finished';

    @TestVisible
    private static String lastTitle;
    @TestVisible
    private static String lastBody;
    @TestVisible
    private static String lastError;

    /** Called by the last object's batch. Sums the Mask Run records of the group and notifies the running user. */
    public static void runFinished(String runGroup) {
        if (String.isBlank(runGroup)) {
            return;
        }
        Integer objects = 0;
        Long processed = 0;
        Long failed = 0;
        Integer batchFailures = 0;
        Id latestRun;
        for (Mask_Run__c run : [
            SELECT Id, Records_Processed__c, Records_Failed__c, Batch_Failures__c
            FROM Mask_Run__c
            WHERE Run_Group__c = :runGroup
            ORDER BY CreatedDate DESC
            LIMIT 500
        ]) {
            objects++;
            processed += run.Records_Processed__c == null ? 0 : run.Records_Processed__c.longValue();
            failed += run.Records_Failed__c == null ? 0 : run.Records_Failed__c.longValue();
            batchFailures += run.Batch_Failures__c == null ? 0 : run.Batch_Failures__c.intValue();
            if (latestRun == null) {
                latestRun = run.Id;
            }
        }
        if (objects == 0) {
            return;
        }
        Boolean clean = failed == 0 && batchFailures == 0;
        String title = clean ? 'Sandbox data mask finished' : 'Sandbox data mask finished with errors';
        String body = objects + (objects == 1 ? ' object, ' : ' objects, ') + Decimal.valueOf(processed).format() + ' records masked';
        if (failed > 0) {
            body += ', ' + Decimal.valueOf(failed).format() + ' failed';
        }
        if (batchFailures > 0) {
            body += ', ' + batchFailures + ' batch execution(s) failed';
        }
        body += '. Open Mask Runs for the details.';
        lastTitle = title;
        lastBody = body;
        send(title, body, latestRun);
    }

    private static void send(String title, String body, Id targetId) {
        List<CustomNotificationType> types = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = :NOTIFICATION_TYPE LIMIT 1];
        if (types.isEmpty()) {
            lastError = 'Custom notification type ' + NOTIFICATION_TYPE + ' is not deployed.';
            return;
        }
        try {
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle(title);
            notification.setBody(body);
            notification.setNotificationTypeId(types[0].Id);
            notification.setTargetId(targetId);
            notification.send(new Set<String>{ UserInfo.getUserId() });
            lastError = null;
        } catch (Exception e) {
            lastError = e.getMessage(); // the run is complete and logged; a lost notification is not worth a failed batch
        }
    }
}
