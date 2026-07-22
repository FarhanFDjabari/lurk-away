cask "lurkaway" do
  version "1.0.0"
  sha256 "3f6f4ec06f4f4e2f3b1f035f1f34fb939a1de522e01a8efe2a5e7bd98817a8cd"

  url "https://github.com/FarhanFDjabari/lurk-away/releases/download/v#{version}/LurkAway.zip",
      verified: "github.com/FarhanFDjabari/lurk-away/"
  name "LurkAway"
  desc "Menu bar anti-theft watchdog that locks and alarms when you step away"
  homepage "https://github.com/FarhanFDjabari/lurk-away"

  depends_on macos: :tahoe

  app "LurkAway.app"

  # Release builds are not notarized, so Gatekeeper would block the app outright.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/LurkAway.app"]
  end

  uninstall launchctl: "com.lurkaway.sleepd",
            quit:      "dev.djabari.LurkAway"

  zap trash: [
    "~/Library/Application Support/LurkAway",
    "~/Library/Caches/dev.djabari.LurkAway",
    "~/Library/HTTPStorages/dev.djabari.LurkAway",
    "~/Library/Preferences/dev.djabari.LurkAway.plist",
  ]
end
