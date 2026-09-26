# Agent Computer Use 开源版

一个**单文件、无状态的 Windows 桌面自动化命令行工具**，专为 AI Agent 操控电脑而设计，人从终端用也一样。

`desktop.ps1` 给 Agent 提供"电脑操控"的四类原语：**看**（全屏/窗口/区域截图）、**指**（真实像素坐标的移动/点击/滚轮）、**写**（键盘、剪贴板、UIA 直接赋值）、**读控件树**（UI Automation）。无常驻进程、无安装步骤、零第三方依赖——每条命令都是一次性的 `powershell -File` 调用，整个工具可审计、不会卡死在后台状态。

> English version: [README.md](README.md)

## 设计取舍

- **刻意无状态。** 每次调用新起一个 PowerShell 进程（约 0.3–0.6 秒）。比常驻宿主慢，但没有会泄漏、会崩溃、难调试的后台进程。出错时，全部信息就在这一条命令的 stdout 和退出码里。
- **默认带守卫。** 按键物理上永远落在"当前焦点窗口"上，所以 `type` / `keys` / `paste` / `paste-file` 带 `--to <sel>` 时，会**先校验目标确实拿到了前台，才发第一个键**；校验不过直接 `ERROR` + 退出码 1，一个键都不发（`--force` 可跳过，退回旧行为）。这条规则来自真实事故：`SetForegroundWindow` 可能被系统前台锁静默拒绝，盲发的按键落进了别的程序。
- **有审计。** 每条实际执行的 act/text/clipboard/uia-settext 命令向 `shots/actions.log` 追加一行：UTC 时间戳、命令、参数、解析到的目标。只记文件**路径**，绝不记剪贴板内容和文件正文。
- **DPI 安全。** 读取任何坐标前先执行 `SetProcessDPIAware()`。少了这句，Windows 会按显示缩放比例虚拟化所有数值（150% 缩放下，2100×1350 的窗口会被读成 1400×900），截图裁切、点击偏移。
- **源码纯 ASCII。** PowerShell 5.1 会把无 BOM 的 UTF-8 脚本按 ANSI 误读，所以脚本里没有任何非 ASCII 字面量。中文等非 ASCII 文本一律通过 `paste <file>` 或 `uia-settext <sel> <name> <file>` 从外部 UTF-8 文件进入。

## 环境要求

- Windows 10/11，PowerShell 5.1（系统自带）或更高
- 不需要任何模块、包、安装步骤

## 快速上手

```powershell
# 现在屏幕上有什么？
powershell -ExecutionPolicy Bypass -File desktop.ps1 wins

# 给某个窗口截图（标题子串或数字 PID 都行）
powershell -ExecutionPolicy Bypass -File desktop.ps1 win notepad shot.png

# 在绝对屏幕坐标点击
powershell -ExecutionPolicy Bypass -File desktop.ps1 click 800 500

# 发 Ctrl+S —— 但只有目标确实在前台时才发
powershell -ExecutionPolicy Bypass -File desktop.ps1 keys --to notepad "^s"

# 输入中文：写进 UTF-8 文件再粘贴（剪贴板用后会恢复原样）
powershell -ExecutionPolicy Bypass -File desktop.ps1 paste --to notepad .\samples\selftest.txt

# 往聊天类应用发文件：文件进剪贴板（FileDrop）+ Ctrl+V
powershell -ExecutionPolicy Bypass -File desktop.ps1 paste-file --to "MyChatWindow" C:\path\to\file.zip
```

## 窗口选择器 `<sel>`

- **数字 PID** 只按进程号匹配。该进程有多个顶层窗口时（主窗口 + 模态对话框），**当前持有前台的那个优先**（`pick=fg`），否则取面积最大的非最小化窗口（`pick=largest`）。
- 其他字符串按**标题子串**匹配（不区分大小写）。
- 子串本身是纯数字时，加 `t:` / `title:` 前缀显式声明按标题匹配。
- 最小化窗口（坐在 −32000,−32000）只在没有别的匹配时才用。

## 命令一览

