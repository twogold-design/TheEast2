# 《东境新城》程序实现方案

## 1. 技术路线

目标是先交付可在浏览器直接体验的 3D 模拟经营原型，再为后续内容扩展保留清晰边界。

- **渲染**：Three.js（WebGLRenderer），正交相机优先，保留切换透视相机的能力。地形、道路、建筑和居民使用低面数程序化几何体，避免原型阶段依赖大体积美术资源。
- **语言**：原生 TypeScript/ES modules。类型只覆盖领域数据和公共接口，避免引入过重框架。
- **界面**：HTML + CSS + 少量 UI 控制器；Three.js 只负责 3D 场景，HUD、建造栏、资源栏和事件日志走 DOM，便于可访问性和响应式适配。
- **构建**：Vite + `tsc`，开发目录和构建输出全部位于 `M:\NewGames\TheEast`。发布时生成纯静态 `dist/`，不需要后端或数据库。
- **资源**：原型阶段优先使用本地程序化网格和颜色材质；需要图片时放在 `public/assets/`，用相对路径加载。不要在运行时依赖 C 盘路径或本机绝对路径。
- **持久化**：`localStorage` 保存存档 JSON；数据版本字段用于以后迁移。没有账号、网络同步和服务器状态。

如果机器不方便安装构建工具，可将依赖打包到 `public/vendor/` 后由 `index.html` 引入，使用任意静态文件服务器打开 `dist/`；游戏运行时仍无后端。

## 2. 建议目录

```text
M:\NewGames\TheEast\
├─ index.html
├─ package.json
├─ tsconfig.json
├─ vite.config.ts
├─ public/
│  └─ assets/                 # 纹理、图标、字体；全部用相对路径
├─ src/
│  ├─ main.ts                 # 应用入口、启动顺序
│  ├─ app/
│  │  ├─ GameApp.ts           # 场景、UI、循环的生命周期
│  │  ├─ GameLoop.ts          # 固定步长模拟 + 渲染插值
│  │  └─ Input.ts             # 鼠标、触控、键盘及快捷键
│  ├─ scene/
│  │  ├─ Scene3D.ts           # renderer/camera/lights/fog
│  │  ├─ Terrain.ts            # 网格地块、地形高度和水域
│  │  ├─ BuildingView.ts      # 建筑网格、选中态、幽灵预览
│  │  └─ CitizenView.ts        # 居民低模、寻路路径可视化
│  ├─ sim/
│  │  ├─ WorldState.ts         # 可序列化的唯一世界状态
│  │  ├─ Simulation.ts         # 每日/每小时经营结算
│  │  ├─ Economy.ts            # 资源产出、消耗、税收和库存
│  │  ├─ Citizens.ts           # 人口需求、工作、满意度
│  │  ├─ Construction.ts       # 选址、占地、费用、解锁
│  │  └─ Events.ts             # 随机/里程碑事件与公告
│  ├─ data/
│  │  ├─ buildings.ts          # 建筑定义（成本、产能、占地、需求）
│  │  ├─ balance.ts            # 经济参数
│  │  └─ scenarios.ts          # 初始地图和挑战目标
│  ├─ ui/
│  │  ├─ Hud.ts                # 资源、日期、人口、满意度
│  │  ├─ BuildPanel.ts         # 建造菜单和筛选
│  │  ├─ InspectPanel.ts       # 建筑/居民信息
│  │  └─ Toasts.ts             # 反馈、警告、事件记录
│  ├─ persistence/
│  │  ├─ SaveGame.ts           # 存档、读档、删除和迁移
│  │  └─ schema.ts             # SaveGame v1 数据结构
│  └─ styles/
│     └─ app.css
└─ docs/
   └─ SAVE_FORMAT.md           # 存档字段说明，便于策划调数值
```

## 3. 核心系统拆分

### 3.1 世界状态和模拟

`WorldState` 是唯一权威数据源，渲染对象只保存 `entityId` 和视觉状态，不直接修改经济数值。推荐的顶层字段：

```ts
type WorldState = {
  version: 1;
  seed: number;
  time: { day: number; hour: number; speed: 0 | 1 | 2 | 4; paused: boolean };
  treasury: number;
  resources: Record<string, number>;
  buildings: BuildingState[];
  citizens: CitizenState[];
  notifications: Notification[];
  goals: Record<string, number | boolean>;
};
```

`GameLoop` 使用固定步长（例如 100 ms 的模拟步，最多补算 5 步）防止不同帧率造成经济结果不一致；渲染帧只读取状态并做位置插值。时间加速通过步长倍率实现，暂停时完全停止模拟。

### 3.2 地块、建造和撤销

