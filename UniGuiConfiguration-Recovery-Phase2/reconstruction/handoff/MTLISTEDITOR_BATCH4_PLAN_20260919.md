# mtListEditor 批次四方案：多表关联 / 从表 / 复杂写入（2026-09-19）

用户清单最后一项（第四批）。本文是**方案与验收标准**，不是已实现的功能；动手前请确认 §5 的三处决策。
按仓库纪律：先在本文写清范围、复用边界、退出标准与未测项，再按阶段实现并逐项给结论。

## 1. 现状（证据）

| 事实 | 证据 |
|---|---|
| mtListEditor 目前**只允许单根表** | `ugConfiguration.ListEditorTemplate.pas`：`if (Tables = nil) or (Tables.Count <> 1) then Exit(Fail('mtListEditor 第一批仅支持单根表。'))` |
| 被复用的列表生成器**已支持关联表**（多表 JOIN） | `ugConfiguration.MultipleTemplate.pas`：`Tables.Count>1 → GenericWrite := True`；`AddMultipleJoinWrite`（写模式）；`CheckMultipleJoin` / `RefreshMultipleJoin`（写前守卫与回显） |
| 关联表的写入语义是**只展示、不写关联表** | `ugConfiguration.MultipleJoins.pas`：注释「按当前暂存值回显完整关联链；不重开主数据集，**不写入关联表**」；`CheckMultipleJoin` 拦「关联输出字段与基础表字段冲突」与「主表行重复展开」 |
| 精灵的数据结构页本来就允许配关联表 | `ugWebConfiguration.DataStructure.pas` 的 `cdsTables` 支持多行（表名/别名/父级/关联方式/关联条件），与模块类型无关 |
| 若发生**从表**（主从两套数据） | 参考实现是 `ugConfiguration.MasterSlaveTemplate.pas` + `MultipleRecord` 等：父子键回填、明细编号/非空/唯一、原子提交 `ApplyUpdatesCds([cdsMain,cdsDetailed])`、明细导入、导航与审批 |

结论：**多表关联是"解锁 + 收口"，从表是"新增一套数据模型"**，两者量级差别很大，因此拆成两步。

## 2. 第一步（建议先做）：多表关联（关联表只读展示 + 只写根表）

### 范围

- 允许 `cdsTables` 多行（根表 + 若干关联表，`left join`，别名唯一），查询沿用 mtMultiple 已生成的 JOIN SQL，**不改 SQL 生成**。
- **关联表字段在记录区/表格里一律只读**（展示用途）：与审计字段同一处理——记录区控件 `ReadOnly := True`，编辑态也不可改。
- **写回只针对根表**：主键/自动编号、必填、唯一校验都必须在根表字段上（现有校验已经要求带根表别名前缀，本步只需把拒绝文案讲清楚）。
- 保存流程接入 mtMultiple 已有的两个守卫：Post 后 `CheckMultipleJoin`（拦关联列误写、主表行重复展开），滚动/保存后 `RefreshMultipleJoin`（按暂存值回显关联链）。
- 分页/查询/截图等其余行为不变。

### 主要改动点

| 位置 | 改动 |
|---|---|
| `ugConfiguration.ListEditorTemplate.pas` | 去掉"仅单根表"限制；记录区字段的来源别名判断（非根表字段一律只读）；把根表别名/关联信息传给写入生成器 |
| `ugConfiguration.ListEditorWrite.pas` | 按来源别名区分"可编辑字段"与"展示字段"；必填/唯一/主键的校验文案标明"必须是根表字段"；保存与滚动处调用 `CheckMultipleJoin` / `RefreshMultipleJoin` |
| `ugWebConfiguration.NormalSetting.pas` | 「非空字段」「主表唯一」的说明补一句"仅根表字段"（可选，属文案优化） |

### 退出标准

1. 根表 + 1~2 张关联表（`left join`）的配置能生成、能编译、能在宿主打开；
2. 关联表字段在记录区**编辑态也改不动**；表格里这些列只读；
3. 新增/修改/保存/撤销只影响根表；保存后关联展示列按新键值回显；
4. 关联表造成的主表行重复展开被拦下并给出明确提示（不是静默保存多份）；
5. 必填/唯一配到关联表字段时给出"必须选根表字段"的明确拒绝；
6. 层级/行权限的部门字段仍必须是根表字段；范围过滤与写时复核与批次二一致。

### 未测/风险

- 关联表为空（`left join` 未命中）时展示列是空值，不是错误——需要在宿主确认显示是否符合预期；
- 1:N 关联（关联表多行）被守卫拦下，**不支持**用它做"展开明细分行"（那是第二步的从表）；
- 关联表参与 `order by`/筛选的支持范围沿用 mtMultiple；跨库/跨 Schema 仍未开放（Catalog/Schema 保持禁用）。

## 3. 第二步（量级大）：从表 / 明细与复杂写入

### 两个方案

| 方案 | 内容 | 量级 |
|---|---|---|
| **S1 从表只读展示** | 选中主记录后，下方/右侧只读列出从表明细（不发写入） | 小（查询即可，无状态机变化） |
| **S2 从表可编辑（主从写入）** | 从表可增删改，父键回填、明细编号/非空/唯一校验、与主表一起原子提交、撤销一起回退 | **大**：等价于把 `mtMasterSlave` 的数据模型与写回规则接进同窗列表编辑器，需要新的状态机（主记录浏览 + 从表暂存）与整套验收项 |

### S2 必须先确认的业务问题（与 `MTDETAIL_RECOVERY_PLAN.md` G0 同一组）

1. 保存粒度：主记录与从表**一起提交**（原子）还是分开？（原版主从是原子提交）
2. 父键回填：从表的外键取自哪一列、在什么时机回填（新增从表行时、保存前 `BeforePost`）；
3. 明细编号（行号）：是否需要、按什么规则、是否参与唯一校验；
4. 从表唯一/非空的比较范围：仅当前主记录内，还是整张表；
5. 删除主记录时从表如何处理（禁止/级联/提示先删明细）——**不做级联删除除非明确要求**；
6. 是否为从表提供导入（与 §4 的导入语义联动）。

### 退出标准（S2）

- 至少主 A 含 2 条从表明细、主 B 含 1 条、主 C 无明细三组数据：切换主记录时从表不串数据；无明细的主记录显示空表；
- 从表增/改/删 + 撤销 + 保存的 9 类分支（校验失败保留、提交失败可重试、提交成功刷新失败不重复提交、结果不确定先核实）逐项有结论；
- 原子性：主表提交失败时从表不得留下半条明细；
- 权限：主记录范围外的从表不得因直接键值访问而写入；
- 与批次二共存：审计字段、层级权限在"主从同窗"下仍成立。

## 4. 导入（btImport）的语义（与批次三衔接）

导入对同窗单行编辑有两种做法，需先定：

| 方案 | 行为 | 量级 |
|---|---|---|
| **A 导入到当前编辑记录** | 先新增/修改进入编辑态，导入（文本/Excel）填进当前记录再保存 | 小，与现有状态机兼容 |
| **B 批量暂存多行** | 导入产生 N 条未保存新行，统一保存 | 中～大，扩展状态机（浏览态存在多条未保存行；校验/定位/撤销/关闭语义；与分页、唯一校验的交互） |

建议先 A。若选 B，它会与 §3 的 S2 共用"多条未保存行"的状态语义，**建议 B 与 S2 一起设计**，避免做两套。

## 5. 需要你确认的三处（确认后我按阶段实施）

1. **第一步多表关联**是否按上文范围做（关联表只读展示、只写根表、复用 mtMultiple 守卫）？还是你希望关联表也**可写**（那是另一套写回规则，风险高，需要单独设计）？
2. **从表**要 S1（只读展示）还是 S2（可编辑主从写入）？选 S2 请顺带回答 §3 的 6 个业务问题（或授权我先按"原子提交 + 父键回填 + 明细行号 + 当前主记录内唯一 + 不做级联删除"这套默认语义实现，并把每条都标为待你确认）。
3. **导入**选 A 还是 B？（若选 B 且要 S2，建议合并设计）

## 6. 交付与验证方式（沿用既有约定）

- 每步独立 `deployment/<主题>-<日期>` 包：DLL 哈希、配置 JSON、生成的 DFM/脚本、探针与运行 profile 结果、未测清单、替换与重新生成步骤；
- 验证分层：配置契约 → DFM/脚本编译闸门（`list-editor-compile`）→ 原生数据集运行 profile（`MultipleScriptProbe`）→ Debug/Release → 宿主验收；
- 不删断言、不把未测写成通过；宿主未验收的项在包 README 与 `validation` 里单列；
- 关联表/从表的**真实库行为**（JOIN 写法、空关联、多行关联、并发）在宿主未验证前一律标未测。

## 7. 按用户选择的默认语义复核（2026-09-19）

用户 2026-09-19 决定：**多表关联不做**（无需求）；**导入要做**；**从表可编辑（主从写入）要做**，
明细区要有**新增行 / 删除行 / 复制行**；默认语义 = 原子提交 + 父键回填 + 明细行号 + 当前主记录内唯一 + **不做级联删除**。
下面是逐条复核，**两条与现状冲突/不可行，一处是全新能力**，其余是待确认的默认项。

