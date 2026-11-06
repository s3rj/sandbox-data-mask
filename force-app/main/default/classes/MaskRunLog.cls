/**
 * Writes the Mask_Run__c audit records: one per object per run.
 */
public with sharing class MaskRunLog {
    public class AccessException extends Exception {
    }

    public static Id create(MaskPlan.Step step, String runGroup) {
        if (!Schema.sObjectType.Mask_Run__c.isCreateable()) {
            throw new AccessException('You need create access to Mask Run (assign the Sandbox Data Mask Admin permission set).');
        }
        Mask_Run__c run = new Mask_Run__c(
            Object_API_Name__c = step.objectApiName,
            Fields_Masked__c = step.fieldList().abbreviate(255),
            Status__c = 'Queued',
            Run_Group__c = runGroup
        );
        insert run;
        return run.Id;
    }

    public static void markRunning(Id runId, Id jobId) {
        requireUpdate();
        update new Mask_Run__c(Id = runId, Status__c = 'Running', Batch_Job_Id__c = jobId, Started__c = System.now());
    }

    public static void finish(Id runId, Integer processed, Integer failed, List<String> errors, Integer batchFailures) {
        requireUpdate();
        Boolean clean = failed == 0 && (batchFailures == null || batchFailures == 0);
        update new Mask_Run__c(
            Id = runId,
            Status__c = clean ? 'Completed' : 'Completed with errors',
            Records_Processed__c = processed,
            Records_Failed__c = failed,
            Batch_Failures__c = batchFailures,
            Error_Summary__c = errors.isEmpty() ? null : String.join(errors, '\n').abbreviate(32768),
            Finished__c = System.now()
        );
    }

    private static void requireUpdate() {
        if (!Schema.sObjectType.Mask_Run__c.isUpdateable()) {
            throw new AccessException('You need edit access to Mask Run (assign the Sandbox Data Mask Admin permission set).');
        }
    }
}
