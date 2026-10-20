# 东境：孤城新生

一个使用 Godot 4.7.2 制作的原创东方古代河谷城镇 3D 模拟经营原型。玩家通过八类住宅、生产、商贸和公共建筑维持资源与民心，并沿七章目标链逐级开拓 48×48 的东方河谷。主场景恢复使用第一版写实资源，居民会按日程在住所、岗位、仓库和河湾步道之间活动。

## 当前技术栈

- 引擎：Godot 4.7.2
- 引擎目录：`D:\tools\Godot-4.7.2`
- 项目目录：`M:\NewGames\TheEast`
- 脚本：GDScript
- 正式目标：Windows 桌面原型

原有 Three.js/Vite 文件是迁移前的可玩参考实现，不是当前正式入口。Godot 版保留其核心玩法和初始数值，现行七章目标链、经营门槛与胜负条件以本文件和 `MAP_GOALS_DESIGN.md` 为准。

玩法扩展需求以 [`GAMEPLAY_REQUIREMENTS.md`](M:/NewGames/TheEast/GAMEPLAY_REQUIREMENTS.md) 为准。该文档把江南水乡经营类游戏中可借鉴的系统抽象为本项目自己的生产链、居民需求、订单商贸、探险、事件、装饰主题和长期目标，并列出 M0～M3 的实现顺序；不复用其他作品的角色、文案、数值、地图或美术资产。

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

`check` 检查引擎和 `project.godot` 路径；`test` 无窗口加载主场景，并自动验收中键平移、自动时间、暂停/倍速、目标栏折叠，以及区域建筑的解锁、分页菜单、每日效果和 v3 存档；`render-test` 短时启动实际图形渲染。日志写入 `M:\NewGames\TheEast\.godot-user\Logs`。

## 3D 美术资源

- Godot 模型目录：`M:\NewGames\TheEast\godot\assets\models`，包含五类建筑、桥、三种树、三种岩石、灯笼、作物和居民的 GLB 文件，以及 `asset_manifest.json` 资源清单。
- Blender 可编辑源文件：`M:\NewGames\TheEast\godot\assets\source\east_valley_art_kit.blend`。
- 资产总览图：`M:\NewGames\TheEast\godot\assets\previews\asset_sheet.png`。
- Godot 资源展厅场景：`M:\NewGames\TheEast\godot\AssetGallery.tscn`。在编辑器中打开该场景后按 `F6`，可单独检查模型、材质、比例和轮廓。
- 资源创建接口位于 `M:\NewGames\TheEast\godot\ArtAssets.gd`；游戏优先加载 GLB，并保留程序化低多边形回退模型。

### 当前主场景资源

当前游戏入口恢复使用 `M:\NewGames\TheEast\godot\RealisticAssets.gd` 提供的第一版写实资源，建筑、桥、树木、岩石、灯笼、作物和居民统一使用 `godot/assets/realistic/` 中的原始模型与 PBR 材质。缺少对应 GLB 时，运行时会回退到 `ArtAssets.gd` 的原始低多边形资源。

水墨换肤和江南建筑 v2～v4 的文件继续保留在项目中，作为后续美术方向比较和备用资源，不再作为主游戏默认美术入口，也不会覆盖第一版写实资源。

本机 Blender 位于 `D:\tools\blender\setup\blender.exe`。需要重新生成整套资源时，双击项目根目录的 `重新生成模型资源.bat`，或在 PowerShell 中运行：

```powershell
& 'M:\NewGames\TheEast\重新生成模型资源.bat'
```

生成器使用 `M:\NewGames\TheEast\tools\generate_lowpoly_assets.py`，会更新 GLB、Blender 源文件、资源清单和总览图。批处理将 Blender 的用户配置、临时目录和生成输出重定向到 `M:\NewGames\TheEast`；不得把模型源、缓存、日志或中间文件输出到 C 盘。可先运行 `重新生成模型资源.bat check` 检查 Blender 和生成器路径。

### 第一版 PBR 写实主资源

写实资源位于 `M:\NewGames\TheEast\godot\assets\realistic`，与原有低多边形资源分开保存。完整包包含五类建筑、木桥、三种树木、三种岩石、灯笼、作物和居民共 15 项，均提供独立 GLB、UV、Base Color/Normal/Roughness 贴图、可编辑 Blender 源文件和渲染预览。它是当前主游戏使用的第一版美术资源；单项缺失时才使用低模回退。

