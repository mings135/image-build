#!/bin/bash
set -e

APP_REPO=SagerNet/sing-box

# 1. 获取最新正式版的发布时间 ISO 8601 格式 (例如 2026-03-20T10:00:00Z)
PUBLISHED_AT=$(gh release list --repo $APP_REPO --exclude-pre-releases --limit 1 --json publishedAt --jq '.[0].publishedAt')

# 2. 将发布时间转换为 Unix 时间戳 (秒)
# 注意：macOS 和 Linux 的 date 命令参数略有不同，这里用的是通用的标准
RELEASE_TIME=$(date -d "$PUBLISHED_AT" +%s)

# 3. 获取当前时间的 Unix 时间戳
NOW_TIME=$(date +%s)

# 4. 计算差值（30小时 = 108000秒）
DIFF=$((NOW_TIME - RELEASE_TIME))

if [ $DIFF -le 108000 ]; then
  TAG_NAME=$(gh release list --repo $APP_REPO --exclude-pre-releases --limit 1 --json tagName --jq '.[0].tagName')
  if gh release view "${APP_NAME}/${TAG_NAME}" >/dev/null 2>&1; then
    echo "版本已存在: $TAG_NAME"
    echo "RELEASE_NEW=no" >> $GITHUB_ENV
  else
    echo "发现新版本: $TAG_NAME"
    echo "RELEASE_NEW=yes" >> $GITHUB_ENV
    echo "RELEASE_TAG=$TAG_NAME" >> $GITHUB_ENV
  fi
else
  echo "没有发现更新"
  echo "RELEASE_NEW=no" >> $GITHUB_ENV
fi