# 《东境》原创背景音乐

## 当前曲目：田野小路 / Country Meadow

轻快而克制的乡村风纯音乐：温暖木吉他分解和弦与轻扫弦、根音／五度交替低音、轻刷节拍、稀疏双弦曼陀林风格应答。没有笛子主旋律、合成哨音或人声，适合长时间经营时低音量循环。

**音色由 NumPy 程序合成，模拟原声乐器的拨弦与节奏特征，并非真实吉他、贝斯或曼陀林录音。** 曲谱为本工程原创，未借用第三方旋律、联网采样或外部音色库。源代码可随工程使用、修改和重建。

- 完整音轨：`country_meadow.wav`；40小节，92 BPM，约104.35秒。
- 格式：44,100 Hz，双声道，16-bit PCM WAV。
- 20秒试听：`qa/bgm/country-preview.wav`，试听单独加首尾淡化；完整曲目不做结尾淡出。
- 可复现生成器：`tools/generate_country_bgm.py`；固定随机种子，全部音符尾音和房间反射跨循环边界保留。
- 统计：`qa/bgm/country_meadow_stats.json`。峰值约−7.69 dBFS，RMS约−22 dBFS，没有削波。循环接点步差约0.00190／0.00144，低于常规相邻样本步差的99.9百分位0.01187，不以末尾静音拼接。
- 五组8小节乐句包含和声、指弹密度与应答变化；低音与扫弦稳定，曼陀林仅35个应答音，避免持续高音抢占游戏音效。

在工程目录重建，文件和临时数据均留在M盘：

```powershell
$env:PYTHONDONTWRITEBYTECODE='1'
$env:TEMP='M:\NewGames\TheEast\.godot-user\Temp'
$env:TMP=$env:TEMP
$env:APPDATA='M:\NewGames\TheEast\.godot-user\AppData\Roaming'
$env:LOCALAPPDATA='M:\NewGames\TheEast\.godot-user\AppData\Local'
& 'D:\tools\python\python.exe' tools/generate_country_bgm.py
```

默认同时输出完整WAV、20秒试听和统计JSON。`--output`、`--preview`、`--stats`可指定项目内其他输出路径。生成器只使用NumPy和Python标准库，不访问网络。

## 保留曲目：水岸晴日 / Riverside Day

为《东境：孤城新生》制作的原创循环背景音乐。以五声音阶旋律、柔和拨弦、气息笛风格音色和低音和声营造舒缓的水乡氛围。音色由程序合成，无人声，未使用第三方歌曲或录音采样。

- 32 小节，76 BPM，约 101.05 秒。
- 44,100 Hz、双声道、16-bit PCM WAV。
- 尾音与混响跨循环边界保留；播放器循环完整音轨，首次播放淡入。
- 峰值约 -8.13 dBFS，RMS 约 -21.5 dBFS。游戏默认音量 45%，可在设置中调节或静音。
- 音乐及音色的生成源代码保留在 `tools/generate_riverside_bgm.py`，可直接随本项目使用和修改。

使用已安装的 Python 与 NumPy 重建（在工程目录执行，所有输出仍在 M 盘工程内）：

```powershell
$env:PYTHONDONTWRITEBYTECODE='1'
$env:TEMP='M:\NewGames\TheEast\.godot-user\Temp'
$env:TMP=$env:TEMP
& 'D:\tools\python\python.exe' tools/generate_riverside_bgm.py --preview qa/bgm/preview.wav
```

完整音轨为 `riverside_day.wav`；20 秒试听位于 `qa/bgm/preview.wav`。
