# Hardware test plan

Record firmware revision, Fedora and libfprint versions, whether the reader
was freshly booted or resumed, and the exact output for each test. Do not
publish fingerprint templates, account passwords, or unreviewed debug logs.

1. Confirm `04f3:0c00`, `bcdDevice 0281`, and `fprintd-list "$USER"` after a
   cold boot and after a restart.
2. Enroll one finger from an empty sensor: eight accepted stages, successful
   commit, then list the finger.
3. Run at least 20 verifications with that finger and 10 with a different
   finger. Record matches, nonmatches, retries, timeouts, and daemon crashes.
4. Repeat verification after suspend and resume and with USB autosuspend in
   its default state. The earlier `power/control=on` experiment did not by
   itself remove timeouts.
5. Cancel a waiting verification. Confirm the next attempt still works.
6. Delete only the test finger and verify that other stored fingerprints, if
   present, remain. Never run whole-sensor clear as part of routine testing.
7. Try GDM login, screen unlock, and an application using PAM. Keep password
   fallback available throughout.

The build with patch 0006 was installed on the tested reader. One matching
and one different finger produced `verify-match` and `verify-no-match`
respectively. A retryable scan error has not yet been reproduced with this
build, so the duplicate-result regression remains unverified on hardware.
`sudo -k` followed by `sudo -v` succeeded with the enrolled finger and no
password. GNOME screen unlock after Super+L also succeeded by fingerprint.
A new GDM login with this build remains to be tested.
The upstream `fpi-ssm` unit test passed. The older source branch's generic
`fpi-device` test fails at `/driver/initial_features/no_storage` in this
build; `elanmoc2` driver tests are skipped because introspection bindings are
not installed. These results do not establish hardware reliability.
