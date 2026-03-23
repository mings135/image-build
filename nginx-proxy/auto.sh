#!/bin/bash
set -e

TAG_NAME=$(gh release list --repo nginx/nginx --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName' | sed 's/release-//')
TAG_NAME="${TAG_NAME}-alpine"

if curl -fsL https://hub.docker.com/v2/repositories/library/nginx/tags/${TAG_NAME} > /dev/null; then
  echo "Nginx 已更新至 dockerhub: $TAG_NAME"

  if gh release view "${APP_NAME}/${TAG_NAME}" >/dev/null 2>&1; then
    echo "版本已存在: $TAG_NAME"
  else
    echo "发现新版本: $TAG_NAME"
    echo "SHOULD_RELEASE=yes" >> $GITHUB_ENV
    echo "TAG_NAME=$TAG_NAME" >> $GITHUB_ENV
  fi
else
  echo "Nginx 未更新至 dockerhub: $TAG_NAME"
fi