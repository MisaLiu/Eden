#!/bin/bash

if [ ! -f './Eden.apk' ]; then
  echo 'No apk found! Aborting...';
  exit 1;
fi

if [ -d './apk' ]; then
  echo 'Found old /apk dir, deleting...';
  rm -rf ./apk
fi

echo 'Extracting apk...';
mkdir './apk';
unzip -n ./Eden.apk -d ./apk;

echo 'Extracting done';