- 地图使用规则方格（第一版 32×32），每格记录地形类型、占用实体和通行标记。
- 鼠标射线投射到地面得到格坐标；`Construction` 先检查边界、地形、道路连通和资金，再显示半透明幽灵建筑。
- 确认后一次性扣款并写入 `WorldState`，渲染层订阅新增/变更事件。
- 第一版支持拆除并按固定比例退款，所有操作提供撤销上一步的单级历史，避免误操作卡死。

### 3.3 经营和居民

- 建筑定义采用数据驱动：`cost`、`upkeep`、`inputs`、`outputs`、`jobs`、`housing`、`unlock` 等字段由策划维护。
- 每个模拟小时结算生产、消耗、工资和满意度；每日结算税收、维护费和事件。
- 居民先用轻量状态机（闲置、上班、回家、搬迁），不做逐人复杂寻路。使用网格 BFS/A* 仅计算工作地与住宅间的短路径，超过数量阈值时按群组移动。
- 任何负库存、人口不足或服务覆盖不足都生成可读的 `Notification`，HUD 负责展示原因和建议。

### 3.4 3D 视图和交互

- 场景层保持“数据实体 → `Object3D`”映射，新增/删除通过 `EntityViewRegistry` 管理。
- 建筑采用共享 `BufferGeometry` + `InstancedMesh`；选中对象使用描边或第二材质，不复制完整网格。
- 相机支持平移、缩放、绕垂直轴旋转；桌面端鼠标、移动端双指缩放和单指平移都映射到同一 `Input` 接口。
- 射线拾取只检测可交互层（建筑、居民、道路），地形层单独处理，避免每帧遍历全部对象。

### 3.5 UI 和反馈

HUD 最少展示铜钱、木材、粮食、人口、满意度、日期/速度。建造栏按分类显示费用和解锁条件；选择建筑后右侧检查面板显示产出、维护和服务范围。所有操作在成功、资金不足、位置非法时立即出现短提示，并在事件日志保留记录。

## 4. 无后端运行方式

1. 开发：在 `M:\NewGames\TheEast` 执行 `npm install`、`npm run dev`，Vite 只提供静态模块和热更新，不保存游戏数据。
2. 交付：执行 `npm run build`，把 `dist/` 整体拷贝到任意静态服务器或打包程序；访问 `index.html` 即可开始。
3. 首次启动生成默认 `WorldState`；自动存档每 30 秒和离开页面前触发，手动存档按钮调用同一接口。
4. 存档仅写入浏览器 `localStorage`。提供“导出存档/导入存档”按钮，使用 JSON 文件让玩家在不同浏览器迁移。

## 5. 性能与稳定性要求

- 验收基线：桌面 1080p、WebGL2，150 个可见动态居民、1,000 个静态建筑/装饰时平均 60 FPS，最低帧率不低于 45 FPS；低端设备降级到 30 FPS 仍可操作。
- 所有重复网格共享几何体和材质，优先实例化；静态地面合并为少量网格，避免每格一个 `Mesh`。
- 模拟与渲染解耦，模拟单步不超过 4 ms（150 居民场景）；路径请求排队并限制每帧数量。
- 只在资源变化、选中目标或窗口尺寸改变时刷新 DOM 文本；避免每帧触发布局。
- `renderer.setPixelRatio(Math.min(devicePixelRatio, 2))`，窗口缩放时更新相机和渲染器。
- 连续运行 10 分钟，内存无持续上涨；切换场景或删除实体后 `dispose()` 几何体、材质和纹理。
- WebGL 不可用时显示清晰错误页和浏览器兼容提示，不让用户看到空白画面。

## 6. 验收检查点

1. 运行 `npm run build` 成功，`dist/` 不包含绝对路径，断网后静态资源仍能启动。
2. 首屏 3D 地图可见，能旋转/缩放/平移；地块高亮和建筑幽灵预览不闪烁。
3. 建造、非法选址、扣费、拆除退款、单步撤销行为正确，刷新页面后存档可恢复。
4. 点击建筑能看到产出、维护和服务范围；时间暂停/1×/2×/4×切换后数值按预期变化。
5. 至少一种生产链（木材→房屋或粮食→居民）完整跑通，人口和满意度会随供需变化。
6. 快速连续点击建造不会重复扣费；导入损坏 JSON 时有提示且不覆盖当前存档。
7. 运行上述性能基线和 10 分钟稳定性检查，记录浏览器、分辨率、实体数量和结果。

## 7. 实施顺序

先搭场景、相机、输入和网格，再接 `WorldState`、建造和 HUD；随后加入固定步长经济结算、居民状态机和存档，最后补事件、移动端输入和性能优化。每一步都保留一个可启动的静态版本，便于制作、美术和策划同时验收。
