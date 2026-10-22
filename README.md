# ELAN 04f3:0c00 on Fedora 44

Experimental `libfprint` integration for the ELAN Match-on-Chip 2 USB reader
`04f3:0c00`, firmware revision `0281` (2.81). It was tested on an HP Pavilion
15-eg0900nc running Fedora 44. This is a patch set and installer for the
system fingerprint stack, **not** a standalone authentication app.

The installer pins [Davide Depau's `elanmoc2` branch](https://gitlab.freedesktop.org/Depau/libfprint/-/tree/elanmoc2)
at `11f0316d069cc90c154c8cb0e46478388c5e2a74`, applies the patches in
`patches/`, builds `libfprint`, and lets only `fprintd` load the resulting
library from `/opt/elan-fprint-fedora44/lib64`. Fedora's packaged library is
left in place. `rollback` removes this override and retains sensor templates.

## Status

- On the tested laptop, `fprintd-enroll` completed eight stages and committed
  a right index fingerprint. `fprintd-verify` returned `verify-match`.
- The fingerprint remained enrolled after a reboot, and `fprintd-list` still
  detected the reader.
- With the updated build, `sudo -k` followed by `sudo -v` authenticated with
  the enrolled finger without a password. GNOME screen unlock after Super+L
  also succeeded with the finger and no login password.
- Some earlier enroll and verify attempts timed out. The sensor also returned
  occasional nonmatches. Patch 0006 addresses a duplicate-result assertion
  seen after retryable scan errors. The updated build was installed and one
  matching finger returned `verify-match` while a different finger returned
  `verify-no-match`. The retryable-error path has not yet been reproduced
  with this build, so the assertion fix is not hardware verified.
- This is not an upstream or Fedora-supported driver. Other firmware revisions
  are intentionally rejected by the installer.
- A fresh GDM login with the updated build has not yet been confirmed.

## Install

Keep password login enabled as a fallback. Run from this repository:

```bash
bash elan-fprint.sh install
fprintd-list "$USER"
fprintd-verify -f right-index-finger
```

Run `fprintd-enroll -f right-index-finger` only if that finger is not already
listed. The sensor stores templates across reboots and driver reinstalls.
Enrollment can change templates stored on the sensor, including ones created
by Windows Hello; do not enroll if you still need those templates until you
have checked how the two systems interact on your device.

The script asks for `sudo` only for Fedora build dependencies and installation.
Enter the password in your own terminal, never in an issue or chat. If an
earlier version of this same override is installed, use its `rollback` command
first; the installer deliberately refuses to overwrite it.

The command accepts `build`, `status`, `debug-on`, `debug-off`, and `rollback`.
`build` checks the source, compiles, and checks the `fprintd` ABI without
installing the driver; it may install missing build dependencies. `debug-on`
temporarily enables driver messages in the `fprintd` journal. It should be
followed by `debug-off` when troubleshooting is complete. Debug logs can
contain local account identifiers; review them before posting publicly.

## Login and the GNOME keyring

On Fedora, enrollment is used by `fprintd` and PAM. The tested laptop had
`authselect` feature `with-fingerprint` enabled for GDM login. The installer
does not edit PAM configuration or remove password authentication.

A fingerprint authenticates the user, but it does not supply the password that
encrypts the GNOME Login keyring. After a fingerprint login, GNOME may ask once
for the keyring password when an app first accesses a saved secret. Changing
the keyring to an empty password avoids that prompt **at the cost of storing
its secrets without keyring password protection**. This repository does not
make that change. On a laptop without disk encryption, it is a substantial
loss of protection if the drive is read by someone else.

## How this differs from existing work

This repository does not claim to be the first `04f3:0c00` driver. It packages
and tests existing community work on Fedora 44 and adds a fix for retry
handling. The six-byte enrollment command comes from
[bassemabdelbaset's Ubuntu project](https://github.com/bassemabdelbaset/libfprint-elan-04f3-0c00-ubuntu).
Memory safety and deletion fixes build on
[jvikramsrd's work](https://github.com/jvikramsrd/elan-0c00).
The original driver by Davide Depau was reverse engineered from Windows USB
captures. See [ATTRIBUTION.md](ATTRIBUTION.md) for patch provenance.

The proper long-term destination is an upstream `libfprint` merge request,
with repeatable hardware results across cold boots, suspend and resume,
matching, nonmatching, enrollment, deletion, and cancellation. See
[docs/TESTING.md](docs/TESTING.md) and [docs/UPSTREAM.md](docs/UPSTREAM.md).

## License

The patched `libfprint` driver and this patch set are distributed under
LGPL-2.1-or-later, matching the upstream source. See [LICENSE](LICENSE).