### 7.1 ⚠ 「不做级联删除」与既有已验收行为不一致（需定口径）

`mtMasterSlave` 删除主单时是**同一事务里连明细一起删**：SQL 为
`delete from <明细表> where <明细键> = :key` ＋ `UGMM.ExecSqlSeparator` ＋ `delete from <主表> where <主键> = :key`
（`ugConfiguration.MasterSlaveTemplate.pas:2126`，且该行为已随 mtMasterSlave 验收通过）。
若 LE 改成"不级联"，删主记录会遇到两种结果：被外键约束拒绝，或留下**孤儿明细**。

需要你定口径（我建议第 2 种）：
1. 真·不级联：有明细就**禁止删除主记录**并提示先删明细（安全，但多一步操作）；
2. **删除主记录 = 同一事务删除它自己的明细**（与 mtMasterSlave 一致）；这仍然不是"擅自删除别人的数据"，
   只是删掉属于该主记录的从表行。我认为这才是你想要的"不做级联"的本意。

### 7.2 ⚠ DBAutoincrement 主键 + 从表在"原子提交"下不成立（需定方案）

从表行必须在提交前带上父键；而 `DBAutoincrement` 的主键**由服务端在提交后回填**（LE 现在靠 `AutoUpdateRefresh`），
提交前根本不知道键值 → 主从一次原子提交无法成立。旁证：`MasterSlaveTemplate` 里**完全没有 DBAutoincrement**
（只支持 MaxCode/Guid/DateTimeRandom），正是为了"键在提交前已知"。

建议（推荐 1）：
1. **明确拒绝**「主键 = 数据库自增 且 配置了从表」，提示改用 MaxInt 或 Guid；——诚实、无隐患，一条校验；
2. 两段式提交（先主表 → 回填键 → 再提交明细）：**失去原子性**（中途失败会留下没有明细的主记录），需要补偿逻辑；
3. 父键交由数据库触发器/默认值处理：把一致性推给库，我们不承诺。

### 7.3 ⚠ 「复制行」是全新能力（全工程都没有，需定语义）

- 精灵功能按钮目录共 25 项，**没有复制行**（`btCopy` 之类不存在）；原版 list editor 参考件、mtMasterSlave、mtDetail 也都没有。
- 注意区分：现有常规设置「表格复制」(1008) 是**单元格文本复制**（"增加表格复制功能"），与"复制行"不是一回事。
- 新增这项要：①功能按钮目录新增一项（**分组归属待定**，建议放 Editor Group 或新建"明细组"）；
  ②LE 生成器支持；③定义语义。**我建议的语义（请确认）**：
  - 复制**当前选中的明细行**，插入到**紧跟其后**；
  - 复制除「明细主键、明细行号、审计字段」以外的全部可编辑字段；
  - 父键取**当前主记录**；行号**重取**（不复制原行号）；
  - 违反「从表唯一」时按既有唯一校验在**保存时**提示（不做即时拦截，与手工新增一致）；
  - 主表不提供复制行（保持"一次编辑一条主记录"）。

### 7.4 明细的交互模型（建议照 mtMasterSlave）

- 明细表格**直接编辑单元格**（新增行后即可编辑）——LE 现在主表格是只读、编辑在记录区，这与 mtMasterSlave 的明细区不同，
  但正是它的做法（明细表格可编辑 + 守卫）。建议照它做，不另造"明细记录区"。
- **明细区位置**：建议放**记录区下方**（alTop），主表格在更下方（alClient）：
  `查询区 → 记录区 → 明细区 → 主表格 → 分页`。要放下方（alBottom）也可以，一句话即可。
- 明细区高度按行数自适应，超过阈值出现滚动条（沿用记录区 350 封顶的做法）。

### 7.5 明细支持哪些控件类型（建议第一批收窄）

- 第一批：文本 / 数值 / 备注 / 复选 / 日期时间 / **固定下拉**（与记录区一致）；
- **明细的查找 / 多列下拉暂不做**（需要 `DetailLookupBridge` 那套桥），配置时**明确拒绝**；
- 明细的 `SqlText` 下拉可评估后加入（成本低于查找），按你意见决定。

### 7.6 明细的校验与设置项（要对 mtListEditor 开目录）

- 需要开放：**从表结构页签**本身（现只对 mtMasterSlave/mtDetail 可见）与目录项
  「关联字段」(2000)、「明细编号」(3001)、「从表唯一」(3002)、「从表非空」(3003)、「隐藏字段-从表」(3004)；
- **明细行号**建议：删除/复制后**重新编号**（mtMasterSlave 即稳定重编号），且**行号不参与从表唯一校验**
  （否则重编号会互相触发）；
- **从表非空**提示按**明细行号**指出第几行（沿用 mtDetail/mtMasterSlave 的报错粒度）；
- 校验作用域按你定的**当前主记录内唯一**。

### 7.7 提交、失败与状态机（照已验收语义实现，无需你决定）

- 提交接口改用宿主已有的 `UGMM.ApplyUpdatesCds(cDataNodeName, [cdsMain, cdsDetailed])`（原子提交），
  保留三类分支：校验失败保留编辑态、提交失败可重试、提交成功但刷新失败不重复提交、结果不确定先核实；
- 主记录与明细**同一编辑会话**：保存一次提交两者，撤销一起回退；
- **切换主记录 / 翻页 / 查询 / 关闭前**若有未保存明细改动 → 守卫阻止并提示（现有 `LEGuard` 挂在 `cdsMain` 的
  Before* 上，需再加 `cdsDetailed` 的守卫）；
- **层级权限**：明细不单独过滤（跟随主记录）；主记录范围外的写操作仍由批次二的行权限复核拦下；
- **审计字段**：第一批只作用于**主记录**；明细不做审计填充（需要的话告诉我，mtDetail 有从表"记录编号"那类规则）。

### 7.8 导入收敛为"明细的文本/Excel 导入（初版）"

从表有了以后「导入」有两个目标，建议第一批只做**明细导入（文本/Excel）**：导入的行进入**当前主记录的明细区**
（未保存，随保存一起提交），复用宿主已有 `ImportText` / `ImpExcel` 入口。
"**从别的模块/查询窗体多选记录导入明细**"（mtDetail 的导入窗体那套）需要 LE 支持模态打开来源模块
（`GetWebSubForm`/`DelWebSubForm` + 桥对象），LE 目前没有这套桥 → **单独一轮**再做。
主表批量导入（方案 B：多条未保存主记录）建议**第一批不做**，它与"多条未保存行"的状态机扩展绑定，
需要时与 S2 的明细暂存一起设计。

## 8. S2 验收骨架（实施后逐项给结论，格式同 mtDetail D01–D25）

数据：主记录 A（2 条明细）、B（1 条明细）、C（无明细）；明细含"值互不相同"的两列用于校验字段错位。

| ID | 场景 | 客观通过标准 |
|---|---|---|
| E01 | 配置往返 | 从表结构/关联字段/明细编号/从表唯一/从表非空/隐藏字段 保存后重开不丢 |
| E02 | 主记录切换 | A→B→C 切换，明细区不串数据；C 显示空表且明细按钮按可用性收敛 |
| E03 | 明细新增行 | 父键=当前主记录；行号按规则取；新行可编辑并可保存 |
| E04 | 明细删除行 | 新增未保存行直接移除；已存在行按 DELTA 提交删除；取消不删除 |
| E05 | 复制行 | 复制当前行到其后：字段照规则复制、父键=当前主记录、行号重取、主键不复制 |
| E06 | 明细行号重编号 | 删除/复制后按已确认规则重编号，不出现重复/空洞（若约定无空洞） |
| E07 | 从表唯一/非空 | 当前主记录内比较；失败提示带明细行号；修正后可继续保存 |
| E08 | 原子提交 | 主表或从表任一失败：两者都不得留下半条数据；重试可继续 |
| E09 | 提交成功刷新失败 | 明确"已保存成功"，禁止重复提交，重载后恢复 |
| E10 | 结果不确定 | 提示核实，不自动重提，可按主键核对 |
| E11 | 未保存时切行/翻页/查询/关闭 | 守卫阻止并提示；不得静默丢弃或把明细带到别的单据 |
| E12 | 校验失败保留编辑 | 主记录与明细的输入都保留，焦点/提示按行号定位 |
| E13 | 权限 | 主记录范围外的写操作被拦；明细不因直接键值访问而写入 |
| E14 | 审计与层级权限共存 | 主记录审计填充、部门只读、写时复核与批次二一致 |
| E15 | 只读/无写按钮 | 明细区只读；明细按钮不可用 |
| E16 | 导入（明细，文本/Excel） | 行进入当前主记录明细区、未保存、可撤销、随保存提交；错误行可查看 |
| E17 | 生命周期 | 连续三次打开/生成/关闭无空白窗、无重复销毁、无新增可归因泄露 |
| E18 | 旧模板回归 | 批次一~三已验收功能（记录区布局/审计/权限/导出打印附件）在含从表的配置下仍成立 |


