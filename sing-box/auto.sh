#!/bin/bash
set -e

# 常量
TAG_NAME=sing-box
REMOTE_TAGS_FILE=sing-box.json
REMOTE_TAGS_URL=https://api.github.com/repos/SagerNet/sing-box/tags
LOCAL_TAGS_FILE=image-build.json
LOCAL_TAGS_URL=https://api.github.com/repos/mings135/image-build/tags

# 新 tag 默认 none
new_release_tag="none"

# 获取本地 tags
curl -fsSL ${LOCAL_TAGS_URL} > ${LOCAL_TAGS_FILE}
yq -rioj '.[].name' ${LOCAL_TAGS_FILE}
local_head_ver=$(head -1 ${LOCAL_TAGS_FILE} | awk -F '/' '{print $2}')

# 循环遍历 page, per_page 默认 100
for i in $(seq 1 3)
do
    # 防止触发 rate limit
    sleep 2
    # 获取远程 tags
    curl -fsSL "${REMOTE_TAGS_URL}?per_page=100&page=$i" > ${REMOTE_TAGS_FILE}
    yq -rioj '.[].name' ${REMOTE_TAGS_FILE}
    # 远程 tags 为空，跳出循环
    if [ ! -s ${REMOTE_TAGS_FILE} ]; then
        echo "没有更多的远程 tags"
        break
    fi
    # 遍历远程 tags
    while read line
    do
        # 远程 tag 和本地最新 tag 的 version 相同，跳出
        if [ "${line}" = "${local_head_ver}" ]; then
            echo "已经存在 ${local_head_ver}"
            break 2
        fi
        # 找到不存在本地的最新 tag(正式版)
        if echo "$line" | grep -Eqi 'v([[:digit:]]*\.){2}[[:digit:]]*$'; then
            if ! grep -Eqi "${line}$" ${LOCAL_TAGS_FILE}; then 
                new_release_tag="${TAG_NAME}/${line}"
                echo "创建新版本 ${new_release_tag}"
                break 2
            fi
        fi
    done < ${REMOTE_TAGS_FILE}
done

if [ "${new_release_tag}" = "none" ]; then
    echo "release_status=no" >> $GITHUB_OUTPUT
    echo "没有新版本"
else
    echo "release_status=yes" >> $GITHUB_OUTPUT
    echo "release_tag=${new_release_tag}" >> $GITHUB_OUTPUT
fi
