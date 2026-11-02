# E-Hentai 局域网来源列表设计

## 目标

在当前 Mac 上临时发布 Aidoku 来源列表，仅包含本地修改并构建的 `multi.ehentai` v3 图源，供同一局域网内的 iPad 或 Mac 添加。

## 方案

使用 Aidoku CLI 从 `/Users/xuxin/Developer/aidoku-community-sources/sources/multi.ehentai/package.aix` 生成官方格式的来源列表。构建目录使用 `/tmp/aidoku-ehentai-source-list`，避免修改两个 Git 工作区。

使用 Python HTTP 服务监听所有网络接口的 8766 端口，来源列表地址为 `http://<Mac局域网IP>:8766/index.min.json`。服务仅在当前会话运行，不配置登录启动或永久后台服务。

## 约束

- 索引中必须只有一个图源，且 id 为 `multi.ehentai`、版本为 3。
- 发布目录只包含 Aidoku CLI 生成的列表文件和图源包。
- 不在日志、索引或 URL 中包含任何 Cookie。
- 服务结束、进程退出或 Mac 重启后地址失效。

## 验证

1. 解析 `index.min.json` 并断言只有 `multi.ehentai` v3。
2. 确认索引引用的 `.aix` 文件存在。
3. 分别通过 `127.0.0.1` 和 Mac 局域网 IP 请求索引。
4. 向用户提供可直接添加到 Aidoku 的完整来源列表地址。
