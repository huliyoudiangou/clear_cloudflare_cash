#!/bin/bash

CONFIG_FILE="$HOME/.cloudflare_config"
SCRIPT_PATH=$(realpath "$0")

create_alias() {
    grep -q "alias c='$SCRIPT_PATH'" "$HOME/.bashrc" || 
    echo "alias c='$SCRIPT_PATH'" >> "$HOME/.bashrc" &&
    echo "别名 'c' 已创建。请运行 'source ~/.bashrc' 以使用新别名。"
}

if [ ! -f "$CONFIG_FILE" ]; then
    read -p "请输入 Zone ID (多个ID用空格分隔): " ZONE_IDS
    read -p "请输入 API Token: " API_TOKEN
    echo "ZONE_IDS=$ZONE_IDS" > "$CONFIG_FILE"
    echo "API_TOKEN=$API_TOKEN" >> "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    create_alias
else
    source "$CONFIG_FILE"
fi

read -p "是否需要清理 Cloudflare 缓存? (Y/N): " NEED_PURGE
[[ ! $NEED_PURGE =~ ^[Yy]$ ]] && echo "操作已取消" && exit 0

read -p "请选择清除缓存的类型 (1.单个页面 2.全站): " PURGE_TYPE
if [ "$PURGE_TYPE" = "1" ]; then
    read -p "请输入要清除缓存的 URL: " URL_TO_PURGE
    data="{\"files\":[\"$URL_TO_PURGE\"]}"
elif [ "$PURGE_TYPE" = "2" ]; then
    data='{"purge_everything":true}'
    read -p "请输入要检查缓存状态的 URL: " URL_TO_PURGE
else
    echo "无效选项,请重新运行脚本" && exit 1
fi

for ZONE_ID in $ZONE_IDS; do
    echo "正在处理 Zone ID: $ZONE_ID"
    response=$(curl -s -w "\n%{http_code}" -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/purge_cache" \
      -H "Authorization: Bearer $API_TOKEN" -H "Content-Type: application/json" --data "$data")

    http_code=$(echo "$response" | tail -n1)
    if [ "$http_code" -eq 200 ]; then
        echo "${PURGE_TYPE}=1 ? 页面 : 全站}缓存清除请求已成功发送 (Zone ID: $ZONE_ID)"
    else
        echo "API 请求失败,状态码: $http_code (Zone ID: $ZONE_ID)"
        echo "响应内容: $(echo "$response" | sed '$d')"
        read -p "API 可能已失效,是否需要更新 API Token? (Y/N): " UPDATE_API
        if [[ $UPDATE_API =~ ^[Yy]$ ]]; then
            read -p "请输入新的 API Token: " NEW_API_TOKEN
            sed -i "s/API_TOKEN=.*/API_TOKEN=$NEW_API_TOKEN/" "$CONFIG_FILE"
            echo "API Token 已更新,请重新运行脚本" && exit 0
        fi
    fi
done

echo "缓存清理操作完成"

# 检查缓存状态
echo "正在检查缓存状态..."
cache_status=$(curl -sI "$URL_TO_PURGE" | grep -i "cf-cache-status")
echo "CF-Cache-Status: $cache_status"

if [[ $cache_status == *"HIT"* ]]; then
    echo "警告: 缓存可能未被完全清理。请等待几分钟后再次检查。"
elif [[ $cache_status == *"MISS"* ]]; then
    echo "缓存已成功清理。"
elif [[ $cache_status == *"DYNAMIC"* ]]; then
    echo "页面被标记为动态内容，不会被缓存。"
elif [[ $cache_status == *"EXPIRED"* ]]; then
    echo "缓存已过期。这通常意味着缓存已被清理，但新的缓存尚未生成。"
else
    echo "无法确定缓存状态，请手动检查。"
fi