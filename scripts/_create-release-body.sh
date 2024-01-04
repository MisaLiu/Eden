#!/bin/bash

curl -i $APK_URL > ./tmp_curlheader.txt

FILE_REAL_URL=$(grep "^Location:" ./tmp_curlheader.txt | sed -r "s/^Location:\s(.+)$/\1/g")
FILE_NAME=$(basename $FILE_REAL_URL)
FILE_VERSION=$(echo $FILE_NAME | grep -o "\([0-9\.]\+\)" | awk 'NR==1')
FILE_MD5=$(cat ./Eden.apk | md5sum | cut -d " " -f1)
RESULT_MD5=$(cat ./output/result.zip | md5sum | cut -d " " -f1)

echo "# Rnu result for version \`$FILE_VERSION\`
* URL: \`$APK_URL\`
* MD5: \`$FILE_MD5\`
* Version: \`$FILE_VERSION\`
* Result MD5: \`$RESULT_MD5\`" > ./_action_body.md