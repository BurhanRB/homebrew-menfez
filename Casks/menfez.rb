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
# SIGNED FROM 1.0.5
# From 1.0.5 the app is Developer ID signed and notarised, so Gatekeeper passes
# on a default configuration. The cask stays in a third-party tap
# (`burhanrb/menfez`) until the first stable release (1.1.0); it can then move
# to homebrew/cask with no change to the stanza below.
cask "menfez" do
  version "1.0.7"

  on_arm do
    sha256 "eeabfc30b5ee26acdf607f13046b79609bdc92f04091fd82eb01990e415d9326"

    url "https://github.com/BurhanRB/Menfez/releases/download/v#{version}/Menfez-#{version}-arm64.dmg"
  end
  on_intel do
    sha256 "0d0253627a8bfba25bb16bd2f0c7082e9dc7b70661ccb4fea46ed0d8d6269718"

    url "https://github.com/BurhanRB/Menfez/releases/download/v#{version}/Menfez-#{version}-intel.dmg"
  end

  name "Menfez"
  desc "Open Discord on networks with SNI-based DPI blocking"
  homepage "https://menfez.app/"

  livecheck do
    url :url
    strategy :github_latest
  end

  # 1.0.6+: the app updates itself (Sparkle), so brew upgrade leaves it alone.
  auto_updates true
  depends_on macos: :ventura

  app "Menfez.app"

  # The optional tunnel setup (install-helper.sh) copies the helper into
  # /Library/PrivilegedHelperTools/menfez and grants it in /etc/sudoers.d/menfez.
  # A cask cannot create that grant (it needs root and is opt-in by design).
  #
  # Plain `uninstall` (which also runs on `brew upgrade`) only quits the app, so
  # an upgrade keeps the helper and the app offers "Güncelle" when it is outdated.
  # Removing the helper is `zap` (`brew uninstall --zap --cask menfez`), or the
  # app's "Tüneli kaldır". Order matters, as in uninstall.sh: the helper first
  # takes the tunnel down and restores DNS from
  # /Library/Application Support/Menfez/dns-state.json (or
  # /var/run/menfez/dns-state.json from older releases; only when that record
  # exists, so a resolver the user set by hand is kept), then the state, the rule
  # and the helper are removed. Every step is best effort and a no-op when the
  # tunnel was never set up.
  #
  # 1.0.7+: zap also deletes the profiles' private keys from the user's login
  # Keychain (generic passwords of service com.menfez.app.wireguard, nothing
  # else). That step runs as the user, not under sudo, so it reaches the user's
  # keychain; it stops when none is left (capped at 200).
  uninstall quit: "com.menfez.app"

  zap early_script: {
        executable:   "/bin/sh",
        args:         [
          "-c",
          "n=0; while [ $n -lt 200 ] && " \
          "/usr/bin/security delete-generic-password -s com.menfez.app.wireguard >/dev/null 2>&1; " \
          "do n=$((n + 1)); done; exit 0",
        ],
        must_succeed: false,
      },
      script:       {
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
      delete:       [
        "/etc/sudoers.d/menfez",
        "/Library/PrivilegedHelperTools/menfez",
      ],
      trash:        "~/Library/Application Support/Menfez"

  caveats <<~EOS
    DPI mode works right away and needs no administrator password.

    The WireGuard tunnel mode is optional and needs your own WireGuard .conf
    file. It also needs a one-time setup, which this cask does not run for you:
      brew install wireguard-tools wireguard-go bash
    then press "Tüneli kur" / "Set up tunnel" in Menfez; macOS asks for your
    administrator password. This copies the tunnel helper to
    /Library/PrivilegedHelperTools/menfez and allows only that helper to run
    with sudo.

    To remove the tunnel helper too, use `brew uninstall --zap --cask menfez`
    or "Tüneli kaldır" / "Remove tunnel" in Menfez.
  EOS
end
