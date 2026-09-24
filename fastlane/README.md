# Marblezzz release automation

Adapted from the BillHive pre-ASC workflow for this single app. Run from the repository root with Fastlane installed. The publishing account must already contain the app and bundle identifier.

Set these environment variables locally; never commit credentials or signing files:

```sh
export ASC_KEY_ID='your-key-id'
export ASC_ISSUER_ID='your-issuer-id'
export ASC_KEY_PATH='/outside/this/repo/AuthKey_your-key-id.p8'
export APPLE_TEAM_ID='your-team-id'
export QA_DESTINATION='id=your-iOS-27-iPhone-simulator-UDID'
```

- `tools/qa/pre_asc_qa.sh --require-asc-key --destination "$QA_DESTINATION"`: local strict gate.
- `tools/qa/pre_asc_qa.sh --allow-dirty --destination "$QA_DESTINATION"`: development checks only.
- `fastlane archive`: signed archive and IPA, with no upload.
- `fastlane beta_checked`: strict gate, signed archive, and TestFlight upload. This lane does not submit to App Review or invite external testers.

The gate validates the current screenshot exports against their reviewed hashes. If UI changes affect a captured screen, refresh it using the Simulator and Computer Use, visually review the native and framed images, rerun `marketing/tools/validate_assets.py`, and commit the new assets and validation record before uploading.

Real Game Center matches, real-device accessibility, and Apple sandbox purchase/restore checks remain required before App Review. See `docs/RELEASE_CHECKLIST.md`.
