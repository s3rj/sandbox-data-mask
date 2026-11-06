/**
 * Applies one step's rules to records in memory. The batch uses it and then updates the records; the preview
 * uses it and only reports what would change.
 */
public with sharing class Masker {
    private final MaskPlan.Step step;
    private final String salt;
    private final Map<String, Integer> fieldLengths;
    private final Map<String, MaskStrategies.Strategy> strategies = new Map<String, MaskStrategies.Strategy>();

    public Masker(MaskPlan.Step step, String salt, Map<String, Integer> fieldLengths) {
        this.step = step;
        this.salt = salt;
        this.fieldLengths = fieldLengths;
        for (MaskRule rule : step.rules) {
            strategies.put(rule.key(), MaskStrategies.forName(rule.strategy));
        }
    }

    /**
     * The new value for every field a rule changes, keyed by field API name. A field that is blank on a rule
     * with Preserve Blank is left out.
     */
    public Map<String, Object> maskedValues(SObject record) {
        Map<String, Object> values = new Map<String, Object>();
        for (MaskRule rule : step.rules) {
            Object original = record.get(rule.fieldApiName);
            if (rule.preserveBlank && isBlank(original)) {
                continue;
            }
            MaskContext ctx = new MaskContext(salt, rule, fieldLengths.get(rule.fieldApiName.toLowerCase()));
            values.put(rule.fieldApiName, strategies.get(rule.key()).mask(original, ctx));
        }
        return values;
    }

    /** Writes the masked values onto the record. No DML. */
    public void apply(SObject record) {
        Map<String, Object> values = maskedValues(record);
        for (String fieldApiName : values.keySet()) {
            record.put(fieldApiName, values.get(fieldApiName));
        }
    }

    public static Boolean isBlank(Object value) {
        return value == null || (value instanceof String && String.isBlank((String) value));
    }
}
