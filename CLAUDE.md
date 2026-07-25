# 项目说明（写给下次做迁移/更新的 AI 或未来的自己）

## 项目定位

基于 [雾凇拼音 (iDvel/rime-ice)](https://github.com/iDvel/rime-ice) 精简出来的个人 Rime
配置仓库，只保留一个输入方案：**小鹤双拼**（`double_pinyin_flypy`），并挂载
[万象语法模型](https://github.com/amzxyz/RIME-LMDG)。

暂不含任何形码方案。以后要加（虎码、宇浩等）就在 `default.custom.yaml` 的
`schema_list` 追加一行，形码方案自成一套文件，不要往双拼方案里混辅码/拆分提示。

## 核心理念

### 一、最小文件集
仓库里每个文件都必须能追到引用链（被某个 schema/dict/config 直接或间接引用）。
追不到引用的文件应当删除。同步上游不是"整目录照搬"，而是"按清单精选"——
上游新增的文件默认不拿，除非要启用对应的新功能。改动后用 `git grep` 确认没有死引用。

### 二、不带 default.yaml（★ 本仓库最重要的结构性决定 ★）
Rime 读配置的顺序是：共享目录的 `default.yaml` ← 用户目录的 `default.yaml`（若存在，
**整份顶掉**共享那份）← 用户目录的 `default.custom.yaml`（打补丁）。

雾凇会在用户目录塞一份自己的 `default.yaml`，把 Rime 出厂的交互语义整份换掉，
而且改了什么**不会有任何编译报错**。历史上已经因此踩过一次大坑（见下方"Emacs 命门"）。

所以：**本仓库永远不带 `default.yaml`**，底座固定为
`/Library/Input Methods/Squirrel.app/Contents/SharedSupport/default.yaml`，
所有偏离出厂的设定显式写在 `default.custom.yaml` 里。换底座时该文件原样带走，
操作逻辑就是固定的。

代价：方案文件对 `default.yaml` 有两处硬依赖，出厂那份满足不了，已搬进
`default.custom.yaml`，同步上游时要对照更新：

| 依赖 | 出处 | 搬自 |
|---|---|---|
| `__include: default:/punctuator` | `double_pinyin_flypy.schema.yaml` | `rime-ice/default.yaml` 122–191 行 |
| `recognizer: import_preset: default` | `double_pinyin_flypy.schema.yaml` | `rime-ice/default.yaml` 196–205 行 |

### 三、定制走 .custom.yaml，不改 vendored 文件
从上游同步来的文件（schema/dict/lua/opencc）一律保持原样，所有个人改动写在对应的
`*.custom.yaml` 里。这样同步上游 = 直接覆盖文件，补丁自动存活，不需要"逐条重放定制"。

个人文件只有这 6 个 + 1 个数据文件：

| 文件 | 作用 | 能不能省 |
|---|---|---|
| `default.custom.yaml` | 交互语义 + 搬自上游的 punctuator/recognizer | 不能 |
| `double_pinyin_flypy.custom.yaml` | 万象模型、uuid_v7、长词优先 | 不能（模型必须在这挂） |
| `melt_eng.custom.yaml` | 英文方案的双拼拼写派生规则 | 不能（上游默认全拼） |
| `radical_pinyin.custom.yaml` | 部件拆字的双拼拼写派生规则 | 不能（上游默认全拼） |
| `squirrel.custom.yaml` | Dvorak、扁平主题、指定 app 默认英文 | 可以（纯外观） |
| `lua/uuid_v7.lua` | UUID v7（上游自带的是 v4） | 可以 |
| `custom_phrase_double.txt` | 自定义短语（模板，可随意增删） | 可以 |

## 硬规则

1. **不要往仓库里加 `default.yaml`。** 同步上游时明确跳过它。这是结构性保证，别绕过。

2. **Emacs 命门：`ascii_composer/switch_key/Shift_L` 必须是 `inline_ascii`。**
   emacs-rime 的"行内临时英文"（`rime-inline-predicates`：中文后打空格、打大写字母时
   自动触发）是靠**向 librime 伪造一次左 Shift 按键**实现的；左 Shift 若是
   `commit_code`，这一次伪造按键就会把会话永久切到西文，表现为
   「rime 明明开着但再也打不出中文」。这个 bug 查了很久，不要再踩。

   出厂默认就是 `inline_ascii`，所以 `default.custom.yaml` 里**一行都没写** ——
   真正的防线是硬规则 1（不带 `default.yaml`）。雾凇那份 `default.yaml` 正是
   `commit_code`，一旦被拿进仓库，bug 立刻复发且无任何编译报错。
   验证路径：Emacs 里打中文 → 空格 → 打英文 → 再打中文。

   ⚠️ **已知风险敞口**（依赖出厂默认换来的代价，已评估后接受）：
   - Squirrel 升级会整份替换出厂 `default.yaml`，若哪天上游改了这个默认值，
     本配置零防护且无告警。**每次升级 Squirrel 后跑一遍上面的验证路径。**
   - 万一有 `default.yaml` 混进用户目录，`ascii_composer` 这块完全没有兜底。

   要封死这两个敞口，加一行路径式补丁即可（路径式不会丢出厂兄弟项，不违反硬规则 4）：
   ```yaml
   ascii_composer/switch_key/Shift_L: inline_ascii
   ```
   目前按「出厂已对就不写」的原则没有加。若将来觉得这个敞口不可接受，就加上 ——
   这是本仓库唯一一处值得为它破例的设定。

3. **`switcher/save_options` 里不能有 `ascii_mode`。**
   加进去的话，卡在英文的状态会被写进 `user.yaml` 跨重启还原，重启都救不回来。
   出厂和雾凇默认都没有它，这里显式钉死防止上游哪天加回来。

4. **补丁尽量用路径形式（`a/b/c:`），不要整块写 `a:` 再嵌套。**
   整块写会把出厂那一节里没列出的兄弟项一起丢掉，而且**编译不报错**，只能靠肉眼
   对比编译产物才发现。这个坑本仓库已经踩过三次：

   | 整块写了什么 | 丢了什么 |
   |---|---|
   | `ascii_composer:` | 出厂的 `Eisu_toggle: clear` |
   | `switcher:` | 出厂的 `hotkeys`、`abbreviate_options` |
   | `squirrel.custom.yaml` 的 `style:` | 出厂的 `font_face: Avenir`、`font_point: 16`、`candidate_format`、`memorize_size`、`show_paging`、`text_orientation` |
   | `squirrel.custom.yaml` 的 `preset_color_schemes:` | 出厂内置的 19 套配色 |

   相应地：**出厂默认已经是想要的就不要写**，只留注释说明为什么不用写。
   检查方法见硬规则 8 —— 改完必须对比编译产物 `build/*.yaml` 里该节点的键数量。

5. **语法模型不进 git。**
   `wanxiang-lts-zh-hans.gram` 是 401 MiB，已在 `.gitignore` 里。每个部署目录各下一份。
   `git reset --hard` 不会动被忽略的未跟踪文件，所以 live 克隆更新时它不会丢。

6. **用户数据红线**，任何情况下不覆盖、不删除、不提交：
   `*.userdb/`、`installation.yaml`、`user.yaml`、`sync/`、`*.gram`。
   **永远不要在 live 克隆里跑 `git clean -xdf`** —— 它会把上面这些连同语法模型一起删掉。

   ⚠️ `installation.yaml` 现在**带有手工配置的内容**（`installation_id` + `sync_dir`，
   见 `README.org`「两个前端各学各的」），不是纯自动生成的了。它不进 git，所以换机器
   或重装时要按 README 手工重做，否则两个前端的用户词典不再合并。

7. **git 保持单提交历史。** 日常改动用 `git commit --amend` 修进根提交。
   `README.org` 只写现状，不写变更流水账。

   **改完自动推送**（2026-07-26 起，用户已授权，不必每次再问）：
   ```shell
   git push --force origin master
   ```
   必须 `--force` —— 历史是 amend 重写的，远端那个 commit 不是本地的祖先。
   顺序：编译验证通过 → `commit --amend` → 同步两个 live 克隆 → push。
   验证失败就不要推。

8. **改动前先编译验证。** 改完 schema/dict/custom 之类的配置，先在 scratchpad 目录
   `rime_deployer --build <目录> "/Library/Input Methods/Squirrel.app/Contents/SharedSupport"`。

   ⚠️ **`rime_deployer` 不往 stderr 写日志**，重定向它的输出会得到一个空文件，
   看着像"零警告"其实什么都没看到。真正的日志在 glog 文件里，按前端分开：

   | 来源 | 日志前缀 |
   |---|---|
   | `rime_deployer` / `rime_dict_manager` | `$TMPDIR/rime.tools.*` |
   | Squirrel | `$TMPDIR/rime.squirrel/` |
   | emacs-rime | `$TMPDIR/rime.emacs.*` |

   验收三件事：退出码 0；对应的 `*.ERROR` 日志为空；**编译产物 `build/*.yaml`** 里补丁
   按预期合并了（尤其 `key_binder/bindings` 的 `__patch` + `/+` 合并结果、
   `engine/filters` 的插入位置、`melt_eng`/`radical_pinyin` 的 `speller/algebra` 是不是
   小鹤而不是全拼）。**光看退出码不够** —— 补丁没合上时 librime 只警告不报错。

   已知的良性警告，不用管：
   - `circular dependencies detected in melt_eng.schema` / `radical_pinyin.schema`
     —— `*.custom.yaml` 里 `__include: melt_eng.schema.yaml:/algebra_*` 引用的正是自己
     要打补丁的那个文件，形式上成环。这是雾凇官方 `others/patch_examples/` 推荐的写法，
     实测 algebra 能正确解析成小鹤那套（已验证）。
   - `duplicate word definition 'XML'` 之类 —— 上游英文词库自带的重复词条。

9. **部署结构。** 本机有两个 live 克隆：
   - `~/Library/Rime`（Squirrel 用户目录）
   - `~/.emacs.d/rime`（emacs-rime 用户目录）

   更新流程（源仓库单提交历史，用 `fetch` + `reset --hard` 而不是 `pull`）：
   ```shell
   git fetch /Users/lakki/p/Rime master && git reset --hard FETCH_HEAD
   ```
   然后重新部署：
   - Squirrel：`Squirrel --reload`
   - emacs-rime：`rime_deployer --build ~/.emacs.d/rime "/Library/Input Methods/Squirrel.app/Contents/SharedSupport"`

   部署完成后检查日志（路径见硬规则 8 的表格）确认没有 `E` 级错误。

## 同步上游的操作顺序

1. `cd ~/p/rime-ice && git pull`
2. 按 `README.org`「同步流程」章节的精选清单逐目录同步（**不要整目录覆盖**，
   尤其不要拿 `default.yaml`）
3. 核对两件事：
   - `rime-ice/default.yaml` 的 `punctuator` / `recognizer` 两块有没有变，变了同步到
     `default.custom.yaml`
   - `double_pinyin_flypy.schema.yaml` 的 `engine/filters` 列表有没有增删，
     变了要调整 `double_pinyin_flypy.custom.yaml` 里 `engine/filters/@before 4` 的索引
4. scratchpad 编译验证（见硬规则 8）
5. 手工验证关键功能（见 `README.org`「验证清单」）
6. 部署到两个 live 克隆，检查部署日志
7. `git commit --amend` 保持单提交历史；是否 push 由用户决定
