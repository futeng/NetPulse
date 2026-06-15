# NetPulse

NetPulse 是一款原生 macOS 菜单栏网络检测工具，面向差旅、VPN、多代理和复杂办公网络场景。它通过真实 HTTP 请求检测文字、图片、视频 CDN 与 API，帮助定位“网站能打开，但图片或视频加载失败”这类普通连通性测试难以发现的问题。

<p align="center">
  <img src="docs/images/netpulse-mascot.png" width="220" alt="NetPulse 网络水獭吉祥物">
</p>

![NetPulse 主面板](docs/images/netpulse-dashboard.png)

## 极低资源占用

NetPulse 使用原生 SwiftUI 和按需检测机制。空闲时只保留菜单栏状态与休眠中的调度任务，不运行持续轮询服务；到达设定周期后才并发完成少量网络采样，保存本地结果后立即重新休眠。视频检测只读取小范围数据，不会下载完整视频，因此日常后台运行对 CPU、网络流量和电量的影响极小。

## 网络水獭

NetPulse 使用“网络水獭”作为应用吉祥物。应用图标中的脉冲球保留心跳线，并加入经纬网、连接节点和 Wi-Fi 标记，用来同时表达网络连接与实时健康检测。

菜单栏使用专门为小尺寸设计的单色网络状态图标：

- 网络健康：无线脉冲。
- 响应异常：警告符号。
- 网络不可用：断开连接。
- 正在检测：刷新符号。状态切换不使用持续动画，避免后台额外占用。

## 功能

- 并发检测 Google、X、ChatGPT/OpenAI 及自定义服务。
- 分别检测文字、图片、视频 CDN 和 API。
- 展示成功率、丢失率、中位数、P95 和最慢耗时。
- 展开查看 DNS、TCP、TLS、首包和请求总耗时。
- 识别 Shadowrocket TUN/Fake-IP 的 `198.18.0.0/15` 虚拟地址。
- 支持服务分组、目标启停、自定义目标和目标置顶。
- 支持 1、5、15、30 分钟快捷周期及 1–1440 分钟自定义周期。
- 支持 macOS 异常通知、恢复通知和登录启动。
- 本地保留最近 50 次检测历史。

## 系统要求

- macOS 13 或更高版本
- Xcode Command Line Tools
- Swift 5.10 或更高版本

## 安装

### GitHub Release

每个版本标签会通过 GitHub Actions 自动生成：

```text
NetPulse-<版本>-universal.dmg
NetPulse-<版本>-universal.dmg.sha256
```

Universal DMG 同时支持 Apple Silicon 与 Intel Mac。下载 DMG、双击打开，再把 `NetPulse.app` 拖入“应用程序”即可。

当前项目没有付费 Apple Developer 证书，因此 Release 使用 **ad-hoc 临时签名，未经过 Apple 公证**。首次启动时：

1. 在 Finder 的“应用程序”中按住 Control 点击 NetPulse。
2. 选择“打开”，再次确认。
3. 如果仍被阻止，请打开“系统设置 → 隐私与安全”，找到 NetPulse 后点击“仍要打开”。

这一步只需要执行一次。具体限制和原因见 [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md)。

### 从源码安装

构建当前 Mac 对应架构并安装到 `~/Applications`：

```bash
./scripts/install_netpulse_app.sh
```

仅构建当前架构：

```bash
./scripts/build_netpulse.sh
```

构建指定架构或 Universal 应用：

```bash
./scripts/build_netpulse.sh arm64
./scripts/build_netpulse.sh x86_64
./scripts/build_netpulse.sh universal
```

生成本地 Universal DMG：

```bash
./scripts/build_release_dmg.sh universal
```

构建产物位于 `dist/NetPulse.app`。安装后可从菜单栏打开，也可运行：

```bash
open netpulse://dashboard
```

首次启动后，请在 macOS“系统设置 → 通知 → NetPulse”中允许通知。

从早期测试版本升级时，由于 Bundle ID 已统一为 `com.ftpai.futeng.NetPulse`，macOS 会把它视为新的应用身份。原有检测目标和历史仍会保留，但通知权限与“登录时启动”需要重新确认一次。

## 使用

主面板直接展示当前检测结果：

- 顶部标签按“服务分组”筛选，例如 Google、X、OpenAI。
- 点击目标行右侧图钉可置顶；置顶目标会优先显示并使用浅色背景区分。
- 点击目标行或展开按钮查看分阶段耗时与路由信息。
- 右上角周期菜单可选择快捷周期、自定义周期或关闭定时检测。
- 列表工具栏最右侧可打开检测历史和配置。

添加检测目标时：

| 字段 | 列表中的作用 |
|---|---|
| 服务分组 | 生成顶部筛选标签，并标识目标所属服务 |
| 目标名称 | 显示为检测列表主标题 |
| 内容类型（图标） | 选择文字、图片、视频、API 或自定义图标 |
| 域名或 URL | 实际发起网络检测的地址 |

已有目标可在“配置 → 检测目标”中点击目标信息编辑。每行仅保留置顶和更多操作；启用、停用与删除位于更多菜单。编辑时可以修改服务分组、名称、内容类型、地址、启用状态和置顶状态；内置目标同样开放编辑并保留其专业检测判定规则。恢复操作位于顶部的更多菜单。

默认策略：

- 每 5 分钟检测一次。
- 每个目标采样 3 次。
- 单次请求超时 5 秒。
- 同类异常 30 分钟内不重复通知。

### 性能分级

| 等级 | P95 总耗时 |
|---|---:|
| 优秀 | `< 300ms` |
| 良好 | `300–799ms` |
| 偏慢 | `800–1499ms` |
| 很慢 | `>= 1500ms` |

任何采样失败或超时会优先标记为“不稳定”；全部采样失败则标记为“不可用”。

## 开发

运行测试：

```bash
swift test --package-path NetPulse
```

项目结构：

```text
NetPulse/
  Package.swift
  Resources/Info.plist
  Sources/NetPulse/
  Tests/NetPulseTests/
docs/ARCHITECTURE.md
docs/DISTRIBUTION.md
scripts/build_netpulse.sh
scripts/build_release_dmg.sh
scripts/install_netpulse_app.sh
```

架构和数据流说明见 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)。

### Intel Mac

可以直接在 macOS 13 或更高版本的 Intel MacBook 上克隆项目并运行：

```bash
./scripts/install_netpulse_app.sh
```

脚本会通过 `uname -m` 自动选择 `x86_64`。在 Apple Silicon Mac 上也可以交叉编译 Intel 版本，项目已验证能够生成 Mach-O `x86_64` 可执行文件。

### 创建 Release

推送符合 `v*` 格式的标签即可触发 Universal DMG 发布：

```bash
git tag v1.0.0
git push origin v1.0.0
```

## 数据与隐私

- 配置和历史保存在 `~/Library/Application Support/NetPulse/`，不会写入代码仓库。
- `198.18.x.x` 和 `198.19.x.x` 是代理软件使用的保留虚拟地址，不是本机公网 IP。
- 检测会对目标发起少量真实请求；视频目标仅读取小范围数据，不下载完整视频。
- 项目不收集遥测数据，不包含第三方消息推送或云端账号凭据。
- Bundle ID：`com.ftpai.futeng.NetPulse`。

## 开源许可

NetPulse 使用 [MIT License](LICENSE)。
