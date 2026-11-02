# E-Hentai `igneous` Cookie 输入实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `multi.ehentai` 图源中增加可直接填写的 `igneous` Cookie 输入框，并安装可验证的版本 3 图源包。

**Architecture:** 仅修改 Aidoku Community Sources 的静态设置清单和图源版本。现有 Rust 代码继续负责读取 `igneous`、生成 Cookie 请求头以及接收服务器返回的新值；Aidoku 应用代码不变。

**Tech Stack:** JSON、Rust 1.99.0、`wasm32-unknown-unknown`、Aidoku CLI、Aidoku `.aix` 图源包

## Global Constraints

- Cookie 等同于账号凭据，不写入日志、测试数据或版本库。
- JSON 文件使用 Tab 缩进并以换行结尾。
- 不增加浏览器 Cookie 导入、网页登录或 Cookie 有效性检查。
- 不修改 Rust 请求逻辑或 Aidoku 应用代码。

---

### Task 1: 暴露 `igneous` 设置并升级图源版本

**Files:**
- Modify: `/Users/xuxin/Developer/aidoku-community-sources/sources/multi.ehentai/res/settings.json`
- Modify: `/Users/xuxin/Developer/aidoku-community-sources/sources/multi.ehentai/res/source.json`

**Interfaces:**
- Consumes: 图源现有的 `defaults_get::<String>("igneous")` 读取逻辑。
- Produces: 名为 `igneous` 的文本设置，以及值为 `3` 的 `info.version`。

- [ ] **Step 1: 创建图源仓库工作分支**

```bash
git clone https://github.com/Aidoku-Community/sources.git /Users/xuxin/Developer/aidoku-community-sources
cd /Users/xuxin/Developer/aidoku-community-sources
git switch -c feat/multi-ehentai-igneous-setting
```

Expected: 当前分支为 `feat/multi-ehentai-igneous-setting`，工作区为空。

- [ ] **Step 2: 运行配置断言并确认当前状态失败**

```bash
python3 - <<'PY'
import json
from pathlib import Path

root = Path("sources/multi.ehentai/res")
settings = json.loads((root / "settings.json").read_text())
source = json.loads((root / "source.json").read_text())
account = next(group for group in settings if group.get("title") == "Account")
igneous = next(item for item in account["items"] if item.get("key") == "igneous")

assert igneous == {
    "type": "text",
    "key": "igneous",
    "title": "igneous",
    "placeholder": "Cookie value from exhentai.org",
    "refreshes": ["listings", "content"],
}
assert source["info"]["version"] == 3
PY
```

Expected: FAIL，因为 Account 分组尚无 `igneous` 项，且图源版本仍为 2。

- [ ] **Step 3: 增加 `igneous` 文本设置**

在 `ipb_pass_hash` 设置项后追加：

```json
{
	"type": "text",
	"key": "igneous",
	"title": "igneous",
	"placeholder": "Cookie value from exhentai.org",
	"refreshes": ["listings", "content"]
}
```

同时将 `sources/multi.ehentai/res/source.json` 中：

```json
"version": 2
```

改为：

```json
"version": 3
```

- [ ] **Step 4: 重新运行配置断言**

```bash
python3 - <<'PY'
import json
from pathlib import Path

root = Path("sources/multi.ehentai/res")
settings = json.loads((root / "settings.json").read_text())
source = json.loads((root / "source.json").read_text())
account = next(group for group in settings if group.get("title") == "Account")
igneous = next(item for item in account["items"] if item.get("key") == "igneous")

assert igneous == {
    "type": "text",
    "key": "igneous",
    "title": "igneous",
    "placeholder": "Cookie value from exhentai.org",
    "refreshes": ["listings", "content"],
}
assert source["info"]["version"] == 3
PY
```

Expected: PASS，无输出且退出码为 0。

- [ ] **Step 5: 校验 JSON 格式约束**

```bash
python3 - <<'PY'
import json
from pathlib import Path

for path in Path("sources/multi.ehentai/res").glob("*.json"):
    raw = path.read_text()
    json.loads(raw)
    assert raw.endswith("\n"), f"{path}: missing final newline"
    for line_number, line in enumerate(raw.splitlines(), 1):
        indentation = line[:len(line) - len(line.lstrip())]
        assert " " not in indentation, f"{path}:{line_number}: indentation must use tabs"
PY
```

Expected: PASS，无输出且退出码为 0。

- [ ] **Step 6: 提交图源配置**

