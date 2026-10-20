# 江南水墨建筑资源 v2

这套资源面向《The East》的俯视 3D 城镇场景，保留 `godot/assets/realistic/` 作为旧版回退，不覆盖或删除旧模型。

## 资源特点

- 青绿水墨配色：灰青瓦、暖木、粉墙和少量朱砂、靛蓝点缀。
- 前侧敞开、后侧保留半坡屋顶，屋内的桌台、炉台、货物、农田和工具在俯视角可读。
- GLB 使用米制、地面中心原点，建筑入口约定为 Godot `+Z`。
- 每个模型附带 `Door` 空节点；游戏接入层可以据此生成路径与碰撞。

## 模型

| 文件 | 主要可读功能 |
| --- | --- |
| `building_house_open.glb` | 住宅庭院、桌台、灯笼、竹景 |
| `building_farm_open.glb` | 水田、稻苗、灌渠、水车、农具棚 |
| `building_lumber_open.glb` | 木料堆、锯台、锯片、斧具 |
| `building_warehouse_open.glb` | 装卸坡、粮袋、木箱、仓储墙 |
| `building_workshop_open.glb` | 炉台、火箱、铁砧、工具架、烟囱 |
| `building_market_open.glb` | 双摊位、布棚、货篮、粮袋、招牌 |
| `building_tea_pavilion_open.glb` | 茶桌、茶杯、坐凳、竹景、灯笼 |

## 文件位置

- GLB：`models/`
- 可编辑 Blender 源文件：`source/jiangnan_style_v2_gallery.blend`
- 预览图：`previews/jiangnan_style_v2_gallery.png`
- 机器可读清单：`models/jiangnan_style_v2_manifest.json`
- 生成脚本：`tools/generate_jiangnan_style_assets.py`

## 重新生成

在项目根目录执行 `重新生成江南水墨资源.bat`，或用 Blender 4.x 后台运行 `tools/generate_jiangnan_style_assets.py`。环境变量 `THE_EAST_PROJECT` 可指定项目根目录，默认仍是 `M:\NewGames\TheEast`。
