// List fields that look like personal data but have no active Mask Rule. Safe anywhere: it reads the schema, not the data.
// From the CLI:  sf apex run -o <org alias> -f scripts/apex/audit-coverage.apex
// Pass your own objects with MaskCoverageAudit.audit(new Set<String>{ 'Contact', 'Patient__c' }) on big orgs.
System.debug(LoggingLevel.INFO, '\n' + MaskCoverageAudit.report(MaskCoverageAudit.audit()));
