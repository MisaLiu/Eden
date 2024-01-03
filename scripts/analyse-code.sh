#!/bin/bash

READ_ANDROID_VER_FROM_XML=false;

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
          resultSortVersionName="${subValue%\.}.$subVersion";
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
        resultBuildTime=$subValue;
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

getQQVersion() {
  local fekitExist=false;
  local apkCertExist=false;
  local apkManifestExist=false;

  local IFS=$'\n\n';

  if [ -f './apk/META-INF/ANDROIDR.RSA' ]; then apkCertExist=true; fi;
  if [ -f './apk/AndroidManifest.xml' ] && [ $READ_ANDROID_VER_FROM_XML == true ]; then apkManifestExist=true; fi;
  if [ -f './apk/lib/arm64-v8a/libfekit.so' ]; then
    cp --update=all ./apk/lib/arm64-v8a/libfekit.so ./libfekit.so;
    fekitExist=true;
  fi

  if [ ! $fekitExist == true ] && [ ! $apkCertExist == true ] && [ ! $apkManifestExist == true ]; then exit 1; fi;

  # TODO: Decode sign file

  if [ -f './apk/AndroidManifest.xml' ]; then
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

cd ..;

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

analyseAppSetting;
echo $resultAppIdPhone;
echo $resultAppIdPad;
echo $resultSortVersionName;
echo .;

analyseEventConstant;
echo $resultAppKey;
echo .;

analyseUtil;
echo $resultBuildTime;
echo $resultSdkVersion;
echo $resultSsoVersion;
echo .;

analyseWtLoginHelper;
echo $resultMainSigMap;
echo $resultSubSigMap;
echo $resultMiscBitmap;
echo .;

analyseQUA;
echo $resultQua;
echo .;

getQQVersion;