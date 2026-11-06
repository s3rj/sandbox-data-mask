@IsTest
private class MaskRuleRepositoryTest {
    @IsTest
    static void readsTheShippedMetadata() {
        Map<String, List<MaskRule>> rules = MaskRuleRepository.activeRulesByObject();
        Assert.isTrue(rules.containsKey('contact'), 'shipped Contact rules are active');
        Assert.isTrue(rules.get('contact').size() >= 4, 'several Contact fields are covered');

        List<MaskRuleRepository.ObjectScope> scopes = MaskRuleRepository.orderedScopes(rules);
        Assert.isFalse(scopes.isEmpty(), 'objects to process');
        Assert.areEqual('Contact', scopes[0].objectApiName, 'Contact runs first (order 10)');
        for (Integer i = 1; i < scopes.size(); i++) {
            Assert.isTrue(scopes[i - 1].compareTo(scopes[i]) <= 0, 'scopes are sorted');
        }
    }

    @IsTest
    static void objectsWithoutScopeRowsRunLastInAlphabeticalOrder() {
        MaskRuleRepository.ruleOverride = new List<MaskRule>{
            new MaskRule('Zeta__c', 'Name', 'Scramble'),
            new MaskRule('Alpha__c', 'Name', 'Scramble'),
            new MaskRule('Mid__c', 'Name', 'Scramble')
        };
        MaskRuleRepository.scopeOverride = new List<MaskRuleRepository.ObjectScope>{
            new MaskRuleRepository.ObjectScope('Mid__c', null, 5, true)
        };

        List<MaskRuleRepository.ObjectScope> scopes = MaskRuleRepository.orderedScopes(MaskRuleRepository.activeRulesByObject());

        Assert.areEqual(3, scopes.size(), 'every object with rules');
        Assert.areEqual('Mid__c', scopes[0].objectApiName, 'configured order first');
        Assert.areEqual('Alpha__c', scopes[1].objectApiName, 'then alphabetical');
        Assert.areEqual('Zeta__c', scopes[2].objectApiName, 'then alphabetical');
    }

    @IsTest
    static void rulesKeepTheirOrderWithinAnObject() {
        MaskRuleRepository.ruleOverride = new List<MaskRule>{
            new MaskRule('Contact', 'Email', 'Email').withOrder(2),
            new MaskRule('Contact', 'Phone', 'Phone').withOrder(1)
        };
        List<MaskRule> rules = MaskRuleRepository.activeRulesByObject().get('contact');
        Assert.areEqual('Email', rules[0].fieldApiName, 'repository preserves the given order; metadata is pre-sorted by the query');
        Assert.areEqual('contact.email', rules[0].key(), 'rule key');
    }
}
