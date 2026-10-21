# 水岸晴日 / Riverside Day

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
