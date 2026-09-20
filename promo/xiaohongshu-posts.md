# 小红书推广帖合集（5 条，角度各不相同）

> 一条项目值得发多次。同一件事从不同切口讲，打到的是完全不同的人。
> 建议间隔 1-2 天发，不要同一天刷屏。

---

## 帖子 1 · 痛点劝退型（打"装 WSL 失败过的人"）

**标题**：装 WSL 弹出这 5 个报错的，进来抄答案

**正文**：

```
不是你手残，是这些报错真的不是命令输错的问题

我第一次在 Win11 上装 WSL，五连炸：

· wsl --update → 403 已禁止
  微软商店的 CDN 连不上，不是网络差，是被拦了
· wsl -d Ubuntu → "WSL 必须更新到最新版本"
  其实系统里只装了个空壳 stub，真正的 WSL 根本没装
· wsl -l -v → 显示有 Ubuntu，进去却是空的
  注册表里留了个孤儿登记，装不上也删不掉
· 脚本一跑 → ParserError，中文全变乱码
  PowerShell 5.1 会把没有 BOM 的 UTF-8 按 GBK 读
· .sh 脚本 → bad interpreter
  文件被转成 CRLF 行尾了

五个坑没一个是操作失误，全是环境和编码层面的问题

我把这套排障过程连同修法全部脚本化了，仓库在
github.com/QianRongAn/wsl2-ubuntu-claude-code-setup

以后谁再被这几个报错卡住，直接拿去用
```

**标签**：#WSL2 #Windows11 #程序员 #踩坑 #开发环境 #Linux #GitHub

---

## 帖子 2 · 省钱型（打"想用 AI 编程但嫌贵的人"）

**标题**：Claude Code 可以不买订阅，我算给你看

**正文**：

```
想试 AI 写代码，一看月费就劝退的举手

其实 Claude Code 这个 CLI 工具本身是开源免费的
真正花钱的是它背后调用的模型

而模型是可以换的

我把 DeepSeek 的 API 接了进去，变成按量付费：
用多少算多少，随充随用，没有月费门槛

实测充 10 块，写小脚本、改 bug、生成文档
能跑很久很久

配置就三步：
1. 装 Claude Code CLI
2. 改一个 settings.json
3. 把 base url 指向 DeepSeek

这三步我全写成脚本了，一条命令跑完
仓库：github.com/QianRongAn/wsl2-ubuntu-claude-code-setup

先小成本试试水，好用再考虑要不要上订阅
这个顺序比较合理
```

**标签**：#ClaudeCode #DeepSeek #AI编程 #程序员 #效率工具 #省钱 #GitHub开源

---

## 帖子 3 · 场景体验型（打"用虚拟机很痛苦的人"）

**标题**：别再装虚拟机了，Windows 上开 Linux 可以很快

**正文**：

```
以前我在 Windows 上写点小东西，流程是：
开虚拟机 → 等它启动 → 卡半天 → 心情没了

现在是一个终端的事

WSL2 里的 Ubuntu 是真实的 Linux 内核
但启动只要一两秒，内存按需占用
Windows 的文件在 /mnt/c 直接读写
VS Code 装个插件就能直接编辑里面的文件

最爽的是搞坏了不心疼：
环境装崩了删掉重装几分钟，Windows 本体一点事没有
特别适合拿来练 Linux、跑脚本、试新工具

顺便说个坑：
项目文件别放 /mnt/c 下面跑，跨文件系统很慢
放 WSL 自己的家目录里

从零到能用的完整脚本我放仓库了
github.com/QianRongAn/wsl2-ubuntu-claude-code-setup
```

**标签**：#WSL2 #Linux #Windows11 #开发环境 #程序员日常 #效率 #虚拟机

---

## 帖子 4 · 干货清单型（打"收藏党"，转发率最高）

**标题**：Windows 装 WSL2 的 5 个坑，收藏备用

**正文**：

```
刷到就是赚到，这五个我全踩过，每个都给了修法

① wsl --update 报 403
原因：微软商店 CDN 不可达
修法：改用本地 MSI 离线安装，或 wsl --update --web-download

② 提示"WSL 必须更新到最新版本"
原因：系统里只有 inbox 版 stub，C:\Program Files\WSL 根本不存在
修法：装现代 WSL 安装包（GitHub release 有 msi）

③ 显示已装 Ubuntu 但目录为空
原因：注册表 Lxss 下的孤儿登记，之前装失败留下的
修法：确认 BasePath 确实不存在后清理该条目

④ PowerShell 脚本报 ParserError、中文变乱码
原因：.ps1 无 UTF-8 BOM，PS 5.1 按 GBK 读取
修法：脚本强制 ASCII-only，别在里面写中文

⑤ .sh 报 bad interpreter
原因：Git 把 LF 转成了 CRLF
修法：加 .gitattributes 强制 *.sh text eol=lf

完整检测和修复都写进脚本了
github.com/QianRongAn/wsl2-ubuntu-claude-code-setup
```

**标签**：#WSL2 #踩坑记录 #程序员 #Windows11 #开发环境 #干货 #Linux #避坑指南

---

## 帖子 5 · 开源日记型（真诚向，涨粉用）

**标题**：折腾了一整天，我把它做成开源项目了

**正文**：

```
起因只是想在公司那台 Win11 上跑个脚本

结果从装 WSL 开始一路翻车：
商店 CDN 403、WSL 是空壳、注册表有残留、
PowerShell 中文乱码、sh 脚本行尾不对

每解决一个就觉得"这下总该好了吧"
然后冒出下一个

折腾到晚上终于跑通了完整的链路：
WSL2 + Ubuntu + Claude Code + DeepSeek

那时候的想法是：
如果这些坑我一个一个重新查一遍要花一天
那下一个人是不是也一样

所以我把整个过程连同修法整理成了脚本和文档
放到了 GitHub 上

不是什么了不起的项目
就是一份"我把坑踩完了你别踩了"的记录

觉得有用点个 star 就好
github.com/QianRongAn/wsl2-ubuntu-claude-code-setup
```

**标签**：#开源 #程序员日常 #GitHub #WSL2 #折腾记录 #AI编程 #DeepSeek

---

## 发布节奏建议

| 顺序 | 帖子 | 为什么先发这条 |
|---|---|---|
| 第 1 天 | 帖子 1（痛点） | 痛点型钩子最强，容易起量 |
| 第 3 天 | 帖子 4（干货清单） | 收藏率高，能把账号权重撑起来 |
| 第 5 天 | 帖子 2（省钱） | 换角度覆盖另一拨人 |
| 第 7 天 | 帖子 3（场景） | 生活化，适合沉淀 |
| 第 10 天 | 帖子 5（真诚向） | 前面的数据起来了，这条最容易涨粉 |

**共通提醒**：
- 每张图配 3-5 张，首图用 `repo-promo.png`
- 正文里那段 GitHub 链接，小红书不会变成可点击的超链接，评论区置顶补一次
- 别在同一条里塞太多技术名词，每条只打一个痛点
