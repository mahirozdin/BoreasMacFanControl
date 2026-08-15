#!/usr/bin/env bash
# ============================================================================
# P8.08 groundwork — generate the Homebrew cask from the disk image itself.
#
# Written by the release job rather than kept by hand, for the reason the rest
# of this project derives things: a cask carries a version and a SHA-256, and
# both are facts about an artefact that does not exist until it is built. A
# hand-maintained cask is a file that is wrong between every release.
#
# The submission is still a manual step (M05) and always will be: it means
# opening a pull request against somebody else's repository, or creating a tap.
# ============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

DMG="${1:-}"
OUT="${2:-build/dmg/boreas.rb}"
if [ ! -f "${DMG:-}" ]; then
  echo "usage: scripts/make-cask.sh /path/to/Boreas-<version>.dmg [out.rb]" >&2
  exit 1
fi

VERSION=$(basename "$DMG" .dmg | sed 's/^Boreas-//')
SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')
REPO="${CASK_REPOSITORY:-mahirozdin/BoreasMacFanControl}"

cat > "$OUT" <<CASK
cask "boreas" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/$REPO/releases/download/v#{version}/Boreas-#{version}.dmg",
      verified: "github.com/$REPO/"
  name "Boreas"
  desc "Fan control and temperature monitoring for Apple Silicon Macs"
  homepage "https://github.com/$REPO"

  # Intel is out of scope by design (ADR 0004), and the minimum is macOS 14
  # (ADR 0003). Declared rather than discovered at launch.
  #
  # The symbol form, not ">= :sonoma": Homebrew deprecated the string
  # comparison and says so on every tap, which is noise a user should not have
  # to learn to ignore.
  depends_on macos: :sonoma
  depends_on arch: :arm64

  app "Boreas.app"
  # The command line tool ships beside the app in the image rather than inside
  # the bundle, so that nesting never constrains the signing order.
  binary "boreas"

  uninstall quit:      "com.bubiapps.boreas",
            launchctl: "com.bubiapps.boreas.fanhelper"

  # The application removes its own helper when asked; this is the safety net
  # for the case where it was dragged to the Trash instead. Nothing here
  # touches firmware or NVRAM, because nothing ever wrote to them.
  zap trash: [
    "~/Library/Application Support/Boreas",
    "~/Library/Preferences/com.bubiapps.boreas.plist",
  ]
end
CASK

echo "  ✓ $OUT (version $VERSION)"
