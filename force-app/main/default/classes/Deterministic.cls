/**
 * Stable, salted hashing. The same salt and input always produce the same number, hex string, or byte
 * stream, which is what lets a masked person look the same on every record and after every sandbox refresh.
 */
public with sharing class Deterministic {
    private static final String HEX_DIGITS = '0123456789abcdef';

    /** Non-negative Integer derived from SHA-256(salt | input). */
    public static Integer value(String salt, String input) {
        return hexToInt(hex(salt, input, 7)); // 28 bits always fits an Integer
    }

    /** Index in [0, modulus). */
    public static Integer index(String salt, String input, Integer modulus) {
        return Math.mod(value(salt, input), modulus);
    }

    /** The first `length` hex characters (up to 64) of SHA-256(salt | input). */
    public static String hex(String salt, String input, Integer length) {
        return fullHex(salt, input).substring(0, length);
    }

    /** All 32 bytes of SHA-256(salt | input) as Integers in [0, 255]. */
    public static List<Integer> bytes(String salt, String input) {
        String digest = fullHex(salt, input);
        List<Integer> out = new List<Integer>();
        for (Integer i = 0; i < 64; i += 2) {
            out.add(hexToInt(digest.substring(i, i + 2)));
        }
        return out;
    }

    private static String fullHex(String salt, String input) {
        String material = salt + '|' + (input == null ? '' : input);
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(material)));
    }

    private static Integer hexToInt(String hexString) {
        Integer result = 0;
        for (Integer i = 0; i < hexString.length(); i++) {
            result = result * 16 + HEX_DIGITS.indexOf(hexString.substring(i, i + 1));
        }
        return result;
    }
}
