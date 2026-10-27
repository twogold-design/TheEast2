# 东境 · 孤城新生 — 完整网页版

双击本目录 **启动网页版.bat** 或 **index.html**，使用新版 Edge / Chrome，点击“入境 · 开始游戏”即可游玩。无需安装 Godot、启动服务器或联网下载资源。也可将本目录交给静态网站平台托管，入口仍为根目录的小写 `index.html`。仓库当前仅维护网页版，原桌面版本可从 Git 历史找回。

## 内容

- `index.html`、`index.js`、`index.wasm`、`index.pck`、两个音频脚本：网页运行文件。
- `local-loader.js`、`local-data.js`：双击 HTML 使用的压缩本地资源；网站模式不下载重复资源。
- `src/project.godot`、`src/godot/`：当前游戏完整可编辑源码和使用中的模型、材质、音乐、字体。
- `src/web/`：网页外壳、单线程 Godot 4.7.2 导出模板与本地资源打包脚本。
- `BuildWeb.cmd` / `rebuild.ps1`：重新构建；需要 Godot 4.7.2 和 Node.js。可用 `-Godot` 参数或 `GODOT_BIN` 环境变量指定编辑器。
- `Launch.cmd`：打开本地入口。`node serve.cjs` 可用网站模式预览，地址为 `http://127.0.0.1:8070/`。

## 操作与存档

左键选择和摆放，右键取消，R旋转；中键拖动地图、滚轮缩放。下方控制游戏时间。点击建筑查看状态或拆除；设置中有帮助、保存、读取和重置。主路以路灯辨识。

浏览器采用自动保存，也保留设置中的手动保存。离开标签页会暂停经营。进度保存在当前浏览器的 IndexedDB，清除网站数据会清除进度；本地文件模式与网站模式的进度独立。网页版不读取旧桌面存档。

本版面向电脑键鼠，使用 WebGL 2 单线程渲染，不需要 COOP/COEP 跨域响应头。所有资源随包附带，无 CDN 或后端依赖。请完整解压，不要只复制一个 HTML 文件。

## 体积与许可

网页版文件合计约 **184.3MB**，构建脚本检查 **200,000,000字节** 上限。统计不含 Git 历史、构建缓存和开发依赖。发布时直接打包根目录运行文件与 `src/` 等项目文件，不包含 `.git/`、`.web-build/`、`.qa-cache/`、`.npm-cache/`、`node_modules/`。解压后 `index.html` 应位于最外层。

内置字体由开源悠哉体 Yozai Regular 裁剪为当前游戏字形，许可见 `FONT-LICENSE.txt`；增加新文字时可替换成合适的完整开源字体并重新确认包体积。Godot及第三方许可见 `THIRD-PARTY-NOTICES.txt`。

## 浏览器验证

可选开发依赖通过 `npm ci` 安装，仅用于测试，正常游玩不需要。已安装 Edge 时，运行 `npm run test:file` 验证双击模式；另开终端运行 `npm run serve` 后，运行 `npm run test:web` 验证普通网站模式。测试使用隔离存储，检查场景启动、建筑摆放、镜头操作、保存与重新打开，不影响玩家浏览器存档。

Godot重建缓存位于本目录 `.web-build/`，测试结果位于 `.qa-cache/`，npm缓存位于 `.npm-cache/`，均不提交到Git。
