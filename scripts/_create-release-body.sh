#!/bin/bash

FILE_NAME=$(basename $APK_URL)
FILE_VERSION=$(echo $FILE_NAME | grep -o "\([0-9\.]\+\)" | awk 'NR==1')
FILE_MD5=$(cat ./Eden.apk | md5sum | cut -d " " -f1)
RESULT_MD5=$(cat ./result.zip | md5sum | cut -d " " -f1)

echo "# Run result for version \`$FILE_VERSION\`
* URL: \`$APK_URL\`
* MD5: \`$FILE_MD5\`
* Version: \`$FILE_VERSION\`
* Result MD5: \`$RESULT_MD5\`" > ./_action_body.md
