/**
 * Masking strategies. Every strategy is deterministic: the fake is derived from the original value and the
 * org's salt, so one person gets the same fake name, email, and phone on every record and after every refresh,
 * while nothing about the original can be recovered without the salt.
 */
public with sharing class MaskStrategies {
    public interface Strategy {
        Object mask(Object original, MaskContext ctx);
    }

    public class UnknownStrategyException extends Exception {
    }

    private static final String LOWER = 'abcdefghijklmnopqrstuvwxyz';
    private static final String UPPER = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

    public static Strategy forName(String name) {
        switch on name {
            when 'FirstName' {
                return new FirstName();
            }
            when 'LastName' {
                return new LastName();
            }
            when 'Email' {
                return new Email();
            }
            when 'Phone' {
                return new Phone();
            }
            when 'Street' {
                return new Street();
            }
            when 'Scramble' {
                return new Scramble();
            }
            when 'Hash' {
                return new Hash();
            }
            when 'Fixed' {
                return new Fixed();
            }
            when 'Null' {
                return new NullValue();
            }
            when else {
                throw new UnknownStrategyException(
                    'Unknown mask strategy "' + name + '". Known: FirstName, LastName, Email, Phone, Street, Scramble, Hash, Fixed, Null.'
                );
            }
        }
    }

    private static String text(Object original) {
        return original == null ? '' : String.valueOf(original);
    }

    /** A first name picked by the original value, so the same source name maps to the same fake everywhere. */
    public class FirstName implements Strategy {
        public Object mask(Object original, MaskContext ctx) {
            Integer index = Deterministic.index(ctx.salt, text(original).toLowerCase(), FakeData.firstNameCount());
            return ctx.fit(FakeData.firstName(index));
        }
    }

    public class LastName implements Strategy {
        public Object mask(Object original, MaskContext ctx) {
            Integer index = Deterministic.index(ctx.salt, text(original).toLowerCase(), FakeData.lastNameCount());
            return ctx.fit(FakeData.lastName(index));
        }
    }

    /** first.last.tag@example.com; the tag keeps distinct source addresses distinct. */
    public class Email implements Strategy {
        public Object mask(Object original, MaskContext ctx) {
            String source = text(original).toLowerCase();
            String first = FakeData.firstName(Deterministic.index(ctx.salt, source, FakeData.firstNameCount()));
            String last = FakeData.lastName(Deterministic.index(ctx.salt, source + '#last', FakeData.lastNameCount()));
            String tag = Deterministic.hex(ctx.salt, source, 6);
            String domain = FakeData.domain(Deterministic.index(ctx.salt, source + '#domain', FakeData.domainCount()));
            return ctx.fit((first + '.' + last + '.' + tag + '@' + domain).toLowerCase());
        }
    }

    /** (NXX) 555-01XX: the 555-01 block is reserved for fiction, so a masked number cannot reach anyone. */
    public class Phone implements Strategy {
        public Object mask(Object original, MaskContext ctx) {
            String source = text(original);
            Integer area = 200 + Deterministic.index(ctx.salt, source + '#area', 800);
            if (Math.mod(area, 100) == 11) {
                area += 1; // N11 codes are service numbers, not area codes
            }
            Integer line = Deterministic.index(ctx.salt, source, 100);
            return ctx.fit('(' + area + ') 555-01' + (line < 10 ? '0' : '') + line);
        }
    }

    public class Street implements Strategy {
        public Object mask(Object original, MaskContext ctx) {
            String source = text(original).toLowerCase();
            Integer houseNumber = 100 + Deterministic.index(ctx.salt, source + '#number', 9900);
            String street = FakeData.street(Deterministic.index(ctx.salt, source, FakeData.streetCount()));
            return ctx.fit(houseNumber + ' ' + street);
        }
    }

    /**
     * Replaces letters with letters (keeping case) and digits with digits, leaving everything else in place,
     * so formats such as "ACME-00123" or "Dr. J. Smith" keep their shape. One hash covers 32 characters.
     */
    public class Scramble implements Strategy {
        public Object mask(Object original, MaskContext ctx) {
            String source = text(original);
            String result = '';
            List<Integer> block = new List<Integer>();
            for (Integer i = 0; i < source.length(); i++) {
                if (Math.mod(i, 32) == 0) {
                    block = Deterministic.bytes(ctx.salt, source + '#' + (i / 32));
                }
                Integer r = block[Math.mod(i, 32)];
                String ch = source.substring(i, i + 1);
                if (ch.isNumeric()) {
                    result += String.valueOf(Math.mod(r, 10));
                } else if (ch.isAlpha()) {
                    String alphabet = ch.isAllUpperCase() ? UPPER : LOWER;
                    Integer at = Math.mod(r, 26);
                    result += alphabet.substring(at, at + 1);
                } else {
                    result += ch;
                }
            }
            return ctx.fit(result);
        }
    }

    /** An opaque token: keeps joins between records possible without exposing the value. */
    public class Hash implements Strategy {
        public Object mask(Object original, MaskContext ctx) {
            return ctx.fit('h_' + Deterministic.hex(ctx.salt, text(original), 16));
        }
    }

    public class Fixed implements Strategy {
        public Object mask(Object original, MaskContext ctx) {
            return ctx.fit(String.isBlank(ctx.rule.fixedValue) ? null : ctx.rule.fixedValue);
        }
    }

    public class NullValue implements Strategy {
        public Object mask(Object original, MaskContext ctx) {
            return null;
        }
    }
}
