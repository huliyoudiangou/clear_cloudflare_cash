#!/bin/bash

CONFIG_FILE="$HOME/.cloudflare_config"
SCRIPT_PATH=$(realpath "$0")

create_alias() {
    grep -q "alias c='$SCRIPT_PATH'" "$HOME/.bashrc" || 
    echo "alias c='$SCRIPT_PATH'" >> "$HOME/.bashrc" &&
    echo "别名 'c' 已创建。请运行 'source ~/.bashrc' 以使用新别名。"
}

load_config() { [ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"; }

save_config() {
    echo "ZONE_IDS=\"$ZONE_IDS\"" > "$CONFIG_FILE"
    echo "DOMAINS=\"$DOMAINS\"" >> "$CONFIG_FILE"
    echo "API_TOKEN=$API_TOKEN" >> "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
}

add_new_zone() {
    read -p "新 Zone ID: " NEW_ZONE_ID
    read -p "对应域名: " NEW_DOMAIN
    ZONE_IDS+=" $NEW_ZONE_ID"
    DOMAINS+=" $NEW_DOMAIN"
    save_config
    echo "新的 Zone ID 和域名已添加。"
}

display_zones() {
    for i in "${!ZONE_ID_ARRAY[@]}"; do
        echo "$((i+1)). ${ZONE_ID_ARRAY[i]} (${DOMAIN_ARRAY[i]})"
    done
}

check_cache_status() {
    cache_status=$(curl -sI "$1" | grep -i "cf-cache-status")
    echo "CF-Cache-Status: $cache_status"
    case $cache_status in
        *HIT*) echo "警告: 缓存可能未被完全清理。请稍后再次检查。" ;;
        *MISS*) echo "缓存已成功清理。" ;;
        *DYNAMIC*) echo "页面被标记为动态内容，不会被缓存。" ;;
        *EXPIRED*) echo "缓存已过期，正在更新。" ;;
        *) echo "无法确定缓存状态，请手动检查。" ;;
    esac
}

load_config

if [ -z "$ZONE_IDS" ] || [ -z "$API_TOKEN" ]; then
    echo "首次运行，请输入 Cloudflare 配置信息"
    read -p "Zone ID: " ZONE_IDS
    read -p "对应域名: " DOMAINS
    read -s -p "API Token: " API_TOKEN
    echo
    save_config
    create_alias
else
    select OPERATION in "添加新Zone" "编辑配置" "清理缓存"; do
        case $OPERATION in
            "添加新Zone") add_new_zone; break ;;
            "编辑配置") ${EDITOR:-nano} "$CONFIG_FILE" && load_config; break ;;
            "清理缓存") break ;;
            *) echo "无效选项，继续清理缓存" ; break ;;
        esac
    done
fi

IFS=' ' read -ra ZONE_ID_ARRAY <<< "$ZONE_IDS"
IFS=' ' read -ra DOMAIN_ARRAY <<< "$DOMAINS"

echo "当前配置的 Zone IDs 和对应域名："
display_zones

read -p "是否清理 Cloudflare 缓存? (Y/N): " NEED_PURGE
[[ ! $NEED_PURGE =~ ^[Yy]$ ]] && echo "操作已取消" && exit 0

if [ ${#ZONE_ID_ARRAY[@]} -gt 1 ]; then
    echo "选择要清理的 Zone ID (0 表示所有):"
    display_zones
    read -p "选项: " ZONE_CHOICE
    if [ "$ZONE_CHOICE" = "0" ]; then
        SELECTED_ZONES=("${ZONE_ID_ARRAY[@]}")
    else
        SELECTED_ZONES=("${ZONE_ID_ARRAY[$((ZONE_CHOICE-1))]}")
    fi
else
    SELECTED_ZONES=("${ZONE_ID_ARRAY[@]}")
fi

select PURGE_TYPE in "单个页面" "全站"; do
    case $PURGE_TYPE in
        "单个页面")
            read -p "要清除缓存的 URL: " URL_TO_PURGE
            data="{\"files\":[\"$URL_TO_PURGE\"]}"
            break ;;
        "全站")
            data='{"purge_everything":true}'
            break ;;
        *) echo "无效选项，请重新选择" ;;
    esac
done

for ZONE_ID in "${SELECTED_ZONES[@]}"; do
    # 找到 ZONE_ID 在数组中的索引
    for i in "${!ZONE_ID_ARRAY[@]}"; do
        if [[ "${ZONE_ID_ARRAY[$i]}" = "${ZONE_ID}" ]]; then
            DOMAIN="${DOMAIN_ARRAY[$i]}"
            break
        fi
    done
    echo "处理 Zone ID: $ZONE_ID ($DOMAIN)"
    response=$(curl -s -w "\n%{http_code}" -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/purge_cache" \
      -H "Authorization: Bearer $API_TOKEN" -H "Content-Type: application/json" --data "$data")
    http_code=$(echo "$response" | tail -n1)
    if [ "$http_code" -eq 200 ]; then
        echo "缓存清除请求已成功发送"
    else
        echo "API 请求失败,状态码: $http_code"
        echo "响应: $(echo "$response" | sed '$d')"
        read -p "API 可能已失效,是否更新 Token? (Y/N): " UPDATE_API
        if [[ $UPDATE_API =~ ^[Yy]$ ]]; then
            read -s -p "新的 API Token: " API_TOKEN
            echo
            save_config
            echo "API Token 已更新,请重新运行脚本"
            exit 0
        fi
    fi

    if [ "$PURGE_TYPE" = "全站" ]; then
        URL_TO_PURGE="https://$DOMAIN"
    fi

    echo "缓存清理完成"
    check_cache_status "$URL_TO_PURGE"

    read -p "是否再次检查缓存状态? (Y/N): " RECHECK
    [[ $RECHECK =~ ^[Yy]$ ]] && check_cache_status "$URL_TO_PURGE"
done

echo "脚本执行完毕"
