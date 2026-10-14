# 东境：孤城新生

一个使用 Godot 4.7.2 制作的原创东方古代河谷城镇 3D 模拟经营原型。玩家通过建造住房、农田、伐木场、仓库和工坊维持资源与民心，并沿七章目标链逐级开拓 48×48 的东方河谷。

## 当前技术栈

- 引擎：Godot 4.7.2
- 引擎目录：`D:\tools\Godot-4.7.2`
- 项目目录：`M:\NewGames\TheEast`
- 脚本：GDScript
- 正式目标：Windows 桌面原型

原有 Three.js/Vite 文件是迁移前的可玩参考实现，不是当前正式入口。Godot 版保留其核心玩法和初始数值，现行七章目标链与胜负条件以 `MAP_GOALS_DESIGN.md` 为准。

## 编辑器启动

最方便的方式是双击项目根目录的 `启动游戏.bat`。默认直接进入游戏；需要打开编辑器时运行：

```powershell
& 'M:\NewGames\TheEast\启动游戏.bat' editor
```

当 `project.godot` 已建立后，在 PowerShell 中运行。先把 Godot 的编辑器配置、日志和临时目录重定向到项目内，避免默认写入 C 盘：

```powershell
powershell -ExecutionPolicy Bypass -File 'M:\NewGames\TheEast\run_editor.ps1'
```

直接试玩可运行：

```powershell
powershell -ExecutionPolicy Bypass -File 'M:\NewGames\TheEast\run_game.ps1'
```

启动脚本会自动完成下面这些环境变量设置；需要手动启动时使用：

```powershell
$godotData = 'M:\NewGames\TheEast\.godot-user'
New-Item -ItemType Directory -Force "$godotData\Roaming", "$godotData\Local", "$godotData\Temp", "$godotData\Logs" | Out-Null
$env:APPDATA = "$godotData\Roaming"
$env:LOCALAPPDATA = "$godotData\Local"
$env:TEMP = "$godotData\Temp"
$env:TMP = "$godotData\Temp"
& 'D:\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe' --editor --path 'M:\NewGames\TheEast' --log-file "$godotData\Logs\editor.log"
```

在编辑器中按 `F6` 运行当前场景，按 `F5` 运行项目主场景。

也可以直接双击根目录的 `启动游戏.bat`。该脚本会清理项目路径末尾的反斜杠，再传给 Godot，避免 Windows 将结束引号和后续参数误解析成项目路径的一部分。

启动器支持以下检查命令：

```powershell
cmd.exe /d /c call "M:\NewGames\TheEast\启动游戏.bat" check
cmd.exe /d /c call "M:\NewGames\TheEast\启动游戏.bat" test
cmd.exe /d /c call "M:\NewGames\TheEast\启动游戏.bat" render-test
```

`check` 检查引擎和 `project.godot` 路径；`test` 无窗口加载主场景，并自动验收中键平移、自动时间、暂停/倍速与目标栏折叠；`render-test` 短时启动实际图形渲染。日志写入 `M:\NewGames\TheEast\.godot-user\Logs`。

## 3D 美术资源

- Godot 模型目录：`M:\NewGames\TheEast\godot\assets\models`，包含五类建筑、桥、三种树、三种岩石、灯笼、作物和居民的 GLB 文件，以及 `asset_manifest.json` 资源清单。
- Blender 可编辑源文件：`M:\NewGames\TheEast\godot\assets\source\east_valley_art_kit.blend`。
- 资产总览图：`M:\NewGames\TheEast\godot\assets\previews\asset_sheet.png`。
- Godot 资源展厅场景：`M:\NewGames\TheEast\godot\AssetGallery.tscn`。在编辑器中打开该场景后按 `F6`，可单独检查模型、材质、比例和轮廓。
- 资源创建接口位于 `M:\NewGames\TheEast\godot\ArtAssets.gd`；游戏优先加载 GLB，并保留程序化低多边形回退模型。

本机 Blender 位于 `D:\tools\blender\setup\blender.exe`。需要重新生成整套资源时，双击项目根目录的 `重新生成模型资源.bat`，或在 PowerShell 中运行：

```powershell
& 'M:\NewGames\TheEast\重新生成模型资源.bat'
```

生成器使用 `M:\NewGames\TheEast\tools\generate_lowpoly_assets.py`，会更新 GLB、Blender 源文件、资源清单和总览图。批处理将 Blender 的用户配置、临时目录和生成输出重定向到 `M:\NewGames\TheEast`；不得把模型源、缓存、日志或中间文件输出到 C 盘。可先运行 `重新生成模型资源.bat check` 检查 Blender 和生成器路径。

### 高细节 PBR 写实样板

