# 验证记录与边界

本文件对应 0.1.0 源码发布。公开预览使用固定示例数据；真实设备记录、地址、凭据、相册和语音内容均不进入仓库。

| 层级 | 已验证 | 边界 |
| --- | --- | --- |
| 固件构建 | 自有原厂程序 → 三个 QRC 变换 → 亮度 → 触摸唤醒 → 空闲降亮；最终 SHA 与当前实机完全一致 | 只支持指定原文件，不推断其他版本兼容 |
| 原生指令仿真 | 自动亮度 19,700 个断言；空闲降亮 2,033 个断言；Wi‑Fi helper 锁顺序、释放顺序、寄存器保存与共享错误路径 | Qt/内核边界使用 stub，不等同真实调度 |
| 主题逻辑 | 1,400 透视相机样本、42 种重叠泳圈拖放、8,000 照片动效方案及裁切边界、照片双缓冲、轮播/分页、空闲计时、月相与时区 | Node 状态测试不能证明渲染帧率 |
| 安装事务 | 重定向文件系统中安装成功、启动失败恢复、偏好保留、完整 QML/文件守卫、后续改动阻止回滚、恢复原主题；恶意修改包在停止 UI 前被拒绝 | 使用无二进制内容的假设备，未执行真实进程信号 |
| 通用安装准备 | 当前无线设备只读 doctor；完整本地安装包和 watchdog 变换通过 | 尚未在另一台干净原厂设备端到端首次安装通用安装器 |
| Wi‑Fi 加载器 | 原始、单次试用、启用、上次未确认、哈希异常、加载失败六类隔离场景；开发设备曾做冷启动/重连 | 无多日连续稳定性结论；不解决所有路由/ARP/射频问题 |
| 媒体协议 | 独立 HTTPS 服务管理/播放权限、Host/Origin、限定文件、符号链接拒绝、内容变化；新编译的 ARM64 中继在实机以隔离合成 TLS 源通过 GET、Range、HEAD 和非法请求检查；既有 NAS 照片缩略图、视频播放/暂停/继续、音乐输出已验收 | 新独立服务的 NAS 部署未复用用户已有管理配置；不保证所有格式可解码 |
| 声笺 | 23 个服务/流式测试，部分结果、停止排空、会话取消、认证与载荷边界；发布的识别源码与运行服务仅许可证头不同 | 回归测试用合成音频和 stub；没有通用识别准确率或延迟保证 |
| 无线调试 | 拔除 USB 后同一设备无线 root shell、文件往返、断开重连、屏幕关闭后重连已验证 | 不证明所有路由器/固件都持久开启 TCP ADB |

## 可重复执行

普通源码和协议回归，不需要自己的厂商文件：

```sh
./tools/check.sh
python3 tools/check_release.py
python3 -m pip install -r integrations/voice/requirements-test.txt
python3 -m unittest discover -s integrations/voice -p 'test_*.py'
cd integrations/media && npm ci && npm test
```

本地持有原厂文件后，可构建并执行生成指令的仿真：

```sh
python3 tools/prepare_firmware.py --input /path/to/your/original/QingSnow2App --output .local/build-native
python3 -m venv .local/native-test-venv
.local/native-test-venv/bin/pip install -r driver/requirements-build.txt 'unicorn==2.1.4'
.local/native-test-venv/bin/python tests/native_brightness.py
.local/native-test-venv/bin/python tests/native_idle.py
.local/native-test-venv/bin/python driver/build_patch.py --input /path/to/your/original/skw.ko --output .local/build-driver
.local/native-test-venv/bin/python tests/driver_patch.py
```

输出路径已经存在时构建器会停止；不要用覆盖选项修改仅存备份。在某些 macOS 沙箱下 Unicorn JIT 会被禁止，应在允许本机执行的终端运行离线测试。

## 隔离 Qt 预览

```sh
python3 tools/preview_device.py
```

该开发工具使用自己的固定传感器对象与 Qing.Snow 枚举 stub，重写所有用户配置、媒体、语音和遥控 IPC 路径；不实例化厂商回退页面。逐个运行 Qt `offscreen` / software 场景，不启动第二个 EGLFS UI。为了避免原厂低空闲内存看门狗杀掉正式页面，会短暂暂停已核对父进程与命令路径的原厂 watchdog，并用 trap 和超时保护恢复。前后校验正式 PID、程序和偏好哈希。

这是开发验收工具，需要设备供电和空闲状态；不要与安装、媒体播放或其他设备操作同时执行。生成图片位于 `.local/preview/<ID>/screens/`，只含示例数据。常驻服务或正式页面的实机性能仍应单独验证。

可选的实机中继检查完全使用新生成的测试证书、合成媒体和独立路径，不读取正式 provider 配置：

```sh
python3 tests/media_proxy_device.py --host <本机局域网IP> --serial <目标设备>
```

## 发布检查

`tools/check_release.py` 只遍历可公开树，不读取 `.local/`、模型、密钥或依赖缓存；并检查 Git index，拒绝强制加入被忽略的本地文件。检查包含来源清单、符号链接、厂商产物、未知二进制、个人路径/网络值/硬件标识、凭据模式、图片来源和 EXIF/文本元数据。

修改公开源码后运行 `python3 tools/check_release.py --write-manifest` 更新清单，再正常检查。清单更新不会绕过内容检查。CI 不需要厂商文件、设备或私人服务，不能据 CI 绿色状态声称已完成干净设备安装。
