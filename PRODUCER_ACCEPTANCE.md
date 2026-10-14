# 《东境：孤城新生》制作人发行验收记录

验收日期：2026-10-14  
工程：`M:\NewGames\TheEast`  
引擎：Godot 4.7.2 stable  
渲染器：OpenGL 3.3 Compatibility  
基准窗口：1366×768

## 结论

**当前 Godot 版本可以作为“可试玩的东方古代城镇 3D 模拟经营原型”交付和演示。** 玩家可在本机双击 `启动游戏.bat` 进入主场景，完成建造、选址限制、资源结算、人口增长、事件、胜负、拆除、重置和保存读取。主玩法默认使用完整 15 项高细节写实资产。

**当前不应标记为面向外部普通玩家的独立发行版。** 工程没有 Windows Desktop 导出预设，也没有 `build` 目录中的独立 EXE/PCK；启动器依赖本机 `D:\tools\Godot-4.7.2`。外部电脑不能保证双击即玩。

**高细节写实资产包已经完成 15/15 并接入主玩法。** 五类建筑、三种树木、三种山石、木桥、灯笼、作物和居民均从 `realistic/models` 加载；低多边形资产只在写实文件缺失时回退。

## 48×48 与目标感专项放行门槛

本轮以“玩家不需要猜下一步”为放行标准。地图和目标链必须同时满足以下条件，不能只扩大地形而维持原有两行区域名提示：

- 地图为 48×48、2304 格，七区面积严格为 400/200/200/100/432/540/432；原 30×30 坐标和区域含义不变。
- 顶栏在 1366×768 下常驻“章节、章节进度、一个当前任务”，当前任务必须包含动作词和当前值/目标值。
- 右侧“复兴目标”面板无需滚动即可同时看到下一解锁、全部条件进度、当前任务、费用、奖励和开拓按钮。
- 当前任务按“专属建筑 → 仓储容量 → 住房 → 人口 → 幸福 → 资源 → 点击开拓”选择首个阻碍；条件完成后立即切换，不继续显示已完成事项。日期只用于自动结算，不参与章节目标。
- 六次开拓均把扣费、区域升级、一次性奖励、目标切换和保存作为一次结算；连续点击不能重复扣费或领奖。
- 第七章常驻人口 45、粮食 200、木材 200、幸福度 80 的终局进度，全部满足时只触发一次“东境全域复兴”。
- v2 存档继续兼容等级 0..3，新存档接受 0..6；旧等级 3 直接进入第四章，不补发前三章奖励。

专项自动验收脚本为 `qa/GoalClarityAcceptance.gd`。它会在实际主场景中检查区域覆盖、1366×768 布局、目标文案、任务优先级、首章奖励和章节切换，成功标志为：

```text
GOAL_CLARITY_ACCEPTANCE_OK: 48x48, 7 regions, no date gates, visible chapter/task/progress/reward
```

## 已通过