### 7.9 追加需求（2026-09-20 用户提出）：从表的唯一字段与自动编号

用户要求：**从表也要有自动编号**，并**为从表增加一个唯一字段**。归入"明细写入"片，与「明细编号」(3001)、
「从表唯一」(3002) 一起开放（当前这两项目录项**故意未对 mtListEditor 开放**，避免"配了不生效"）。

| 项 | 初版约定（可按你意见调整） |
|---|---|
| 从表唯一字段 | 明细自己的主键（单字段）或当前主记录内的组合唯一字段；用于定位与重复校验 |
| 从表自动编号 | 初版按**明细表内 MaxInt 递增**（与主表 MaxInt 同一套写法；并发冲突由数据库唯一约束兜底、失败可重试） |
| 作用范围 | 编号＝**整张从表唯一**（明细主键通常全表唯一）；"当前主记录内唯一"仍由「从表唯一」负责，两者不混用 |
| 与父键的关系 | 父键回填（关联从表）与明细主键是两件事：新增明细行时父键取当前主记录，明细主键由编号规则生成 |
| 需要你确认的 | 是否也要 `Guid`/`DateTimeRandom`；编号字段是否显示在明细区（可隐藏）；是否要求"当前主记录内重编号"（如行号） |

## 9. 明细写入片实施清单（下一轮照单执行，2026-09-20 登记）

> **执行细节见附件** [`MTLISTEDITOR_WRITE_SLICE_DESIGN_20260920.md`](MTLISTEDITOR_WRITE_SLICE_DESIGN_20260920.md)：
> 那里写了要替换哪几个函数、生成的脚本骨架长什么样、每步的三绿门。
> 上一轮失败的原因是按文本块切改生成器（patch 脚本）——**本轮一律整函数替换**。

第一片（只读联动）已宿主验收通过。写入片按下列顺序做，每步可独立编译/验证：

1. **数据可写**：`cdsDetailed` 由查询式数据集改为"取数 + 可编辑"（保留 `LEDetailLoad` 取数路径）；
   明细区表格去掉只读、列保持按字段映射（不按序号）。
2. **明细区按钮**：`btDetailAppend` / `btDetailDelete` / `btDetailCopy`（新增行/删除行/复制行），放在明细区标题旁的独立小工具条；
   `复制行` 是**新目录项**（分组按建议放 **Editor Group**），只对 mtListEditor 开放；三者只在"主记录编辑态或浏览态允许的时机"可用（见第 6 条）；
   事件入口内部一律先 `if not btXxx.Enabled then Exit;` 守卫。
3. **父键回填**：`cdsDetailed.BeforePost` 把「关联从表」字段填成当前主记录的「关联字段」值；主记录主键为空时不落库（保持新增态）。
4. **明细唯一字段 + 自动编号**（§7.9）：新增明细行时按明细表内 `MaxInt` 取号（可隐藏、不可手工改）；唯一字段用于定位与重复校验。
5. **行号**：如需行号列 → 删除/复制后**重新编号**，行号**不参与**从表唯一校验。
6. **校验**：从表非空（按**明细行号**报第几行）、从表唯一（**当前主记录内**比较），失败保留输入与编辑态；
   与主记录校验的先后：先主记录必填/唯一，再从表明细逐行校验（报错带行号）。
7. **原子提交**：保存流程改 `UGMM.ApplyUpdatesCds(cDataNodeName, [cdsMain, cdsDetailed])`；
   保留四类分支（校验失败保留编辑、提交失败可重试、提交成功刷新失败不重复提交、结果不确定先核实）；
   撤销 `Cancel + CancelUpdates` 同时作用于两个数据集。
8. **删主记录连明细**：单事务脚本（`delete from <从表> where <关联从表> = :key` ＋ `UGMM.ExecSqlSeparator` ＋ `delete from <主表> where <主键> = :key`），
   与 mtMasterSlave 一致；**明确不做**其它表的级联。
9. **守卫与状态机**：明细数据集也挂 `BeforeScroll/BeforeClose/BeforePost/BeforeDelete` 守卫；
   切主记录/翻页/查询/关闭前若有未保存明细改动 → 阻止并提示（复用 `LEGuard` 语义）；
   新增主记录时明细可先暂存（父键在保存前由第 3 条回填）。
10. **拒绝项**：`DBAutoincrement` 主键 + 从表 → 明确拒绝（提示改 MaxInt/Guid）；明细的查找/多列下拉 → 明确拒绝。
11. **精灵侧随功能开放**（不提前开放）：`明细编号`(3001)、`从表唯一`(3002)、`从表非空`(3003) 的适用模块加 mtListEditor；
    新增 `复制行` 目录项。
12. **测试**：明细区按钮/父键回填/取号/行号/唯一·非空/原子提交/删主记录连明细/守卫 各一组探针断言 +
    一个 `list-editor-detail-write` 运行 profile（主 A 2 条、B 1 条、C 无明细；含删除与撤销分支）；
    编译闸门沿用；对照 §8 的 E01–E18 逐项给结论。

### 9.1 写入片进度（2026-09-20 第一轮）

> **2026-09-20 第三轮更新（见 §9.4）：计划侧已按下面的配置形状重做并立住契约；生成侧仍待接通。**
> 第一轮做过的计划侧代码在回退中丢失（回退取的证据副本是只读片那版），本轮按宿主既有设置项形状重做。

已完成（本地验证；**尚无用户可见能力**，因为写入路径还没接通）：

| 步骤（对应 §9） | 状态 |
|---|---|
| 3/4 的计划侧：明细**唯一字段**（`记录编号` 的 `cbField`）+ **编号方式**（`MaxInt`/`Guid`，含前后缀/补位）+ 父键字段 | 已解析并入计划对象 |
| 10 的拒绝项：`DBAutoincrement` + 从表 → 明确拒绝（理由写明"明细必须在提交前带父键与主键才能原子提交"）；`记录编号` 非 MaxInt/Guid → 拒绝；编号字段不在已勾选从表字段 → 拒绝 | 已完成并有拒绝用例 |
| 顺带修掉：解析器里 `AutoJSON` 未初始化就无条件释放 → 生成器 AV（被测试套件在提交前抓到） | 已修复 |

未完成（下一轮）：§9 第 1~8 步的**生成侧**（明细数据集可写、明细区三按钮与工具条、父键回填运行时、取号运行时、
原子提交 `ApplyUpdatesCds([cdsMain,cdsDetailed])`、撤销同时作用于两个数据集、删主记录同事务连明细、守卫），
以及 §9 第 11 步（精灵侧开放 `记录编号`/`明细编号`/`从表唯一`/`从表非空` 与新增 `复制行` 目录项）
与第 12 步（`list-editor-detail-write` 运行 profile 与 E01–E18 逐项结论）。

**当前状态说明（避免误用）**：写入模式 + 从表仍然被**明确拒绝**（提示"从表写入将在下一批接入"），
所以不会出现"半可写"的模块；`记录编号`/`明细编号`/`从表唯一`/`从表非空` 也**仍未**对 mtListEditor 开放，
不存在"配了不生效"的设置项。全量 `tests/*.py` 81 通过 / 0 失败。

### 9.2 写入片第一次尝试的复盘与回退（2026-09-20 第二轮）

生成侧（§9 第 1~8 步）这一轮**没有做成**，过程与结论如实记录：

1. 用 `tools/patch_write_slice_1..9.py` 逐段改 `ListEditorTemplate` / `ListEditorWrite`，中途改坏了
   `btSaveOnClick` 的提交块（生成脚本报 `'FINALLY' or 'EXCEPT' expected862:3`，`ListEditorWrite` 自身
   也变成 Delphi 语法错误）。为保住"能编译的树"做了回退，但**回退取的证据副本取错了版本**
   （写入单元取了批次二那份，丢了批次三的导出/打印/附件），导致 4 个套件变红。
2. 修完回退后定位到两个**真实缺陷**（都在生成侧，都会进宿主 DLL），已修并留了回归门：
   | 缺陷 | 根因 | 现状 |
   |---|---|---|
   | 所有前置拒绝路径在退出时 Access violation（读 `0xFFFFFFFFFFFFFFFF`） | `DetailPlan` 未初始化的局部指针，被统一 cleanup 无条件 `Free` | 已在函数开头 `DetailPlan := nil`；四个生成探针退出码恢复 0 |
   | 「只读列表 + 配了审计字段」被静默接受 | 审计字段从克隆里摘掉后，原本由 `mtMultiple` 给出的"需要写回按钮"校验一并消失，写入侧又只在 `WriteMode` 时校验 | `ListEditorTemplate` 自己给出同义拒绝（`录入部门` 除外，只读下它是层级权限的查询过滤） |
3. 全量恢复绿灯：`tests/*.py` **81 通过 / 0 失败**，`tests/test_recovery.py` 退出码 0。
4. 教训（已写入 `DEVELOPMENT_HISTORY.md` §5）：统一 cleanup 用的指针要在**所有退出点之前**置 nil；
   复用别的生成器并从中摘字段时，必须逐条确认"这些字段原本由谁校验"并自己补上；
   这类缺陷断言全过、消息全对，**只有探针退出码能抓到** —— 所以探针测试必须断言 `returncode == 0`。
