@IsTest
private class MaskCoverageAuditTest {
    private static Map<String, MaskCoverageAudit.Gap> byField(List<MaskCoverageAudit.Gap> gaps) {
        Map<String, MaskCoverageAudit.Gap> index = new Map<String, MaskCoverageAudit.Gap>();
        for (MaskCoverageAudit.Gap gap : gaps) {
            index.put(gap.qualifiedName().toLowerCase(), gap);
        }
        return index;
    }

    @IsTest
    static void flagsPersonalDataFieldsThatHaveNoRule() {
        MaskRuleRepository.ruleOverride = new List<MaskRule>{
            new MaskRule('Contact', 'Email', 'Email'),
            new MaskRule('Contact', 'Phone', 'Phone'),
            new MaskRule('Contact', 'FirstName', 'FirstName')
        };
        MaskRuleRepository.scopeOverride = new List<MaskRuleRepository.ObjectScope>();

        Map<String, MaskCoverageAudit.Gap> gaps = byField(MaskCoverageAudit.audit(new Set<String>{ 'Contact' }));

        Assert.isFalse(gaps.containsKey('contact.email'), 'covered by a rule');
        Assert.isFalse(gaps.containsKey('contact.phone'), 'covered by a rule');
        Assert.isFalse(gaps.containsKey('contact.firstname'), 'covered by a rule');
        Assert.isTrue(gaps.containsKey('contact.fax'), 'phone-typed field flagged');
        Assert.areEqual('Phone', gaps.get('contact.fax').fieldType, 'type reported');
        Assert.isTrue(gaps.get('contact.homephone').reason.contains('Phone field'), 'reason names the type');
        Assert.isTrue(gaps.containsKey('contact.lastname'), 'last name flagged by name');
        Assert.isTrue(gaps.get('contact.lastname').reason.contains('last name'), 'reason names the phrase');
        Assert.isTrue(gaps.containsKey('contact.birthdate'), 'birthdate flagged by name');
        Assert.isTrue(gaps.get('contact.birthdate').reason.contains('only the Null strategy'), 'non-text field gets the Null advice');
        Assert.isTrue(gaps.containsKey('contact.mailingstreet'), 'street flagged');
        Assert.isFalse(gaps.containsKey('contact.title'), 'ordinary field not flagged');
        Assert.isFalse(gaps.containsKey('contact.description'), 'ordinary field not flagged');
        Assert.isFalse(gaps.containsKey('contact.name'), 'read-only compound field skipped');
        Assert.isFalse(gaps.containsKey('contact.accountid'), 'lookups skipped');
    }

    @IsTest
    static void rulesOnAnObjectSwitchedOffDoNotCount() {
        MaskRuleRepository.ruleOverride = new List<MaskRule>{ new MaskRule('Contact', 'Email', 'Email') };
        MaskRuleRepository.scopeOverride = new List<MaskRuleRepository.ObjectScope>{
            new MaskRuleRepository.ObjectScope('Contact', null, 1, false)
        };

        Map<String, MaskCoverageAudit.Gap> gaps = byField(MaskCoverageAudit.audit(new Set<String>{ 'Contact' }));

        Assert.isTrue(gaps.containsKey('contact.email'), 'an inactive Mask Object leaves the field unmasked');
    }

    @IsTest
    static void defaultScopeCoversPersonObjectsRuleObjectsAndCustomObjects() {
        MaskRuleRepository.ruleOverride = new List<MaskRule>{ new MaskRule('Opportunity', 'Description', 'Null') };
        MaskRuleRepository.scopeOverride = new List<MaskRuleRepository.ObjectScope>();

        Set<String> scope = MaskCoverageAudit.defaultScope();

        for (String name : new List<String>{ 'Account', 'Contact', 'Lead', 'Case', 'Opportunity', 'Mask_Run__c' }) {
            Assert.isTrue(scope.contains(name), name + ' in scope');
        }
        Assert.isFalse(scope.contains('Mask_Settings__c'), 'custom settings are not audited');
        Assert.isFalse(scope.contains('Mask_Rule__mdt'), 'custom metadata is not audited');
    }

    @IsTest
    static void unknownObjectIsAnError() {
        try {
            MaskCoverageAudit.audit(new Set<String>{ 'Nope__c' });
            Assert.fail('expected ConfigException');
        } catch (MaskPlan.ConfigException e) {
            Assert.isTrue(e.getMessage().contains('Nope__c'), 'names the object');
        }
    }

    @IsTest
    static void nameHintsReadCamelCaseAndUnderscores() {
        Assert.areEqual('address', MaskCoverageAudit.nameHint('Home_Address__c'), 'underscored token');
        Assert.areEqual('dob', MaskCoverageAudit.nameHint('DOB__c'), 'acronym');
        Assert.areEqual('date of birth', MaskCoverageAudit.nameHint('Date_Of_Birth__c'), 'phrase');
        Assert.areEqual('ssn', MaskCoverageAudit.nameHint('SSN__c'), 'acronym');
        Assert.areEqual('email', MaskCoverageAudit.nameHint('PersonEmail'), 'camel case');
        Assert.areEqual('account number', MaskCoverageAudit.nameHint('AccountNumber'), 'camel-case phrase');
        Assert.areEqual('first name', MaskCoverageAudit.nameHint('FirstName'), 'standard name field');
        Assert.isNull(MaskCoverageAudit.nameHint('Rating'), 'ordinary word');
        Assert.isNull(MaskCoverageAudit.nameHint('Latin_Name__c'), '"name" alone is not personal data');
        Assert.isNull(MaskCoverageAudit.nameHint('Hinting__c'), 'tokens match whole, not as substrings');
        Assert.isNull(MaskCoverageAudit.nameHint('Description'), 'ordinary word');
    }

    @IsTest
    static void reportAndFlowEntryPointListTheGaps() {
        MaskRuleRepository.ruleOverride = new List<MaskRule>();
        MaskRuleRepository.scopeOverride = new List<MaskRuleRepository.ObjectScope>();

        String report = MaskCoverageAudit.report(MaskCoverageAudit.audit(new Set<String>{ 'Contact' }));
        Assert.isTrue(report.contains('Contact.Email'), 'lists the field: ' + report);
        Assert.isTrue(report.contains('Mask Rule'), 'says what to do');
        Assert.isTrue(MaskCoverageAudit.report(new List<MaskCoverageAudit.Gap>()).contains('Every field'), 'clean report');

        MaskCoverageAudit.Request request = new MaskCoverageAudit.Request();
        request.objectApiNames = 'Contact, Lead';
        List<String> reports = MaskCoverageAudit.auditFromFlow(new List<MaskCoverageAudit.Request>{ request });
        Assert.areEqual(1, reports.size(), 'one report per request');
        Assert.isTrue(reports[0].contains('Lead.Email'), 'both objects audited');
        Assert.isTrue(reports[0].contains('Contact.Fax'), 'both objects audited');
    }
}
