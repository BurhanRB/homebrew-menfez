# typed: strict
# frozen_string_literal: true

# Homebrew cask for Menfez.
#
# TWO CASKS, NOT ONE
# macOS 27 warns every Apple-silicon user whose download contains an x86_64
# slice: "this app contains a component that will not open on macOS 28". The
# slice exists for Intel Macs, so shipping one universal build would show a
# warning to the majority who can never trigger it. The cask picks the right
# image for the machine instead of asking the user to know their own CPU.
#
# WHY `on_arm` / `on_intel` RATHER THAN ONE `url`
# Homebrew supports per-architecture URLs through the `on_arm` and `on_intel`
# blocks. That keeps one cask name (`menfez`) so `brew install --cask menfez`
# works everywhere, which is what users will type.
#
# INSTALLING BEFORE THE DEVELOPER ID ARRIVES
# The app is ad-hoc signed. Official homebrew/cask requires Gatekeeper to pass on
# a default configuration, so this cask belongs in a third-party tap
# (`burhanrb/menfez`) until notarisation lands. After that it can move to
# homebrew/cask with no change to the stanza below.
cask "menfez" do
  version "1.0.0"

  on_arm do
    sha256 "f1023084771641059d94e98fc056d8bd8434a2806797cf2026c67a5166f4d3ff"

    url "https://github.com/BurhanRB/Menfez/releases/download/v#{version}/Menfez-#{version}-arm64.dmg"
  end
  on_intel do
    sha256 "3eb549b75a64a4d1c9acdb02733488d85cdef1f341f5571c9ff3c797e353be5c"

    url "https://github.com/BurhanRB/Menfez/releases/download/v#{version}/Menfez-#{version}-intel.dmg"
  end

  name "Menfez"
  desc "Open Discord on networks with SNI-based DPI blocking"
  homepage "https://menfez.app/"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "Menfez.app"

  # The optional tunnel setup (install-helper.sh) copies the helper into
  # /Library/PrivilegedHelperTools/menfez and grants it in /etc/sudoers.d/menfez.
  # A cask cannot create that grant (it needs root and is opt-in by design), but
  # it must not leave it behind. Order matters, as in uninstall.sh: the helper
  # first takes the tunnel down and restores DNS from /Library/Application Support/Menfez/dns-state.json
  # (or /var/run/menfez/dns-state.json from older releases)
  # (only when that record exists, so a resolver the user set by hand is kept),
  # then the state, the rule and the helper are removed. Every step is best
  # effort and a no-op when the tunnel was never set up.
  #
  # This is `uninstall`, not only `zap`, so it also runs on `brew upgrade`: the
  # root-owned copy is of the old version anyway, and the caveat asks the user
  # to re-run the setup after an upgrade.
  uninstall script: {
              executable:   "/bin/sh",
              args:         [
                "-c",
                "H=/Library/PrivilegedHelperTools/menfez/menfez-route; " \
                "if [ -x \"$H\" ] && [ \"$(stat -f %u \"$H\")\" = 0 ]; then " \
                "\"$H\" down; " \
                "D='/Library/Application Support/Menfez/dns-state.json'; " \
                "{ [ -f \"$D\" ] || [ -f /var/run/menfez/dns-state.json ]; } && \"$H\" dns auto; " \
                "fi; rm -rf /var/run/menfez '/Library/Application Support/Menfez'; exit 0",
              ],
              sudo:         true,
              must_succeed: false,
            },
            delete: [
              "/etc/sudoers.d/menfez",
              "/Library/PrivilegedHelperTools/menfez",
            ]

  zap trash: "~/Library/Application Support/Menfez"

  caveats <<~EOS
    Menfez is not signed by Apple yet, so macOS blocks the first launch.
    Open Menfez once, click Done, then go to System Settings > Privacy &
    Security, scroll down and click "Open Anyway". You only do this once.

    DPI mode works right away and needs no administrator password.

    The WireGuard tunnel mode is optional and needs your own WireGuard .conf
    file. It also needs a one-time setup that asks for your password, which
    this cask does not run for you:
      brew install wireguard-tools wireguard-go bash
      sudo /bin/bash /Applications/Menfez.app/Contents/Resources/install-helper.sh \\
        /Applications/Menfez.app/Contents/MacOS/menfez-route "$USER"
    This copies the tunnel helper to /Library/PrivilegedHelperTools/menfez and
    allows only that helper to run with sudo. Run it again after each upgrade.
  EOS
end
