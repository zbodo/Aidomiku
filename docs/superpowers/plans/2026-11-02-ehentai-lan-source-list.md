# E-Hentai 局域网来源列表实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 临时发布仅包含 `multi.ehentai` v3 的 Aidoku 局域网来源列表。

**Architecture:** Aidoku CLI 从已验证的单个 `.aix` 包生成官方索引，输出到临时目录。Python HTTP 服务在 8766 端口监听所有接口，同一局域网设备通过 Mac 的活动网络地址读取索引。

**Tech Stack:** Aidoku CLI、Python 3 HTTP Server、JSON、macOS 网络工具

## Global Constraints

- 索引只包含 `multi.ehentai` v3。
- Cookie 不进入构建文件、URL 或日志。
- 服务只在当前会话运行，不创建 LaunchAgent。
- 不修改 Aidomiku 或图源仓库的跟踪文件。

---

### Task 1: 生成并校验单图源索引

**Files:**
- Consume: `/Users/xuxin/Developer/aidoku-community-sources/sources/multi.ehentai/package.aix`
- Generate: `/tmp/aidoku-ehentai-source-list.*/public/index.min.json`
- Generate: `/tmp/aidoku-ehentai-source-list.*/public/sources/*.aix`

**Interfaces:**
- Consumes: 已通过 `aidoku verify` 的 `multi.ehentai` v3 包。
- Produces: 只包含该图源的官方来源列表目录。

- [ ] **Step 1: 创建唯一临时目录并生成来源列表**

```bash
staging="$(mktemp -d /tmp/aidoku-ehentai-source-list.XXXXXX)"
cd "$staging"
PATH="/opt/homebrew/opt/rustup/bin:$HOME/.local/aidoku-cli/bin:$PATH" \
	aidoku build \
	/Users/xuxin/Developer/aidoku-community-sources/sources/multi.ehentai/package.aix \
	--name "Aidomiku E-Hentai Local"
printf '%s\n' "$staging"
```

Expected: `$staging/public/index.min.json` 和一个 `.aix` 文件存在。

- [ ] **Step 2: 校验索引只包含目标图源**

```bash
STAGING="$staging" python3 - <<'PY'
import json
import os
from pathlib import Path

public = Path(os.environ["STAGING"]) / "public"
index = json.loads((public / "index.min.json").read_text())
sources = index["sources"]

assert len(sources) == 1
assert sources[0]["id"] == "multi.ehentai"
assert sources[0]["version"] == 3
assert (public / sources[0]["downloadURL"]).is_file()
PY
```

Expected: PASS，无输出且退出码为 0。

### Task 2: 启动并验证局域网服务

**Files:**
- Serve: `/tmp/aidoku-ehentai-source-list.*/public`

**Interfaces:**
- Consumes: Task 1 生成并校验的 `public` 目录。
- Produces: `http://<Mac局域网IP>:8766/index.min.json`。

- [ ] **Step 1: 获取活动局域网地址并确认端口可用**

```bash
interface="$(route -n get default | awk '/interface:/{print $2; exit}')"
lan_ip="$(ipconfig getifaddr "$interface")"
test -n "$lan_ip"
! lsof -nP -iTCP:8766 -sTCP:LISTEN
printf '%s\n' "$lan_ip"
```

Expected: 输出一个非回环 IPv4 地址，且 8766 端口未被占用。

- [ ] **Step 2: 启动临时 HTTP 服务**

```bash
python3 -m http.server 8766 \
	--bind 0.0.0.0 \
	--directory "$staging/public"
```

Expected: 服务保持运行并监听 `0.0.0.0:8766`。

- [ ] **Step 3: 验证本机与局域网地址**

```bash
curl --fail --silent --show-error "http://127.0.0.1:8766/index.min.json" >/dev/null
curl --fail --silent --show-error "http://$lan_ip:8766/index.min.json" >/dev/null
printf 'http://%s:8766/index.min.json\n' "$lan_ip"
```

Expected: 两个请求均成功，最后输出可添加到 Aidoku 的来源列表地址。
