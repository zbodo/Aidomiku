# E-Hentai `igneous` Cookie 输入设计

## 目标

在 `multi.ehentai` 图源的 Account 设置分组中增加 `igneous` 文本输入框，使用户可以和 `ipb_member_id`、`ipb_pass_hash` 一样直接填写浏览器 Cookie。

## 方案

修改 Aidoku Community Sources 中 `sources/multi.ehentai/res/settings.json`，新增键为 `igneous` 的文本设置，并将 `sources/multi.ehentai/res/source.json` 的图源版本从 2 升到 3，使已安装用户能够收到更新。现有图源代码已经通过 `defaults_get("igneous")` 读取该值并将其加入请求 Cookie，因此不修改 Rust 请求逻辑或 Aidoku 应用代码。

输入框使用普通文本类型，与现有两个 Cookie 输入框保持一致。修改值后触发 `listings` 和 `content` 刷新，使新的 Cookie 立即用于列表及详情请求。

## 数据流

1. 用户在图源设置中填写 `igneous`。
2. Aidoku 以 `multi.ehentai.igneous` 为命名空间持久化该值。
3. 图源的 `build_cookie_header()` 读取该值。
4. E-Hentai 和 ExHentai 请求携带 `igneous`、`ipb_member_id`、`ipb_pass_hash`。
5. ExHentai 返回新的 `igneous` 时，现有自动刷新逻辑仍可覆盖已保存值。

## 安全与限制

- Cookie 等同于账号凭据，不写入日志、测试数据或版本库。
- 本次不增加浏览器 Cookie 导入、网页登录或 Cookie 有效性检查。
- 图源更新会保留该设置声明；仅修改本机已安装文件不是交付方案。

## 验证

1. 校验 `settings.json` 和 `source.json` 格式，并确认图源版本为 3。
2. 构建 `multi.ehentai` 图源包。
3. 安装图源包并确认三个 Cookie 输入框同时显示。
4. 填写测试账号 Cookie 后，确认 ExHentai 列表可刷新。
5. 使用 `https://e-hentai.org/g/4296238/2b37661563/` 的深链确认 Aidoku 能进入对应详情页。
