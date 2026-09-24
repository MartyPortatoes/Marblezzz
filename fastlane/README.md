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
- `fastlane listing`: upload English metadata and the reviewed screenshots without submitting to App Review. Read back screenshot counts, order, checksums and COMPLETE state; Fastlane retries can leave duplicates even when the command succeeds.
- `fastlane archive`: signed archive and IPA, with no upload.
- `fastlane beta_checked`: strict gate, signed archive, and TestFlight upload. This lane does not submit to App Review or invite external testers.
- Set `TESTFLIGHT_CHANGELOG` to the build-specific tester notes before running `beta_checked`. The lane verifies that the local build number exceeds the latest TestFlight build for version 1.0.
- `TESTFLIGHT_BUILD_NUMBER=<build> TESTFLIGHT_CHANGELOG='Tester notes' fastlane distribute_internal_build`: attach the processed build to the existing Private Testing group without uploading again. This keeps external beta review disabled.

The gate validates the current screenshot exports against their reviewed hashes. If UI changes affect a captured screen, refresh it using the Simulator and Computer Use, visually review the native and framed images, rerun `marketing/tools/validate_assets.py`, and commit the new assets and validation record before uploading.

Real Game Center matches, real-device accessibility, and Apple sandbox purchase/restore checks remain required before App Review. See `docs/RELEASE_CHECKLIST.md`.
