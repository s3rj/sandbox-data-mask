/**
 * Reads Mask_Rule__mdt and Mask_Object__mdt. Tests inject rules through the @TestVisible overrides because
 * custom metadata records cannot be inserted in a test context.
 */
public with sharing class MaskRuleRepository {
    private static final Decimal DEFAULT_ORDER = 1000000;

    /** Per-object settings: processing order and an optional WHERE clause. */
    public class ObjectScope implements Comparable {
        public String objectApiName { get; private set; }
        public String whereClause { get; private set; }
        public Decimal order { get; private set; }
        public Boolean active { get; private set; }

        public ObjectScope(String objectApiName, String whereClause, Decimal order, Boolean active) {
            this.objectApiName = objectApiName;
            this.whereClause = whereClause;
            this.order = order == null ? DEFAULT_ORDER : order;
            this.active = active == null ? true : active;
        }

        public Integer compareTo(Object other) {
            ObjectScope that = (ObjectScope) other;
            if (this.order != that.order) {
                return this.order < that.order ? -1 : 1;
            }
            return this.objectApiName.toLowerCase().compareTo(that.objectApiName.toLowerCase());
        }
    }

    @TestVisible
    private static List<MaskRule> ruleOverride;
    @TestVisible
    private static List<ObjectScope> scopeOverride;

    /** Active rules grouped by lower-cased object API name, each list in rule order. */
    public static Map<String, List<MaskRule>> activeRulesByObject() {
        Map<String, List<MaskRule>> byObject = new Map<String, List<MaskRule>>();
        for (MaskRule rule : loadRules()) {
            String key = rule.objectApiName.toLowerCase();
            if (!byObject.containsKey(key)) {
                byObject.put(key, new List<MaskRule>());
            }
            byObject.get(key).add(rule);
        }
        return byObject;
    }

    /**
     * The objects to process, in order: every object with at least one active rule, unless a Mask Object row
     * switches it off. Objects without a row run after the configured ones, alphabetically.
     */
    public static List<ObjectScope> orderedScopes(Map<String, List<MaskRule>> rulesByObject) {
        Map<String, ObjectScope> configured = new Map<String, ObjectScope>();
        for (ObjectScope scope : loadScopes()) {
            configured.put(scope.objectApiName.toLowerCase(), scope);
        }
        List<ObjectScope> scopes = new List<ObjectScope>();
        for (String key : rulesByObject.keySet()) {
            ObjectScope scope = configured.get(key);
            if (scope == null) {
                scope = new ObjectScope(rulesByObject.get(key)[0].objectApiName, null, DEFAULT_ORDER, true);
            }
            if (scope.active) {
                scopes.add(scope);
            }
        }
        scopes.sort();
        return scopes;
    }

    private static List<MaskRule> loadRules() {
        if (ruleOverride != null) {
            return ruleOverride;
        }
        List<MaskRule> rules = new List<MaskRule>();
        for (Mask_Rule__mdt record : [
            SELECT Object_API_Name__c, Field_API_Name__c, Strategy__c, Fixed_Value__c, Preserve_Blank__c, Order__c
            FROM Mask_Rule__mdt
            WHERE Active__c = true
            ORDER BY Order__c NULLS LAST, DeveloperName
        ]) {
            rules.add(MaskRule.fromMetadata(record));
        }
        return rules;
    }

    private static List<ObjectScope> loadScopes() {
        if (scopeOverride != null) {
            return scopeOverride;
        }
        List<ObjectScope> scopes = new List<ObjectScope>();
        for (Mask_Object__mdt record : [
            SELECT Object_API_Name__c, Where_Clause__c, Order__c, Active__c
            FROM Mask_Object__mdt
            LIMIT 500
        ]) {
            scopes.add(new ObjectScope(record.Object_API_Name__c, record.Where_Clause__c, record.Order__c, record.Active__c));
        }
        return scopes;
    }
}
