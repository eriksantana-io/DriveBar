# Developer ID signing and notarization

Use an active Apple Developer Program membership and Xcode. In Xcode Settings → Accounts, add your Apple Account, select the developer team, and open Manage Certificates. Create a **Developer ID Application** certificate. If creation is unavailable, contact the team's Account Holder. The matching private key must be installed in your Mac's Keychain.

Check available identities:

```sh
security find-identity -v -p codesigning
```

Create an app-specific password for your Apple Account at https://account.apple.com. Store notarization credentials in your local Keychain; this command prompts for the values instead of including them in shell history:

```sh
xcrun notarytool store-credentials "DriveBar-notary"
```

Enter your Apple Account email, developer Team ID, and app-specific password when requested. Do not commit passwords, API keys, certificate exports, or private keys to GitHub.

Build, sign, submit to Apple, staple, and verify:

```sh
export DRIVEBAR_SIGNING_IDENTITY="Developer ID Application: YOUR CERTIFICATE NAME (TEAMID)"
bash scripts/notarize.sh DriveBar-notary
```

Copy the exact certificate name (or its SHA-1 identity) from `security find-identity`. The script requires Apple to return Accepted, then staples and validates the ticket, checks Gatekeeper, and produces `dist/DriveBar.zip`. Internet access and access to the signing private key are required. Keychain may ask you to approve codesign access.

Publish the resulting signed archive as a new release after pushing the source:

```sh
git push origin main
gh release create v1.1.2 dist/DriveBar.zip --target main --title "DriveBar 1.1.2" --notes "Fix drive detection for external storage and removable cards in built-in readers."
```

For submission errors, use the ID in `dist/notarization-result.json`:

```sh
xcrun notarytool log SUBMISSION_ID --keychain-profile DriveBar-notary
```

Running `bash scripts/build.sh` without DRIVEBAR_SIGNING_IDENTITY still produces a local development build. Rebuilding after notarization replaces the signed app and requires notarization again before distribution.
