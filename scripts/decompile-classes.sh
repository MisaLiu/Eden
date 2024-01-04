#!/bin/bash

DECOMPILE_CLASSES=(
  "com.tencent.mobileqq.dt.model.FEBound"
  "com.tencent.common.config.AppSetting"
  "oicq.wlogin_sdk.report.event.EventConstant"
  "oicq.wlogin_sdk.tools.util"
  "oicq.wlogin_sdk.request.WtloginHelper"
  "cooperation.qzone.QUA"
);

if [ ! -d './classes' ]; then
  echo 'Dir /classes not found! Aborting...';
  exit 1;
fi

if [ -d './decompile' ]; then
  echo 'Found old /decompile dir, deleting...';
  rm -rf ./decompile
fi
mkdir './decompile';

decompileClassesText="";
for decompileClass in ${DECOMPILE_CLASSES[@]}; do
  decompileClassPath="./classes/${decompileClass//./\/}.class";
  decompileClassesText="$decompileClassesText $decompileClassPath";
done

./tools/procyon.sh $decompileClassesText -o ./decompile;

echo 'Decompiling done';