- Blender 源文件：`M:\NewGames\TheEast\godot\assets\realistic\source\east_valley_realistic_full.blend`
- 写实模型：`M:\NewGames\TheEast\godot\assets\realistic\models`
- PBR 贴图：`M:\NewGames\TheEast\godot\assets\realistic\materials`
- Blender 总览图：`M:\NewGames\TheEast\godot\assets\realistic\previews\realistic_full_asset_sheet.png`
- Godot 写实展厅：`M:\NewGames\TheEast\godot\RealisticGallery.tscn`
- 重建脚本：`M:\NewGames\TheEast\重新生成写实模型资源.bat`

第一版写实资源展厅：`M:\NewGames\TheEast\godot\RealisticGallery.tscn`。在 Godot 编辑器中打开后按 `F6`，可以检查当前主游戏使用的 15 项写实资源。`AssetGallery.tscn` 恢复为原始低多边形资源展厅。

双击 `重新生成写实模型资源.bat` 可重建全部 15 项资源，运行 `重新生成写实模型资源.bat check` 可只检查 Blender、Godot 和生成器路径。批处理会校验 Blender 输出中的 `REALISTIC_FULL_OK 15` 成功标记，随后让 Godot 自动重新导入 GLB，避免游戏继续使用旧缓存；用户配置、临时文件、日志与全部产物均留在 `M:\NewGames\TheEast`。

五类建筑都遵循俯视屋顶识别规则：茅舍使用红色檐下构件，伐木场使用两根深木色顺坡压条，农田使用稻草人，仓库使用双通风帽，工坊使用单个高砖烟囱。生成器会把唯一的 `roof_identity` 与可见网格 `roof_marker` 同时写入 GLB extras 和 `realistic_manifest.json`，自动验收会检查它们没有重复或丢失。

集市、医馆和书院使用这五类写实 GLB 作为主体，再由运行时组合专属构件，保持原有材质风格并从俯视角形成区别：集市带朱红街棚、双灯和屋顶牌旗，医馆带青绿药棚、药柜和屋脊药葫芦，书院带蓝灰卷轴匾、金色屋脊和庭前书案。它们不伪装成新增导入资源，因此严格资源清单仍保持 15/15。

### 备用江南水墨建筑

`ink_wash` 和 `jiangnan_style_v2`～`jiangnan_style_v4` 继续完整保留，便于后续重新制定统一的场景色彩和建筑结构后再评估。它们当前不是主游戏入口；当前游戏固定优先使用第一版 `realistic` 资源。

- 可编辑 Blender 源文件：`M:\NewGames\TheEast\godot\assets\jiangnan_style_v4\source\jiangnan_style_v4_gallery.blend`
- GLB 清单：`M:\NewGames\TheEast\godot\assets\jiangnan_style_v4\models\jiangnan_style_v4_manifest.json`
- 预览图：`M:\NewGames\TheEast\godot\assets\jiangnan_style_v4\previews\jiangnan_style_v4_gallery.png`
- 生成脚本：`M:\NewGames\TheEast\tools\generate_jiangnan_style_assets_v4.py`
- 重新生成：`M:\NewGames\TheEast\重新生成江南水墨资源.bat`
- Godot 注册器：`M:\NewGames\TheEast\godot\JiangnanStyleAssets.gd`

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
- 左键点击已有建筑：选中并打开详情，可暂停/启用生产，或用“删除建筑”拆除并返还一半木材与铜钱
- 时间默认自动以 1× 流逝，每 8 秒结算一天；底栏可暂停或切换 1×/2×/4×
- 右侧目标栏右上角的箭头可收起/展开，收起后顶栏仍显示当前任务
- 顶栏“设置”：展开查看模式、保存进度、读取存档和重新开始；这些低频操作不再占用底部建造栏
- 读取与重新开始会先要求确认；启动时仍会自动续读有效存档
- 存档在编辑器中写入项目内 `saves`，导出后写入可执行文件旁的 `saves`

居民日程按一个自动流逝的游戏日循环：0%–12% 居家起床，12%–28% 通勤，28%–68% 按岗位工作（农田耕作、伐木场伐木或工坊制作），68%–78% 到仓库取食，78%–92% 在河湾步道散步，92%–100% 回家休息。每名居民带有轻微错峰，新增或拆除建筑后会重新选择最近岗位。暂停时位置和日程都冻结；日程只驱动移动与状态提示，不直接修改人口、资源、日期或幸福度。

地图共有 2304 格和七片区域：河湾故地、北坡梯田、东麓林场、云岫高台、沧波东原、朔岭关田和天际新都。新局只开放河湾故地；每次点击开拓都必须同时满足经营条件和木材、粮食、铜钱费用，完成后才开放下一片区域并领取一次性奖励。锁定区域仍显示地貌与区域牌，但不能建造。