5. 因此下一轮重做写入片时：**不要再用 patch 脚本切代码块**（提交块就是被这样切坏的），
   直接整函数替换；并且每一步都先确认 `build-win64.bat` + `build-list-editor-probes.bat` + 全量套件三绿再往下走。

### 9.3 这两处缺陷在"已交付 DLL"里（已核实）

不是"新引入"：把 `deployment/list-editor-detail-readonly-20260920/evidence/ugConfiguration.ListEditorTemplate.pas`
放回 `src/` 重建探针，`ListEditorAuditProbe` 与 `ListEditorOutputProbe` 立刻复现（前者
`FAIL 无写按钮时审计设置未被拒绝`，后者退出时 AV）—— 也就是说**上一包交付给宿主的那份 DLL 源码就带这两处缺陷**。

判定依据（DLL 哈希在两次构建之间不可复现，因为 PE 元数据/时间戳会变，**大小可判定**）：

| 构建 | 大小 | 说明 |
|---|---|---|
| 干净构建"未修复快照" | **4144640** | 与交付 DLL（`3800C975E0DBDBD9D4958761FE727AE25A846DDF9E6BFAB4A4A54DFF26C8AFC6`）**完全同尺寸** |
| 干净构建"含这两处修复" | **4145152** | 本修复包 |

故已另出隔离修复包 `deployment/list-editor-reject-fix-20260920/`（DLL + README：范围/未测/哈希/复测步骤/更新步骤），
**专门等宿主复测**：①只读+导出按钮应"明确拒绝且不吐 AV"；②只读+审计字段应被拒绝；③层级权限的只读组合不受影响。
写入片（§9 第 1~8、11、12 步）仍待下一轮。
**宿主已复测通过**（用户 2026-09-20 反馈"第1项复测修复包 测试通过"），底座确认干净，写入片在其上继续。

### 9.4 写入片第三轮：计划侧完成（2026-09-20，生成侧仍待接通）

按执行附件 §2 的清单，本轮完成**配置解析与校验**这一半（`ugConfiguration.ListEditorDetail.pas`），
配置形状全部对齐宿主既有设置项（先读了精灵目录 3000~3003 与 `mtMasterSlave` 的读取代码，不自己发明键名）：

| 设置项 | 形状（与 mtMasterSlave 同一套） | 本模板语义 |
|---|---|---|
| 记录编号（3000，从表结构分组） | JSON：cbField + cbAutoNumberType + edPrefix/edSuffix/seDigitCapacity | **明细行的自动编号**（MaxInt/Guid），字段必须属于**从表**；隐藏列、不可手工改 |
| 明细编号（3001） | 单个从表字段（带别名） | **行号列**：同一主记录内 1..N，删除/复制后重排，**不参与从表唯一** |
| 从表唯一（3002） | JSON：cbField + cdsMultiSelectFields（分号分隔） | 组合唯一，**在当前主记录内**比较 |
| 从表非空（3003） | 分号分隔字段清单 | 必填校验，报错带**明细第几行** |

拒绝项（每条都有用例）：记录编号指向主表字段；编号方式不是 MaxInt/Guid（含 DBAutoincrement、
DateTimeRandom）；MaxInt 用在非数值列；明细编号与记录编号/关联从表同列或非数值列；
从表唯一/非空含非从表字段；从表唯一含行号或父键（两者在同主记录内恒定，放进唯一组合等于没校验）；
从表唯一不是合法 JSON；**主键=数据库自增 且配置从表**（父键提交前拿不到）；只读列表下配置任一写入项。

顺带修掉一个会在宿主里暴露的问题：「记录编号」属于从表设置，但复用的 `mtMultiple` 生成器不认识它，
之前没从克隆里摘掉 → 写入夹具生成时报 `mtMultiple 首批尚未实现常规设置：记录编号`。现在随其它从表设置一起摘除。

改动与防线：

- `TListEditorDetailPlan` 增 `KeyField/KeyType/KeyPrefix/KeySuffix/KeyDigits/DetailNoField/UniqueIDField/RequiredFields/UniqueFields`；
  `TryPlanListEditorDetail` 增 `AWriteMode` 参数（只读下配置写入项要拒绝）；`ListEditorTemplate` 调用点同步。
- 新探针 `tests/ListEditorDetailPlanProbe.dpr`（直接调解析函数，**不需要打开生成侧闸门**就能立契约）
  + 新测试 `tests/list_editor_detail_plan.test.py`（10 组，含全部拒绝用例与"只读配置不受影响"回归）。
- **明细区面板两版式**（块 A 的界面半边）：`AddListEditorDetailPanel(..., AWritable)` —— 可写版式＝
  标题右侧小工具条（`btDetailAppend`/`btDetailDelete`/`btDetailCopy`，标题用 `#NNN` 不包引号）+ 网格去掉
  `ReadOnly` 并带 `dgEditing`；只读版式与批次四逐项一致。同一探针加 `panel` 模式断言，
  新测试 `tests/list_editor_detail_panel.test.py`（可写/只读两版式 + 隐藏列 + 中文标题编码）。
  模板当前仍以 `False` 调用（写模式+从表在闸门处被拒），所以**不会**出现可编辑明细区却没有写入脚本的中间态。
- 夹具 `fixtures/list-editor/detail-write-20260920.json` 重做：从表 `Basic_UnitItem(b)` 字段为
  FItemID(明细编号)/FLineNo(行号)/FUnitID(父键)/FItemCode/FItemName/FQty/FItemNote(隐藏)。
- **明细写入脚本生成器**（块 A/B/D 的脚本半边）：`AddListEditorDetailWriteScript` 生成
  `LEDetailGetMaxKey`（MaxInt 取号，Guid 模式不生成）/ `LEDetailPrepare`（保存前统一补齐父键、自动编号、行号）/
  `LEDetailRenumber` / `LEDetailCheck`（非空按行号报错 + 当前主记录内行间比较的组合唯一）/
  `LEDetailAppendRow` / `LEDetailCopyRow` / `LEDetailDeleteRow` + 三个 `btDetail*OnClick` 入口 /
  `LEDetailBeforePost`（落库前补父键）/ `LEDetailGuard`（编辑未提交不许滚动关闭）。
  刻意不用 for-in、TBookmark、TStringList（宿主 FastScript 环境），唯一性比较用 RecNo 回到原行。
  新测试 `tests/list_editor_detail_write_script.test.py`（语句齐备 / 定义顺序满足先定义后调用 / Guid 模式）。
- 顺带修掉两处会被误伤的校验：①「主键=数据库自增 + 从表 → 拒绝」原先没带写模式条件，会把**只读联动 +
  自增主键**（批次四已验收组合）判死 —— 现在只在写模式生效，并有专门回归用例；
  ②「记录编号」属于从表设置，之前没从克隆里摘掉，导致宿主报 `mtMultiple 首批尚未实现常规设置：记录编号`。
- 全量 `tests/*.py` **84 通过 / 0 失败**，`test_recovery.py` 退出码 0，DLL/探针构建 0 错误。

**本轮踩到并修掉的两个坑（都值得记）**：

1. `Release` 在**成功路径**把计划一起释放了（我先把失败/成功两条出口都指向同一个 Release），
   调用方拿到悬空指针 → 探针立刻 AV。教训与 §9.2 那条同族：**统一收尾函数不能释放"要交接给调用方"的对象**，
   成功/失败两条出口必须分开（`ReleaseTemps` vs `Release`）。
2. 注释里写 `{cbField, cdsMultiSelectFields}` 会把 `{}` 注释**提前闭合**（Delphi 报 `Illegal character '}'`），
   说明性文字里不要出现成对花括号。

**2026-09-20 第四轮：写入片生成侧已接通并交付宿主测试**（包 `deployment/list-editor-detail-write-20260920`，DLL `B3087378…`）：

- 写入单元接线：明细写入脚本插在 `btSaveOnClick` 之前、三个明细按钮事件与数据集守卫绑定、
  `ChangeCount` 同时看两个数据集、提交改 `UGMM.ApplyUpdatesCds(cDataNodeName,[cdsMain,cdsDetailed])`、
  撤销/关闭同时 Cancel 两个数据集、删主记录改单事务连明细、`LERefresh` 收敛三个明细按钮。
- 模板：去掉「写模式+从表」闸门、以 `WriteMode` 调面板、**给明细网格补回 `dgEditing`**
  （模板末尾会全量剥离它；记录区编辑走记录区控件，所以主表格保持剥离）。
- 精灵侧：记录编号(3000)/明细编号(3001)/从表唯一(3002)/从表非空(3003) 对 mtListEditor 开放。
- **契约更新（不是删断言）**：`list_editor_detail.test.py` 里"写模式+从表必须被拒绝"改为正面契约
  `test_detail_write_contract`（可编辑明细网格 / 三按钮与守卫事件 / 补齐校验 / 两数据集算变化 / 原子提交 / 删主记录连明细）；
  `normal_setting_mtdetail_alignment.test.py` 里"写入片三项暂未开放"改为"已开放"。
