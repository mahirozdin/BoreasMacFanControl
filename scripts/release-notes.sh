#!/usr/bin/env bash
# ============================================================================
# Release notes for a tag, assembled rather than written twice.
#
# A 0.x version is a pre-release by definition, and this prints the warning
# that goes with it: the software has run on exactly one machine, and somebody
# installing it is being asked to watch their own.
# ============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

VERSION="${1:?usage: scripts/release-notes.sh <version>}"

case "$VERSION" in
  0.*|*-beta*|*-rc*)
cat <<'WARNING'
> ## Beta — please read before installing
>
> **This has run on one Mac.** A Mac mini (M4, 2024). Every other Apple Silicon
> model should work and none has been tried, so treat this as software under
> test rather than a finished product.
>
> **Watch your machine while you use it.** Boreas writes fan speeds. Five safety
> layers can only ever *raise* them, three of those cannot be switched off, and a
> watchdog hands the fans back to the firmware if the app stops answering — but
> none of that has been exercised on your hardware. Keep an eye on temperatures
> for the first while, especially under sustained load.
>
> **If something looks wrong, quit Boreas.** Quitting returns the fans to the
> firmware immediately and unconditionally. So does removing it.
>
> **Monitoring alone needs no privileges and changes nothing.** You can run it
> without ever enabling fan control, and that is the safe way to start.
>
> Reports are the point of a beta: sensors shown as `uncategorized`, a fan that
> does not respond, anything that reads wrong in your language.

WARNING
    ;;
esac

# The section for this version, straight out of the changelog, so the notes and
# the file cannot disagree.
awk -v v="$VERSION" '
  $0 ~ "^## \\[" v "\\]" { inside = 1; next }
  inside && /^## \[/ { exit }
  inside { print }
' CHANGELOG.md
