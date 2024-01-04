#!/bin/bash

_READ_ANDROID_VER_FROM_XML=$(echo ${READ_ANDROID_VER_FROM_XML:-false});

readJava() {
  local classname=$1;
  local classpath="./decompile/${classname//./\/}.java";

  if [ -f "$classpath" ]; then
    cat $classpath;
  fi
}

readValueFromCode() {
  local code=$1;
  local withQuota=$2;

  local resultRawSemi=$(echo $code | awk -F '=' '{print $2}' | awk '$1=$1');
  local resultRaw=${resultRawSemi%';'};
  local result=$resultRaw;

  if [ -z $withQuota ] || [ ! $withQuota == true ]; then
    local resultRawQuotaStart=${resultRaw#'"'};
    local resultRawQuotaEnd=${resultRawQuotaStart%'"'};
    result=$resultRawQuotaEnd;
  fi

  echo $result;
  exit 0;
}

analyseAppSetting() {
  if [ -z "$sAppSetting" ]; then
    exit 0;
  fi;

  local subVersion=0;
  local staticBlock=false;
  local level=0;
  local IFS=$'\n\n';

  for line in $sAppSetting; do
    if [ $staticBlock != true ]; then
      if [[ "$(echo $line | awk '$1=$1')" == static\ {* ]]; then
        staticBlock=true;
        continue;
      fi

      if [ $subVersion -gt 0  ] || [[ ! $line =~ "=" ]]; then continue; fi;

      local subValue=$(readValueFromCode $line);
      subVersion=$(echo $subValue | awk '{print int($0)}');
    else
      if [[ $line =~ "{" ]]; then level=$((level+1)); fi;
      if [[ $line =~ "}" ]]; then
        level=$((level-1));
        if [ $level -lt 0 ]; then break; fi;
      fi;

      if [[ $line =~ "=" ]] && [[ ! $line =~ "\"" ]] && [ -z "$resultAppIdPhone" -o -z "$resultAppIdPad" ]; then
        local subValue=$(readValueFromCode $line true);

        if [[ $subValue =~ ^-?[0-9]+$ ]]; then
          if [ -z $resultAppIdPhone ]; then
            resultAppIdPhone=$subValue;
            continue;
          fi
          if [ -z $resultAppIdPad ]; then
            resultAppIdPad=$subValue;
            continue;
          fi
        fi
      fi

      if [[ $line =~ ".append(\"" ]]; then
        local subValueRight=${line##*(\"};
        local subValue=${subValueRight%%\")\;};

        if [[ ! $subValue == V* ]] && [[ $subValue == *\. ]]; then
          QQversion=${subValue%\.};
          resultSortVersionName="$QQversion.$subVersion";
          break;
        fi;
      fi
    fi
  done
}

analyseEventConstant() {
  if [ -z "$sEventConstant" ]; then
    exit 0;
  fi;

  local IFS=$'\n\n';

  for line in $sEventConstant; do
    if [[ $line =~ "String EVENT_WT_LOGIN_PASSWORD" ]] && [[ $line =~ "=" ]]; then
      local subValue=$(readValueFromCode $line);
      resultAppKey=${subValue%%_*};
      break;
    fi
  done
}

analyseUtil() {
  if [ -z "$sUtil" ]; then
    exit 0;
  fi;

  local IFS=$'\n\n';

  for line in $sUtil; do
    if [ ! -z "$resultBuildTime" ] && [ ! -z "$resultSdkVersion" ] && [ ! -z "$resultSsoVersion" ]; then break; fi;
    if [[ $line =~ "=" ]]; then
      local subValue=$(readValueFromCode $line);
      
      if [[ $line =~ "long BUILD_TIME" ]]; then
        resultBuildTime=${subValue%L};
        continue;
      fi
      if [[ $line =~ "String SDK_VERSION" ]]; then
        resultSdkVersion=$subValue;
        continue;
      fi
      if [[ $line =~ "int SSO_VERSION" ]]; then
        resultSsoVersion=$subValue;
        continue;
      fi
    fi
  done
}

analyseWtLoginHelper() {
  if [ -z "$sWtLoginHelper" ]; then
    exit 0;
  fi;

  local IFS=$'\n\n';

  for line in $sWtLoginHelper; do
    if [ ! -z $resultMiscBitmap ] && [ ! -z $resultMainSigMap ] && [ ! -z $resultSubSigMap ]; then break; fi;
    if [[ $line =~ "=" ]]; then
      local subValue=$(readValueFromCode $line);

      if [[ $line =~ "this.mMainSigMap" ]]; then
        resultMainSigMap=$subValue;
        continue;
      fi
      if [[ $line =~ "this.mSubSigMap" ]]; then
        resultSubSigMap=$subValue;
        continue;
      fi
      if [[ $line =~ "this.mMiscBitmap" ]]; then
        resultMiscBitmap=$subValue;
        continue;
      fi
    fi
  done
}

analyseQUA() {
  if [ -z "$sQUA" ]; then
    exit 0;
  fi;

  local IFS=$'\n\n';

  for line in $sQUA; do
    if [ ! -z $resultQua ]; then break; fi;
    if [[ $line =~ "String QUA" ]] && [[ $line =~ "=" ]]; then
      resultQua=$(readValueFromCode $line);
    fi
  done
}

decodeSignMd5() {
  if [ ! -f './apk/META-INF/ANDROIDR.RSA' ]; then
    exit 1;
  fi;

  if [ -f './pubkey.der' ]; then
    rm -f ./pubkey.der;
  fi;

  openssl pkcs7 -inform DER -in ./apk/META-INF/ANDROIDR.RSA -print_certs -outform PEM | openssl x509 -outform DER > pubkey.der;
  local signMd5Raw=$(openssl dgst -md5 ./pubkey.der);
  local signMd5RawSpace=${signMd5Raw#*=};
  local signMd5=$(echo $signMd5RawSpace | awk '$1=$1');

  if [ ! -z $signMd5 ]; then
    resultApkSign=$signMd5;
  else
    echo '[WARN] Failed to get sign md5, use default value';
  fi;
}

getAppIdFromManifest() {
  local apkManifestExist=false;

  local IFS=$'\n\n';

  # NOTE: These line are in a mess
  # Plz do something if you can

  if [ -f './apk/AndroidManifest.xml' ]; then apkManifestExist=true; fi;
  if [ ! $apkManifestExist == true ]; then return 0; fi;

  if [ ! $_READ_ANDROID_VER_FROM_XML == true ]; then
    echo '[INFO] Read Android version from xml is disabled.';
    return 0;
  fi

  if [ $apkManifestExist == true ]; then
    if [ ! -f './decompile/AndroidManifest.xml' ]; then
      ./tools/xml-decode.sh ./apk/AndroidManifest.xml > ./decompile/AndroidManifest.xml;
    fi

    local xmlAppMetaDataNodesRaw=$(xpath -q -e '/manifest/application//meta-data[@android:name and @android:value]' ./decompile/AndroidManifest.xml);
    local tmpAppId=-1;
    local tmpAppIdPad=-1;

    for line in $xmlAppMetaDataNodesRaw; do
      local lineTrim=$(echo $line | awk '$1=$1');

      if [ $lineTrim == '</meta-data>' ]; then continue; fi;

      local metaname=$(echo $lineTrim | sed -r "s/^<meta-data\\sandroid:name=\"(.+)\"\\sandroid:value=\"(.*)\">$/\1/g");
      local metavalue=$(echo $lineTrim | sed -r "s/^<meta-data\\sandroid:name=\"(.+)\"\\sandroid:value=\"(.*)\">$/\2/g");
      
      if [ -z $metaname ] || [ -z $metavalue ]; then continue; fi;
      if [ $metaname == "AppSetting_params" ]; then
        local IFS="#";
        read -a subArray <<< "$metavalue";
        
        if [[ ${subArray[0]} =~ ^-?[0-9]+$ ]]; then
          echo "Found appId from AndroidManifest.xml, replacing...";
          tmpAppId=${subArray[0]};
        fi
      fi
      if [ $metaname == "AppSetting_params_pad" ]; then
        local IFS="#";
        read -a subArray <<< "$metavalue";
        
        if [[ ${subArray[0]} =~ ^-?[0-9]+$ ]]; then
          echo "Found appIdPad from AndroidManifest.xml, replacing...";
          tmpAppIdPad=${subArray[0]};
        fi
      fi

      local IFS=$'\n\n';
    done

    if [ $tmpAppId -le -1 ] || [ $tmpAppIdPad -le -1 ]; then
      echo '[WARN] No appId found in AndroidManifest.xml, use decompiled value instead.';
    else
      resultAppIdPhone=$tmpAppId;
      resultAppIdPad=$tmpAppIdPad;
    fi
  fi
}

checkIsResultEmpty() {
  if [ -z "$resultAppIdPhone" ]; then resultAppIdPhone="null"; fi;
  if [ -z "$resultAppIdPad" ]; then resultAppIdPad="null"; fi;
  if [ -z "$resultAppKey" ]; then resultAppKey="null"; fi;
  if [ -z "$resultSortVersionName" ]; then resultSortVersionName="null"; fi;
  if [ -z "$resultApkSign" ]; then resultApkSign="null"; fi;
  if [ -z "$resultSdkVersion" ]; then resultSdkVersion="null"; fi;
  if [ -z "$resultSsoVersion" ]; then resultSsoVersion="null"; fi;
  if [ -z "$resultMiscBitmap" ]; then resultMiscBitmap="null"; fi;
  if [ -z "$resultMainSigMap" ]; then resultMainSigMap="null"; fi;
  if [ -z "$resultSubSigMap" ]; then resultSubSigMap="null"; fi;
  if [ -z "$resultQua" ]; then resultQua="null"; fi;
}

generateQuaServerConfig() {
  if [ -z "$resultQua" ]; then
    echo "{}";
    exit 1;
  fi;

  local quaArray=($(echo $resultQua | tr "_" "\n"));
  local result="{
  \"server\": {
    \"host\": \"0.0.0.0\",
    \"port\": 8080
  },
  \"share_token\": false,
  \"key\": \"Eden\",
  \"auto_register\": true,
  \"protocol\": {
    \"package_name\": \"com.tencent.mobileqq\",
    \"qua\": \"$resultQua\",
    \"version\": \"${quaArray[3]}\",
    \"code\": \"${quaArray[4]}\"
  },
  \"unidbg\": {
    \"dynamic\": false,
    \"unicorn\": true,
    \"kvm\": false,
    \"debug\": true
  }
}";

  echo "$result";
}

generateProtocolJson() {
  local _isPad=$1;
  local isPad=$_isPad;

  if [ -z $_isPad ] || [ ! $_isPad == true ]; then
    isPad=false;
  else
    isPad=true;
  fi

  local appId=$resultAppIdPhone;
  local protocolType=1;

  if [ $isPad == true ]; then
    appId=$resultAppIdPad;
    protocolType=6;
  fi

  local result="{
  \"apk_id\": \"com.tencent.mobileqq\",
  \"app_id\": $appId,
  \"sub_app_id\": $appId,
  \"app_key\": \"$resultAppKey\",
  \"sort_version_name\": \"$resultSortVersionName\",
  \"build_time\": $resultBuildTime,
  \"apk_sign\": \"$resultApkSign\",
  \"sdk_version\": \"$resultSdkVersion\",
  \"sso_version\": $resultSsoVersion,
  \"misc_bitmap\": $resultMiscBitmap,
  \"main_sig_map\": $resultMainSigMap,
  \"sub_sig_map\": $resultSubSigMap,
  \"dump_time\": $resultBuildTime,
  \"qua\": \"$resultQua\",
  \"protocol_type\": $protocolType
}";

  echo "$result";
}