- 编译闸门替身补了三个宿主成员：`RecNo`（据已验收的 mtTree 生成产物确认宿主有）、`UGMM.ApplyUpdatesCds`、
  `UGMM.ExecSql/ExecSqlSeparator`；生成脚本里改用直接比较而不是 `SameText`、不调 `CanFocus`（宿主脚本环境没有这两个）。
- 本地：DLL/探针 0 错误、全量 **84 通过 / 0 失败**、**生成脚本过编译闸门**。
- **未做**：运行 profile（端到端按钮/保存/删除断言）与宿主验收；明细三按钮未做目录项（随"写模式+从表"一起生成）。

**2026-09-20 第五轮：宿主第一轮反馈的三条已修**（包 `deployment/list-editor-detail-write-fix1-20260920`，DLL `A6D71564…`）：

| 宿主反馈 | 根因 | 修复 |
|---|---|---|
| 空明细行保存报 `Blocking method Execute() could not be called.`，随后提示 `gridMain:…请先保存或撤销当前编辑。` | "新增行"把行留在**未落库的插入态**；保存时服务端 `Post` 一条客户端从未见过的插入行，UniGUI 需要客户端同步 → 该 blocking 报错；报错后编辑态未退，后续操作撞主记录守卫（提示本身正确） | 改用同族 `mtMasterSlave` 的**空白占位行**模型：新增行**当场落库**（Append + 补父键 + 行号 + Post）；保存时**丢弃空白占位行**（只丢本次会话新增/改动的），不再对它做必填校验；配了「从表非空」且无有效明细时才提示 `请录入至少一条有效明细。` |
| 连续"新增行"被拦（`gridDetail:…请先提交或取消当前明细行的修改。`） | 明细数据集挂了 `BeforeScroll/BeforeClose` 守卫，而未落库的插入行会让第二次新增触发滚动 | 去掉明细的 `BeforeScroll/BeforeClose` 守卫（同族也没有）；空白行当场落库后不再存在"未提交的明细行"状态。`BeforePost`（补父键）保留 |
| 明细区三按钮被网格盖住；要求明细区 `alRight` | 标题/工具条是绝对定位，网格是 `alClient` → 被盖住 | 明细区 `Align = alRight`（宽 480）；标题与工具条放进 `alTop` 头部容器 `pDetailHead`（两者都 `alLeft`），网格 `alClient` 在头部下方 |

顺带把组合唯一的报法对齐同族：`第 N 行明细的组合唯一字段 [字段=值, …] 与第 M 行重复，请修改后重试。`（只校验有内容的行）。
编译闸门替身补了 `usModified` 常量（`mtMasterSlave` 的已验收脚本也用它）。契约测试同步更新（面板加 alRight/头部容器断言；
脚本契约断言"无明细守卫"、占位行判据、`请录入至少一条有效明细`）。全量 **84 通过 / 0 失败**、生成脚本过编译闸门。

**2026-09-20 第六轮：宿主第二轮反馈（明细非空校验保存报 Blocking method）**

现象：明细区新增行后只填一个非空字段、另一个留空 → 保存报 `Blocking method Execute() could not be called.`，
随后提示 `gridMain:TUgDBGrid:请先保存或撤销当前编辑。`（配置已固化为 `fixtures/list-editor/detail-write-host-20260920.json`）。

根因：**不是非空判断写错**，而是校验失败的提示方式不成立 —— 生成的 `WaitEditorError` 用 `errorAlert.Execute`
（阻塞模态），而用户在明细网格里刚编辑过单元格就点保存，客户端还挂着未提交的网格编辑；宿主在该状态下
**拒绝阻塞调用**，于是阻塞报错先抛出、校验提示反而没出来，编辑态也没退。对照同族 `mtMasterSlave`：
它的保存失败一律 `RaiseException` 交回宿主，从不自己弹框。

修复（两条分开，避免动到已验收行为）：

1. 新增 `LEDetailFlushRow`（落库明细网格里正在编辑的那一行），在 `btSaveOnClick` 开头、任何提示框之前调用；
2. **明细**校验失败打 `LEDetailError` 标记后 `RaiseException(ExceptionMessage)` → 由宿主标准错误框显示；
   **主记录**校验/行权限失败保持原来的 `WaitEditorError` + 保持编辑态（运行 profile 有断言，一起改会红）。

第一次尝试把整个 except 都改成交回宿主，`list_editor_audit` 的运行 profile 立刻变红（主记录行权限路径被改）——
所以最终按"分流"落地，并把这条分流写成断言（`tests/list_editor_detail_write_host_config.test.py`）。
顺带：明细"空行 + 从表非空"现在明确提示 `请录入至少一条有效明细。`（不再含混地报"数据没有变化"）。
本地：全量 **85 通过 / 0 失败**、你那份配置生成的脚本过编译闸门。包 `deployment/list-editor-detail-write-fix2-20260920`（DLL `40D2C7FF…`）。

**2026-09-20 第七轮：宿主第三轮反馈（1/2/4 条；第 3 条宿主确认第 2、3 项通过）**

| 反馈 | 根因 | 修复 |
|---|---|---|
| 校验提示之后又弹 `gridMain:TUgDBGrid:请先保存或撤销当前编辑。` | 上一轮把明细校验失败改成抛异常；异常从保存处理抛出后，框架还会再碰主数据集（刷新/同步），此时编辑态仍在 → `LEGuard` 按设计再抛一次 | 明细校验失败改用 **`ShowActionError`（宿主里是非阻塞 `Show`）** + `Exit`：不弹阻塞模态、也不抛异常出去，因此不会再触发守卫提示。主记录路径不变 |
| 删除报 `Access violation … FireDACCommon260.bpl. Read of address 0x40`，但记录已删 | 宿主的多语句事务入口 `UGMM.ExecSql` **可能在已提交之后才报错**（同族 mtMasterSlave 处理过同类的 `CANNOT ROLLBACK - NO TRANSACTION IS ACTIVE`） | 删除失败时用新生成的 `LERecordExists(表, 键字段, 键值)` 复核：**主表与从表都查不到即视为删除成功**，只有一边还在才报失败 |
| 布局（宿主指定） | — | 无从表：`gridMain = alClient`；有从表：`gridMain = alLeft`、`pListEditorDetail = alClient`、**不生成 `capListEditorDetail`**、`pDetailHead.Height` 与 `pButtons.Height` 一致（新增 `ApplyDetailLayout`，从 DFM 读实际值回填 33，不写死） |

新增断言：删主记录复核（主表+从表两条 `LERecordExists`）、有从表时 `gridMain = alLeft` 与
**头部高度 == pButtons 高度**、面板 `alClient` 且无标题标签；无从表模块仍 `alClient`（`control-types` 夹具实测）。
本地：全量 **85 通过 / 0 失败**、生成脚本过编译闸门。包 `deployment/list-editor-detail-write-fix3-20260920`（DLL `21359C9B…`）。

**2026-09-20 第八轮：宿主第四轮反馈（先弹图1、再弹校验提示）**

顺序说明触发者不是校验逻辑：图1（`gridMain:TUgDBGrid:请先保存或撤销当前编辑。`）**比校验提示还早**，
来自挂在主数据集上的 `LEGuard`（`cdsMain.BeforeScroll/BeforeClose/BeforePost/BeforeDelete`）。
在明细网格里编辑后点保存时，框架先提交明细的网格编辑、并顺带碰一下主数据集 → 守卫误报。

修复：**移除数据集事件守卫**（绑定与例程都去掉）。依据：同族已验收的 `mtMasterSlave` 没有这种守卫，
只在按钮处理里显式检查 `vEditing`；本模板面向用户的入口本来就按状态拦住（编辑态下 `gridMain.Enabled=False`、
`pPages.Enabled=False`，查询/删除/关闭/新增/修改各有 `LEState` 检查，`dsMain.AutoEdit=False` 阻止隐式提交），
所以不会因此丢输入。新增断言：生成的脚本与 DFM 里不得再出现 `LEGuard` 与 `cdsMain|<This>.BeforeScroll…`。
本地：全量 **85 通过 / 0 失败**、生成脚本过编译闸门。包 `deployment/list-editor-detail-write-fix4-20260920`（DLL `C50062A6…`）。

**2026-09-20 第九轮：宿主第五轮反馈（明细被刷新掉 / 浏览态可编辑 / 新增行后按钮仍灰）**

| 反馈 | 根因 | 修复 |
|---|---|---|
| 校验提示后明细被刷新掉或刷回原值 | `LEDetailLoad` 绑在 `cdsMain.AfterScroll` 上**无条件重载**；报错后框架再同步主数据集 → AfterScroll → 明细被重查，用户刚新增/编辑的行被冲掉 | `LEDetailRefresh` 加 `if cdsDetailed.Active and (cdsDetailed.ChangeCount > 0) then Exit;`（**有未提交改动就不重载**）。判据用 ChangeCount 而非 `LEInternal/LEState` —— 后者只在写模式声明，只读模块引用会编译不过（编译闸门当场抓到） |
| 非修改状态下明细表还能编辑 | 明细网格可编辑性只写了 DFM 初始值，没随编辑态切换 | `LERefresh` 里 `gridDetail.ReadOnly := LEState <> 1;` |
| 新增一行后"删除行/复制行"仍是灰的 | 按钮可用性在 `LERefresh` 里算，而新增行后没有重算 | 三个 `btDetail*OnClick` 末尾都 `LERefresh;` |

