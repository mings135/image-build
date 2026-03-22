#!/bin/bash
set -e

TAG_NAME=$(gh release list --repo SagerNet/sing-box --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName')

if gh release view "${APP_NAME}/${TAG_NAME}" >/dev/null 2>&1; then
  echo "版本已存在: $TAG_NAME"
  echo "RELEASE_NEW=no" >> $GITHUB_ENV
else
  echo "发现新版本: $TAG_NAME"
  echo "RELEASE_NEW=yes" >> $GITHUB_ENV
  echo "RELEASE_TAG=$TAG_NAME" >> $GITHUB_ENV
fi