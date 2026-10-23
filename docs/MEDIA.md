# NAS 照片、视频与音乐

设备通过 Wi‑Fi 直接读取局域网 HTTPS 服务，不依赖 ADB 或 USB。已有兼容网关可以继续使用；仓库也提供一个独立的媒体服务，不要求部署 MacRemote、电视控制或 Friday。

## 1. 在 NAS 准备服务

NAS 需 Node.js 22+、可读的媒体目录。图片预览优先使用现成 Synology 缩略图，或 ImageMagick `convert`；视频封面需要 FFmpeg。独立视频按原文件传输，建议 MP4 / H.264（720p 或更低）+ AAC，音乐优先 MP3。文件后缀可被选择不代表设备有对应解码器；HEIC、HEVC、某些 MKV/FLAC 等格式可能需要自行转换。

把仓库放到 NAS，在 NAS 本机建立独立凭据和 TLS 证书。将下面占位值替换为自己的局域网 IPv4 地址和允许浏览的目录；可以重复指定 `--root`。未列出的目录和符号链接不会被浏览。

```sh
python3 tools/initialize_service.py media \
  --host <NAS局域网IP> --port 6080 \
  --root /volume1/Media \
  --output .local/nas
cd integrations/media
npm ci
npm run build
node server.mjs ../../.local/nas
```

服务只绑定指定的局域网地址。管理页面位于 `https://<NAS局域网IP>:6080/`。证书由自己的实例生成；首次使用需确认并信任自己的证书。管理密钥位于 `.local/nas/admin-token`，只在页面连接时输入，不保存在浏览器存储或 URL 中。播放密钥与管理密钥不同。

如需 Synology Photos 共享相册，可在初始化时增加：

```sh
--photos-origin https://<NAS证书域名>:5001
```

Photos 请求通过所选 NAS 地址连接，并按该域名校验正常 HTTPS 证书。默认只提供文件夹/文件模式；不需要创建公开分享链接。服务应以只具有所选媒体读取权限的账户运行，不需要 DSM 管理员身份。

## 2. 为设备配置媒体

将 NAS 的 `.local/nas/` 中这三份文件通过自己的安全方式复制到电脑的私有目录：`origin`、`server.pem`、`auth-header`。**不要复制 `server.key`、`admin-token` 或整份目录到设备。** 它们只属于 NAS 服务。

在电脑的仓库根目录运行：

```sh
python3 tools/configure.py media --private .local/my-nas-client
```

该命令编译本地环回中继，安装媒体工作脚本与启动入口，将 TLS 公钥及独立播放凭据放入设备私有目录 `/userdata/cgs2-media/`，不会覆盖 Micro 的配对目录。默认拒绝覆盖已有配对；确实要切换现有服务时使用 `--replace`，旧文件会备份在设备 `/userdata/cgs2-provider-backups/<ID>/`。先关闭设备上的媒体和遥控页面。此命令不会更改 NAS 服务或其他项目的网关。

## 3. 在设置页面选择

输入管理密钥并连接后，可以：

- 选择照片文件夹，按需包含子文件夹。
- 从同一浏览器单独选择视频和音乐文件，无需把它们加入相册。
- 选择 3–60 秒的轮播间隔，启用后保存。
- 配置了 Photos 服务时，也可切换到已有的共享相册。

设备主菜单分别提供“相册”“视频播放”“音乐播放”，每个页面只列出对应类型。照片支持前后切换与随机轮播，视频和音乐支持播放/暂停。视频默认静音，点“静音”可开启声音；音乐默认开启声音。文件夹轮播在整份照片列表中随机选取，使用打乱袋避免一轮内重复，并跨分页预热；旧版 Photos 服务按分页打乱；只有一张照片时保留当前画面。下一张在当前停留期选定并下载，并用两个图像缓冲区提前解码；网络尚未完成时保留当前图片，避免加载 Toast 和黑帧。切换无音效。照片平移与缩放按比例和随机种子选择，宽图更常横移。

视频和音乐通过设备本地 `127.0.0.1:6097` 中继转发到认证 HTTPS，支持单段 Range 和 HEAD；该中继不在局域网监听，也不接受任意 URL。解码与声音输出仍由 CGS2 自己完成。硬件扬声器已通过开发设备的可听播放验证，音量在播放界面控制。

夜间息屏或离开媒体时会停止轮播/播放并释放任务。大照片必须先生成合适预览；网络、NAS 缩略图、格式与设备性能都会影响切换延迟。不要把 ADB、媒体端口或管理页面转发到公网。

## Live Photo

文件夹模式保留原片与同名 `.MOV` / `.mov`，服务会核对照片 Apple MakerNote 的内容标识与 QuickTime 的内容标识；仅文件名相同不会被当作 Live Photo。[Apple 的配对说明](https://developer-rno.apple.com/videos/play/wwdc2016/501/)。

随机轮播遇到已识别的 Live Photo 时，先显示照片，在后台准备动态，播放结束后再切下一张。动态默认静音，可以开启声音；暂停轮播会暂停当前动态，离开页面或息屏会停止播放。转换失败则保留照片，按普通照片间隔继续轮播。普通照片仍使用设置的 3–60 秒停留时间。

原始 iPhone 动态通常是高分辨率 HEVC，NAS 需提供带 HEVC 解码、`libx264` 和 AAC 编码的 FFmpeg。服务只为配对动态生成最长 15 秒、适配 720×720 以内的 H.264/AAC 兼容短片，保留原片不改写。NAS 最多保留 8 份转换缓存，设备最多缓存 2 份；切换下一张时先预取对应短片。首个未缓存动态可能需要准备时间。

服务优先查找配置目录相邻 `runtime/cgs2-tools/ffmpeg`，其次使用系统 FFmpeg。请从可信发行渠道安装符合 NAS 架构的版本并核对其许可证；仓库不包含 FFmpeg 二进制文件。[FFmpeg 下载与许可](https://ffmpeg.org/download.html)。现成 JPEG 缩略图仍用于 HEIC 的静态预览。

Photos 共享相册模式可使用其接口提供的 `live` 项和 H.264 兼容预览；具体可用性取决于 NAS 版本及预览是否生成。文件夹配对和 Photos 接口提供的动态是两条独立路径。

## 现有服务

`device/micro-client.sh` 与 `S97cgs2-micro` 保留已有 Micro 协议客户端，使用独立配置和连接状态；独立媒体服务不提供远程桌面或 Micro 命令路由。ARL 适配器不在此仓库内。已有部署的配置不会被基础表盘安装器覆盖。
