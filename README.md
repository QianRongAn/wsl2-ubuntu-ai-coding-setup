# WSL2 + Ubuntu + Claude Code(DeepSeek) 一键配置工程

一套在 Windows 11 上从零搭建 WSL2 开发环境、并把 DeepSeek API 接入 Claude Code CLI 的可复现方案。

本仓库记录的**不是理论步骤**，而是一次真实排障过程的完整沉淀：目标机器存在微软商店 CDN 被屏蔽、WSL 仅为 inbox stub、注册表残留孤儿登记等多重障碍，所有脚本都是在解决这些真实问题后成型的。

---

## 目录

- [1. 项目解决什么问题](#1-项目解决什么问题)
- [2. 目录结构](#2-目录结构)
- [3. 目标环境实测数据](#3-目标环境实测数据)
- [4. 完整流程总览](#4-完整流程总览)
- [5. 阶段一：安装 WSL2 + Ubuntu](#5-阶段一安装-wsl2--ubuntu)
- [6. 阶段二：创建 UNIX 账号](#6-阶段二创建-unix-账号)
- [7. 阶段三：安装 Claude Code CLI](#7-阶段三安装-claude-code-cli)
- [8. 阶段四：接入 DeepSeek API](#8-阶段四接入-deepseek-api)
- [9. 阶段五：验证](#9-阶段五验证)
- [10. 脚本功能详解](#10-脚本功能详解)
- [11. 排障手册](#11-排障手册)
- [12. 安全须知](#12-安全须知)
- [13. 使用手册（装好之后怎么用）](#13-使用手册装好之后怎么用)
- [14. 推广素材](#14-推广素材)

---

## 1. 项目解决什么问题

在 Windows 上配置 WSL2 开发环境时，常规教程（`wsl --install` 一条命令搞定）在以下情况会直接失败：

| 障碍 | 表现 | 本项目对策 |
|---|---|---|
| 微软商店 CDN 不可达 | `wsl --update` 报 **403 已禁止** | 改用 GitHub 的 `--web-download`，或本地 MSI 离线安装 |
| 仅有 inbox 版 WSL | 任何 wsl 命令都提示"**必须更新到最新版本**" | 捆绑现代 WSL 安装包（MSI），脚本自动用 msiexec 安装 |
| 注册表残留孤儿登记 | 显示已装 Ubuntu 但实际目录不存在 | 仅在 BasePath 确实缺失时清理，避免误删数据 |
| PowerShell 中文编码 | `.ps1` 中文变乱码 → **ParserError**，整脚本不执行 | 全部脚本强制 ASCII-only |
| wsl.exe 写 stderr | 配合 `ErrorActionPreference=Stop` 变成终止异常 | 对原生命令统一降级为 Continue，且不重定向 stderr |

---

## 2. 目录结构

```
wsl-ubuntu-setup/
├── README.md                        ← 本文档
├── .gitignore                       ← 排除大文件与含密钥配置
├── scripts/
│   ├── 01-install-wsl-ubuntu.ps1    ← Windows 管理员执行：装 WSL + Ubuntu
│   ├── 02-setup-claude.sh           ← WSL 内执行：Node.js + Claude Code + DeepSeek 配置
│   ├── 03-verify.sh                 ← WSL 内执行：逐项自动化验证
│   └── 04-verify.ps1                ← Windows 执行：概览验证
├── config/
│   └── deepseek-settings.example.json   ← DeepSeek 配置模板（Key 为占位符）
├── docs/
│   └── USAGE.md                     ← 装好之后怎么用 Claude Code（日常手册）
└── promo/
    ├── repo-promo.html              ← 推广图 HTML 源（改文案后可重新渲染）
    ├── repo-promo.png               ← 推广图成品（2880×1520）
    ├── xiaohongshu.md               ← 小红书文案（含标题备选 + 配图建议）
    └── xiaohongshu.txt              ← 小红书文案纯文本版（可直接复制）
```

> **WSL 安装包不在仓库内**：`wsl.2.7.14.0.x64.msi` 有 247MB，超过 GitHub 单文件 100MB 上限，需自行下载（见 [5.2](#52-准备-wsl-安装包))。

---

## 3. 目标环境实测数据

以下均为真实探测结果，可作为判断自身环境是否适用的参照：

| 项目 | 实测值 |
|---|---|
| 系统 | Windows Build 26220 / 25H2 |
| `Microsoft-Windows-Subsystem-Linux` | Enabled |
| `VirtualMachinePlatform` | Enabled |
| `HypervisorPlatform` | Enabled |
| `System32\wsl.exe` | 10.0.26100.8875（**inbox stub**） |
| `C:\Program Files\WSL` | 安装前**不存在** |
| 微软商店 CDN | 不可达（TLS SNI 干扰 / 403） |
| GitHub | API 可直连；release 资产需走代理 |
| 本机代理 | Clash `127.0.0.1:7890`，系统代理已开启 |

**装成后的终态：**

| 项目 | 值 |
|---|---|
| WSL | `C:\Program Files\WSL\wsl.exe` = **2.7.14.0** |
| 发行版 | Ubuntu（默认，带 `*`） |
| WSL 版本 | **Version = 2** |
| 磁盘镜像 | `ext4.vhdx` 约 1.4 GB |
| 系统 | Ubuntu 26.04.1 LTS |
| 内核 | `6.18.33.2-microsoft-standard-WSL2` |
| UNIX 用户 | `DefaultUid = 1000`（普通用户，非 root） |

---

## 4. 完整流程总览

```
┌─ 阶段一 ─ Windows（管理员 PowerShell）
│   01-install-wsl-ubuntu.ps1
│     ├─ 1/7 检查 Windows 版本
│     ├─ 2/7 校验三项 Windows 功能（缺失则启用并提示重启）
│     ├─ 3/7 安装现代 WSL（本地 MSI → --web-download → 微软 CDN 三级回退）
│     ├─ 4/7 清理孤儿 Lxss 登记（仅当 BasePath 不存在）
│     ├─ 5/7 设置默认 WSL 版本 = 2
│     ├─ 6/7 安装 Ubuntu（--web-download 优先）
│     ├─ 7/7 设为默认发行版
│     └─ 附  写入 %USERPROFILE%\.wslconfig
│
├─ 阶段二 ─ 新终端执行 wsl -d Ubuntu
│     创建 UNIX 用户名 / 密码
│
├─ 阶段三 ─ WSL 内执行 02-setup-claude.sh
│     nvm + Node LTS → npm 镜像 → npm i -g @anthropic-ai/claude-code
│
├─ 阶段四 ─ 同上脚本自动完成
│     写入 ~/.claude/settings.json + 预置 onboarding
│
└─ 阶段五 ─ 03-verify.sh / 04-verify.ps1
       版本 → 配置 → 网络 → 端到端真实调用
```

---

## 5. 阶段一：安装 WSL2 + Ubuntu

### 5.1 前置条件

- Windows 10 2004+ 或 Windows 11
- **管理员权限**
- 若网络受限（微软 CDN 403），需准备可用的代理，并确保节点能访问 GitHub

### 5.2 准备 WSL 安装包

脚本优先使用同目录下的本地 MSI。下载最新版：

```
https://github.com/microsoft/WSL/releases
```

取 `wsl.<版本>.0.x64.msi`（本工程验证版本：**2.7.14**，247MB）。

**网络技巧**：若直连 GitHub 缓慢，检查本机代理地址后显式指定，例如 Clash 默认端口：

```bash
curl -L -x http://127.0.0.1:7890 -o wsl.2.7.14.0.x64.msi \
  https://github.com/microsoft/WSL/releases/download/2.7.14/wsl.2.7.14.0.x64.msi
```

> 没有本地 MSI 时脚本会自动尝试在线安装，不阻断流程。

### 5.3 执行

以**管理员身份**打开 PowerShell：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
& ".\scripts\01-install-wsl-ubuntu.ps1"
```

### 5.4 验证

```powershell
wsl -l -v
```

期望：

```
  NAME      STATE      VERSION
* Ubuntu    Stopped    2
```

两个关键点：`VERSION` 为 **2**（是 WSL2 不是 WSL1）；`Ubuntu` 行首有 `*`（默认发行版）。

### 5.5 如何不跑 wsl 命令判断安装状态

当 wsl 命令不可用时，可直接查注册表与磁盘：

```powershell
Get-ChildItem 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss' |
  ForEach-Object { Get-ItemProperty $_.PSPath }
```

| 字段 | 含义 |
|---|---|
| `State = 1` | 已安装 |
| `Version = 2` | WSL2（1 则为 WSL1） |
| `DefaultUid` | `0` = 尚无用户（root）；`1000` = 已建普通用户 |
| `BasePath` | 实际磁盘位置，现代 WSL 为 `AppData\Local\wsl\{guid}` |

配合检查 `BasePath` 下的 `ext4.vhdx` 是否存在及其大小，即可完全判断安装真伪。

---

## 6. 阶段二：创建 UNIX 账号

脚本用了 `--no-launch`，发行版装好但未启动过，因此 **UNIX 账号尚未创建**（此时 `DefaultUid = 0`）。

新开终端：

```powershell
wsl -d Ubuntu
```

依次输入：

```
Enter new UNIX username: dev
New password: ******
Retype new password: ******
```

> 该账号是 WSL 内部账号，与 Windows 账号无关，`sudo` 用的就是它。
> 忘记密码：`wsl -d Ubuntu -u root` 进 root 后 `passwd <用户名>` 重置。

**验证：** 出现形如 `dev@主机名:~$` 的提示符，且 `uname -r` 含 `WSL2`。

> 若提示符显示 `/mnt/c/WINDOWS/system32`，是因为从该目录启动的。执行 `cd ~`，
> 或在 Windows Terminal 把 WSL 配置文件的"起始目录"设为 `~`。

---

## 7. 阶段三：安装 Claude Code CLI

在 Ubuntu 内执行（脚本内 `KEY` 需自行提供）：

```bash
DEEPSEEK_API_KEY='sk-你的密钥' bash scripts/02-setup-claude.sh
```

脚本按顺序完成：

1. `apt-get update/upgrade` + 安装 `curl git jq xz-utils build-essential`
2. 安装 **nvm**，通过它安装 Node.js **LTS**（二进制走 npmmirror 镜像）
3. npm registry 设为 `https://registry.npmmirror.com`
4. `npm install -g @anthropic-ai/claude-code`
5. 写入 `~/.claude/settings.json`
6. 预置 `~/.claude.json` 跳过首次交互向导
7. 拉取 DeepSeek 模型列表核对模型名

**手动等价命令：**

```bash
npm install -g @anthropic-ai/claude-code
claude --version
```

---

## 8. 阶段四：接入 DeepSeek API

### 8.1 配置文件

路径：`~/.claude/settings.json`（权限 600）

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "<你的 DeepSeek API Key>",
    "ANTHROPIC_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "deepseek-v4-pro[1m]",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "deepseek-v4-flash[1m]",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "CLAUDE_CODE_EFFORT_LEVEL": "max"
  }
}
```

### 8.2 字段含义

| 字段 | 作用 |
|---|---|
| `ANTHROPIC_BASE_URL` | DeepSeek 的 Anthropic 协议兼容端点，固定值 |
| `ANTHROPIC_AUTH_TOKEN` | DeepSeek API Key（`sk-` 开头） |
| `ANTHROPIC_MODEL` | 默认主模型 |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | 重型档（复杂架构、疑难 bug） |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | 均衡档（日常写业务代码） |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | 轻量档（简单脚本、补全） |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | 关闭非必要遥测 |
| `CLAUDE_CODE_EFFORT_LEVEL` | 推理强度，`max` 为最高 |

三档模型字段只是给 Claude Code 的三档绑定具体模型，可自由换成平台上已开通的任意模型。

### 8.3 实测记录（重要）

这些结论是真实发请求验证过的，不是照抄文档：

| 校验项 | 结果 |
|---|---|
| Key 有效性 | `GET /user/balance` → `is_available=true`，余额 ¥9.95 |
| `POST /anthropic/v1/messages` | **HTTP 200**，正常返回 |
| `deepseek-v4-pro[1m]` | 200 |
| `deepseek-v4-flash[1m]` | 200 |
| `deepseek-v4-pro` / `deepseek-v4-flash` | 200 |
| `deepseek-flash[1m]` / `deepseek-flash` | 200 |

**两个易踩的坑：**

1. `GET https://api.deepseek.com/models` 只返回 `deepseek-v4-pro` 和 `deepseek-flash` 两个基础 ID，**不含 `[1m]` 变体**；但带 `[1m]` 的写法在 Anthropic 兼容端点确实可用，不要因此误判文档写错。
2. `GET /anthropic/v1/models` **返回 404**，该端点不提供模型列表，只能用 `/models` 查。

**等价的环境变量写法**（临时生效，仅当前 shell）：

```bash
export ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
export ANTHROPIC_AUTH_TOKEN=sk-xxxxxx
export ANTHROPIC_MODEL='deepseek-v4-pro[1m]'
```

> 推荐用配置文件方式：CLI 和 VSCode 扩展都能读到。

---

## 9. 阶段五：验证

### 9.1 WSL 内逐项验证

```bash
bash scripts/03-verify.sh
```

覆盖四组检查：

| 组 | 检查项 |
|---|---|
| A 运行时版本 | Node ≥ 18、npm、claude --version |
| B 配置 | settings.json 存在、BASE_URL 正确、Key 已填、JSON 合法 |
| C 网络 | `api.deepseek.com/models` 返回 200、打印可用模型 ID |
| D 端到端 | `claude -p "只回复两个字：可用"` 真实调用模型 |

### 9.2 Windows 侧概览验证

```powershell
.\scripts\04-verify.ps1
```

打印发行版列表、`wsl --status`，并进入 WSL 内探测内核 / 系统版本 / Node / npm / claude / 配置。

### 9.3 手动验证清单

```bash
node -v
npm -v
claude --version
cat ~/.claude/settings.json

curl -s https://api.deepseek.com/models -H "Authorization: Bearer $KEY" | jq -r '.data[].id'

mkdir -p ~/cc-test && cd ~/cc-test
claude -p "只回复两个字：可用" --output-format text
```

**成功标志**：最后一条命令在 10~60 秒内返回模型的文字回复。

---

## 10. 脚本功能详解

### `scripts/01-install-wsl-ubuntu.ps1`（Windows，管理员）

| 步骤 | 功能 | 关键设计 |
|---|---|---|
| 1/7 | 打印系统版本 | 从注册表读 ProductName / DisplayVersion / CurrentBuild |
| 2/7 | 校验三项 Windows 功能 | 缺失则 `Enable-WindowsOptionalFeature` 并置 `$needReboot`，要求重启后重跑 |
| 3/7 | 安装现代 WSL | 三级回退：本地 MSI（msiexec）→ `wsl --update --web-download` → `wsl --update` |
| 4/7 | 清理孤儿登记 | 遍历 Lxss，仅在 BasePath 不存在时 `Remove-Item` |
| 5/7 | 默认版本设 2 | `wsl --set-default-version 2` |
| 6/7 | 安装 Ubuntu | 依次尝试 `--no-launch --web-download` → `--web-download` → 默认 |
| 7/7 | 设为默认发行版 | `wsl --set-default Ubuntu` |
| 附 | 写 `.wslconfig` | 8GB 内存 / 4 核 / 4GB swap，已存在则不覆盖 |

**健壮性设计：**
- 全程 ASCII-only，规避 GBK 编码导致的 ParserError
- `Use-Native` 把 `$ErrorActionPreference` 降为 `Continue`，避免 wsl.exe 的 stderr 输出变成终止异常
- 原生命令输出统一 `2>&1 | ForEach-Object { Info "$_" }`，不做 `2>$null` 重定向
- 幂等，可重复运行

**msiexec 退出码：** `0` 成功；`3010` 成功但建议重启。

### `scripts/02-setup-claude.sh`（WSL 内）

安装 Node.js LTS + Claude Code CLI，并写入 DeepSeek 配置。
用法：`DEEPSEEK_API_KEY='sk-xxx' bash 02-setup-claude.sh`
已内置 npmmirror 镜像以加速国内网络；结束时打印核对模型名。

### `scripts/03-verify.sh`（WSL 内）

`chk` 函数封装"描述 + 命令 + 期望正则"，逐项 PASS/FAIL 并统计。
D 组做真实端到端调用，超时 180 秒。

### `scripts/04-verify.ps1`（Windows）

从 Windows 侧一次性打印发行版列表、WSL 状态，并进入 WSL 探测内核、Node、npm、claude、配置。

---

## 11. 排障手册

| 现象 | 原因 | 处理 |
|---|---|---|
| `.ps1` 报 ParserError、中文乱码 | 无 UTF-8 BOM，PS 5.1 按 GBK 读取 | 脚本已强制 ASCII；自行修改时勿写中文 |
| `wsl --update` 报 403 / 已禁止 | 微软商店 CDN 不可达 | 用 `--web-download` 走 GitHub，或本地 MSI |
| 提示"WSL 必须更新到最新版本" | 仅有 inbox stub，`Program Files\WSL` 不存在 | 装现代 WSL（MSI） |
| 脚本报 NativeCommandError 中断 | wsl.exe 写 stderr + `EAP=Stop` + `2>$null` | 已修；自改脚本时注意这两点 |
| Lxss 有 Ubuntu 但目录不存在 | 孤儿登记 | 脚本第 4 步自动清理（BasePath 缺失时） |
| `wsl -l -v` 中 VERSION 是 1 | 装成了 WSL1 | `wsl --set-version Ubuntu 2` |
| `wsl --install` 要求 Microsoft Store | 走商店通道被墙 | 加 `--web-download` |
| 提示虚拟化未启用 | BIOS 未开 VT-x / SVM | 进 BIOS 开启 |
| 网络不通 / DNS 失败 | resolv.conf 异常 | `sudo rm /etc/resolv.conf` 后 `wsl --shutdown` |
| `claude` 命令找不到 | PATH 未加载 | 新开终端，或 `export PATH="$HOME/.local/node/bin:$PATH"` |
| 模型报 404 / unknown model | 模型名不对 | 查 `/models` 真实 ID 后改配置 |
| 仍弹 Claude Code 登录页 | settings.json 缺失或非法 | `jq -e . ~/.claude/settings.json` 校验 |
| **WSL 内下载卡死 / 连不上 GitHub** | WSL 默认 NAT 模式，用不了 Windows 的 localhost 代理 | 脚本 v3 已移除全部 GitHub 依赖（Node 走 npmmirror、npm 走国内镜像），无需代理 |
| **装完提示 `claude: command not found`** | PATH 写在 `~/.bashrc`，当前终端未刷新 | `source ~/.bashrc`，或重开终端 |

### 常用运维命令

| 命令 | 作用 |
|---|---|
| `wsl -l -v` | 列出发行版及 WSL 版本 |
| `wsl --status` | 默认版本与内核版本 |
| `wsl --shutdown` | 强制关闭所有实例（改 `.wslconfig` 后必做） |
| `wsl --set-version Ubuntu 2` | 转换为 WSL2 |
| `wsl -d Ubuntu -u root` | 以 root 进入 |
| `wsl --export Ubuntu ubuntu.tar` | 备份 |
| `wsl --unregister Ubuntu` | 注销（清空数据，慎用） |

配置文件位置：
- `%USERPROFILE%\.wslconfig` → 全局（内存、CPU、swap）
- WSL 内 `/etc/wsl.conf` → 单发行版（挂载、systemd 等）

---

## 12. 安全须知

- **不要把真实 API Key 提交进仓库**。仓库只提供 `config/deepseek-settings.example.json` 占位模板；`.gitignore` 已排除 `*settings.json`、`*.key`。
- 配置文件建议 `chmod 600 ~/.claude/settings.json`。
- 若 Key 曾误提交，请立即到 DeepSeek 平台作废并重新生成。
- WSL 安装包（247MB）不入库，请自行下载。

---

## 13. 使用手册（装好之后怎么用）

安装完成只是起点。日常怎么用 Claude Code、斜杠命令清单、省 token 技巧、`CLAUDE.md` 怎么写、DeepSeek 报错速查，全部在：

➡️ **[`docs/USAGE.md`](./docs/USAGE.md)**

最值得先做的三件事：

1. 进项目目录再启动（`cd ~/项目 && claude`），别在 `~` 里启动
2. 新项目先跑 `/init` 生成 `CLAUDE.md`
3. 出问题先敲 `/doctor`

---

## 14. 推广素材

`promo/` 下是社媒推广用的现成物料：

| 文件 | 用途 |
|---|---|
| `repo-promo.png` | 仓库页风格推广图（2880×1520 高清 PNG），适合做首图 |
| `repo-promo.html` | 推广图 HTML 源。改文案/配色后，用 Chrome 无头模式重新渲染即可 |

重新出图：

```bash
chrome --headless=new --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=2 --window-size=1440,760 \
  --screenshot=repo-promo.png repo-promo.html
```

> 注：`repo-promo.png` 中侧栏的 star / fork / view 数字为**装饰性占位值**，并非真实数据，对外发布前请替换为真实数字或移除。

---

## 附：验证过的版本组合

| 组件 | 版本 |
|---|---|
| WSL | 2.7.14 |
| Ubuntu | 26.04.1 LTS |
| 内核 | 6.18.33.2-microsoft-standard-WSL2 |
| Node.js | v22 LTS（从 npmmirror 镜像下载，装到 `~/.local/node`，需 ≥ 18） |
| Claude Code | `@anthropic-ai/claude-code` 最新版 |
| DeepSeek 模型 | `deepseek-v4-pro[1m]` / `deepseek-v4-flash[1m]` |

> **实机验证**：上述组合于 2026-09-20 在一台真实 Windows 11 机器上从零跑通全流程
> （WSL2 → Ubuntu → Claude Code CLI → DeepSeek 端到端对话），
> 安装脚本在无代理环境下完成，DeepSeek `/models` 与 `/anthropic/v1/messages` 均返回 200。
