@IsTest
private class MaskPlanTest {
    private static MaskPlan.Step step(String objectName, String fieldName, String strategy) {
        MaskPlan.Step step = new MaskPlan.Step(objectName, null);
        step.rules.add(new MaskRule(objectName, fieldName, strategy));
        return step;
    }

    private static String failure(MaskPlan.Step step) {
        try {
            MaskPlan.validateStep(step);
            return null;
        } catch (Exception e) {
            return e.getMessage();
        }
    }

    @IsTest
    static void validStepReturnsFieldLengths() {
        Map<String, Integer> lengths = MaskPlan.validateStep(step('Contact', 'Email', 'Email'));
        Assert.areEqual(80, lengths.get('email'), 'Contact.Email is 80 characters');
    }

    @IsTest
    static void rejectsBadConfiguration() {
        Assert.isTrue(failure(step('Nope__c', 'Email', 'Email')).contains('unknown object'), 'unknown object');
        Assert.isTrue(failure(step('Contact', 'Nope__c', 'Email')).contains('unknown field'), 'unknown field');
        Assert.isTrue(failure(step('Contact', 'CreatedDate', 'Null')).contains('not updateable'), 'read-only field');
        Assert.isTrue(failure(step('Contact', 'Birthdate', 'FirstName')).contains('writes text'), 'text strategy on a date');
        Assert.isTrue(failure(step('Contact', 'LastName', 'Null')).contains('required'), 'null on a required field');
        Assert.isTrue(failure(step('Contact', 'LastName', 'Fixed')).contains('required'), 'blank fixed value on a required field');
        Assert.isTrue(failure(step('Contact', 'Email', 'Bogus')).contains('Bogus'), 'unknown strategy');
        MaskPlan.Step duplicate = step('Contact', 'Email', 'Email');
        duplicate.rules.add(new MaskRule('Contact', 'email', 'Hash'));
        Assert.isTrue(failure(duplicate).contains('Two active rules'), 'duplicate rules on one field');
    }

    @IsTest
    static void shippedRulesAreValidInThisOrg() {
        MaskPlan plan = MaskPlan.fromMetadata();
        Assert.isFalse(plan.steps.isEmpty(), 'the shipped rules produce a plan');
        Assert.areEqual('Contact', plan.steps[0].objectApiName, 'Contact runs first');
        plan.validate();
    }

    @IsTest
    static void nullIsAllowedOnNillableNonTextFields() {
        Map<String, Integer> lengths = MaskPlan.validateStep(step('Contact', 'Birthdate', 'Null'));
        Assert.isTrue(lengths.containsKey('birthdate'), 'date field accepted for Null');
    }

    @IsTest
    static void planFollowsScopeOrderAndSkipsInactiveObjects() {
        MaskRuleRepository.ruleOverride = new List<MaskRule>{
            new MaskRule('Contact', 'Email', 'Email'),
            new MaskRule('Lead', 'Email', 'Email'),
            new MaskRule('Account', 'Phone', 'Phone')
        };
        MaskRuleRepository.scopeOverride = new List<MaskRuleRepository.ObjectScope>{
            new MaskRuleRepository.ObjectScope('Lead', 'IsConverted = false', 1, true),
            new MaskRuleRepository.ObjectScope('Account', null, 2, false)
        };

        MaskPlan plan = MaskPlan.fromMetadata();

        Assert.areEqual(2, plan.steps.size(), 'the inactive Account scope is skipped');
        Assert.areEqual('Lead', plan.steps[0].objectApiName, 'configured object first');
        Assert.areEqual('Contact', plan.steps[1].objectApiName, 'unconfigured object last');
        Assert.areEqual('SELECT Id, Email FROM Lead WHERE IsConverted = false', plan.steps[0].soql(), 'where clause applied');
        Assert.areEqual('SELECT Id, Email FROM Contact', plan.steps[1].soql(), 'no where clause');
        Assert.areEqual('Email', plan.steps[0].fieldList(), 'field list');
        plan.validate();
    }
}
