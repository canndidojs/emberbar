# Homebrew cask template. It is meant for a tap repository (e.g. canndidojs/homebrew-emberbar,
# file Casks/emberbar.rb). Update `version` and `sha256` for each release (the sha256 is in
# EmberBar-mac.zip.sha256 on the release page).
cask "emberbar" do
  version "0.1.0"
  sha256 "REPLACE_WITH_SHA256_FROM_THE_RELEASE"

  url "https://github.com/canndidojs/emberbar/releases/download/mac-v#{version}/EmberBar-mac.zip"
  name "EmberBar"
  desc "Claude usage limits in the menu bar"
  homepage "https://github.com/canndidojs/emberbar"

  depends_on macos: ">= :ventura"

  app "EmberBar.app"

  zap trash: [
    "~/Library/Containers/io.github.canndidojs.emberbar",
    "~/Library/Preferences/io.github.canndidojs.emberbar.plist",
  ]
end
