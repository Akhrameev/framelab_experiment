#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
configuration="${1:-Debug}"
simulator_id="${2:-${SIMULATOR_ID:-}}"
if [[ "$configuration" != Debug && "$configuration" != Release ]]; then
  echo "Usage: ./run.sh [Debug|Release] SIMULATOR_UUID" >&2
  exit 2
fi
if [[ -z "$simulator_id" ]]; then
  echo "Choose a UUID using: xcrun simctl list devices available" >&2
  echo "Usage: ./run.sh [Debug|Release] SIMULATOR_UUID" >&2
  exit 2
fi
mkdir -p Results
run_dir=$(mktemp -d "Results/${configuration}.XXXXXX")
status=0
xcodebuild test -project FrameLab.xcodeproj -scheme FrameLab \
  -configuration "$configuration" \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath DerivedData -resultBundlePath "$run_dir/tests.xcresult" \
  -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES || status=$?
xcrun xcresulttool export attachments --path "$run_dir/tests.xcresult" \
  --output-path "$run_dir/frames"
echo "Exported frames and attachment manifest: $run_dir/frames"
exit "$status"
