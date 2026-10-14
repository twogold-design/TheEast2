# Godot 4.7.2 原生版本

此目录现同时保留网页原型和 Godot 原生项目。Godot 项目入口为根目录的 `project.godot`，核心场景与脚本位于 `godot/`。

## 启动

双击项目根目录的 `启动游戏.bat` 可直接试玩。打开编辑器时运行：

```powershell
& 'M:\NewGames\TheEast\启动游戏.bat' editor
```

也可以使用 PowerShell 启动脚本：

```powershell
powershell -ExecutionPolicy Bypass -File 'M:\NewGames\TheEast\run_editor.ps1'
powershell -ExecutionPolicy Bypass -File 'M:\NewGames\TheEast\run_game.ps1'
```

这些入口会把 Godot 的 `APPDATA`、`LOCALAPPDATA`、临时目录和日志全部定向到 `M:\NewGames\TheEast\.godot-user`，避免向 C 盘写入。编辑器打开后按 F6/F5 运行场景或项目。

## 资产陈列场景

在 Godot 编辑器中打开 `godot/AssetGallery.tscn` 并按 F6，可以检查原始低多边形资产包。

主游戏默认通过 `godot/RealisticAssets.gd` 加载 `godot/assets/realistic/models/` 中的 15 项高细节写实 GLB，包括五类建筑、三种树木、三种山石、木桥、灯笼、作物和居民。仅当对应写实文件缺失时才调用 `ArtAssets.gd` 的低多边形模型回退。

在 Godot 编辑器中打开 `godot/RealisticGallery.tscn` 并按 F6，可以一次验收全部 15 项写实资产。顶部状态条会显示加载数量和来源；完整交付状态应为 `15/15` 且全部来自 `realistic/models`。

## 操作

- 左键单击：建造或查看建筑
- 中键拖动：平移地图
- 右键短按：取消当前建筑摆放
- 右键拖动：旋转镜头
- 滚轮：缩放
- 选择底部建筑，再单击格子：建造
- 再次点击当前建筑按钮，或按 `Esc`：取消摆放并回到查看模式
- 左键点击已有建筑：选中并打开详情，可用“删除建筑”拆除并返还一半木材
- 时间默认自动以 1× 流逝，每 8 秒结算一天；底栏可暂停或切换 1×/2×/4×
- 目标栏右上角箭头可收起/展开，收起后顶栏继续显示当前任务
- 顶栏“设置”集中提供查看模式、保存进度、读取存档和重新开始，底栏只保留建造与时间控制
- 读取与重新开始会先要求确认；启动时仍自动续读有效存档
- 编辑器运行时存档位于项目内 `saves/savegame.json`，Windows 导出后位于可执行文件旁的 `saves/savegame.json`

地图现在为 48×48，共 2304 格，分为河湾故地、北坡梯田、东麓林场、云岫高台、沧波东原、朔岭关田和天际新都七区。新局只开放河湾故地；顶栏常驻章节、进度与唯一当前任务，右侧“复兴目标”面板显示逐项条件、下一解锁、费用和奖励。开拓成功后锁区雾层和区域牌消失，锁定区域不能建造。

农田需靠近河流，伐木场需建在各区域林缘，小工坊需人口达到 8。七区全部开放、人口达到 45、木材和粮食各不少于 200、幸福度达到 80 时胜利；粮食耗尽或幸福度连续三日低于 20 时失败。v1 存档可直接读取，区域等级按 0 处理并在下次保存时写成 v2；旧 v2 等级 0..3 保持原义。详细规则见 `MAP_GOALS_DESIGN.md`。

