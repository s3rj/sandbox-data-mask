/**
 * One masking rule: which field on which object, and how to mask it.
 * Rules normally come from Mask_Rule__mdt; tests build them directly.
 */
public with sharing class MaskRule {
    public String objectApiName { get; private set; }
    public String fieldApiName { get; private set; }
    public String strategy { get; private set; }
    public String fixedValue { get; private set; }
    public Boolean preserveBlank { get; private set; }
    public Decimal order { get; private set; }

    public MaskRule(String objectApiName, String fieldApiName, String strategy) {
        this.objectApiName = objectApiName;
        this.fieldApiName = fieldApiName;
        this.strategy = strategy;
        this.preserveBlank = true;
        this.order = 0;
    }

    public MaskRule withFixedValue(String value) {
        fixedValue = value;
        return this;
    }

    public MaskRule withPreserveBlank(Boolean preserve) {
        preserveBlank = preserve == null ? true : preserve;
        return this;
    }

    public MaskRule withOrder(Decimal value) {
        order = value == null ? 0 : value;
        return this;
    }

    public static MaskRule fromMetadata(Mask_Rule__mdt record) {
        return new MaskRule(record.Object_API_Name__c, record.Field_API_Name__c, record.Strategy__c)
            .withFixedValue(record.Fixed_Value__c)
            .withPreserveBlank(record.Preserve_Blank__c)
            .withOrder(record.Order__c);
    }

    /** Lower-cased "object.field", unique per rule within a plan. */
    public String key() {
        return (objectApiName + '.' + fieldApiName).toLowerCase();
    }
}
