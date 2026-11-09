-- Baseline fixture. No SavedVariables and no automatic messages or timers.
CallToArmsProbeSnapshots = CallToArmsProbeSnapshots or {}
local name = "CallToArmsProbeSnapshot02"
local previous = CallToArmsProbeSnapshots[name]
CallToArmsProbeSnapshots[name] = {
    marker = "BASELINE_02",
    writtenUtc = "baseline-fixture",
    executions = (previous and previous.executions or 0) + 1,
}
