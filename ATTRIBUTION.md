# Attribution and patch provenance

This repository downloads a pinned revision of
[Depau's `elanmoc2` branch](https://gitlab.freedesktop.org/Depau/libfprint/-/tree/elanmoc2).
The branch is part of `libfprint` and is licensed LGPL-2.1-or-later.

| Patch | Origin |
| --- | --- |
| 0001 | Six-byte enroll command for `04f3:0c00`, adapted from [bassemabdelbaset](https://github.com/bassemabdelbaset/libfprint-elan-04f3-0c00-ubuntu). |
| 0002 | Safer deletion and no implicit whole-sensor wipe, based on [jvikramsrd](https://github.com/jvikramsrd/elan-0c00). |
| 0003 | Retry `GError` ownership correction by jvikramsrd. |
| 0004 | Finger info reply length checks by jvikramsrd. |
| 0005 | Fedora build adjustment: omit the unrelated C++ example. |
| 0006 | Complete a retryable verify/identify action after its single result report. |

The work is not affiliated with ELAN, HP, Fedora, or the `libfprint`
maintainers. Fingerprint templates remain on the sensor; this repository does
not contain fingerprint templates or a Windows binary driver.