逐级门槛如下（“住房”是可容纳人数，不是当前人口；稳定天数要求口粮充足、维护无欠款且岗位配员率不低于 70%）：

| 解锁区域 | 人口 / 住房 / 幸福 / 稳定日 | 建筑要求 | 前一区域建设 | 木材 / 粮食 / 铜钱费用 |
| --- | --- | --- | --- | --- |
| 北坡梯田 | 8 / 8 / — / 1 | 农田 1 | — | 65 / 30 / 15 |
| 东麓林场 | 14 / 16 / 60 / 2 | 农田 2、伐木场 2、仓库 1、集市 1 | 北坡农田 1、集市 1 | 130 / 65 / 35 |
| 云岫高台 | 20 / 24 / 68 / 3 | 农田 2、伐木场 2、仓库 2、小工坊 1 | 东麓伐木场 1 | 190 / 95 / 60 |
| 沧波东原 | 28 / 32 / 72 / 4 | 农田 4、伐木场 3、仓库 2、小工坊 1、医馆 1 | 高台小工坊 1、医馆 1 | 250 / 135 / 90 |
| 朔岭关田 | 36 / 40 / 76 / 5 | 农田 5、伐木场 4、仓库 3、小工坊 2、书院 1 | 东原仓库 1、书院 1 | 320 / 180 / 125 |
| 天际新都 | 45 / 48 / 80 / 6 | 农田 6、伐木场 5、仓库 4、小工坊 3 | 北关小工坊 1 | 390 / 230 / 165 |

顶部与右侧“复兴目标”都只显示当前一条行动目标；右侧另列区域用途、三类开拓费用、奖励和开拓按钮，不显示完成比例、`当前/要求` 或逐项条件清单。收起后只保留 `目标 · 区域名`，按钮不可用时可悬停查看首个阻碍。农田需靠近河流，伐木场需建在各区域的林缘，小工坊需人口达到 8。

新局拥有 60 铜钱。建筑费用为：茅舍 12 木/4 钱、农田 18 木/6 钱、伐木场 22 木/6 钱、仓库 30 木/10 钱、小工坊 38 木/16 钱；这五类全部从开局可用，并集中显示在“开局”页。北坡、高台、东原开拓后，图鉴再依次增加集市 45 木/18 钱、医馆 52 木/24 钱、书院 68 木/38 钱；后续建筑按“产业 / 民生”分页，锁定项直接标出开放区域。

系统把人口的 70% 向上取整为有效劳动力，按农田 → 伐木场 → 小工坊 → 集市 → 医馆 → 书院分配。农田与伐木场按实际在岗比例生产；小工坊必须 3 人满员，并整份消耗 4 木材与 2 粮食后获得 10 铜钱；集市满员消耗 3 粮食获得 9 铜钱；医馆满员使幸福目标 +7；书院满员每日增加 5 铜钱并使幸福目标 +4。玩家可暂停单座生产或公共建筑，重新分配劳动力。

每日口粮为人口的一半向上取整，且每座茅舍额外消耗 1 粮食。每日人口税为人口的一半向下取整，至少获得 1 铜钱；有工人运转的农田和伐木场还会参与民生交易，每处获得 2 铜钱、每日最多 4 铜钱。因此即使未建小工坊且铜钱耗尽，基础生产仍能恢复资金；主动维持生产比单纯等待更快，小工坊的 10 铜钱加工收入则提供明显的效率提升。农田、伐木场、仓库每天各需 1 铜钱维护，小工坊和集市需 2 铜钱，医馆需 3 铜钱，书院需 4 铜钱；欠款会中断稳定经营与居民迁入。每座仓库让木材和粮食容量各增加 75。七区全部开放后，还需人口 45、木材 200、粮食 200、铜钱 150、幸福度 80，并连续稳定经营 7 日，才能完成“东境全域复兴”；幸福度连续三日低于 20 则失败。

存档当前写为 v3，并保存铜钱、稳定天数、维护欠款及建筑启停状态。v1 存档按河湾故地读取，v2 保留原区域等级；两者缺少的新字段会使用兼容默认值，下一次保存时迁移为 v3。

当前大地图与目标链规格详见 [`MAP_GOALS_DESIGN.md`](M:/NewGames/TheEast/MAP_GOALS_DESIGN.md)。

## 文件位置约束

项目源文件、导入缓存、编辑器用户数据、日志、临时文件与导出产物只允许写入 `M:\NewGames\TheEast`。Godot 可执行程序从 `D:\tools\Godot-4.7.2` 读取，不在 C 盘创建项目副本或构建目录。每次从新的 PowerShell 窗口启动前，需重新执行编辑器启动章节中的环境变量设置。
