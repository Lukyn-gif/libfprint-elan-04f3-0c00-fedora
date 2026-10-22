# Path to upstream support

`04f3:0c00` is missing from the upstream supported-device list. This Fedora
repository is a hardware-specific integration of the `elanmoc2` branch, not
an independent new protocol implementation.

For an upstream libfprint submission:

1. Rebase the `elanmoc2` driver onto current libfprint and split protocol
   support, safety fixes, and retry handling into reviewable commits.
2. Provide hardware evidence for `04f3:0c00` revision `0281`: firmware
   query, eight-stage enrollment, commit, match, nonmatch, cancellation,
   deletion, cold boot, and suspend/resume. Use the matrix in `TESTING.md`.
3. Add a regression test for the retry path. `fpi_device_verify_report()`
   accepts only one report per action. The older driver reported a retry
   error, continued scanning in the same action, then reported again,
   producing `result_reported == FALSE` assertions. Patch 0006 completes the
   action after its retry report; a fresh action is required for another scan.
4. Investigate genuine USB timeouts separately from no-finger timeouts using
   command, endpoint, and duration logs. If Linux traces are inconclusive,
   compare them with captures from the official Windows driver. Do not
   collect or publish fingerprint templates or other personal data.
5. Run the upstream test suite and address its results against a clean
   baseline. The current pinned branch has a generic
   `/driver/initial_features/no_storage` failure in both the earlier and
   updated builds on Fedora 44; the `elanmoc2` test is skipped in this
   build because introspection bindings are absent.

The tested installation uses an isolated `/opt` library and systemd override.
Once upstream support lands and Fedora ships it, remove this local override
with `bash elan-fprint.sh rollback` before using the Fedora package.
