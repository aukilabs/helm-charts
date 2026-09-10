#!/usr/bin/env bash
set -euo pipefail

chart_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/charts/hagall"
fixture="$chart_root/ci/default-values.yaml"
check_dir="$(mktemp -d)"
trap 'rm -rf "$check_dir"' EXIT

helm lint --strict "$chart_root" -f "$fixture"
helm template hagall "$chart_root" --namespace default \
  -f "$fixture" --set podMonitor.enabled=true > "$check_dir/direct.yaml"

# Exercise the actual dependency boundary, including Helm's injected global map.
mkdir "$check_dir/wrapper"
cat > "$check_dir/wrapper/Chart.yaml" <<EOF
apiVersion: v2
name: hagall-wrapper-check
version: 0.1.0
dependencies:
  - name: hagall
    version: 1.0.0
    repository: file://$chart_root
EOF
{
  printf 'hagall:\n'
  sed 's/^/  /' "$fixture"
} > "$check_dir/wrapper/values.yaml"
helm dependency build --skip-refresh "$check_dir/wrapper"
helm lint --strict "$check_dir/wrapper"
helm template hagall "$check_dir/wrapper" --namespace default \
  --set hagall.podMonitor.enabled=true > "$check_dir/wrapped.yaml"

for variant in direct wrapped; do
  yq -o=json '.' "$check_dir/$variant.yaml" | \
    jq -sS 'sort_by(.kind, .metadata.namespace, .metadata.name)' > "$check_dir/$variant.json"
done
diff -u "$check_dir/direct.json" "$check_dir/wrapped.json"

# Preserve schema enforcement when accepting the reserved Helm global value.
for invalid in 'replicaCount=2' 'identity.existingSecret=' 'image.digest=invalid' 'unknownSetting=true'; do
  if helm template hagall "$chart_root" -f "$fixture" --set "$invalid" \
    > "$check_dir/invalid.log" 2>&1; then
    printf 'Expected schema rejection for %s\n' "$invalid" >&2
    exit 1
  fi
  grep -q 'values don.t meet the specifications of the schema' "$check_dir/invalid.log"
done
printf 'Hagall lint, schema rejection, and subchart equivalence checks passed.\n'
