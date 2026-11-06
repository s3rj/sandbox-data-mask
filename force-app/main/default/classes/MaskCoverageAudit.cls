/**
 * Lists fields that look like personal data but have no active mask rule, so the rules get reviewed after every
 * schema change instead of after a leak. Three signals: the field type (Email, Phone, classic Encrypted Text),
 * the field name (FirstName, Birthdate, SSN__c, Home_Address__c, ...), and what admins recorded on the field in
 * Setup as Compliance Categorization (PII, GDPR, HIPAA, ...) and Data Sensitivity Level.
 */
public with sharing class MaskCoverageAudit {
    public class Request {
        @InvocableVariable(label='Object API names' description='Comma-separated. Blank audits every object with a rule, Account, Contact, Lead, Case, and every custom object.')
        public String objectApiNames;
    }

    public class Gap implements Comparable {
        public String objectApiName { get; private set; }
        public String fieldApiName { get; private set; }
        public String fieldType { get; private set; }
        public String reason { get; private set; }

        public Gap(String objectApiName, String fieldApiName, String fieldType, String reason) {
            this.objectApiName = objectApiName;
            this.fieldApiName = fieldApiName;
            this.fieldType = fieldType;
            this.reason = reason;
        }

        public String qualifiedName() {
            return objectApiName + '.' + fieldApiName;
        }

        public Integer compareTo(Object other) {
            return qualifiedName().toLowerCase().compareTo(((Gap) other).qualifiedName().toLowerCase());
        }
    }

    public static final Set<String> STANDARD_PERSON_OBJECTS = new Set<String>{ 'Account', 'Contact', 'Lead', 'Case' };
    /** Field types that hold personal data whatever they are called. */
    public static final Set<String> SENSITIVE_TYPES = new Set<String>{ 'EMAIL', 'PHONE', 'ENCRYPTEDSTRING' };
    /** Field types the audit looks at. Lookups, checkboxes, formulas, and ids are skipped. */
    private static final Set<String> AUDITED_TYPES = new Set<String>{
        'STRING', 'TEXTAREA', 'EMAIL', 'PHONE', 'URL', 'ENCRYPTEDSTRING', 'DATE', 'DATETIME', 'DOUBLE', 'CURRENCY', 'INTEGER', 'LONG', 'PERCENT', 'PICKLIST', 'MULTIPICKLIST'
    };
    private static final Set<String> SENSITIVE_CLASSIFICATIONS = new Set<String>{ 'Confidential', 'Restricted', 'MissionCritical' };
    /** Single name tokens that suggest personal data. "name" alone is not one: Account.Name is a company. */
    private static final Set<String> HINT_TOKENS = new Set<String>{
        'email', 'phone', 'mobile', 'fax', 'street', 'address', 'birthdate', 'birthday', 'dob', 'ssn', 'sin', 'nino', 'tin', 'passport',
        'license', 'licence', 'salary', 'income', 'iban', 'routing', 'swift', 'gender', 'ethnicity', 'religion', 'medical', 'diagnosis',
        'nickname', 'maiden', 'spouse', 'latitude', 'longitude'
    };
    /** Phrases of tokens that suggest personal data. */
    private static final Set<String> HINT_PHRASES = new Set<String>{
        'first name', 'last name', 'middle name', 'full name', 'legal name', 'contact name', 'supplied name', 'account number', 'credit card',
        'card number', 'national id', 'tax id', 'social security', 'date of birth', 'driver license', 'drivers license', 'ip address'
    };
    private static final Integer OBJECTS_PER_QUERY = 50;

    /** Audits every object with a rule, the standard person objects, and every custom object. */
    public static List<Gap> audit() {
        return audit(defaultScope());
    }

    /** Audits the given objects. Throws ConfigException for a name the org does not have. */
    public static List<Gap> audit(Set<String> objectApiNames) {
        Map<String, Set<String>> coveredByObject = coveredFields();
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        Map<String, String> classifications = classificationsFor(objectApiNames);
        List<Gap> gaps = new List<Gap>();
        for (String objectApiName : objectApiNames) {
            Schema.SObjectType type = globalDescribe.get(objectApiName.toLowerCase());
            if (type == null) {
                throw new MaskPlan.ConfigException('Cannot audit an unknown object: ' + objectApiName);
            }
            Schema.DescribeSObjectResult objectDescribe = type.getDescribe(SObjectDescribeOptions.DEFERRED);
            Set<String> covered = coveredByObject.get(objectDescribe.getName().toLowerCase());
            for (Schema.SObjectField field : objectDescribe.fields.getMap().values()) {
                Schema.DescribeFieldResult describe = field.getDescribe();
                String fieldType = String.valueOf(describe.getType());
                if (!describe.isUpdateable() || !AUDITED_TYPES.contains(fieldType) || (covered != null && covered.contains(describe.getName().toLowerCase()))) {
                    continue;
                }
                String reason = reasonFor(objectDescribe.getName(), describe.getName(), fieldType, classifications);
                if (reason != null) {
                    gaps.add(new Gap(objectDescribe.getName(), describe.getName(), typeLabel(fieldType), reason));
                }
            }
        }
        gaps.sort();
        return gaps;
    }

    /** Every object with an active rule, Account, Contact, Lead, Case, and every custom object that is not a custom setting. */
    public static Set<String> defaultScope() {
        Set<String> names = new Set<String>(STANDARD_PERSON_OBJECTS);
        for (List<MaskRule> rules : MaskRuleRepository.activeRulesByObject().values()) {
            names.add(rules[0].objectApiName);
        }
        for (Schema.SObjectType type : Schema.getGlobalDescribe().values()) {
            Schema.DescribeSObjectResult describe = type.getDescribe(SObjectDescribeOptions.DEFERRED);
            if (describe.isCustom() && describe.getName().endsWith('__c') && !describe.isCustomSetting() && describe.isUpdateable() && describe.isQueryable()) {
                names.add(describe.getName());
            }
        }
        return names;
    }

    /** The audit as text, for the CLI, the Developer Console, or a Flow screen or email. */
    public static String report(List<Gap> gaps) {
        if (gaps.isEmpty()) {
            return 'Every field that looks like personal data has an active mask rule.';
        }
        List<String> lines = new List<String>{ gaps.size() + ' field(s) look like personal data and have no active mask rule:' };
        for (Gap gap : gaps) {
            lines.add('  ' + gap.qualifiedName().rightPad(44) + gap.fieldType.rightPad(16) + gap.reason);
        }
        lines.add('Add a Mask Rule for each one that should be masked (Setup > Custom Metadata Types > Mask Rule).');
        return String.join(lines, '\n');
    }

    @InvocableMethod(
        label='Audit mask coverage'
        description='Lists fields that look like personal data (by type, by name, or by their compliance categorization) but have no active Mask Rule. Returns the report as text.'
        category='Sandbox Data Mask'
    )
    public static List<String> auditFromFlow(List<Request> requests) {
        List<String> reports = new List<String>();
        for (Request request : requests) {
            reports.add(report(String.isBlank(request.objectApiNames) ? audit() : audit(parseNames(request.objectApiNames))));
        }
        return reports;
    }

    /** Why a field name suggests personal data (the token or phrase that matched), or null. */
    @TestVisible
    private static String nameHint(String fieldApiName) {
        String bare = fieldApiName.removeEndIgnoreCase('__c').removeEndIgnoreCase('__pc');
        String spaced = bare.replace('_', ' ')
            .replaceAll('([a-z0-9])([A-Z])', '$1 $2')
            .replaceAll('([A-Z]+)([A-Z][a-z])', '$1 $2')
            .toLowerCase()
            .normalizeSpace();
        List<String> tokens = spaced.split(' ');
        for (String token : tokens) {
            if (HINT_TOKENS.contains(token)) {
                return token;
            }
        }
        String padded = ' ' + spaced + ' ';
        for (String phrase : HINT_PHRASES) {
            if (padded.contains(' ' + phrase + ' ')) {
                return phrase;
            }
        }
        return null;
    }

    private static String reasonFor(String objectApiName, String fieldApiName, String fieldType, Map<String, String> classifications) {
        List<String> reasons = new List<String>();
        if (fieldType == 'EMAIL') {
            reasons.add('Email field');
        } else if (fieldType == 'PHONE') {
            reasons.add('Phone field');
        } else if (fieldType == 'ENCRYPTEDSTRING') {
            reasons.add('Encrypted text field');
        }
        String classification = classifications.get((objectApiName + '.' + fieldApiName).toLowerCase());
        if (classification != null) {
            reasons.add(classification);
        }
        String nameMatch = nameHint(fieldApiName);
        if (nameMatch != null) {
            reasons.add('name suggests personal data ("' + nameMatch + '")');
        }
        if (reasons.isEmpty()) {
            return null;
        }
        if (!MaskPlan.TEXT_TYPES.contains(fieldType)) {
            reasons.add('only the Null strategy fits a ' + typeLabel(fieldType) + ' field');
        }
        return String.join(reasons, '; ');
    }

    /** Lower-cased "object.field" -> what admins recorded on the field in Setup, for the objects given. */
    // FieldDefinition takes one entity filter plus one more condition and no OR, so two bounded queries per chunk of objects.
    @SuppressWarnings('PMD.OperationWithLimitsInLoop')
    private static Map<String, String> classificationsFor(Set<String> objectApiNames) {
        Map<String, String> reasons = new Map<String, String>();
        List<String> names = new List<String>(objectApiNames);
        for (Integer start = 0; start < names.size(); start += OBJECTS_PER_QUERY) {
            List<String> chunk = new List<String>();
            for (Integer i = start; i < Math.min(start + OBJECTS_PER_QUERY, names.size()); i++) {
                chunk.add(names[i]);
            }
            for (FieldDefinition def : [
                SELECT EntityDefinition.QualifiedApiName, QualifiedApiName, ComplianceGroup
                FROM FieldDefinition
                WHERE EntityDefinition.QualifiedApiName IN :chunk AND ComplianceGroup != null
            ]) {
                reasons.put(key(def), 'compliance categorization ' + def.ComplianceGroup.replace(';', ', '));
            }
            for (FieldDefinition def : [
                SELECT EntityDefinition.QualifiedApiName, QualifiedApiName, SecurityClassification
                FROM FieldDefinition
                WHERE EntityDefinition.QualifiedApiName IN :chunk AND SecurityClassification != null
            ]) {
                if (!SENSITIVE_CLASSIFICATIONS.contains(def.SecurityClassification)) {
                    continue;
                }
                String fieldKey = key(def);
                String sensitivity = 'data sensitivity ' + def.SecurityClassification;
                reasons.put(fieldKey, reasons.containsKey(fieldKey) ? reasons.get(fieldKey) + ', ' + sensitivity : sensitivity);
            }
        }
        return reasons;
    }

    private static String key(FieldDefinition def) {
        return (def.EntityDefinition.QualifiedApiName + '.' + def.QualifiedApiName).toLowerCase();
    }

    /** Lower-cased object -> lower-cased fields with an active rule, ignoring objects a Mask Object row switches off. */
    private static Map<String, Set<String>> coveredFields() {
        Map<String, List<MaskRule>> rulesByObject = MaskRuleRepository.activeRulesByObject();
        Map<String, Set<String>> covered = new Map<String, Set<String>>();
        for (MaskRuleRepository.ObjectScope scope : MaskRuleRepository.orderedScopes(rulesByObject)) {
            Set<String> fields = new Set<String>();
            for (MaskRule rule : rulesByObject.get(scope.objectApiName.toLowerCase())) {
                fields.add(rule.fieldApiName.toLowerCase());
            }
            covered.put(scope.objectApiName.toLowerCase(), fields);
        }
        return covered;
    }

    private static Set<String> parseNames(String csv) {
        Set<String> names = new Set<String>();
        for (String part : csv.split(',')) {
            if (String.isNotBlank(part)) {
                names.add(part.trim());
            }
        }
        return names;
    }

    private static String typeLabel(String fieldType) {
        switch on fieldType {
            when 'STRING' {
                return 'Text';
            }
            when 'TEXTAREA' {
                return 'Text Area';
            }
            when 'ENCRYPTEDSTRING' {
                return 'Encrypted Text';
            }
            when 'DATETIME' {
                return 'Date/Time';
            }
            when 'DOUBLE' {
                return 'Number';
            }
            when 'MULTIPICKLIST' {
                return 'Multi-Select';
            }
            when else {
                return fieldType.substring(0, 1) + fieldType.substring(1).toLowerCase();
            }
        }
    }
}
