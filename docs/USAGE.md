# Claude Code 使用手册（装好之后怎么用）

> 适用对象：已完成 `02-setup-claude.sh` 安装、DeepSeek 配置已写入 `~/.claude/settings.json` 的环境。
> 如果还没装完，先看主 README 的[阶段三](./README.md#7-阶段三安装-claude-code-cli)和[阶段四](./README.md#8-阶段四接入-deepseek-api)。

---

## 1. 启动前：务必先进入项目目录

```bash
cd ~/你的项目        # 推荐放在 WSL 家目录下
claude               # 启动
```

Claude Code 是**以当前目录为工作范围**的。在 `~` 里启动，它会把整个家目录当项目扫，又慢又容易误操作。

⚠️ **不要把项目放在 `/mnt/c/` 下跑**。跨 Windows/Linux 文件系统读写性能极差，文件监听也会失灵。要用 Windows 上的代码就先 `cp -r` 进 WSL。

---

## 2. 首次运行

> **刚装完提示 `claude: command not found`？** 不是没装上。安装脚本把 Node 的 PATH 写进了
> `~/.bashrc`，但只对新终端生效。在当前窗口执行 `source ~/.bashrc`，或重开一个 Ubuntu 即可。

配置正确时**不会弹出登录界面**，直接进入对话。因为它通过 `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` 认证，不走官方 OAuth。

**第一次进入某个目录时会弹信任确认**（"Yes, I trust this folder"），用方向键 ↓ 选 Yes 回车。
这个目录决定了它的读写范围，所以每次换项目都会问一次——**不要对系统目录或家目录随便选 Yes**。

如果弹了登录页 → 配置没生效，敲 `/doctor` 看诊断，或检查：

```bash
cat ~/.claude/settings.json
```

确认里面有 `ANTHROPIC_BASE_URL: https://api.deepseek.com/anthropic`（**不能带 `/v1`**）。

---

## 3. 核心用法：直接说人话

进界面后不用记命令，直接描述需求：

```
帮我看看这个项目是干嘛的
给 utils.py 的 download() 加上超时和重试
为什么 npm test 里第三个用例跑不过？修一下
把 README 里的安装步骤改成表格
```

它会先读代码、再给方案、改之前**征求你同意**。

---

## 4. 常用斜杠命令

| 命令 | 什么时候用 |
|---|---|
| `/init` | **新项目第一件事**。扫描代码库生成 `CLAUDE.md`，之后每次启动都会自动读它 |
| `/model` | 切换模型。想省钱就切到 haiku 档（`deepseek-v4-flash`） |
| `/cost` | 看本次会话花了多少 token，心里有数 |
| `/clear` | 上下文乱了/换任务，清掉重开 |
| `/compact` | 上下文快满时压缩保留要点，比 `/clear` 温和 |
| `/review` | 让它审查当前改动 |
| `/doctor` | 出问题时的自检首选 |
| `/help` | 全部命令列表 |

---

## 5. 快捷键

| 键 | 作用 |
|---|---|
| `Esc` | 中断它正在做的事（它跑偏了就按） |
| `Shift + Tab` | 切换自动接受模式 |
| `Ctrl + C` | 退出 |
| 直接拖文件 / `@文件名` | 把指定文件加进上下文 |

**权限建议**：第一次用**别开自动接受**，看着它改，确认它靠谱后再开。它会执行的命令（尤其 `rm`、git push）一定要自己过一眼。

---

## 6. `CLAUDE.md`：让它一次配置、长期懂你

`/init` 生成的 `CLAUDE.md` 会被每次会话自动加载。手写也行，放项目根目录：

```markdown
# 项目说明
这是一个 Python 数据处理脚本集合。

## 约定
- Python 3.11+，用 uv 管理依赖
- 所有新增函数必须写 docstring 和单测
- 不要修改 config/ 下的生产配置

## 常用命令
- 测试：uv run pytest
- 格式化：uv run ruff format
```

写完这一份，它就不会每次都猜你的技术栈和风格了。**这是投入产出比最高的一件事。**

---

## 7. 推荐工作流

```
1. 描述需求，先让它给方案（"先别改代码，说说你打算怎么改"）
2. 确认方案合理 → 让它执行
3. /review 自查一遍
4. 自己 git diff 过一遍再提交
```

**不要一上来就让它大改**。先要方案、再执行，能省掉大量返工和 token。

---

## 8. 省钱技巧

DeepSeek 按量计费，几个习惯能明显省钱：

- 简单问答、格式化、写注释 → `/model` 切到 **haiku 档**（`deepseek-v4-flash`），便宜很多
- 长会话定期 `/compact`，别让上下文无脑膨胀
- 单个任务完成后 `/cost` 看一眼，建立体感
- 明确划定范围："只看 `src/api/` 这个目录"

---

## 9. 排错速查

| 现象 | 原因 / 处理 |
|---|---|
| 启动就要求登录 | `settings.json` 未生效，用 `/doctor` 检查；确认文件路径是 `~/.claude/settings.json` |
| `401 Unauthorized` | API Key 错误，或**余额耗尽**（可在 platform.deepseek.com 查余额） |
| `404 Not Found` | `ANTHROPIC_BASE_URL` 写错。必须是 `https://api.deepseek.com/anthropic`，**末尾不要加 `/v1`** |
| 模型不存在 | 用配置里已验证的 `deepseek-v4-pro[1m]` / `deepseek-v4-flash[1m]`。注意 `GET /models` 只返回基础 ID，不带 `[1m]` 变体，但兼容端点支持 |
| 命令很慢/卡住 | 检查是否在 `/mnt/c/` 下运行；或网络不通，见主 README 排障手册 |
| 改文件报权限 | 当前用户对项目目录无写权限，`ls -la` 看一下属主 |

快速体检：

```bash
claude -p '只回复两个字：可用'      # 非交互，直接验证端到端链路
```

---

## 10. 和 Windows 的协作

```bash
explorer.exe .          # 在 Windows 资源管理器打开当前目录
code .                  # 用 Windows 上的 VS Code 打开（需装 WSL 插件）
```

VS Code 装 **WSL 插件**后可以直接编辑 WSL 里的文件，同时终端里跑 `claude`，是最舒服的组合。
