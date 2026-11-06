@IsTest
private class DeterministicTest {
    @IsTest
    static void sameInputsGiveSameOutputs() {
        Assert.areEqual(Deterministic.value('salt', 'alice'), Deterministic.value('salt', 'alice'), 'value is stable');
        Assert.areEqual(Deterministic.hex('salt', 'alice', 12), Deterministic.hex('salt', 'alice', 12), 'hex is stable');
        Assert.areEqual(Deterministic.bytes('salt', 'alice'), Deterministic.bytes('salt', 'alice'), 'bytes are stable');
    }

    @IsTest
    static void saltAndInputBothChangeTheOutput() {
        Assert.areNotEqual(Deterministic.value('salt', 'alice'), Deterministic.value('other', 'alice'), 'salt changes the value');
        Assert.areNotEqual(Deterministic.value('salt', 'alice'), Deterministic.value('salt', 'bob'), 'input changes the value');
    }

    @IsTest
    static void indexStaysInRangeAndValueIsNonNegative() {
        for (Integer i = 0; i < 200; i++) {
            Integer index = Deterministic.index('salt', 'record' + i, 7);
            Assert.isTrue(index >= 0 && index < 7, 'index in range: ' + index);
            Assert.isTrue(Deterministic.value('salt', 'record' + i) >= 0, 'value is non-negative');
        }
    }

    @IsTest
    static void bytesAndHexHaveTheExpectedShape() {
        List<Integer> bytes = Deterministic.bytes('salt', 'x');
        Assert.areEqual(32, bytes.size(), 'SHA-256 gives 32 bytes');
        for (Integer b : bytes) {
            Assert.isTrue(b >= 0 && b <= 255, 'byte in range: ' + b);
        }
        Assert.areEqual(6, Deterministic.hex('salt', 'x', 6).length(), 'hex length honours the request');
        Assert.isTrue(Deterministic.hex('salt', 'x', 64).isAlphanumeric(), 'hex is alphanumeric');
    }

    @IsTest
    static void nullInputIsTreatedAsEmpty() {
        Assert.areEqual(Deterministic.value('salt', ''), Deterministic.value('salt', null), 'null equals empty');
    }
}