本地：全量 **85 通过 / 0 失败**、生成脚本过编译闸门（含只读明细模块）。包 `deployment/list-editor-detail-write-fix5-20260920`（DLL `89A2FE6B…`）。

**2026-09-21 第十轮：宿主第六轮反馈（表格序号覆盖所有表格 + 工具栏分隔线/图标/布局对齐 mtDetail）**

| 反馈 | 修复 |
|---|---|
| 启用「表格序号」时窗体上**所有**表格都要开序号 | 明细表格**镜像主表格的实际取值**（主表格 Options 里有 `dgRowNumbers` 就给明细表格加上），不另读配置，保证一致 |
| 顶部工具栏要分隔线；附件/展开查询没图标；布局与分隔对齐 mtDetail | 新增导出函数 `RelayoutListEditorToolbar`（由模板在 `AddListEditorPresentation` **之后**调用 —— 「展开查询」是那一步插进工具条的，重排必须能看到它，否则同名重复），按原版参考件（`fixtures/list-editor/user-reference-20260917.dfm`，与 mtDetail 同表）重排：查询｜新增 删除 修改｜保存 撤销｜导出 打印｜附件 展开查询｜关闭；组间插 1px 分隔面板（`tabEditorGroup`/`tabAppendUpdateGroup`/`tabOutputGroup`/`tabAnnexGroup`/`tabFormGroup`，宽 1、色 9211020、上下 Margins 5）；图标位 查询0 新增7 删除8 修改9 保存11 撤销12 导出16 打印17 附件18 关闭23；步进＝按钮宽+6、分隔后再+7（与原版 Left 值逐项一致）。「展开查询」用查询图标(0)——原版没有这个按钮、也找不到专用图标位，不猜索引 |

本轮踩到并修掉的坑：把发射块从写入单元搬走时**留下了旧的插入循环**，而那时 `Extra` 里装的是脚本文本
（`Code.AddStrings(Extra)` 之后未清），于是把脚本原文插进了工具条面板 —— DFM 结构校验（`ObjectTextToBinary`）
报 `Identifier expected` 当场拦下。另外 `TStrings.DeleteRange` 在 Delphi 10.3 不存在，按块长度循环删。
本地：全量 **85 通过 / 0 失败**、DFM 结构校验 + 编译闸门通过。包 `deployment/list-editor-detail-write-fix6-20260921`（DLL `9A77A470…`）。

**2026-09-21 第十一轮：宿主反馈"查询条件标题中文乱码"**

根因：查询区控件由 `ugConfiguration.MultipleQueryControls.pas` 生成，它的 `Quoted()` 只做 `QuotedStr`
引号包裹、**不把非 ASCII 转成 DFM 字符码** → `FieldLabel = '数据类型'` 这种写法宿主按 DFM 文本编码解析成乱码
（其它模板和列表编辑器自己的标题都写 `#NNN`，所以只有查询区乱）。

修复：`Quoted()` 改成 DFM 正确形式（ASCII 引号包裹、非 ASCII/控制字符写引号外的 `#NNN`），
纯 ASCII 输出逐字符不变（既有 mtMultiple 模块生成结果不受影响）。修完是 `FieldLabel = #25968#25454#31867#22411`。

过程中的教训：我先误改了列表编辑器自己的两处标题（记录区 `Caption`/`FieldLabel`），而那两个循环里的
`Captions[I]` **本来就是已编码文本**，再套一层 `Enc` 变成二次编码 —— 探针当场报"复选标题应写入 Caption"、
"标题为空时应回退到排版标题"。已撤回。**教训：给属性值加编码前，先确认那个变量是明文还是已编码**
（同文件里同名数组可能一个明文一个已编码）。

新增通用防线：`tests/list_editor_detail_write_host_config.test.py` 断言**生成 DFM 的属性区不得出现原始非 ASCII**。
本地：全量 **85 通过 / 0 失败**。包 `deployment/list-editor-detail-write-fix7-20260921`（DLL `3C8DFD2C…`）。

**2026-09-21 第十二轮：图标列表对齐 mtDetail + 展开查询图标（宿主指定）**

- 内嵌模板的 `Imgs.IconText` 只有 14 项，而工具栏索引（导出16/打印17/附件18/关闭23）是按 mtDetail 的
  **27 项**定的 → 不换列表这些索引指到界外（"附件没图标"的根因之一）。现在生成时把 `Imgs.IconText`
  整体替换成 mtDetail 参考件的 27 项（顺序原样），并追加宿主指定的 `icon iconfont icon-pingmufangda`
  作为第 28 项（**索引 27**，`btToggleQuery` 用它）；追加在末尾所以既有索引一个都没动。
- 实现：`ApplyDetailIconList`（列表编辑器写入单元，`RelayoutListEditorToolbar` 调用前先跑），
  图标类名以常量形式内嵌（注明来源是 `fixtures/reference/mtDetail.dfm`），并逐项断言防回归。
- 包 `deployment/list-editor-iconlist-fix8-20260921`（DLL `B48354FE…`）；全量 **85 通过 / 0 失败**。


**2026-09-21 第十三轮：明细区 7 个行按钮（按钮目录项）——已交付**

功能按钮页新增分组 **Detail Row Group（明细行功能）**：`btDetailAppend/Insert/Delete/Copy/MoveUp/MoveDown/Clear`
（标题 新增行/插入行/删除行/复制行/上移/下移/清空），**只发射勾选的**。实现要点：

- 生成侧：`AddListEditorDetailPanel` / `AddListEditorDetailWriteScript` 增 `AButtons` 参数（勾选集合）；
  事件绑定与按钮可用性也按勾选生成；一个都没勾就不发工具条。
- 新做 4 个操作：**插入行**（`TDataSet.Insert` 在当前行前插占位行，表为空时等价新增）、
  **上移/下移**（与相邻行**交换业务字段值**，记录编号/父键留原位，行号重排）、
  **清空**（确认后删当前主记录全部明细行，保存时才落库）。
- 三条拒绝（勾了不生效一律拒绝）：只读列表下勾；未配从表；配了写入却既没勾新增行也没勾插入行。
  （第三轮里我把"未配从表"误写成查主表 `Tables`，测试当场抓到 → 改查 `TWebDetailedStructure`。）
- 图标位：7/1/8/2/20/21/25（插入/复制/清空在 mtDetail 的 27 项里没有语义对应，暂取最接近的，待宿主给类名）。
- 目录项的适用列表**只放 mtListEditor**：mtMasterSlave 的明细区还没有行按钮，放进去会"配了不生效"。
  **待用户确认**是否要给 mtMasterSlave 的明细区也加这 7 个按钮（它已验收，属于改动已验收行为）。
- 本地：全量 **85 通过 / 0 失败**、DFM 结构校验 + 编译闸门通过、新增"勾选生效/三条拒绝"断言。
  包 `deployment/list-editor-detail-buttons-20260921`（DLL `1FFCB9F7…`）。

**2026-09-21 第十四轮：mtMasterSlave 也加这 7 个按钮 + pDetailBar 宽度修正**

- 目录项 `Detail Row Group` 的适用列表改为 `mtListEditor;mtMasterSlave;`；mtMasterSlave 的
  `AllowedButtons` 也放行这 7 个名字（它有独立的按钮白名单）。
- mtMasterSlave 工具条：记录区 alTop、明细网格 `gridDetailed` alClient → 工具条也 alTop 并**插在网格之前**；
  行操作沿用它的模型（`AppendDetailBlankRows` 那套：空白占位行当场落库、父键当场补齐、`RenumberDetails` 排行号）；
  按钮可用性在 `SetEditState` 里按勾选刷新；事件与其它按钮同一条通道绑定。
- **pDetailBar 宽度**：按钮 AlignWithMargins 除 Width(64) 外还吃左右边距各 3，容器原按 68/个算 → 第 7 个被裁。
  改为 `按钮数 × 70 + 8`（7 个 = 526），并显式写 `Margins.Left/Right = 3`。
- 本轮自己踩的两个坑（都被闸门/测试抓到）：① `var C0, C1; D0, D1: Variant;` 不是合法 Pascal
  （mtMasterSlave 这条链路没有脚本格式化器兜底，列表编辑器那边有）→ 合并成一条声明；
  ② 明细行操作的发射调用插到了 `RenumberDetails` 的 `if` 块**内部** → 生成"例程套例程"，移到块外。
  另外 `build-masterslave-probes.bat` 原来没编译 `MasterSlaveTemplateProbe`（探针是 9-08 的旧二进制），已补上。