### 读取（read）
| 命令 | 说明 |
|---|---|
| `shot [outPath]` | 整屏（虚拟屏全范围）截图 |
| `win <sel> [outPath]` | 窗口截图 |
| `rect <x> <y> <w> <h> [outPath]` | 区域截图 |
| `wins` | 列出可见窗口（pid、矩形、标题） |
| `info <sel>` | pid / 句柄 / 窗口与客户区矩形 / 是否最小化 / 是否前台 |
| `rect-of <sel>` | 只输出 `x y w h`，方便算相对坐标 |
| `cursor` | 当前光标位置 |
| `wait-win <sel> <timeoutSec>` | 轮询等窗口出现 |
| `wait-gone <sel> <timeoutSec>` | 轮询等窗口消失（对话框关闭等） |

### 操作（act，绝对屏幕坐标）
| 命令 | 说明 |
|---|---|
| `move` / `click` / `rclick` / `dblclick` | 光标与按键 |
| `wheel <amount> [x y \| --at <sel>]` | 滚轮（负数向下）；可先把光标移到指定坐标或某窗口中心 |
| `relclick <sel> <dx> <dy>` | 相对窗口左上角点击，与 `win` 截图坐标系一致，窗口挪了也不用重算 |

### 文本（text，永远回报目标与实际前台的对账）
| 命令 | 说明 |
|---|---|
| `focus <sel>` | 还原并置前，回显 `fg_ok=True/False` |
| `type [--to <sel>] <文本...> [--force]` | ASCII 文本（SendKeys，特殊字符自动转义） |
| `keys [--to <sel>] <spec> [--force]` | 原始 SendKeys：`^s`、`%{F4}`、`{ENTER}` |
| `paste [--to <sel>] <file> [--force]` | UTF-8 文件 → 剪贴板 → Ctrl+V；事后恢复原剪贴板（文本和文件列表都支持） |

### 剪贴板（clipboard）
| 命令 | 说明 |
|---|---|
| `copy-file <path>` | 文件以 FileDrop 格式上剪贴板，自带验证；刻意保留不恢复（产物就是要粘的东西） |
| `paste-file [--to <sel>] <path> [--force]` | copy-file + 前台守卫 + Ctrl+V + 剪贴板恢复 |

### UI 自动化（uia，仅当目标应用暴露无障碍树）
| 命令 | 说明 |
|---|---|
| `uia-tree <sel> [maxDepth]` | 控件树 dump（头部注明实际扫描的窗口句柄） |
| `uia-find <sel> <nameSub> [typeRe]` | 按名字/类型搜索元素 |
| `uia-click <sel> <nameSub>` | 优先 InvokePattern，失败回退点元素中心 |
| `uia-focus <sel> <nameSub>` | SetFocus |
| `uia-settext <sel> <nameSub> <file>` | ValuePattern 直接写入 UTF-8 文件内容并回读校验——不经键盘、不经剪贴板 |

UIA 的根按**所选窗口的句柄**解析，与主窗口同 PID 的对话框可以被精确寻址。

退出码：`0` 成功，`1` 失败（stdout 输出 `ERROR: <原因>`）。

## 已知限制（都是踩出来的）

1. **Chromium 壳应用**（Electron/Tauri 系的编辑器、聊天客户端）的无障碍树常常只暴露到 `Pane` 一层，`uia-*` 无效，只能截图 + 坐标。
2. **"窗口置前"不等于"输入框有焦点"。** 往 Chromium 输入框粘贴，要先 `relclick` 点进输入框再 `paste`。判断成没成要看截图，不能只看命令回显。
3. **Windows 通用文件对话框**的"文件名"框是一个不暴露任何可写 UIA 模式的 `Pane`，`uia-settext` 会如实报错并提示回退 `click` + `paste`。
4. **`SetForegroundWindow` 有前台锁**——后台进程有时抢不到焦点（Windows 只闪任务栏）。守卫把这种静默失败变成响亮的 `ERROR`，而不是让按键落进无辜程序。向桌面（`Program Manager`）发键尤其容易触发，这是系统行为不是 bug。
5. **单实例应用**（如 Win11 记事本会在既有进程里开标签页）：`Start-Process` 返回的 PID 可能没有顶层窗口，用 `wins` 找真正的。
6. 按键是物理输入——**Agent 操作期间人别碰鼠标键盘**；执行不可逆动作（发消息、删除）前，Agent 应当用截图确认目标窗口。

## 目录结构

```
desktop.ps1            # 工具的全部
samples/selftest.txt   # 验证中文粘贴路径用的样本
shots/                 # 运行时目录（gitignored）：默认截图输出 + actions.log 审计日志
```

## 许可

MIT — 见 [LICENSE](LICENSE)。
