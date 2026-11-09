-- Baseline fixture. No SavedVariables and no automatic messages or timers.
CallToArmsProbeSnapshots = CallToArmsProbeSnapshots or {}
local name = "CallToArmsProbeSnapshot03"
local previous = CallToArmsProbeSnapshots[name]
CallToArmsProbeSnapshots[name] = {
    marker = "BASELINE_03",
    writtenUtc = "baseline-fixture",
    executions = (previous and previous.executions or 0) + 1,
}
