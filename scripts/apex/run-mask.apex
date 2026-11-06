// Queue a mask run for every object with active rules.
// From the CLI:  sf apex run -o <sandbox alias> -f scripts/apex/run-mask.apex
Id runId = SandboxDataMaskRunner.run();
System.debug(LoggingLevel.INFO, 'Queued mask run ' + runId + '. Follow progress on the Mask Runs tab.');
