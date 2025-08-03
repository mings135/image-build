#!/bin/bash
set -e

if [ "${{ github.event.inputs.tag }}" ]; then
    tmp_tag="${{ github.event.inputs.tag }}"
else
    tmp_tag="${{ github.ref_name }}"
fi
tmp_name=$(echo ${tmp_tag} | awk -F '/' '{print $1}')
tmp_version=$(echo ${tmp_tag} | awk -F '/' '{print $2}')
echo "tag_latest=${{ secrets.DOCKERHUB_REGISTRY }}/${tmp_name}:latest" >> $GITHUB_OUTPUT
echo "tag_version=${{ secrets.DOCKERHUB_REGISTRY }}/${tmp_name}:${tmp_version}" >> $GITHUB_OUTPUT
echo "build_name=${tmp_name}" >> $GITHUB_OUTPUT
echo "build_version=${tmp_version}" >> $GITHUB_OUTPUT
