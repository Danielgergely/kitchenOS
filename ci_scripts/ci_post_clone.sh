#!/bin/sh
//  ci_post_clone.sh
//  KitchenOS
//
//  Created by Daniel Gergely on 4/10/26.
//

# This script runs automatically in Xcode Cloud after cloning the repo.
echo "🚀 Running ci_post_clone.sh"
echo "Building Config.xcconfig file from Xcode Cloud Environment Variables..."

# Navigate to the folder where your Config file should be.
# (The script runs inside the ci_scripts folder, so we go up one level)
cd ..

# Create the Config.xcconfig file and write the variables into it
cat <<EOF > KitchenOS/Config.xcconfig
SUPABASE_URL = $SUPABASE_URL
SUPABASE_KEY = $SUPABASE_KEY
GOOGLE_API_KEY = $GOOGLE_API_KEY
ADMIN_PASSWORD = $ADMIN_PASSWORD
EOF

echo "✅ Config.xcconfig created successfully!"
