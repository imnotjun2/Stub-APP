# Stub｜生活存根

收藏电影票、登机牌、火车票、小票等真实生活凭证，并通过时间、地点、标签、旅册与回顾重新发现个人记忆。

它不是记账、报销、售票或公开社交产品。

## 仓库结构

| 目录 | 说明 |
|---|---|
| `ios/` | 原生 iOS App（Swift / SwiftUI），App Store 形态的完整实现 |
| `miniprogram/` | 微信小程序版本 |
| `prototype/` | Web 原型（React 19 + TypeScript + Vite），浏览器原生响应式站点 |
| `design/` | 配色与语义 token |
| `docs/` | 产品需求文档 |

## Web 原型

`prototype/` 是浏览器原生的响应式站点：桌面端左侧导航，移动端底部导航，**不显示手机外框或模拟键盘**。

数据保存在当前浏览器的 IndexedDB 中，并保留旧版 localStorage 迁移兼容逻辑。没有账号、云同步或后台 OCR——这是刻意的隐私边界。

本地开发：

```bash
cd prototype
npm ci
npm run check:runtime
npm run dev
```

改动后验证：

```bash
npm run check:runtime
node --test tests/stub-feature-contract.test.mjs tests/sites-worker.test.mjs
npm run build
```

> `npm run check:runtime` 会校验受保护运行时文件的哈希（见 `prototype/mobile-runtime.lock.json`）。
> 若你确实需要改动 `vite.config.ts`、`src/mobile/`、`worker/index.js` 等受保护文件，改动验证通过后运行 `npm run update:runtime-lock`，不要绕过检查。

## 部署

构建产物在 `prototype/dist/client`（纯静态）。仓库已为三个免费平台准备好配置，选一个连上仓库即可自动发布：

| 平台 | 配置文件 | 后台需要填的 |
|---|---|---|
| **Netlify**（零配置，推荐） | 根目录 `netlify.toml` | 只需连仓库，其余自动读取；子域名 `<name>.netlify.app` |
| **Vercel** | 根目录 `vercel.json` | Root Directory 留空即可（配置里已 `cd prototype`）；子域名 `<name>.vercel.app` |
| **Cloudflare Pages** | `prototype/wrangler.toml` | Root `prototype`、Build `npm ci && npm run build`、Output `dist/client`、环境变量 `NODE_VERSION=22` |

三者都需要 **Node 22**（Vite 8 / TypeScript 7 要求 ≥ 20.19），仓库已通过 `prototype/.nvmrc` 声明。

GitHub Actions 工作流 `.github/workflows/prototype.yml` 会在每次 PR / push 时校验运行时完整性、跑契约测试并构建；如需用纯 CI 发布到 Cloudflare Pages，配置 `CLOUDFLARE_API_TOKEN` 与 `CLOUDFLARE_ACCOUNT_ID` 两个 Secrets 即可。