- [x] `project.godot` 直接指向 `godot/Main.tscn`，无需先打开子场景。
- [x] 本机普通入口 `启动游戏.bat` 路径检查通过，Godot 和工程位置均可找到。
- [x] 48×48 河谷、河道、林缘、道路、桥、树木、岩石、灯笼、居民和正交相机齐全；旧 30×30 坐标与区域含义完整保留。
- [x] 七片区域按河湾故地 → 北坡梯田 → 东麓林场 → 云岫高台 → 沧波东原 → 朔岭关田 → 天际新都线性开放，锁区雾层、区域牌和复兴目标面板可见。
- [x] 茅舍、伐木场、农田、仓库、小工坊五类建筑可区分并使用独立 GLB。
- [x] 河道禁建、农田临河、伐木场临林、工坊人口门槛、资源不足与占用格限制已实现。
- [x] 自动日结算覆盖生产、维护、口粮、人口、幸福度和四类周期事件。
- [x] 全域开放、45 人、200 木、200 粮、幸福度 80 的最终胜利条件，断粮失败、终局遮罩与重置通过自动验收。
- [x] 连续推进 30 日的可持续聚落保持有效资源和响应，日期准确到第 31 日。
- [x] 保存、读取、损坏存档拒绝、拆除退款和初始状态恢复通过自动验收。
- [x] 15 件低多边形 GLB 均能由 Godot 加载，预览染色覆盖嵌套网格。
- [x] 15 项高细节写实 GLB/PBR 资源均由 `realistic/models` 加载；严格测试和展厅均不允许把回退资源误报为写实资源。
- [x] 写实民居屋面已重导修正；最终 Godot 展厅中 15 件资产按三排陈列，轮廓和标签清楚，顶部明确报告 `15/15`。
- [x] `Main.gd` 已全面切换到 `RealisticAssets.gd`，主场景中的建筑、环境物件和居民均验证为 `asset_source=realistic`。
- [x] 五类写实建筑的门点和实体碰撞体、木桥桥面碰撞体均通过严格断言；2 米格尺度在主场景中匹配。
- [x] Godot 无头导入退出码 0；主玩法、低多边形资产、写实资产测试退出码均为 0。
- [x] 项目文本、资源引用、缓存、日志、存档和本轮测试输出均位于 M 盘；未发现 `C:\` 项目路径引用。
- [x] 1366×768 验收图中 HUD 无需滚动，资源、人口、幸福度、目标、建造、暂停与倍速入口清楚可见；右侧目标栏可收起。
- [x] 底栏只保留高频建造与时间操作；查看、保存、读取和重新开始集中到顶栏设置菜单，菜单默认收起、无点击穿透且不会暂停自动时间。
- [x] 左键建造/查看、中键拖动平移、右键旋转和滚轮缩放职责分离；中键拖动不会建造或扣费。
- [x] 时间以 8 秒/日自动流逝，暂停、1×、2×、4×与终局停止通过专项验收；界面不再提供手动跳日。
- [x] 启动时自动续读有效存档；所有新增专项验收在结束后原样恢复玩家存档。
- [x] 48×48 地图、七区 2304 格与七章目标链通过专项验收；原 30×30 坐标和区域含义完整保留。
- [x] 1366×768 下顶栏常驻章节、进度和唯一当前任务；右侧面板同屏展示条件进度、下一解锁、费用、奖励和按钮，首章与第四章均无裁切或重叠。
- [x] 当前任务按建筑、容量、住房、人口、幸福、资源和开拓顺序切换；六章均可在第 1 日满足其他条件后开拓，北坡首次开拓的扣费、20 粮奖励和第二章切换只结算一次。
- [x] 地图扩展专项验收通过：48×48 七区面积为 400/200/200/100/432/540/432；六次开拓的条件、费用、奖励、顺序和新区规则均通过。
- [x] v1 存档读取后区域等级补为 0，保存迁移为 v2；旧 v2 等级 0..3 保持原义，锁区建筑和非法等级存档被事务式拒绝。
- [x] 策划规则、程序资源键和美术资源清单形成稳定接口；缺失写实资源有低模回退，不会出现空节点。

## 已知限制与发行前缺项

### 阻断独立发行

- [ ] 创建 Windows Desktop 导出预设并输出到 `M:\NewGames\TheEast\build\windows`。
- [ ] 在没有 Godot 编辑器的环境中双击 EXE，走通建造、结算、胜负、重置与再次启动。
- [ ] 确认发布包保存路径位于 EXE 同目录且不会写入 C 盘。

### 后续质量项

- [ ] 按 `REALISTIC_ASSET_PLAN.md` 继续补充 LOD，并记录不同硬件档位的性能数据。
- [ ] 在 1920×1080 复验 UI、失焦恢复、连续拖动和快速双击。
- [ ] 记录 50 名居民、100 个场景物件下的帧率和 10 分钟内存趋势。
- [ ] 增加低幸福连续三日失败、失败优先于胜利、连续重置十次的专项测试。
- [ ] 当前结算采用轻量原型规则；岗位分配、随机权重事件、事件选择、每日账本和“继续建设”尚未达到 `GAME_DESIGN.md` 的扩展规格。

## 本轮自动验收结果

```text
工程导入：EXIT 0
SMOKE_TEST_OK: scene, build rules, economy, save and load
ASSET_SMOKE_OK: GLB buildings, props, citizen and recursive preview tint
REALISTIC_ASSET_SMOKE_OK: available=15 missing=0 all_sources=realistic
PRODUCER_ACCEPTANCE_OK: win, food loss, 30-day stability
MAP_EXPANSION_ACCEPTANCE_OK: 48x48, 7 regions, MultiMesh locks, v1/v2 migration, final victory
MAP_UNLOCK_SMOKE_OK: 48x48, 7 regions, day-one unlocks, rewards, goal chain, v1/v2 saves
MAP_EXPANSION_RENDER_OK: locked_and_opened
GOAL_CLARITY_ACCEPTANCE_OK: 48x48, 7 regions, visible chapter/task/progress/reward, staged task priority
CONTROLS_TIME_UI_ACCEPTANCE_OK: middle-mouse pan, automatic time, pause/speeds, collapsible objectives
GOAL_CLARITY_RENDER_OK: chapter_one_expanded_and_collapsed, chapter_four_1366x768
REALISTIC_PERFORMANCE_OK: frames=600 seconds=2.185 fps=274.6 draw_calls=5399 primitives=642360 nodes=5602
```

最终 15 项写实资产验收图：`qa/realistic-gallery/complete-15-v100000003.png`。  
主游戏写实场景验收图：`qa/realistic-gallery/main-realistic-v100000007.png`。
历史 30×30 四区截图：`qa/map-expansion-start.png`、`qa/map-expansion-open.png` 与 `qa/map-expansion/region-sign00000002.png`，仅保留作迁移记录，不代表当前版本。
目标链首章展开图：`qa/goal-clarity/chapter-one-1366x768.png`；收起图：`qa/goal-clarity/chapter-one-collapsed-1366x768.png`；第四章实机图：`qa/goal-clarity/chapter-four-1366x768.png`。

Godot 每次启动会记录 `Failed to read the root certificate store`；强制导入时还会记录两条 Windows `get_system_dir` 查询失败。它们出现在用户目录与临时目录全部重定向到 M 盘的测试环境中，未影响 GLB/PBR 导入、离线主场景或全部自动验收。若后续加入联网功能，需要单独解决证书环境问题。

性能数据来自本机 RTX 3060 Ti、1366×768、OpenGL Compatibility、关闭垂直同步的 48×48 七区域主场景。600 帧采样耗时 2.185 秒，约 274.6 FPS、5399 次绘制调用、642360 个图元和 5602 个节点；当前可试玩，但继续增加建筑和居民时仍应补充 LOD、合批和压力测试。
