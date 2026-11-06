/**
 * Word lists for readable fakes. Email domains are the RFC 2606 reserved ones, so a masked address
 * can never deliver to a real mailbox.
 */
public with sharing class FakeData {
    private static final List<String> FIRST_NAMES = new List<String>{
        'Ada', 'Amir', 'Ana', 'Andre', 'Anika', 'Asha', 'Ben', 'Bianca', 'Caleb', 'Carmen', 'Chen', 'Clara',
        'Dani', 'Dev', 'Diego', 'Elena', 'Eli', 'Emeka', 'Erin', 'Farah', 'Felix', 'Gabe', 'Gia', 'Hana',
        'Hugo', 'Ida', 'Ivan', 'Jade', 'Jonas', 'Juno', 'Kai', 'Kira', 'Leo', 'Lena', 'Luca', 'Maya',
        'Milo', 'Nadia', 'Nico', 'Noor', 'Omar', 'Orla', 'Pavel', 'Priya', 'Quinn', 'Rafael', 'Rhea', 'Rosa',
        'Sami', 'Sana', 'Sofia', 'Tariq', 'Tess', 'Theo', 'Tomas', 'Uma', 'Vera', 'Vikram', 'Wes', 'Yara',
        'Yusuf', 'Zara', 'Zoe', 'Zev'
    };
    private static final List<String> LAST_NAMES = new List<String>{
        'Abara', 'Adeyemi', 'Alvarez', 'Becker', 'Bennett', 'Brooks', 'Byrne', 'Castillo', 'Chen', 'Cole',
        'Costa', 'Dasgupta', 'Diaz', 'Dubois', 'Dunn', 'Egan', 'Ellis', 'Farouk', 'Fischer', 'Flores', 'Fox',
        'Garcia', 'Grant', 'Haddad', 'Hayes', 'Ibrahim', 'Iyer', 'Jensen', 'Kapoor', 'Khan', 'Kowalski',
        'Larsen', 'Lee', 'Lopez', 'Mehta', 'Moreau', 'Morgan', 'Nakamura', 'Navarro', 'Novak', 'Okafor',
        'Olsen', 'Ortiz', 'Park', 'Patel', 'Petrov', 'Quinn', 'Ramos', 'Reyes', 'Rossi', 'Sato', 'Schmidt',
        'Silva', 'Singh', 'Sousa', 'Tanaka', 'Torres', 'Varga', 'Vega', 'Walsh', 'Weber', 'Yamamoto', 'Young',
        'Zhang'
    };
    private static final List<String> STREETS = new List<String>{
        'Maple Street', 'Oak Avenue', 'Cedar Lane', 'Pine Road', 'Elm Drive', 'Birch Court', 'Willow Way',
        'Aspen Place', 'Juniper Boulevard', 'Sycamore Terrace', 'Harbor Street', 'Ridge Road', 'Canyon Drive',
        'Meadow Lane', 'Summit Avenue', 'Valley Road', 'Lakeview Drive', 'Prairie Street', 'Orchard Lane',
        'Mill Road', 'Garden Court', 'Highland Avenue', 'Sunset Boulevard', 'Riverside Drive', 'Park Street',
        'Union Avenue', 'Market Street', 'Bridge Road', 'Spring Lane', 'Forest Drive', 'Copper Street',
        'Saguaro Way'
    };
    private static final List<String> DOMAINS = new List<String>{ 'example.com', 'example.net', 'example.org' };

    public static String firstName(Integer index) {
        return FIRST_NAMES[index];
    }
    public static Integer firstNameCount() {
        return FIRST_NAMES.size();
    }
    public static String lastName(Integer index) {
        return LAST_NAMES[index];
    }
    public static Integer lastNameCount() {
        return LAST_NAMES.size();
    }
    public static String street(Integer index) {
        return STREETS[index];
    }
    public static Integer streetCount() {
        return STREETS.size();
    }
    public static String domain(Integer index) {
        return DOMAINS[index];
    }
    public static Integer domainCount() {
        return DOMAINS.size();
    }
}
