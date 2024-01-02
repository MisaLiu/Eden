#!/bin/bash

extractFiles() {
  checkFile() {
    local classname=$1;
    declare -a filelist=("${!2}");

    for file in $filelist; do
      if [ "$file" == "$classname" ]; then
        echo "Found class: $classname";
        local filepath=$(dirname $classname);

        mkdir -p "./classes/$filepath";
        cp "./cache/tmp/$classname" "./classes/$classname";
      fi
    done
  }

  local filepath=$1;
  local filelist=$(zipinfo -1 $filepath);
  local targetClasses=(
    "com/tencent/mobileqq/dt/model/FEBound.class"
    "com/tencent/common/config/AppSetting.class"
    "oicq/wlogin_sdk/report/event/EventConstant.class"
    "oicq/wlogin_sdk/report/event/EventConstant\$EventParams.class"
    "oicq/wlogin_sdk/report/event/EventConstant\$EventType.class"
    "oicq/wlogin_sdk/tools/util.class"
    "oicq/wlogin_sdk/request/WtloginHelper.class"
    "cooperation/qzone/QUA.class"
  )

  if [ -d './cache/tmp' ]; then
    rm -rf './cache/tmp';
  fi

  mkdir './cache/tmp';
  unzip -o $filepath -d ./cache/tmp > /dev/null;

  for targetClass in ${targetClasses[@]}; do
    checkFile $targetClass filelist[@];
  done

  rm -rf './cache/tmp';
}

cd ..;

if [ ! -d './apk' ]; then
  echo 'Dir ./apk not found! Aborting...';
  exit 1;
fi

if [ -d './cache' ]; then
  echo 'Found old /cache dir, deleting...';
  rm -rf ./cache
fi

if [ -d './classes' ]; then
  echo 'Found old /classes dir, deleting...';
  rm -rf ./classes
fi

echo 'Converting all *.dex to *.jar...';
mkdir './cache';
mkdir './classes';
for file in ./apk/*.dex; do
  filename=$(basename $file .dex);
  ./tools/d2j-dex2jar.sh $file -o ./cache/$filename.jar;
  extractFiles "./cache/$filename.jar";
done

echo 'Converting *.jar done';