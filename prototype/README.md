# Stub｜生活存根 Responsive Web Demo

这是 Stub 的浏览器原生响应式网页 Demo。生产入口直接占满浏览器：手机端使用底部导航，桌面端使用左侧导航，不显示 iPhone/Android 模型、系统状态栏或模拟键盘。

## 当前能力

- 从相册选择或拍摄真实票据图片。
- 在浏览器内预览图片并编辑标题、日期、类型、标签和一句话记忆。
- 在 IndexedDB 中保存存根与媒体，刷新后仍可访问。
- 浏览时间轴、存根详情、旅册和存根墙。
- 支持电影格式、飞机/火车分类、附加照片、海报确认、主题及中英文界面。
- 同一枚 Stub 在首页、墙和旅册之间通过引用共享，不复制记录。

## 当前边界

数据只保存在当前浏览器中。清除网站数据、换浏览器或换设备后不会自动恢复；当前没有账号、云同步或后台 OCR。不要把演示数据或静态航班卡解释成实时服务。

新版“回顾”页面的选定设计稿在交接包根目录 `design-concepts/review-option-3-SELECTED.png`，尚未实现。实现前先阅读根目录 `AGENT-HANDOFF.md`。

## 本地启动

```bash
npm ci
npm run check:runtime
npm run dev
```

## 修改后验证

```bash
npm run check:runtime
node --test tests/stub-feature-contract.test.mjs tests/sites-worker.test.mjs
npm run build
```

## 主要文件

- `src/Prototype.tsx`：页面、上传、保存、筛选、详情和旅册逻辑。
- `src/prototype.css`：Stub 视觉、响应式布局与交互状态。
- `src/Prototype.tsx`：本地数据、媒体持久化与旧版迁移逻辑也暂时集中在这里。
- `public/reference-crops/`、`public/stub-assets/`：票据、海报、地图与航司素材。
- `tests/`：数据模型、功能与 Sites Worker 契约测试。
- `.openai/hosting.json`：现有 Sites 项目配置。