写实资源位于 `M:\NewGames\TheEast\godot\assets\realistic`，与原有低多边形资源分开保存。完整包包含五类建筑、木桥、三种树木、三种岩石、灯笼、作物和居民共 15 项，均提供独立 GLB、UV、Base Color/Normal/Roughness 贴图、可编辑 Blender 源文件和渲染预览。游戏默认加载写实模型，单项缺失时才使用低模回退。

- Blender 源文件：`M:\NewGames\TheEast\godot\assets\realistic\source\east_valley_realistic_full.blend`
- 写实模型：`M:\NewGames\TheEast\godot\assets\realistic\models`
- PBR 贴图：`M:\NewGames\TheEast\godot\assets\realistic\materials`
- Blender 总览图：`M:\NewGames\TheEast\godot\assets\realistic\previews\realistic_full_asset_sheet.png`
- Godot 写实展厅：`M:\NewGames\TheEast\godot\RealisticGallery.tscn`
- 重建脚本：`M:\NewGames\TheEast\重新生成写实模型资源.bat`

双击 `重新生成写实模型资源.bat` 可重建全部 15 项资源，运行 `重新生成写实模型资源.bat check` 可只检查 Blender 和生成器路径。批处理会校验 Blender 输出中的 `REALISTIC_FULL_OK 15` 成功标记，并将用户配置、临时文件、日志与全部产物留在 `M:\NewGames\TheEast`。

## 命令行验证

```powershell
& 'D:\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path 'M:\NewGames\TheEast' --editor --headless --quit --log-file 'M:\NewGames\TheEast\.godot-user\Logs\import.log'
& 'D:\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe' --path 'M:\NewGames\TheEast' --headless --quit-after 5 --log-file 'M:\NewGames\TheEast\.godot-user\Logs\runtime.log'
```

以上验证命令沿用上一节设置的环境变量。第一条命令验证工程导入与脚本解析，第二条命令短时运行主场景。两条命令均应以退出码 0 结束，且不出现脚本解析、缺失资源或缺失节点错误。

## Windows 导出

在 Godot 编辑器的“项目 → 导出”中建立 Windows Desktop 预设，将输出放在 `M:\NewGames\TheEast\build\windows\`。发布包应可在不安装 Godot、Node.js 或浏览器开发服务器的情况下独立运行。

## 操作

- 左键单击：建造或查看建筑
- 按住鼠标中键拖动：平移地图
- 右键短按：取消当前建筑摆放
- 右键拖动：旋转与调整俯角
- 鼠标滚轮：缩放
- 选择底部建筑后点击格子：建造
- 再次点击当前建筑按钮，或按 `Esc`：取消摆放并回到查看模式
- 左键点击已有建筑：选中并打开详情，可用“删除建筑”拆除并返还一半木材
- 时间默认自动以 1× 流逝，每 8 秒结算一天；底栏可暂停或切换 1×/2×/4×
- 右侧目标栏右上角的箭头可收起/展开，收起后顶栏仍显示当前任务
- 顶栏“设置”：展开查看模式、保存进度、读取存档和重新开始；这些低频操作不再占用底部建造栏
- 读取与重新开始会先要求确认；启动时仍会自动续读有效存档
- 存档在编辑器中写入项目内 `saves`，导出后写入可执行文件旁的 `saves`

地图共有 2304 格和七片区域：河湾故地、北坡梯田、东麓林场、云岫高台、沧波东原、朔岭关田和天际新都。顶栏常驻章节进度与唯一的“当前任务”；右侧“复兴目标”面板显示逐项进度、用途、下一解锁、费用、奖励和开拓按钮。锁定区域仍显示地貌与区域牌，但不能建造。

农田需靠近河流，伐木场需建在各区域的林缘，小工坊需人口达到 8。七区全部开放、人口达到 45、木材和粮食各不少于 200、幸福度达到 80 时完成“东境全域复兴”；粮食耗尽或幸福度连续三日低于 20 则失败。旧版 v1 存档会自动按河湾故地读取并迁移为 v2，原有 v2 等级 0..3 存档保持原区域含义。

当前大地图与目标链规格详见 [`MAP_GOALS_DESIGN.md`](M:/NewGames/TheEast/MAP_GOALS_DESIGN.md)。

## 文件位置约束

项目源文件、导入缓存、编辑器用户数据、日志、临时文件与导出产物只允许写入 `M:\NewGames\TheEast`。Godot 可执行程序从 `D:\tools\Godot-4.7.2` 读取，不在 C 盘创建项目副本或构建目录。每次从新的 PowerShell 窗口启动前，需重新执行编辑器启动章节中的环境变量设置。
