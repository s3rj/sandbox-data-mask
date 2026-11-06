/**
 * The ordered list of objects to mask and the rules for each. Built from metadata and validated against the
 * schema before anything is queued, so a misconfigured rule fails in the caller's face instead of in a batch log.
 */
public with sharing class MaskPlan {
    public class ConfigException extends Exception {
    }

    /** Field types a text-producing strategy may write to. */
    public static final Set<String> TEXT_TYPES = new Set<String>{ 'STRING', 'EMAIL', 'PHONE', 'TEXTAREA', 'URL' };

    public class Step {
        public String objectApiName { get; private set; }
        public String whereClause { get; private set; }
        public List<MaskRule> rules { get; private set; }

        public Step(String objectApiName, String whereClause) {
            this.objectApiName = objectApiName;
            this.whereClause = whereClause;
            this.rules = new List<MaskRule>();
        }

        public List<String> fieldNames() {
            List<String> names = new List<String>();
            for (MaskRule rule : rules) {
                names.add(rule.fieldApiName);
            }
            return names;
        }

        public String fieldList() {
            return String.join(fieldNames(), ', ');
        }

        /** The batch query. Object and field names have been checked against the describe by validateStep(). */
        public String soql() {
            String query = 'SELECT Id, ' + fieldList() + ' FROM ' + objectApiName;
            return String.isBlank(whereClause) ? query : query + ' WHERE ' + whereClause;
        }
    }

    public List<Step> steps { get; private set; }

    public MaskPlan() {
        steps = new List<Step>();
    }

    public static MaskPlan fromMetadata() {
        Map<String, List<MaskRule>> rulesByObject = MaskRuleRepository.activeRulesByObject();
        MaskPlan plan = new MaskPlan();
        for (MaskRuleRepository.ObjectScope scope : MaskRuleRepository.orderedScopes(rulesByObject)) {
            Step step = new Step(scope.objectApiName, scope.whereClause);
            step.rules.addAll(rulesByObject.get(scope.objectApiName.toLowerCase()));
            plan.steps.add(step);
        }
        return plan;
    }

    /** Validates every step. Throws ConfigException on the first problem. */
    public void validate() {
        for (Step step : steps) {
            validateStep(step);
        }
    }

    /**
     * Checks one step against the schema: the object exists and is updateable, every field exists, is updateable,
     * and suits its strategy. Returns field lengths keyed by lower-cased field API name for the batch to use.
     */
    public static Map<String, Integer> validateStep(Step step) {
        Schema.SObjectType type = Schema.getGlobalDescribe().get(step.objectApiName.toLowerCase());
        if (type == null) {
            throw new ConfigException('Mask rule points at an unknown object: ' + step.objectApiName);
        }
        Schema.DescribeSObjectResult objectDescribe = type.getDescribe(SObjectDescribeOptions.DEFERRED);
        if (!objectDescribe.isUpdateable()) {
            throw new ConfigException(step.objectApiName + ' is not updateable, so it cannot be masked.');
        }
        Map<String, Schema.SObjectField> fields = objectDescribe.fields.getMap();
        Map<String, Integer> lengths = new Map<String, Integer>();
        Set<String> seen = new Set<String>();
        for (MaskRule rule : step.rules) {
            String key = rule.fieldApiName.toLowerCase();
            String label = step.objectApiName + '.' + rule.fieldApiName;
            if (!seen.add(key)) {
                throw new ConfigException('Two active rules target ' + label + '. Deactivate one.');
            }
            Schema.SObjectField field = fields.get(key);
            if (field == null) {
                throw new ConfigException('Mask rule points at an unknown field: ' + label);
            }
            Schema.DescribeFieldResult describe = field.getDescribe();
            if (!describe.isUpdateable()) {
                throw new ConfigException(label + ' is not updateable, so it cannot be masked.');
            }
            String fieldType = String.valueOf(describe.getType());
            Boolean clearsField = rule.strategy == 'Null' || (rule.strategy == 'Fixed' && String.isBlank(rule.fixedValue));
            if (clearsField && !describe.isNillable()) {
                throw new ConfigException(label + ' is required and cannot be set to null. Use another strategy or a fixed value.');
            }
            if (rule.strategy != 'Null' && !TEXT_TYPES.contains(fieldType)) {
                throw new ConfigException(
                    'Strategy ' + rule.strategy + ' writes text, but ' + label + ' is ' + fieldType + '. Only Null works on non-text fields.'
                );
            }
            MaskStrategies.forName(rule.strategy); // throws on an unknown strategy
            lengths.put(key, describe.getLength());
        }
        return lengths;
    }
}
