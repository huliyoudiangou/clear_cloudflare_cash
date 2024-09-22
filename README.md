# Cloudflare 缓存清理脚本

这是一个用于清理 Cloudflare CDN 缓存的 Bash 脚本。

## 功能

- 支持清理单个页面缓存或全站缓存
- 支持多个 Cloudflare Zone ID
- 自动保存和读取 Cloudflare 配置
- 支持更新 API Token
- 创建别名以便快速调用脚本
- 检查并显示缓存清理后的状态

## 使用方法

1. 确保您有正确的 Cloudflare Zone ID(s) 和 API Token。
2. 给脚本添加执行权限：
   ```
   chmod +x purge_cache.sh
   ```
3. 运行脚本：
   ```
   ./purge_cache.sh
   ```
4. 按照提示进行操作。
5. 脚本执行后，会显示缓存清理状态。

## 注意事项

- 首次运行时，需要输入 Cloudflare Zone ID(s) 和 API Token。
- 多个 Zone ID 请用空格分隔。
- 配置信息保存在 `$HOME/.cloudflare_config` 文件中。
- 如果 API Token 失效，脚本提供了更新选项。
- 脚本会创建别名 'c'，可以通过 `source ~/.bashrc` 来启用。
- 缓存清理可能不会立即生效，可能需要等待几分钟。

## 缓存状态说明

- HIT: 缓存命中，可能未被完全清理。
- MISS: 缓存未命中，通常表示清理成功。
- DYNAMIC: 页面被标记为动态内容，不会被缓存。
- EXPIRED: 缓存已过期，通常意味着缓存已被清理，但新缓存尚未生成。

## 贡献

欢迎提交 Issues 和 Pull Requests 来改进这个脚本。

## 许可

MIT License
