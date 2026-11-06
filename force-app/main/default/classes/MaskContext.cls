/**
 * What a strategy needs to know while masking one field on one record.
 */
public with sharing class MaskContext {
    public String salt { get; private set; }
    public MaskRule rule { get; private set; }
    /** Field length from the describe, or null when unknown. */
    public Integer fieldLength { get; private set; }

    public MaskContext(String salt, MaskRule rule, Integer fieldLength) {
        this.salt = salt;
        this.rule = rule;
        this.fieldLength = fieldLength;
    }

    /** Truncates a generated value to the field's length so a long fake never fails the update. */
    public String fit(String value) {
        if (value == null || fieldLength == null || fieldLength <= 0 || value.length() <= fieldLength) {
            return value;
        }
        return value.substring(0, fieldLength);
    }
}
