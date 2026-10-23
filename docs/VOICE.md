# 声笺：麦克风转文字技术验证

声笺（编号 13）保留空气读数，并留出纸面式转写区域。基础安装可查看界面；语音识别需要另行配置服务。本版本的识别服务使用 Apple Silicon Mac 的 MLX Whisper，不在 CGS2 或 NAS 上运行模型。

## Mac 服务

需要 Apple Silicon、Python 3.10+，以及自己的 Whisper 模型。模型不随仓库分发，请遵守所选模型的许可证。可从 [mlx-community/whisper-small-mlx](https://huggingface.co/mlx-community/whisper-small-mlx) 获取本地模型；性能取决于 Mac 和模型。

```sh
python3 -m venv .local/voice-venv
.local/voice-venv/bin/pip install -r integrations/voice/requirements.lock
python3 tools/initialize_service.py voice \
  --host <Mac局域网IP> --port 6095 --output .local/voice-private
python3 integrations/voice/make_warmup.py --output .local/synthetic-warmup.pcm
.local/voice-venv/bin/python integrations/voice/server.py \
  --host <Mac局域网IP> --peer <设备局域网IP> \
  --private .local/voice-private --model /path/to/your/model \
  --warmup .local/synthetic-warmup.pcm
```

`make_warmup.py` 只用 macOS `say` 合成一段固定测试语句，不访问麦克风；默认中文声音 `Tingting`，不可用时可通过 `--voice` 选择已安装的中文声音。服务先在同一解码线程完成模型与解码器预热，再接受音频。可以使用自己的进程管理器常驻该命令；请保留明确的模型、私有配置及 warmup 路径，避免依赖临时目录。

## 配置设备

从 `.local/voice-private/` 准备 `origin`、`server.pem`、`auth-header` 三份客户端文件。Mac 和设备由同一电脑管理时可直接使用该私有目录；配置工具只传输这些必要的客户端内容，不上传服务器私钥。

```sh
python3 tools/configure.py voice --private .local/voice-private
```

默认拒绝覆盖已有服务，确需切换时增加 `--replace`。旧文件先保留在设备的 provider 备份目录。服务启动后保持空闲，不会自动开启录音。

## 行为与隐私

- 点击“开始”才采集设备麦克风；显示监听、识别、完成和错误状态。
- 使用分块 PCM 与 NDJSON 返回部分转写，首段以约 1.6 秒音频为触发窗口；这不是端到端 1.6 秒的延迟保证。
- 点击“停止”先停止新增采集，再让已进入缓冲区的尾段在有界时间内完成；不立即杀掉最后一次识别。
- 离开页面、失去心跳或会话到期后停止任务；旧会话结果不能写入新会话。
- 单次监听、内存、文本长度、网络与排空等待都有上限。忙碌、离线或模型加载失败会显示错误，不伪造文字。
- 音频通过内存管道传输，服务器不保存或记录麦克风音频/转写；设备临时文字只在 RAM-backed `/tmp` 与当前界面存在，不写入表盘偏好。

协议、流式状态与尾段测试可在不运行模型、不接麦克风时执行：

```sh
python3 -m pip install 'numpy>=2,<3'
python3 -m unittest discover -s integrations/voice -p 'test_*.py'
```

这些测试使用合成 PCM 与 stub 识别器。真实识别准确率、口音、噪声和所有 Mac 型号的延迟没有统一保证；这是技术验证功能。
