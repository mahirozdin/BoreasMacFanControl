# Boreas — development tools
#
# Install:  brew bundle
# Verify:   make bootstrap   (also checks that the tools actually WORK)
#
# NOTE: swift-format is NOT here. It ships built into the Swift 6.2
# toolchain and is invoked as the `swift format` subcommand. Installing a
# separate package would let two different versions collide.
#
# None of these is a RUNTIME dependency — they are not linked into the
# application and never enter the shipped product. See ADR 0013 and NOTICE.

brew "xcodegen"     # project.yml -> .xcodeproj  (ADR 0001, invariant T5)
brew "swiftlint"    # rule enforcement
brew "xcbeautify"   # makes xcodebuild output readable
brew "imagemagick"  # regenerates the icon and the disk image background

# imagemagick is needed only to REGENERATE artwork, never to build. Its two
# outputs — App/Resources/Boreas.icns and Design/dmg/background.png — are
# committed, so a fresh clone and a CI runner build the product without it.
# `make icon` and `make dmg-background` are the commands that need it.