generateDTConfig() {
  convertCodeToJsonArray() {
    local code=$1;

    local resultRawEnd=${code##*byte\[\]\[\]};
    local resultRaw=${resultRawEnd%%\;*};
    local resultQuote=${resultRaw//\{/\[};
    local result=${resultQuote//\}/\]};

    echo $result | awk '$1=$1';
  }

  if [ -z "$sFEBound" ]; then
    echo "{}";
    return 1;
  fi;

  local en=null;
  local de=null;
  local IFS=$'\n\n';

  for line in $sFEBound; do
    if [ ! $en == null ] && [ ! $de == null ]; then break; fi;
    if [[ ! $line =~ "=" ]] || [[ ! $line =~ "byte[][]" ]]; then continue; fi;
    if [[ $line =~ "FEBound.mConfigEnCode" ]]; then
      en=$(convertCodeToJsonArray $line);
      continue;
    fi
    if [[ $line =~ "FEBound.mConfigDeCode" ]]; then
      de=$(convertCodeToJsonArray $line);
      continue;
    fi
  done

  local result="{
  \"en\": $en,
  \"de\": $de
}"
  echo "$result";
}

if [ ! -d './apk' ]; then
  echo 'Dir /apk not found! Aborting...';
  exit 1;
fi

if [ ! -d './decompile' ]; then
  echo 'Dir /decompile not found! Aborting...';
  exit 1;
fi

# Init variables for generating result
resultAppIdPhone="";
resultAppIdPad="";
resultAppKey="";
resultSortVersionName="";
resultBuildTime="";
resultApkSign="a6b745bf24a2c277527716f6f36eb68d";
resultSdkVersion="";
resultSsoVersion="";
resultMiscBitmap="";
resultMainSigMap="";
resultSubSigMap="";
resultQua="";

# Init variables for analysing code
sFEBound=$(readJava "com.tencent.mobileqq.dt.model.FEBound");
sAppSetting=$(readJava "com.tencent.common.config.AppSetting");
sEventConstant=$(readJava "oicq.wlogin_sdk.report.event.EventConstant");
sUtil=$(readJava "oicq.wlogin_sdk.tools.util");
sWtLoginHelper=$(readJava "oicq.wlogin_sdk.request.WtloginHelper");
sQUA=$(readJava "cooperation.qzone.QUA");
QQversion="unknown";

echo 'Analysing base info...';
analyseAppSetting;
echo "[INFO] appId: $resultAppIdPhone";
echo "[INFO] appIdPad: $resultAppIdPad";
echo "[INFO] version: $QQversion";
echo "[INFO] versionName: $resultSortVersionName";

echo 'Analysing appKey...';
analyseEventConstant;
echo "[INFO] appKey: $resultAppKey";

echo 'Analysing util...';
analyseUtil;
echo "[INFO] buildTime: $resultBuildTime";
echo "[INFO] sdkVersion: $resultSdkVersion";
echo "[INFO] ssoVersion: $resultSsoVersion";

echo 'Analysing WtLoginHelper...';
analyseWtLoginHelper;
echo "[INFO] mainSigMap: $resultMainSigMap";
echo "[INFO] subSigMap: $resultSubSigMap";
echo "[INFO] miscBitmap: $resultMiscBitmap";

echo 'Analysing QUA...';
analyseQUA;
echo "[INFO] qua: $resultQua";

echo 'Getting sign md5...';
decodeSignMd5;
echo "[INFO] apkSign: $resultApkSign";

echo 'Getting appId from AndroidManifest.xml...';
getAppIdFromManifest;
echo "[INFO] appId: $resultAppIdPhone";
echo "[INFO] appIdPad: $resultAppIdPad";

echo 'Check if any result value is empty...';
checkIsResultEmpty;

outputDir="./output/$QQversion/";
mkdir -p "$outputDir";

echo 'Generating config.json for sign server...';
generateQuaServerConfig > "$outputDir/config.json";

echo 'Generating protocol json...';
generateProtocolJson false > "$outputDir/android_phone.json";
generateProtocolJson true > "$outputDir/android_pad.json";

echo 'Generating dtconfig.json...';
generateDTConfig > "$outputDir/dtconfig.json";

echo 'Copying libfekit.so...';
if [ -f './apk/lib/arm64-v8a/libfekit.so' ]; then
  cp -a ./apk/lib/arm64-v8a/libfekit.so "$outputDir/libfekit.so";
else
  echo '[WARN] libfekit.so not found!';
fi

echo 'Analyzing code done';