/**
 * Entry points: anonymous Apex, Flow (invocable action), and the SandboxPostCopy hook. Builds the plan from
 * metadata, validates it synchronously so misconfiguration fails immediately, and queues the first object;
 * each object's batch chains to the next. Every Mask Run record of one run shares a Run Group.
 */
public with sharing class SandboxDataMaskRunner {
    public class MaskRunException extends Exception {
    }

    public class Request {
        @InvocableVariable(label='Batch size' description='Records per batch execution, 1 to 2000. Defaults to Mask Settings or 200.')
        public Integer batchSize;
    }

    /** Masks every object with active rules. Returns the Mask Run record for the first object. */
    public static Id run() {
        return run(MaskPlan.fromMetadata(), null);
    }

    public static Id run(MaskPlan plan, Integer batchSize) {
        OrgGuard.requireSandbox();
        if (plan.steps.isEmpty()) {
            throw new MaskRunException('Nothing to mask: there are no active Mask Rule records.');
        }
        plan.validate();
        return startStep(plan, 0, resolveSalt(), batchSize, UUID.randomUUID().toString());
    }

    @InvocableMethod(
        label='Run sandbox data mask'
        description='Masks PII in this sandbox using the active Mask Rule metadata. Refuses to run anywhere that is not a sandbox.'
        category='Sandbox Data Mask'
    )
    public static List<Id> runFromFlow(List<Request> requests) {
        Integer batchSize = (requests == null || requests.isEmpty()) ? null : requests[0].batchSize;
        return new List<Id>{ run(MaskPlan.fromMetadata(), batchSize) };
    }

    /** Creates the audit record for one step and queues its batch. Called by run() and by the previous batch's finish(). */
    public static Id startStep(MaskPlan plan, Integer position, String salt, Integer batchSize, String runGroup) {
        Id runId = MaskRunLog.create(plan.steps[position], runGroup);
        Database.executeBatch(new SandboxDataMaskBatch(plan, position, salt, runId, runGroup), effectiveBatchSize(batchSize));
        return runId;
    }

    /**
     * The org salt. Generated once and stored in Mask Settings so fakes stay stable across runs. Set it in
     * production (the tool never runs there) and every refreshed sandbox inherits it, so fakes also stay
     * stable across refreshes. The preview uses the same salt, so what it shows is what the run will write.
     */
    public static String resolveSalt() {
        Mask_Settings__c settings = Mask_Settings__c.getOrgDefaults();
        if (String.isNotBlank(settings.Salt__c)) {
            return settings.Salt__c;
        }
        if (!Schema.sObjectType.Mask_Settings__c.isCreateable() || !Schema.sObjectType.Mask_Settings__c.isUpdateable()) {
            throw new MaskRunException('You need access to Mask Settings so the org salt can be generated.');
        }
        settings.Salt__c = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
        if (settings.Id == null) {
            settings.SetupOwnerId = UserInfo.getOrganizationId();
        }
        upsert settings;
        return settings.Salt__c;
    }

    private static Integer effectiveBatchSize(Integer requested) {
        Integer size = requested;
        if (size == null) {
            Decimal configured = Mask_Settings__c.getOrgDefaults().Batch_Size__c;
            size = configured == null ? null : configured.intValue();
        }
        if (size == null || size < 1) {
            return SandboxDataMaskBatch.DEFAULT_BATCH_SIZE;
        }
        return Math.min(size, 2000);
    }
}
