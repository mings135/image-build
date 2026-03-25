#!/bin/bash
set -e

IS_MAINLINE=0

for i in $(seq 0 1); do
  TAG_NAME=$(gh release list --repo nginx/nginx --exclude-pre-releases --limit 3 --json tagName --jq ".[$i].tagName" | sed 's/release-//')
  [ -z "$TAG_NAME" ] && continue

  if [[ $TAG_NAME =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    minor=${BASH_REMATCH[2]}
    if (( minor % 2 != 0 )); then
      echo "Mainline 版本: $TAG_NAME"
      IS_MAINLINE=1
      break
    fi
  else
    echo "ERROR: $TAG_NAME is not a valid tag name"
    exit 1
  fi
  
  sleep 1
done

if [ $IS_MAINLINE -eq 0 ]; then
  echo "前 2 个都不是 Mainline 版本"
  exit 0
fi

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