- 本地：全量 **86 通过 / 0 失败**（新增 `tests/master_slave_detail_buttons.test.py`：工具条在网格之前、
  7 个按钮与图标位、事件绑定、7 个行操作、勾选控制、**脚本过宿主编译闸门**）。
  包 `deployment/ms-detail-buttons-20260921`（DLL `FF1357F5…`）。

**2026-09-21 第十五轮：明细行按钮图标按宿主指定类名**

宿主给出三个类名：复制行 `icon iconfont icon-fuzhi`、插入行 `icon iconfont icon-caidanshouqi`、
清空 `icon iconfont icon-guanbi2fill`。做法：连同上一轮的 `icon-pingmufangda` 一起**追加进 Imgs**
（`TUGIconClsList.IconText`），列表 27 → 31 项，索引 **27 pingmufangda / 28 fuzhi / 29 caidanshouqi /
30 guanbi2fill**；两个模板（mtListEditor、mtMasterSlave）基础列表本来就逐项相同，追加后又一样，
所以索引两边完全一致。图标位：插入行 29、复制行 28、清空 30（新增 7 / 删除 8 / 上移 20 / 下移 21 不变）。

本轮被测试抓到的两个自己的错误：① 注释块结尾写成 `*/`（`{ }` 注释没闭合，吞掉后面整段代码，
编译报一堆"标识符未宣告"）；② mtMasterSlave 的图标追加放得太早 —— `EmitDetailRowBar` 执行时 Imgs 还没进
`Lines`，一个都没追加进去（测试报"Imgs 缺少图标"），已挪到 DFM 拼装完成之后。

本地：全量 **86 通过 / 0 失败**、两个模板的生成脚本都过宿主编译闸门。
包 `deployment/detail-icons-20260921`（DLL `8FBB13AE…`）。

**2026-09-21 第十六轮：mtMasterSlave 布局（明细工具条高度 + 区域分隔线）**

宿主反馈两条：①明细工具条比主控件区矮一截；②生成的界面里工具栏/记录区/表格没有分隔线（原版有）。

根因与修法：

- 高度：我写死 `Height = 30`，主工具条 `pToolbar` 是 `33` → 改为**从 DFM 读 pToolbar 的实际高度**再赋给
  `pDetailBar`（不写死，两边永远一致）。
- 分隔线：原版有两条 1px 线（`Align = alBottom`、`Height = 1`、`Color = 9211020`）——
  `topline`（工具栏底部）与 `lbEditControls`（记录区底部）。生成器**自己重排**了 `pToolbar`/`pMain`
  （都是重新发射的），把这两条原版自带的装饰线漏掉了 → 现在两条都按原版属性发回来，并给明细工具条补一条
  同风格的 `detailBarLine`，所以三个区域之间都有分隔线。
- 附带：记录区分组重排（`GroupMainControls`）会校验"记录区子控件数 = 字段数"，分隔线算进去就报
  `Main group control count mismatch`，且重建 `pMain` 时会丢线 → 分组时跳过它、重建后再补回
  （`tests/main_groups.test.py` 重新变绿）。

本地：全量 **86 通过 / 0 失败**（`multiple_generic_import` 一次既有 Windows 临时目录偶发，重跑通过）、
mtMasterSlave 脚本过编译闸门、新增"高度一致 + 三条分隔线"断言。
包 `deployment/ms-layout-lines-20260921`（DLL `D920F17F…`）。

**2026-09-21 第十七轮：分隔线颜色调淡 + 记录区分隔线定位（宿主第三项反馈）**

- **颜色**：分隔线统一为 `$00C7C8C4`（十进制 13093060，比原版 `$008C8C8C` 淡）。两处同时改：
  ① 生成器源头 15 处（DetailTemplate 3 / MasterSlaveTemplate 5 / ListEditorWrite 2 / MultipleTemplate 3 /
  TreeTemplate 2）；② 向导侧 `GenerateRunFrame` 拿到 DFM 后再做一次 `9211020 → 13093060` 全量替换 ——
  这一层专门覆盖**原版参考件里自带**的分隔线（不在生成器代码里）。只改向导侧的话探针走不到、本地验证不了；
  只改生成器的话参考件的线还是旧色。两处幂等，不互相干扰。
- **记录区分隔线没在最底下**：根因是**分组路径下 `pMain` 被重建为 `TUgScrollBox`**，而那条线用的是
  `Align = alBottom` —— 滚动容器里贴的是**视口**底部，内容更高时线就跑到中间（宿主截图正是分组场景）。
  改为按**内容高度**绝对定位（Left=0 / Top=分组累计高度 / Width=860 / Height=1），未分组路径保持 alBottom。
- 断言：`tests/main_groups.test.py`（本来就跑分组场景）新增"不贴底 + 按内容高度 + 新颜色"；
  `tests/master_slave_detail_buttons.test.py` 的颜色断言按新值更新。
- 本地：全量 **86 通过 / 0 失败**。包 `deployment/separator-color-20260921`（DLL `0809DD53…`）。

**2026-09-22 第十八轮：「记录区布局」移植到 mtMasterSlave —— 第一步（解析器共享）**

宿主 2026-09-21 提出：mtListEditor 有「记录区布局」，mtMasterSlave 也需要。移植分三步，本轮做第一步：

- 把 `TListEditorLayoutItem` + `ReadListEditorLayout`（含位置 Top/Left、列数 1..3、每列宽度 80..800、
  分组标题开关、每字段 标题/分组/显隐/跨列/宽度，以及**全部拒绝项**）从 `ugConfiguration.ListEditorTemplate`
  搬到共享单元 **`ugConfiguration.ListEditorLayout`**；列表编辑器改为引用共享单元。
  这样两个模板的**解析口径与拒绝文案完全一致**，不会各写一套。
- 该单元原有的 `SwapLayoutRows`（上移/下移真交换）保留不动。
- 验证：列表编辑器的布局测试（`list_editor_layout.test.py`：DFM 结构、对话框 JSON 形状、用户现场配置、
  7 条拒绝路径）全绿；全量 **86 通过 / 0 失败**；DLL/探针构建 0 错误。
- **未做（下一步）**：① mtMasterSlave 生成侧按布局排版记录区（`pMain` 的 位置/列数/列宽 + 每字段
  标题/显隐/分组/跨列/顺序）；② 目录项「记录区布局」(1015) 的适用列表加 mtMasterSlave；
  ③ 专项测试（生成契约 + 编译闸门 + 拒绝项）。
  **顺序说明**：目录项留到最后开 —— 生成侧没接就开放会"配了不生效"，这是本项目一直守的规矩。

**2026-09-22 第十八轮续：生成侧尝试 → 回退（诊断已记录，下一轮从这里接着做）**

本轮把生成侧也写了一遍（位置/列数/列宽/每字段标题·显隐·分组·跨列·顺序，未配布局时严格走原三分栏），
**但没做成，已回退到绿灯状态**（DLL 0 错误、全量 86/0、目录项收回不开放）。踩到的问题按顺序记下来：

1. **回归（已修）**：新游标一开始也用在"未配布局"的路径上 → 改动了已验收版式（`typesetting_order` 与
   MasterSlaveTemplateProbe 的"原版三分栏"断言同时变红）。修法：所有新逻辑用 `if LayOK then … else 原代码` 分流，
   分组路径在未配布局时显式恢复 4 列 / 210 步进。
2. **编译闸门抓到真实缺陷（部分修）**：布局**过滤掉字段**后，脚本里仍有多处 `a<字段>` 控件引用
   （`SetEditState` 的 ReadOnly 循环、combobox 的 `Loada<字段>Items`、必填聚焦、动态查找事件绑定，
   以及导入/审批等路径），少生成控件就"标识符未宣告"（报过 `aBillStatus`、`aCustCode`）。
   已给前三类加了 `MainFieldInArea` 判据，但**没有穷尽**（仍有引用漏网）。
   → 下一轮建议：**别用"不生成控件"表达隐藏**，改成"控件照常生成、`Visible = False` 隐藏"
   （mtListEditor 那边能直接不生成，是因为它的脚本本来就对"记录区里没有控件的字段"做了判断）。
3. **未定位的 AV（回退的直接原因）**：改成"控件照常生成 + Visible=False"之后，生成器抛
   `Access violation … Read of address FFFFFFFFFFFFFFFF`（典型的空串下标）。已排查并加了一处边界检查
   （`GroupMainControls` 里 `LayItems[N]` 越界 —— 因为 MainDisplayOrder 后面还跟着"未列进布局"的字段），
   但 AV 依旧。**下一轮第一步就是把这个 AV 定位掉**（建议：先只做"位置 + 列数 + 列宽 + 顺序"，
   暂时不动显隐，确认能生成；再单独加显隐）。

保留并已验收的部分：共享解析器（`ugConfiguration.ListEditorLayout`）+ 通用生成探针
`tests/MasterSlaveGenerateProbe.dpr`（专用探针 `MasterSlaveTemplateProbe` 与它自己的夹具场景绑得较紧，
配了布局就踩它的硬编码断言，所以加了通用探针）+ `build-masterslave-probes.bat` 的编译项。

