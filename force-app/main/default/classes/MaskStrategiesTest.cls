@IsTest
private class MaskStrategiesTest {
    private static MaskContext ctx(String strategy, Integer length) {
        return new MaskContext('test-salt', new MaskRule('Contact', 'Email', strategy), length);
    }

    private static Object mask(String strategy, Object original, Integer length) {
        return MaskStrategies.forName(strategy).mask(original, ctx(strategy, length));
    }

    @IsTest
    static void namesComeFromTheWordListsAndAreStable() {
        Object first = mask('FirstName', 'Alice', 40);
        Assert.areEqual(first, mask('FirstName', 'alice', 40), 'same person in any case gets the same fake');
        Assert.areNotEqual('Alice', first, 'the original is gone');
        Assert.isTrue(String.valueOf(first).isAlpha(), 'a word from the list: ' + first);
        Object last = mask('LastName', 'Smith', 80);
        Assert.areNotEqual('Smith', last, 'last name masked');
        Assert.isTrue(String.valueOf(last).isAlpha(), 'a word from the list: ' + last);
    }

    @IsTest
    static void emailsLandOnReservedDomainsAndKeepDistinctSourcesDistinct() {
        String alice = (String) mask('Email', 'alice@customer.test', 80);
        String bob = (String) mask('Email', 'bob@customer.test', 80);
        Assert.areEqual(alice, mask('Email', 'ALICE@customer.test', 80), 'same address in any case maps to the same fake');
        Assert.areNotEqual(alice, bob, 'different addresses map to different fakes');
        Assert.isTrue(Pattern.matches('[a-z]+\\.[a-z]+\\.[0-9a-f]{6}@example\\.(com|net|org)', alice), 'shape: ' + alice);
    }

    @IsTest
    static void phonesUseTheFictionalExchange() {
        for (Integer i = 0; i < 50; i++) {
            String phone = (String) mask('Phone', '602-555-' + (1000 + i), 40);
            Assert.isTrue(Pattern.matches('\\([2-9][0-9]{2}\\) 555-01[0-9]{2}', phone), 'shape: ' + phone);
            Assert.areNotEqual('11', phone.substring(2, 4), 'no N11 area codes: ' + phone);
        }
    }

    @IsTest
    static void streetsLookLikeStreets() {
        String street = (String) mask('Street', '1 Real Rd', 255);
        Assert.isTrue(Pattern.matches('[0-9]{3,5} [A-Za-z ]+', street), 'shape: ' + street);
        Assert.areEqual(street, mask('Street', '1 real rd', 255), 'stable regardless of case');
    }

    @IsTest
    static void scrambleKeepsShape() {
        String scrambled = (String) mask('Scramble', 'ACME-00123 Co.', 255);
        Assert.areEqual(14, scrambled.length(), 'length kept');
        Assert.isTrue(Pattern.matches('[A-Z]{4}-[0-9]{5} [A-Z][a-z]\\.', scrambled), 'character classes kept: ' + scrambled);
        Assert.areNotEqual('ACME-00123 Co.', scrambled, 'content changed');
        Assert.areEqual(scrambled, mask('Scramble', 'ACME-00123 Co.', 255), 'stable');

        String longValue = 'x'.repeat(100) + '9'.repeat(100);
        String longScrambled = (String) mask('Scramble', longValue, 255);
        Assert.areEqual(200, longScrambled.length(), 'long values keep their length');
        Assert.isTrue(Pattern.matches('[a-z]{100}[0-9]{100}', longScrambled), 'classes kept across hash blocks');
        Assert.areEqual('', mask('Scramble', '', 255), 'empty stays empty');
    }

    @IsTest
    static void hashFixedAndNull() {
        String hashed = (String) mask('Hash', 'secret', 255);
        Assert.isTrue(Pattern.matches('h_[0-9a-f]{16}', hashed), 'hash shape: ' + hashed);
        Assert.areEqual(hashed, mask('Hash', 'secret', 255), 'hash is stable');

        MaskContext fixedCtx = new MaskContext('s', new MaskRule('Contact', 'Title', 'Fixed').withFixedValue('Redacted'), 128);
        Assert.areEqual('Redacted', MaskStrategies.forName('Fixed').mask('CEO', fixedCtx), 'fixed value');
        MaskContext blankFixed = new MaskContext('s', new MaskRule('Contact', 'Title', 'Fixed'), 128);
        Assert.isNull(MaskStrategies.forName('Fixed').mask('CEO', blankFixed), 'blank fixed value clears the field');
        Assert.isNull(mask('Null', 'anything', 10), 'null strategy clears the field');
    }

    @IsTest
    static void valuesAreTruncatedToTheFieldLength() {
        String email = (String) mask('Email', 'someone@customer.test', 10);
        Assert.areEqual(10, email.length(), 'truncated to the field length');
        Assert.areEqual('Ab', new MaskContext('s', null, 2).fit('Abc'), 'fit truncates');
        Assert.areEqual('Abc', new MaskContext('s', null, null).fit('Abc'), 'unknown length leaves the value alone');
        Assert.isNull(new MaskContext('s', null, 5).fit(null), 'null passes through');
    }

    @IsTest
    static void unknownStrategyIsAnError() {
        try {
            MaskStrategies.forName('Bogus');
            Assert.fail('expected UnknownStrategyException');
        } catch (MaskStrategies.UnknownStrategyException e) {
            Assert.isTrue(e.getMessage().contains('Bogus'), 'message names the strategy');
        }
    }
}
