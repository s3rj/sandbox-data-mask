// Show what the active rules would do to the first five Contact records. Nothing is written. Sandbox only.
// From the CLI:  sf apex run -o <sandbox alias> -f scripts/apex/preview-mask.apex
System.debug(LoggingLevel.INFO, '\n' + MaskPreview.report('Contact', 5));