**下一件（宿主提出）**：把 mtListEditor 的「记录区布局」移植到 **mtMasterSlave**（目录项开放 + 对话框字段来源
切主表 + 生成侧按布局排版记录区）。按老规矩三步走：配置契约 → 生成契约 → 编译闸门。

**2026-09-22 第十九轮：「记录区布局」移植到 mtMasterSlave —— 完成（本地通过 / 宿主未测）**

第十八轮续留下的三件事全部收口，包 `deployment/masterslave-record-layout-20260922`（DLL `C294F14A…`）。

**1. AV 定位到了（根因，不是猜的）**：记录区排版与分组重排里有 `I := MainFields.IndexOf(...)` 之后
**直接** `MainTypes[I]` / `MainFields[I]` 的写法。布局行里可能有"当前数据结构已经没有"的字段（换表残留，
或布局行的写法与主字段名对不上），命中就是下标 **-1**；`TStringList[-1]` 读到数组前面那块内存，
拿到野指针当字符串用 → `Access violation … Read of address FFFFFFFFFFFFFFFF`。
`GroupMainControls` 里那处 `K:=MainFields.IndexOf(Name)` 同理（而且它前面还要求
`Blocks.Count = MainDisplayOrder.Count`，布局改过顺序/字段集时更容易踩）。

修法：①所有布局查询走 `LayRowOf/LaySpanOf/LayWidthOf/LayCaptionOf/LayGroupOf`，找不到返回 -1/空/缺省，
调用方先判再取；②显示顺序改成"布局可见字段 ∩ 主表已勾选字段 + 其余主字段"，**从构造上**保证
`MainDisplayOrder` 只含 `MainFields` 里的名字；③平面排版、控件发射、分组重排三处各加 `if I<0 then Continue` 兜底。

**定位手法（按约定）**：最小夹具二分 —— 位置+列数+列宽 → 顺序 → 标题 → 跨列 → 分组 → 显隐 → Left 位置，
每加一个维度跑一次生成探针，**8 步全程 0 AV**。这 8 个台阶已固化进测试。

**2. 分两片实现，两片都绿灯**：
- 片 1：位置（Top/Left）、列数、每列宽度、字段顺序、字段标题 —— `if HasLayout then … else 原代码` 严格分流；
- 片 2：显隐 + 跨列 + 分组覆盖 + 单字段宽度。
- 显隐按上一轮的建议做：**控件照常生成 + `Visible = False`**，不做"不生成控件"；
  隐藏字段不占排版格子（排在可见区下方），分组路径里挂到最后一个可见分组，不为它多出空分组框。
- 分组来源：配了布局用布局的 `fdGROUP`（勾了「显示分组标题」才出标题行），未配布局仍按数据结构「列」；
  列数/列宽/步进在分组路径同样按布局走（未配布局时显式走 4 列 / 210 步进）。

**3. 未配布局逐字节不变（铁律验证）**：改动前后对 5 个场景（原版参考配置 / case-upper / memo /
分组 / 隐藏字段）生成的 DFM 做 **SHA-256 比对，全部一致**。这一条在本轮抓到了一次真实回归：
分组路径的旧分支只复位了行高没复位新加的列游标 `GrpCol`，导致未配布局的分组模块控件坐标漂了
（`aCreateTime` 从左 10 变 850）——哈希比对当场变红，修好后恢复一致。**没有哈希比对这个网，
这条回归会混进包里**。

**4. 目录项开放 + 测试 + 包**：
- 目录项 1015「记录区布局」的适用列表加 `mtMasterSlave`（生成侧接通后才开放）。对话框字段来源本来就是
  主表 `cdsColumns`（`SourceColumnsForCurrent` 只对「从表结构」分组切从表），无需改逻辑，只更新了注释。
- 新增 `tests/masterslave_record_layout.test.py`（13 个用例）：生成契约（顺序/标题/位置/列数/列宽/跨列/
  单字段宽度/分组/显隐）、**每个主表字段都有控件**、编译闸门（平面/跨列/分组/隐藏/Left/未配布局各跑一遍）、
  8 条拒绝路径、残留旧字段丢弃、宿主 published 属性校验、未配布局回归、目录项适用列表。
- 夹具 `fixtures/masterslave/record-layout-20260922.json` + 生成脚本 `tools/make_ms_record_layout_fixture.py`。
- 三绿门：DLL 0 错误 / 两边探针 0 错误 / 全量 `tests/*.py` **88 文件 155 用例通过 0 失败**、
  `test_recovery.py` 退出码 0。

**下一件**：宿主复测本包（重点：Left 位置与竖分隔线、隐藏字段后编辑/导入/必填聚焦是否照常、
未配布局老模块重新生成后版式不变）。

**2026-09-22 第二十轮：mtListEditor 导入（btImport）—— 做完（本地通过 / 宿主未测）**

批次三挂起的「导入」收口，包 `deployment/list-editor-import-20260922`（DLL `5A421B1C…`）。

**1. 语义先按原版证据定案，不用再问"单条还是批量"**：原版 list editor 参考件
`fixtures/list-editor/user-reference-20260917.dfm` 里导入的脚本就是
`g := gridMain; fe := '<字段名;>'; fs := '<列标题;>';` + `UGMM.ImportText(g, fs)` /
`UGMM.ImpExcel(g, Self.Caption, fe)` —— **目标是当前列表本身（方案 B 批量暂存）**，
不是明细区。§7.8 当时建议"第一批只做明细导入"是没看到这段证据时的推断，本轮以原版证据为准。
按钮也照原版：TUgMenuButton、位置在「修改」之后「保存」之前、`ImageIndex = 10`
（正好是 mtDetail 图片表里的 `icon-ico_daoru_xuanzhong`），下拉两项 文本格式/电子表格。

**2. 新增「导入暂存态」LEState = 4**（导入的行进 cdsMain 未保存）：
- 保存 → `LEImportSave`：逐行补号（MaxInt 从 `GetMaxIntNumber` 一次取号后顺序 +1 / Guid 逐行 /
  数据库自增不动；已有编号的行不动）、逐行补审计（录入* 为空才补、修改* 覆盖，与 `LEAuditFill` 同一套赋值）、
  `ValidateGenericRows` 全行校验（非空按**行号**报、组合唯一含数据库）、一次 `SubmitUpdates`、
  按当前查询范围 `LEReloadList`；
- 撤销 → 确认后 `CancelUpdates` 丢整批；查询 → 确认后丢批重查；关闭 → 沿用既有 `LEClose`（`LEState <> 0` 先确认）；
- 新增/修改/删除/导入/导出/打印/附件/翻页/查询区在暂存态一律不可用；**表格保持可用**（能滚动看导入行，仍只读）；
- 导入按钮再叠一层宿主按按钮权限：`UGMM.VerifyRunFramePermAction(Self, btImport.Name)`（原版 RefState 的写法）。

**3. 列清单与三条拒绝**：可导入字段＝可见字段里能由文本表达的（排除复选、自动编号主键、自动赋值字段）；
`fs`＝标题、`fe`＝「非空字段」∩ 可导入（没配就退回全部可导入，与 mtMasterSlave 的明细导入同规则）。
生成期拒绝三条：只读列表勾导入；「非空字段」落在复选/自动赋值字段上（导入必然校验不过）；一个可导入字段都没有。
第二条是实测得来：宿主 `ImportText` 写复选用的是 `AsString`，而 `TBooleanField.SetAsString`
只认该字段的 True/False 文本（查了 Delphi 源码 Data.DB.pas），所以复选列**填不上**。

**4. 两条踩坑（都已修，值得记）**：
- **`TDataSet.RecNo`/`RecordCount` 在脚本里不可见**：它们是 **public** 属性，FastScript 只看 published；
  我最初在逐行补号/审计里写了"保存/恢复光标"，编译闸门报 `Undeclared identifier: 'RecordCount'`。
  改成不恢复光标（这两个过程只在暂存保存里跑，紧接着就 `LEReloadList`）。
- **未勾导入的模块必须逐字节不变**：所有新发射都按 `if ImportOn then … else 原代码` 分流；
  连一句脚本注释也改回了原文（否则每个模块重新生成都会多一行注释、DFM 字节就变了）。
  另立 `tools/le_dfm_hash_guard.py`（与 mtMasterSlave 的 ms_dfm_hash_guard.py 同一套用法：
  `capture` / `verify` 比 10 个既有夹具的 DFM SHA-256）。

**5. 验证**：DLL 与两边探针 0 错误；全量 `tests/*.py` **89 文件 162 用例通过 0 失败**、
`test_recovery.py` 退出码 0；新增 `tests/list_editor_import.test.py`（7 用例：生成契约/编译闸门/
3 条拒绝/未勾导入零产物回归）；导入配置过编译闸门（含带从表的模块）；两个哈希守卫全一致。

**下一件**：宿主复测本包（重点：文本粘贴的分隔符习惯、Excel 模板列、导入多行后保存/撤销/查询/关闭的确认、
权限对导入按钮的收效）。**仍未做**："从别的模块/查询窗体多选记录导入"（mtDetail 导入窗体那套，
需要 list editor 支持模态打开来源模块的桥，单独一轮）。
