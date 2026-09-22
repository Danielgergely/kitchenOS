#!/bin/sh
#
#  ci_post_clone.sh
#  KitchenOS
#
#  Created by Daniel Gergely on 4/10/26.
#
#  Runs automatically in Xcode Cloud after cloning the repo. Config.xcconfig is
#  not in version control, so it is rebuilt here from the workflow's environment
#  variables.
#
#  The names written below must match the $(...) placeholders in
#  KitchenOS/Info.plist, which is what Secrets (ConfigService.swift) reads. A
#  name that doesn't match resolves to an empty string rather than failing the
#  build, so a typo ships a silently broken integration — writing SUPABASE_KEY
#  where Info.plist wants SUPABASE_PUBLISHABLE_KEY did exactly that to the
#  Recipe Store. Hence the explicit check at the end.
#

set -eu

echo "🚀 Running ci_post_clone.sh"
echo "Building Config.xcconfig from Xcode Cloud environment variables..."

# The script runs inside ci_scripts/, so go up to the repository root.
cd ..

# Accept either name for the Supabase key, since the workflow's variable was
# originally called SUPABASE_KEY.
SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-${SUPABASE_KEY:-}}"

cat <<EOF > KitchenOS/Config.xcconfig
GOOGLE_API_KEY = ${GOOGLE_API_KEY:-}
SUPABASE_URL = ${SUPABASE_URL:-}
SUPABASE_PUBLISHABLE_KEY = ${SUPABASE_PUBLISHABLE_KEY}
ADMIN_PASSWORD = ${ADMIN_PASSWORD:-}
EOF

# Fail loudly if a variable was missing, instead of shipping an empty key.
missing=""
for key in GOOGLE_API_KEY SUPABASE_URL SUPABASE_PUBLISHABLE_KEY ADMIN_PASSWORD; do
    if ! grep -qE "^${key} = .+" KitchenOS/Config.xcconfig; then
        missing="${missing} ${key}"
    fi
done

if [ -n "${missing}" ]; then
    echo "❌ Empty value(s) for:${missing}"
    echo "   Set them in the Xcode Cloud workflow's environment variables."
    exit 1
fi

echo "✅ Config.xcconfig created successfully!"
