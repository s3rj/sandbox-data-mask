/**
 * Masks the configured fields of one object in bulk-safe chunks, records the outcome on its Mask Run record,
 * then chains to the next object in the plan. The last object's batch notifies the user who started the run.
 *
 * Runs without sharing on purpose: a mask that skipped records the running user cannot see would leave PII
 * behind. The sandbox guard and the Sandbox Data Mask Admin permission set are the access control.
 */
public without sharing class SandboxDataMaskBatch implements Database.Batchable<SObject>, Database.Stateful {
    public static final Integer DEFAULT_BATCH_SIZE = 200;
    public static final Integer MAX_ERRORS_KEPT = 25;

    private final MaskPlan plan;
    private final Integer position;
    private final String salt;
    private final Id runId;
    private final String runGroup;
    private Map<String, Integer> fieldLengths = new Map<String, Integer>();
    private Integer processed = 0;
    private Integer failed = 0;
    private List<String> errors = new List<String>();

    public SandboxDataMaskBatch(MaskPlan plan, Integer position, String salt, Id runId, String runGroup) {
        this.plan = plan;
        this.position = position;
        this.salt = salt;
        this.runId = runId;
        this.runGroup = runGroup;
    }

    // The query is assembled from admin-managed custom metadata that validateStep() has just checked against the
    // describe (object and field names must exist); it never contains user input.
    @SuppressWarnings('PMD.ApexSOQLInjection')
    public Database.QueryLocator start(Database.BatchableContext context) {
        OrgGuard.requireSandbox();
        MaskPlan.Step step = currentStep();
        fieldLengths = MaskPlan.validateStep(step);
        MaskRunLog.markRunning(runId, context.getJobId());
        return Database.getQueryLocator(step.soql());
    }

    public void execute(Database.BatchableContext context, List<SObject> scope) {
        Masker masker = new Masker(currentStep(), salt, fieldLengths);
        for (SObject record : scope) {
            masker.apply(record);
        }
        Database.DMLOptions options = new Database.DMLOptions();
        options.optAllOrNone = false;
        options.duplicateRuleHeader.allowSave = true; // masked names and emails collide with duplicate rules by design
        List<Database.SaveResult> results = Database.update(scope, options);
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                processed++;
                continue;
            }
            failed++;
            if (errors.size() < MAX_ERRORS_KEPT) {
                errors.add(scope[i].Id + ': ' + results[i].getErrors()[0].getMessage());
            }
        }
    }

    public void finish(Database.BatchableContext context) {
        AsyncApexJob job = [SELECT NumberOfErrors FROM AsyncApexJob WHERE Id = :context.getJobId() LIMIT 1];
        MaskRunLog.finish(runId, processed, failed, errors, job.NumberOfErrors);
        Boolean hasNext = position + 1 < plan.steps.size();
        if (!hasNext) {
            MaskRunNotifier.runFinished(runGroup);
        } else if (!Test.isRunningTest()) { // a test context allows only one batch execution
            SandboxDataMaskRunner.startStep(plan, position + 1, salt, null, runGroup);
        }
    }

    private MaskPlan.Step currentStep() {
        return plan.steps[position];
    }
}
