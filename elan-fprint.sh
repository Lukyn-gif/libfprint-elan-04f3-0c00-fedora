#!/usr/bin/env bash
set -euo pipefail

# Fedora 44, ELAN 04f3:0c00 bcdDevice 2.81 only.
# Build a pinned libfprint elanmoc2 fork and load it only in fprintd.

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
work_dir="${ELAN_BUILD_DIR:-$script_dir/work}"
source_dir="$work_dir/libfprint"
build_dir="$source_dir/build"
library="$build_dir/libfprint/libfprint-2.so.2.0.0"
install_dir="/opt/elan-fprint-fedora44/lib64"
override_dir="/etc/systemd/system/fprintd.service.d"
override_file="$override_dir/90-elan-fprint-fedora44.conf"
debug_file="$override_dir/91-elan-fprint-debug.conf"
upstream="https://gitlab.freedesktop.org/Depau/libfprint.git"
commit="11f0316d069cc90c154c8cb0e46478388c5e2a74"
expected_diff_sha="29ad9752f5ff3dcde8526ba0f4c89ec75b78fed7a4b56dcb0b5696388fa729b6"

usage() {
  printf 'Usage: %s build|install|status|debug-on|debug-off|rollback\n' "$0"
}

check_hardware() {
  source /etc/os-release
  [[ "$ID" == fedora && "$VERSION_ID" == 44 ]] || {
    echo 'This procedure was prepared for Fedora 44 only.' >&2
    exit 1
  }
  local dev vendor product revision found=no
  for dev in /sys/bus/usb/devices/*; do
    [[ -r "$dev/idVendor" && -r "$dev/idProduct" ]] || continue
    read -r vendor < "$dev/idVendor"
    read -r product < "$dev/idProduct"
    [[ "$vendor:$product" == '04f3:0c00' ]] || continue
    read -r revision < "$dev/bcdDevice"
    [[ "$revision" == '0281' ]] || {
      echo "ELAN revision $revision found; this build targets 2.81." >&2
      exit 1
    }
    echo "ELAN 04f3:0c00, revision 2.81 ($revision) found at $dev"
    found=yes
    break
  done
  [[ "$found" == yes ]] || { echo 'ELAN 04f3:0c00 not found.' >&2; exit 1; }
}

status() {
  echo 'Current fprintd library and service override:'
  if [[ -e "$override_file" ]]; then
    LD_LIBRARY_PATH="$install_dir" ldd /usr/libexec/fprintd | grep libfprint || true
  else
    ldd /usr/libexec/fprintd | grep libfprint || true
  fi
  systemctl cat fprintd.service | tail -12
  fprintd-list "$(id -un)" || true
}

rollback() {
  sudo rm -f -- "$override_file" "$debug_file"
  sudo rm -rf -- /opt/elan-fprint-fedora44
  sudo systemctl daemon-reload
  sudo systemctl restart fprintd.service
  echo 'Original Fedora libfprint is active again.'
  status
}

debug_on() {
  [[ -f "$override_file" && -e "$install_dir/libfprint-2.so.2" ]] || {
    echo 'Install the ELAN driver before enabling diagnostics.' >&2
    exit 1
  }
  if [[ -e "$debug_file" ]]; then
    echo "Diagnostics override already exists: $debug_file" >&2
    exit 1
  fi
  printf '[Service]\nEnvironment="G_MESSAGES_DEBUG=libfprint-elanmoc2"\n' \
    | sudo tee "$debug_file" >/dev/null
  sudo systemctl daemon-reload
  sudo systemctl restart fprintd.service
  echo 'ELAN driver diagnostics enabled for fprintd.'
}

debug_off() {
  if [[ -e "$debug_file" ]]; then
    sudo rm -f -- "$debug_file"
    sudo systemctl daemon-reload
    sudo systemctl restart fprintd.service
  fi
  echo 'ELAN driver diagnostics disabled.'
}

build_library() {
  check_hardware
  [[ -x /usr/libexec/fprintd ]] || { echo 'fprintd is missing.' >&2; exit 1; }

  if ! rpm -q --quiet git gcc meson ninja-build pkgconf-pkg-config \
      glib2-devel libgusb-devel; then
    echo 'Installing build dependencies (Fedora repositories only)...'
    sudo dnf --disablerepo='*' --enablerepo=fedora \
      --enablerepo=updates install -y \
      git gcc meson ninja-build pkgconf-pkg-config \
      glib2-devel libgusb-devel
  fi

  mkdir -p "$work_dir"
  if [[ ! -e "$source_dir" ]]; then
    git clone --branch elanmoc2 --single-branch "$upstream" "$source_dir"
    git -C "$source_dir" checkout --detach "$commit"

    local patch
    for patch in "$script_dir"/patches/*.patch; do
      git -C "$source_dir" apply --check "$patch"
      git -C "$source_dir" apply "$patch"
    done
  else
    echo 'Reusing the patched checkout from the previous run.'
  fi
  local actual_commit actual_diff_sha
  actual_commit="$(git -C "$source_dir" rev-parse HEAD)"
  actual_diff_sha="$(git -C "$source_dir" diff --binary | sha256sum)"
  actual_diff_sha="${actual_diff_sha%% *}"
  [[ "$actual_commit" == "$commit" && "$actual_diff_sha" == "$expected_diff_sha" ]] || {
    echo "Checkout differs from the pinned source and patches: $source_dir" >&2
    exit 1
  }
  git -C "$source_dir" diff --check

  if [[ ! -e "$build_dir/build.ninja" ]]; then
    if [[ -e "$build_dir" ]]; then
      local failed_dir
      failed_dir="$(mktemp -d "$work_dir/failed-build.XXXXXX")"
      mv -- "$build_dir" "$failed_dir/build"
    fi
    meson setup "$build_dir" "$source_dir" \
      --prefix=/opt/elan-fprint-fedora44 --libdir=lib64 \
      -Ddrivers=elanmoc2 -Dintrospection=false -Ddoc=false \
      -Dinstalled-tests=false -Dgtk-examples=false \
      -Dudev_rules=disabled -Dudev_hwdb=disabled
  fi
  meson compile -C "$build_dir"

  [[ -s "$library" ]] || { echo "Build output missing: $library" >&2; exit 1; }
  readelf -Ws "$library" | grep -F 'fp_context_new@@LIBFPRINT_2.0.0' >/dev/null || {
    echo 'Built library is missing the expected libfprint ABI.' >&2
    exit 1
  }
  local abi_output
  abi_output="$(LD_LIBRARY_PATH="$(dirname "$library")" ldd -r /usr/libexec/fprintd 2>&1)" || {
    echo "Could not check fprintd ABI: $abi_output" >&2
    exit 1
  }
  if [[ "$abi_output" == *'undefined symbol'* ]]; then
    echo 'The built library is incompatible with the installed fprintd.' >&2
    exit 1
  fi
  echo "Build and fprintd ABI check passed: $library"
}

install() {
  [[ ! -e "$override_file" && ! -e "$install_dir/libfprint-2.so.2" ]] || {
    echo 'This driver is already installed. Run rollback first to replace it.' >&2
    exit 1
  }
  build_library

  echo 'Installing isolated library for fprintd only...'
  sudo install -d -m 0755 "$install_dir" "$override_dir"
  sudo install -m 0755 "$library" "$install_dir/libfprint-2.so.2.0.0"
  sudo ln -s libfprint-2.so.2.0.0 "$install_dir/libfprint-2.so.2"
  sudo restorecon -R /opt/elan-fprint-fedora44 || true
  printf '[Service]\nEnvironment="LD_LIBRARY_PATH=%s"\n' "$install_dir" \
    | sudo tee "$override_file" >/dev/null
  sudo systemctl daemon-reload
  if ! sudo systemctl restart fprintd.service; then
    echo 'fprintd failed to restart; rolling back.' >&2
    rollback
    exit 1
  fi

  echo 'Checking that fprintd starts with the patched library...'
  if ! systemctl is-active --quiet fprintd.service; then
    echo 'fprintd did not start; rolling back.' >&2
    rollback
    exit 1
  fi
  local pid probe_output
  pid="$(systemctl show -p MainPID --value fprintd.service)"
  if ! sudo grep -q "$install_dir/libfprint-2.so.2" "/proc/$pid/maps"; then
    echo 'fprintd did not load the isolated library; rolling back.' >&2
    rollback
    exit 1
  fi
  if ! probe_output="$(busctl --system call net.reactivated.Fprint \
      /net/reactivated/Fprint/Manager net.reactivated.Fprint.Manager GetDevices 2>&1)"; then
    echo "fprintd device check failed: $probe_output" >&2
    rollback
    exit 1
  fi
  if [[ "$probe_output" == 'ao 0' ]]; then
    echo 'fprintd still sees no fingerprint device; rolling back.' >&2
    rollback
    exit 1
  fi
  echo 'Driver installed. Next: fprintd-enroll -f right-index-finger'
  printf '%s\n' "$probe_output"
  status
}

case "${1:-}" in
  build) build_library ;;
  install) install ;;
  status) status ;;
  debug-on) debug_on ;;
  debug-off) debug_off ;;
  rollback) rollback ;;
  *) usage; exit 2 ;;
esac