```bash
git add sources/multi.ehentai/res/settings.json sources/multi.ehentai/res/source.json
git commit -m "feat(multi.ehentai): 添加 igneous Cookie 输入项"
```

Expected: 只提交上述两个 JSON 文件。

### Task 2: 构建、安装并验证图源包

**Files:**
- Verify: `/Users/xuxin/Developer/aidoku-community-sources/sources/multi.ehentai/Cargo.toml`
- Generate: `/Users/xuxin/Developer/aidoku-community-sources/sources/multi.ehentai/package.aix`
- Verify: `/Users/xuxin/Library/Containers/xu.aidoku.Aidomiku/Data/Library/Application Support/Sources/multi.ehentai/source.json`
- Verify: `/Users/xuxin/Library/Containers/xu.aidoku.Aidomiku/Data/Library/Application Support/Sources/multi.ehentai/settings.json`

**Interfaces:**
- Consumes: Task 1 产生的版本 3 图源清单。
- Produces: 可由 Aidoku 导入的 `package.aix`，以及显示三个 Cookie 输入框的已安装图源。

- [ ] **Step 1: 准备 Rust 与 Aidoku CLI**

```bash
brew install rustup
rustup toolchain install 1.99.0 --target wasm32-unknown-unknown

revision="$(git ls-remote https://github.com/Aidoku/aidoku-rs.git HEAD | awk '{print $1}')"
PATH="$HOME/.cargo/bin:$PATH" cargo +1.99.0 install \
	--git https://github.com/Aidoku/aidoku-rs \
	--rev "$revision" \
	--root "$HOME/.local/aidoku-cli" \
	aidoku-cli
```

Expected: `rustup target list --installed --toolchain 1.99.0` 包含 `wasm32-unknown-unknown`，且 `$HOME/.local/aidoku-cli/bin/aidoku` 可执行。若工具已安装，则跳过对应安装命令。

- [ ] **Step 2: 运行格式与 Clippy 检查**

```bash
cd /Users/xuxin/Developer/aidoku-community-sources/sources/multi.ehentai
PATH="$HOME/.cargo/bin:$PATH" cargo +1.99.0 fmt --check
PATH="$HOME/.cargo/bin:$PATH" cargo +1.99.0 clippy \
	--target wasm32-unknown-unknown \
	-- -D warnings
```

Expected: 两个命令均退出码为 0，无格式或 lint 警告。

- [ ] **Step 3: 打包并验证 `.aix`**

```bash
cd /Users/xuxin/Developer/aidoku-community-sources/sources/multi.ehentai
PATH="$HOME/.local/aidoku-cli/bin:$HOME/.cargo/bin:$PATH" aidoku package
PATH="$HOME/.local/aidoku-cli/bin:$HOME/.cargo/bin:$PATH" aidoku verify package.aix
```

Expected: 生成 `package.aix`，验证命令退出码为 0。

- [ ] **Step 4: 导入图源包**

```bash
open /Users/xuxin/Developer/aidoku-community-sources/sources/multi.ehentai/package.aix
```

Expected: Aidoku 导入 `multi.ehentai` 版本 3，并保留现有图源设置值。

- [ ] **Step 5: 验证已安装清单**

```bash
python3 - <<'PY'
import json
from pathlib import Path

root = Path.home() / "Library/Containers/xu.aidoku.Aidomiku/Data/Library/Application Support/Sources/multi.ehentai"
settings = json.loads((root / "settings.json").read_text())
source = json.loads((root / "source.json").read_text())
account = next(group for group in settings if group.get("title") == "Account")

assert [item["key"] for item in account["items"]] == [
    "ipb_member_id",
    "ipb_pass_hash",
    "igneous",
]
assert source["info"]["version"] == 3
PY
```

Expected: PASS，无输出且退出码为 0。

- [ ] **Step 6: 验证应用行为**

1. 打开 Aidoku 的 E-Hentai 图源设置。
2. 确认 Account 分组显示 `ipb_member_id`、`ipb_pass_hash`、`igneous` 三个输入框。
3. 输入用户自己的三个 Cookie；不要在日志或测试输出中打印值。
4. 将 Domain 设为 ExHentai 并刷新图源，确认列表可加载。
5. 打开 `aidoku://multi.ehentai/https%3A%2F%2Fe-hentai.org%2Fg%2F4296238%2F2b37661563%2F`。

Expected: Aidoku 显示对应作品详情页。
