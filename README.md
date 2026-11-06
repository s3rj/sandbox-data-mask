# sandbox-data-mask

Deterministic PII masking for Salesforce sandboxes, driven by custom metadata, with a post-refresh hook so a sandbox is clean before the first tester logs in.

A refreshed Full or Partial sandbox is a copy of production: customer names, emails, phone numbers, and addresses, readable by every developer, tester, and contractor with a login. Salesforce only neuters User emails. Most teams cover the gap with an anonymous Apex script someone wrote once, that nobody re-runs, and that breaks the first time a field changes. This project turns that script into a configurable, bulk-safe, auditable job that refuses to run anywhere except a sandbox.

## What it does

- **Rules live in custom metadata.** Each `Mask_Rule__mdt` record names an object, a field, and a strategy. An optional `Mask_Object__mdt` record sets the processing order and a `WHERE` clause that limits which records are touched. Rules deploy with the rest of your metadata and need no code change to adjust.
- **Fakes are deterministic.** Every fake is derived from the original value and a per-org salt, so `alice@customer.test` becomes the same `ada.okafor.3f9a2c@example.org` on the Contact, the Lead, and the Case, in every run and after every refresh. Joins, dedup rules, and test scripts keep working, and nothing about the original can be recovered without the salt.
- **It is bulk-safe.** One batch per object, chained in order, `Database.update` with partial success, duplicate rules bypassed, record-level errors captured instead of aborting the run.
- **It refuses to run in production.** `Organization.IsSandbox` is checked before anything is queued and again inside the batch.
- **It fails fast on bad configuration.** Object and field names, updateability, nullability, and strategy/field-type compatibility are validated against the describe before the first batch is queued, so a typo in a rule is an error in the caller's face, not a half-masked sandbox.
- **It leaves an audit trail.** A `Mask_Run__c` record per object per run: fields masked, records processed and failed, batch job id, timings, and the first 25 record-level errors.

## Strategies

| Strategy | Produces | Example |
|---|---|---|
| `FirstName` | A first name from a word list, chosen by the original value | `Alice` → `Priya` |
| `LastName` | A last name from a word list | `Smith` → `Okafor` |
| `Email` | `first.last.tag@example.{com,net,org}` (RFC 2606 reserved domains, so nothing can be delivered) | `alice@customer.test` → `ada.okafor.3f9a2c@example.org` |
| `Phone` | `(NXX) 555-01XX`, the block reserved for fiction | `602-555-1234` → `(480) 555-0147` |
| `Street` | House number plus a street from a word list | `1 Real Rd` → `4821 Juniper Boulevard` |
| `Scramble` | Same length, letters stay letters (case kept), digits stay digits, punctuation stays put | `ACME-00123 Co.` → `QZTR-84910 Lw.` |
| `Hash` | `h_` plus 16 hex characters: an opaque token that still joins | `secret` → `h_9c2f...` |
| `Fixed` | The rule's `Fixed Value`, or null when blank | `CEO` → `Redacted` |
| `Null` | Clears the field. The only strategy that works on non-text fields | `1985-04-12` → null |

Text strategies work on Text, Text Area, Long Text Area, Email, Phone, and URL fields and are truncated to the field's length. Records where the field is already blank are left blank unless the rule unchecks **Preserve Blank**.

## Install

```bash
sf project deploy start --target-org <sandbox>
sf org assign permset --name Sandbox_Data_Mask_Admin --target-org <sandbox>
```

The shipped rules cover the usual suspects: Contact and Lead names, emails, phones, and streets; Account phones and addresses; Case supplied name, email, and phone; Lead company (scrambled). Edit, deactivate, or add rules under **Setup > Custom Metadata Types > Mask Rule**.

## Run

Any of these:

```bash
# Anonymous Apex
sf apex run --target-org <sandbox> --file scripts/apex/run-mask.apex
```

```apex
Id firstRun = SandboxDataMaskRunner.run();
```

- **Flow:** add the Apex action **Run sandbox data mask** (optional input: batch size).
- **Automatically after every refresh:** in **Setup > Sandboxes**, when creating or refreshing a sandbox, set **Apex Class** to `MaskPostCopy`. The mask runs as soon as the copy finishes.

Progress is on the **Mask Runs** tab or with `scripts/soql/mask-runs.soql`.

## Keeping fakes stable across refreshes

The salt lives in the **Mask Settings** hierarchy custom setting. The first run in a sandbox generates one if it is blank, which keeps fakes stable across runs in that sandbox. To keep them stable across refreshes too, set `Salt` once in production: custom-setting data is copied with every refresh, and the tool never writes to production (it cannot run there). Changing the salt changes every fake on the next run.

## Scoping and exclusions

`Mask_Object__mdt` takes a `WHERE` clause without the keyword, for example:

| Object | Where Clause | Effect |
|---|---|---|
| Lead | `IsConverted = false` | Converted leads keep their data (their Contact gets masked instead) |
| Contact | `Account.Is_Internal__c = false` | Leave the team's own test accounts readable |
| Case | `CreatedDate = LAST_N_DAYS:365` | Only recent cases |

An inactive `Mask_Object__mdt` row switches an object off entirely, even if it has active rules. Where clauses are admin-managed metadata, not user input; validation checks object and field names against the describe before any query is built.

## What it does not do

- **Automation still fires.** Record-triggered flows, triggers, and validation rules run on the masking updates. If your org has a bypass pattern (a custom permission or a hierarchy custom setting), grant it to the running user before masking; otherwise expect some records to fail validation and show up in the run's error summary.
- **It does not mask Users, Usernames, or Person Accounts' person fields** out of the box. Users can be added as rules if the running user can edit them; Salesforce already invalidates User emails on refresh.
- **It does not touch field history, Chatter, email message bodies, attachments, or files.** Those need their own cleanup.
- **It is not encryption.** Deterministic fakes let a reader with the salt and a candidate value check whether that value was present. Keep the salt in production where only admins see it.
- **Big objects and external objects** are out of scope.

## Development

```bash
scripts/validate.sh <org alias>     # deploy and run all local tests with coverage
pmd check -d force-app -R pmd/ruleset.xml -f text   # static analysis, same ruleset as CI
```

CI runs PMD on every push and, when the `SF_AUTH_URL` secret is present (output of `sf org display --verbose`), deploys to that org and runs the tests.

Tests inject rules through `MaskRuleRepository.ruleOverride` because custom metadata records cannot be inserted in a test context, and set `OrgGuard.isSandboxOverride` because the test org may not be a sandbox. Batch chaining to the next object is skipped in tests, where only one batch execution is allowed.

## Design notes

- **One batch per object, chained from `finish()`**, rather than one batch over a union of objects: each object gets its own query locator, its own batch size, and its own audit record, and a failure in one object does not stop the others.
- **Custom metadata, not custom settings, for rules**: rules are configuration that should travel with deployments and show up in version control. The salt is the one value that must differ between orgs, so it is a custom setting.
- **Deterministic over random**: random fakes are simpler, but they break the relationships testers rely on (the same customer on two objects, the same email in a test script) and make duplicate rules fire unpredictably.
- **Validation before queuing**: Apex batch failures are quiet; a `ConfigException` thrown synchronously from `run()` is not.

## License

MIT
