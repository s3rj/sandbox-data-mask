/**
 * A dry run for one object: what the active rules would do to the first few records, without writing anything.
 * Run it after changing rules and before the batch, so a bad rule is caught on five records instead of five
 * hundred thousand. Sandbox only, like everything else here: it prints real values side by side with fakes.
 */
public with sharing class MaskPreview {
    public static final Integer DEFAULT_SAMPLE = 5;
    public static final Integer MAX_SAMPLE = 200;

    public class Row {
        public Id recordId { get; private set; }
        public String fieldApiName { get; private set; }
        public Object before { get; private set; }
        public Object after { get; private set; }

        public Row(Id recordId, String fieldApiName, Object before, Object after) {
            this.recordId = recordId;
            this.fieldApiName = fieldApiName;
            this.before = before;
            this.after = after;
        }
    }

    /** One row per record per rule for the first `sampleSize` records in the object's scope. Nothing is written. */
    // Same admin-managed, describe-validated query as the batch; the only addition is the LIMIT.
    @SuppressWarnings('PMD.ApexSOQLInjection')
    public static List<Row> preview(String objectApiName, Integer sampleSize) {
        OrgGuard.requireSandbox();
        MaskPlan.Step step = stepFor(MaskPlan.fromMetadata(), objectApiName);
        Map<String, Integer> fieldLengths = MaskPlan.validateStep(step);
        Masker masker = new Masker(step, SandboxDataMaskRunner.resolveSalt(), fieldLengths);
        Integer sample = sampleSize == null || sampleSize < 1 ? DEFAULT_SAMPLE : Math.min(sampleSize, MAX_SAMPLE);
        List<Row> rows = new List<Row>();
        for (SObject record : Database.query(step.soql() + ' LIMIT ' + sample)) {
            Map<String, Object> masked = masker.maskedValues(record);
            for (MaskRule rule : step.rules) {
                Object before = record.get(rule.fieldApiName);
                Object after = masked.containsKey(rule.fieldApiName) ? masked.get(rule.fieldApiName) : before;
                rows.add(new Row(record.Id, rule.fieldApiName, before, after));
            }
        }
        return rows;
    }

    /** The preview as text, for the CLI or the Developer Console. */
    public static String report(String objectApiName, Integer sampleSize) {
        List<Row> rows = preview(objectApiName, sampleSize);
        Set<Id> records = new Set<Id>();
        for (Row row : rows) {
            records.add(row.recordId);
        }
        List<String> lines = new List<String>{
            'Preview of the active rules on ' + objectApiName + ': ' + records.size() + ' record(s), nothing written.'
        };
        Id current;
        for (Row row : rows) {
            if (row.recordId != current) {
                current = row.recordId;
                lines.add(String.valueOf(current));
            }
            lines.add('  ' + row.fieldApiName.rightPad(24) + show(row.before) + '  ->  ' + show(row.after));
        }
        return String.join(lines, '\n');
    }

    private static MaskPlan.Step stepFor(MaskPlan plan, String objectApiName) {
        for (MaskPlan.Step step : plan.steps) {
            if (step.objectApiName.equalsIgnoreCase(objectApiName)) {
                return step;
            }
        }
        throw new SandboxDataMaskRunner.MaskRunException('No active Mask Rule targets ' + objectApiName + '.');
    }

    private static String show(Object value) {
        return value == null ? '(blank)' : String.valueOf(value);
    }
}
