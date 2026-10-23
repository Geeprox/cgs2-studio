# 安装、备份与恢复

## 支持范围

设备必须是 Linux/Qt 版青萍 CGS2，固件 `4.5.6_0167`、内核 `4.19.232`、架构 `aarch64`，且已有可用 root ADB。ADB 显示的 Nexus 4 / mako 是固件标识，不表示它是 Android 手机。此项目不提供其他机型的刷机包，也不负责开启或破解调试权限。

| 本地输入 | SHA‑256 |
| --- | --- |
| 原厂 QingSnow2App | `1c6043a24298812401fd45678ef5c1869a9f36815330fab32ef9da8107c918ac` |
| 原厂 skw.ko | `ec8916437220d062470f082f09e77c2c7ff0e2b596418aae1448be451f016f9b` |
| 本版本生成程序 | `91e0fc422f77f70e024bf9571a5bc395849eaeeb21c7c2a3c3973a49d8d7d8b7` |
| Wi‑Fi 修复生成模块 | `d88d8f8e807162a681201d04391b38cac139239b23f035e97d909547f1ee2ffa` |

主机建议 macOS / Linux，Python 3.10+、ADB、clang。`clang -target aarch64-linux-gnu` 需能汇编 ARM64；macOS Xcode Command Line Tools 和 Linux clang 可用。Windows 可通过有设备访问权限的 Linux 环境运行，但未验证。

## 安装表盘

1. 先通过 USB 连接供电，确认 `adb devices` 中只有目标设备。多设备或同一设备同时有 USB/Wi‑Fi 连接时，用 `--serial <目标>` 明确选择。
2. 在仓库根目录运行只读检查：

   ```sh
   python3 tools/device.py
   ```

   输出必须是受支持的 CGS2、内核和 root 状态。脚本不打印设备标识或读取网络凭据。
3. 可先只准备安装包，设备不会被写入：

   ```sh
   python3 tools/install.py --prepare-only
   ```

4. 正式安装：

   ```sh
   python3 tools/install.py
   ```

   安装器从当前原厂设备读取程序和 watchdog，校验后在 `.local/install/<ID>/` 生成完整补丁和原生回退 QML。在设备 `/userdata/cgs2-studio-backups/<ID>/` 备份被管理的文件和原 QML，再原子替换。活动媒体、遥控或语音会话、空间不足、未知文件、符号链接和内容变化都会阻止操作。安装期间保持供电和 ADB 连接。

   新程序启动后需保持同一进程至少 14 秒，并通过可执行文件哈希检查。失败时自动恢复已替换文件、原 QML 和 watchdog。成功输出备份 ID 和回滚命令。此项证明启动稳定，不代替触摸、传感器及长期稳定性验收。

5. 在主菜单打开表盘选择，检查 14 款主题、传感器、触摸和夜间息屏设置。媒体和语音默认未配置，可独立添加。

已经安装本项目的设备不会被当作原厂输入二次打补丁。提供自己的原始文件：

```sh
python3 tools/install.py --firmware .local/firmware/QingSnow2App.original
```

可以只运行构建器，无需连接设备：

```sh
python3 tools/prepare_firmware.py \
  --input /path/to/your/original/QingSnow2App \
  --output .local/build-native
```

输出包含厂商内容，**仅供本地使用**。构建器生成表盘入口、Wi‑Fi 空列表控制、亮度、触摸唤醒和空闲降亮补丁，最终结果必须与上表匹配。

## 回滚表盘

使用安装成功时输出的 ID：

```sh
python3 tools/rollback.py --backup <32位备份ID>
```

回滚会先校验安装后的所有管理文件及完整 QML 清单。后续有人修改过这些文件时会停止，避免覆盖新修改。确认自己已关闭媒体、遥控和语音，再回滚。原偏好、网络配置和传感器数据库始终不被恢复脚本改写。

若 UI 无法启动但 ADB 仍可用，可直接执行设备上的同一回滚脚本：

```sh
adb shell /bin/sh /userdata/cgs2-studio-backups/<ID>/rollback-ui.sh <ID>
```

若哈希守卫拒绝，先把对应备份和当前文件复制到自己的电脑排查；不要删除保护条件、套用其他固件地址或覆盖配置。保留 USB 连接和备份，直到确认恢复正常。

## 单独试用 Wi‑Fi 修复

详细原因见 [driver/README.md](../driver/README.md)。驱动只修复已定位的锁顺序反转，不承诺修复所有断联原因。

```sh
python3 -m venv .local/driver-venv
.local/driver-venv/bin/pip install -r driver/requirements-build.txt
.local/driver-venv/bin/python tools/wifi.py install
```

`install` 只接受原始加载器，读取自己的原模块、在本机生成候选模块，再把它放入 `/userdata/cgs2-wifi-rea/`，保留原加载器。**不卸载正在使用的驱动、不覆盖 `/system/lib/modules/skw.ko`、不自动重启。** 保留 USB 连接，手动重启进入单次试用：

```sh
adb reboot
python3 tools/wifi.py status
```

确认实际重新连接、状态显示 `trial loaded`，并检查传感器和页面后，可启用后续启动：

```sh
python3 tools/wifi.py enable
```

未执行 `enable` 时，下次启动使用原始模块。启用后每次启动设定待确认标记；90 秒后只有 UI 进程存在且 Wi‑Fi 完成连接才清除标记。若一次启动未确认，**下一次启动**回退原模块；不会自动重启解救当前一次卡住的启动。

恢复原加载器：

```sh
python3 tools/wifi.py rollback
adb reboot
```

## 无线 ADB

媒体播放不依赖 ADB。无线 ADB 仅用于维护；设备和电脑需在受信任的同一局域网，设备持续供电。

若当前固件已经在 TCP 5555 监听：

```sh
adb connect <设备局域网IP>:5555
python3 tools/device.py --serial <设备局域网IP>:5555
```

若未监听，可在 USB 已可用时尝试 `adb tcpip 5555`，再连接设备 IP。不同固件启动脚本可能不会持久保留这个模式；该命令也可能令原连接重连。本项目不默认开启它。拔 USB 后再次运行只读检查，并用 `adb -s <IP>:5555 shell uname -r` 验证。不要把端口暴露到公网；这是旧式 TCP ADB，不是 Android 11 的无线配对机制。
