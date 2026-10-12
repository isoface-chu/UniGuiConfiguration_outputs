# mtListEditor 开发交接文档

更新日期：2026-09-19（批次一 记录区布局）  
状态：持续开发中；本文是 `mtListEditor` 的当前交接基线，覆盖早期方案和阶段记录中已经过时的“未实现”描述。

最近一轮（2026-09-19，包 `deployment/lookup-dialect-20260919`，DLL `0D297C1A…`）：⑧ **动态加载下拉的行数上限改为按数据库驱动生成**——宿主在 MSSQL 节点上报 `"limit" 附近有语法错误`，根因是照抄原版 MySQL 样例把上限写死成 `limit N`；现在脚本里按新增常量 `cDataNodeDriver = UGMM.GetNodeNameByDriver(cDataNodeName)` 现算（`MSSQL`/`MSAcc` 用 `top N`，`MySQL`/`SQLite` 保持 `limit N`，`Ora` 不加），同一处缺陷在 `MasterSlaveTemplate` 的多列下拉动态查找里也一并修掉；⑨ **`SqlText` 下拉的多行 `mmText` 归一化**——真换行写进脚本常量会让 FastScript 报 `Expression expected`，现与查找字段 SQL 同一条归一化规则（换行→空格 + `Trim`）；⑩ **修正 `LIKE` 引号**——上一版把值的起始引号写进了常量，运行时拼出 `like ''%值%'`，宿主报「字符串 '      )' 后的引号不完整」，现在常量只写到 ` like `、引号由 `quotedstr` 提供（与 `MasterSlaveTemplate` 的原版写法一致），并把断言改成**逐字符比对整条 SQL**。详见 [LISTEDITOR_CONTROLTYPES_20260918.md](../validation/LISTEDITOR_CONTROLTYPES_20260918.md) §15。

最新一批（2026-09-19 批次一，包 `deployment/list-editor-record-layout-20260919`，DLL `94F56D92…`（含宿主第一轮反馈修复））：⑪ **记录区独立字段布局 + 分组布局（宿主验收通过）**——常规设置新增「记录区布局」(1015，仅 mtListEditor)，配置 `TWebListEditorSetting`：位置 Top/Left、列数 1..3、每列宽度、分组标题开关，以及每字段的 显隐/顺序/记录区标题/分组/跨列/宽度；区块缺失时行为与之前逐字符一致。顺带修掉"记录区没有控件的字段会生成 `leField-1.SetFocus`"的潜在缺陷。见 validation §16。

用户 2026-09-19 宿主反馈「记录区布局 测试通过」（含上移/下移换序、宽度设置与提示可读）；尚未单独点过的子项（`Left` 位置窄屏、分组+跨列视觉、窗口缩放）保留为未测。

**批次二（2026-09-19）已完成**：⑫ **审计字段**（录入*/修改* × 用户/部门/时间，时间按列类型赋值，必填前填充，记录区只读）；⑬ **层级/行权限**（查询部门 in 过滤 + 保存/删除按主键回库复核 + 空权限不退化成全表 + admin 不豁免 + 开启层级权限即保护部门只读）；⑭ 精灵适用列表对齐（层级权限与五个审计项加入 mtListEditor）。见 validation §17，包 `deployment/list-editor-audit-scope-20260919`（DLL `83613460…`，**宿主验收通过**：用户 2026-09-19 反馈「1-2测试通过」）。

**批次三（2026-09-19）已完成**：⑮ **导出/打印/附件**——按钮类与图标照原版 list editor 参考件（打印为 TUgMenuButton），实现沿用宿主已有入口（ExpExcel / AddReport / OpenFileManager 按当前记录主键），只在浏览态且有数据时可用，编辑态全部禁用；只读列表下明确拒绝。**导入（btImport）未接入**：需先确认“导入到当前记录”还是“批量暂存多行”，已给出建议（先做 A）等确认。见 validation §18，包 `deployment/list-editor-output-20260919`（DLL `83BE8B97…`）。

**批次四 S2 第一片已交付**（2026-09-20，包 `deployment/list-editor-detail-readonly-20260920`，DLL `3800C975…`）：从表（明细）只读联动（明细区在记录区下方、关联字段取数、随主记录联动、隐藏字段、4 条配置拒绝、写模式拒绝）；顺带修掉两个只在只读路径暴露的既有缺陷（只读模式下写入类设置漏给 mtMultiple 导致生成失败、动态下拉常量行匹配）。下一片：明细写入（增/删/复制行、父键回填、行号、从表唯一/非空、原子提交、删主记录连明细）与明细导入。

**批次四方案**（含 §7 复核结论与 §8 E01–E18 验收骨架）：[MTLISTEDITOR_BATCH4_PLAN_20260919.md](MTLISTEDITOR_BATCH4_PLAN_20260919.md) —— 多表关联（复用 mtMultiple 的关联表机制：只展示、不写关联表、接 CheckMultipleJoin/RefreshMultipleJoin）、从表（S1 只读展示 / S2 主从写入两案）、导入（A 单条 / B 批量暂存）。

**后续批次队列**（用户 2026-09-19 指定，按此顺序推进）：~~② 审计字段 + 层级/行权限~~（宿主验收通过）；~~③ 导入/导出/打印/附件~~（导出/打印/附件已交付待验收；导入待确认语义）；③ 导入/导出/打印/附件；④ 多表关联/从表/复杂写入。

更早一批（2026-09-18）：① 记录区按字段对象类型生成 文本/数值/备注/复选/日期/时间/固定下拉 六类控件、按控件高度两列排布，必填判定按类型改用 `IsNull`（`0`/`False` 不再被当成空）；② 新增 **SqlText 下拉**（初始化时按配置 SELECT 灌入选项，值即选项文本）并把 `time` 对齐到宿主 `TUgDBTimePicker`；③ 新增**查找字段 `lookupedit`/`lookupeditextra`**（值=代码、extra 显示名称，按 mtMasterSlave 的做法生成选项数据集与初始化打开）；④ 新增**多列下拉 `gridcombobox`/`gridcomboboxextra`**（`GridLookupFields` 多列表格，`IsLookUp` 标可搜索列，分页按配置）；⑤ 新增**多列下拉的动态加载**（`cbDynamicLoading`：空壳数据集 + `OnExtEditValueChange` 输入时远程取数），静态时 `GridLookupDataSetFilter = True`；⑥ `表格序号` 支持 mtListEditor（表格 Options 加 `dgRowNumbers`）；⑦ 记录区**顺序与标题改由「排版」(cdsTypesetting) 决定**（分组/列跨度未接入，缺配置入口）。见包 `deployment/list-editor-control-types-20260918`。SQL 下拉/lookup/gridcombobox 的写入仍拒绝（§9 第 3 条剩余部分）。

## 1. 模块定义

`mtListEditor` 是一个**单表、同窗编辑列表**模板：查询区、顶部记录区、表格和分页都在同一窗体中。顶部记录区和表格共用 `dsMain/cdsMain`，因此选中表格行后顶部字段自动显示当前行；不依赖查询窗体或编辑窗体。

它是重建工程中新增加的模板，不是原 DLL 已提取出的原始生成器代码。实现方式是复用 `mtMultiple` 的查询、分页、权限和提示基础，再叠加同窗记录区与写入状态机。

## 2. 当前支持范围

| 项目 | 当前结论 |
|---|---|
| 数据结构 | 仅一张根表；不支持从表、JOIN 写回或数据透视 |
| 查询与分页 | 支持现有 `mtMultiple` 查询条件和分页生成能力 |
| 查询布局 | 常规设置“界面布局”支持 `Top` / `Left`；查询区默认收起，可由“展开查询”按钮切换 |
| 顶部记录区 | 按主表列表可见字段自动生成，两列排列；与表格同源绑定 |
| 隐藏字段 | “隐藏字段-主表”同时隐藏表格列和顶部控件；自动编号主键可隐藏，但必须仍为已选数据字段 |
| 写入 | 新增、修改、保存、撤销；删除为可选按钮 |
| 自动编号 | `DBAutoincrement`、`Guid`、`MaxInt` |
| 文本类型 | `Normal`、`Upper`、`Lower`；只作用于普通文本输入框，查找/下拉返回码保持原值 |
| 必填/唯一 | 支持根表非空与主表唯一校验；提示使用字段标题，确认后恢复焦点 |
| 记录区控件 | 按字段对象类型生成：文本 `TUgDBEdit`、数值 `TUgDBNumberEdit`、备注 `TUgDBMemo`(H170)、复选 `TUgDBCheckBox`(H25, 标题走 `Caption`)、日期/时间/日期时间 `TUgDBDateTimePicker`、固定下拉 `TUgDBComboBox`(SetText)；按控件高度两列排布 |
| 必填判定 | 文本/备注/固定下拉按去空格文本；数值/复选/日期时间按 `IsNull`（`0`/`False` 是有效值）；复选必填标红走 `Font.Color` |
| 提示 | 使用现有 SweetAlert / `UGMM.LT` 机制，不使用阻塞 `ShowMessage` |

### 写入按钮约束

一旦启用写入，以下按钮必须同时勾选：`btQuery`、`btClose`、`btAppend`、`btEditor`、`btSave`、`btCancel`。

`btDelete` 是可选项：只有在功能按钮页明确勾选时才生成删除按钮、删除事件和确认流程。

### 自动编号约束

- `DBAutoincrement`：主键必须为 `INT`、`INTEGER`、`BIGINT`、`SMALLINT` 或 `AUTOINC`。新增时不预写主键，依赖 `AutoUpdateRefresh` 接收服务端回填值；若未回填，不使用 `MAX(id)` 猜测并发记录，只刷新列表并明确提示。
- `Guid`：主键必须为长度至少 36 的字符字段。
- `MaxInt`：仅非自增 `INT` / `INTEGER` 主键；新增时使用全表最大值 + 1。它不是原子编号器，业务表必须有主键/唯一约束，冲突后不能自动重试。
- `DBAutoincrement` / `MaxInt` 不允许前缀、后缀、补位或序列配置。

## 3. 关键交互和状态机

生成脚本用 `LEState` 管理状态：

| 状态 | 含义 | 允许动作 |
|---|---|---|
| `0` | 浏览 | 查询、新增、修改、可选删除、关闭 |
| `1` | 编辑中 | 保存、撤销、确认关闭 |
| `2` | 已提交，准备/完成重载 | 受控重载、关闭 |
| `3` | 提交结果待核实 | 查询核对、关闭；禁止重复保存或删除 |

`LEBusy` 防止双击重复提交；`LEInternal` 只在受控内部操作期间放行数据集事件。`BeforeScroll`、`BeforeClose`、`BeforePost`、`BeforeDelete` 绑定至守卫，不能只依赖按钮灰化。

保存路径：必填校验 → `Post` → 通用唯一校验 → `SubmitUpdates` → 保持查询条件重载并按主键定位。校验失败会保留编辑状态和输入值；提交成功但刷新失败会提示“已保存成功”，不把它误报为保存失败。

删除路径：确认 → `cdsMain.Delete` → `SubmitUpdates` → 刷新当前查询范围。提交异常进入待核实状态，禁止自动重提。

## 4. 代码地图

| 文件 | 职责 | 修改注意事项 |
|---|---|---|
| `src/ugConfiguration.Document.pas` | 模板名合法性 | 新模板名必须在此处登记 |
| `src/ugWebConfiguration.Moduletype.pas` | 模块类型选择和说明 | 文案必须与真实支持矩阵同步 |
| `src/ugWebConfiguration.FunctionButton.pas` | 精灵功能按钮目录 | `btDelete` 已开放给 `mtListEditor`；新增按钮先在这里声明 |
| `src/ugWebConfiguration.NormalSetting.pas` | 常规设置适用范围 | 隐藏字段、界面布局、主表唯一、自动编号、非空字段均已纳入 |
| `src/ugWebConfiguration.NormalSetting.SetupAutoNumber.pas` | 自动编号配置界面 | `MaxInt` 仅对 `mtListEditor` 额外开放；数据库自增沿用既有类型 |
| `src/ugWebConfigurationModule.GenerateRunFrame.pas` | 生成路由 | `mtListEditor` 必须显式调用 `TryBuildListEditorTemplate` |
| `src/ugConfiguration.ListEditorTemplate.pas` | DFM 总装配、记录区、查询收缩按钮 | 维护 `TWebListEditorLayout` 桥接契约；不要把记录区改成另一份缓存数据 |
| `src/ugConfiguration.ListEditorWrite.pas` | 写入能力校验、状态机、脚本和按钮注入 | 所有新增写动作都应进入同一状态机和 SweetAlert 边界 |
| `src/ugConfiguration.MultipleTemplate.pas` | 查询/分页基础 DFM | 收到 `TWebListEditorLayout=True` 时生成紧凑查询区、`pQueryContent` 与 `pQueryDivider`；同一标记下放行 `fdDropDownOptions`（固定下拉由记录区控件消费，网格仍为只读文本列），`fdDataCheck` 仍拒绝 |
| `src/ugConfiguration.ListEditorWrite.pas`（校验部分） | 记录区写入能力校验 | 对象类型白名单与数据库类型必须匹配（文本↔字符/文本、数值↔数值、复选↔BIT/BOOL、日期时间↔DATE/TIME/…）；固定下拉必须 `SetText` 且选项非空；SQL 下拉/lookup/gridcombobox 明确拒绝 |
| `src/ugConfiguration.MultipleQueryControls.pas` | 查询控件 DFM/脚本 | `Upper/Lower` 仅为普通 `edit` 生成 `CharCase` |
| `src/ugConfiguration.MultipleRecord.pas` | 通用唯一校验和 `MaxInt` 取号 | 避免复制外部编辑窗体逻辑到 ListEditor |

## 5. 布局契约

生成结构如下，后续修改应保持父子关系和对齐责任清晰：

```text
UgWebRunFrame
├─ pButtons
├─ pQuery                  ← 默认 Visible=False
│  ├─ pQueryContent        ← 查询控件
│  └─ pQueryDivider        ← Top 时底线 / Left 时右线
├─ pListEditorFields       ← 顶部记录区，绑定 dsMain
│  └─ listEditorBottomLine
├─ gridMain                ← 绑定 dsMain
└─ pPages
```

`Left` 布局**不得**再生成 `listEditorLeftLine`。分隔线仅由 `pQueryDivider` 负责，避免记录区再叠一根竖线导致缺段、重线或缩放错位。

查询区按钮由 `AddListEditorPresentation` 加入：初始标题“展开查询”；点击后切换 `pQuery.Visible`，并改为“收起查询”。不得通过重建数据集或重建窗体实现收缩。

## 6. 配置与生成前校验

> 2026-09-18 修正：精灵在 `SetText`/`SqlText` 下拉下不提供“显示字段/返回字段”，切换类型时也不清空旧值；这些**残留只忽略、不作为配置依据**（SqlText 取结果集第一列）。曾因把它们当配置而误拒用户现场配置。
>
> 2026-09-19 修正：**列标题取错配置项**——下拉的展示列（含 `字段@标题`）在 `edOptionFields`，搜索列在 `edOptionLookupFields`；曾取反导致下拉显示英文字段名（`ListEditorTemplate`/`MasterSlaveTemplate`/`EditTemplate` 的查找分支已统一）。

生成器会拒绝以下配置，而不是静默降级：

- 非单根表、从表、透视、独立 `TWebListEditorSetting` 布局区。
- 写入模式缺少一组必需按钮。
- 主表唯一未指向根表已选字段。
- 自动编号类型、字段或数据类型与上表不匹配。
- 写入字段的对象类型不在 {edit, number, memo, check, date, time, datetime, combobox} 内（如 lookupedit/gridcombobox），或对象类型与数据库类型不匹配。
- 固定下拉不是 `SetText`（SqlText/SqlQuery 需额外数据集）或选项内容为空；非下拉字段却带了下拉选项。
- 审计字段、层级权限开启。
- 不支持的文本类型或功能按钮。

当前“顶部字段”来源是最终生成表格的可见列，顺序跟随表格列；尚未实现独立的记录区字段顺序、分组、控件类型和列跨度配置。不要伪造 `TWebListEditorSetting` JSON 绕过生成器。

## 7. 验证资产与命令

主要测试文件：

| 文件 | 验证内容 |
|---|---|
| `tests/ListEditorProbe.dpr` | G1 只读联动和基本生成 |
| `tests/ListEditorWriteProbe.dpr` | Guid 写入配置与拒绝路径 |
| `tests/ListEditorMaxIntProbe.dpr` | MaxInt、隐藏主键、Top/Left、默认收起、删除按钮、数据库自增、Upper/Lower |
| `tests/ListEditorControlTypesProbe.dpr` | 记录区控件类/高度/按类型属性、两列不重叠、面板高度推导，以及 7 条类型不匹配与下拉拒绝路径 |
| `tests/ListEditorControlTypesRuntime.inc` | 混合控件类型的原生数据集行为：只读绑定、按类型必填（`IsNull` 对 `0`/`False`）、日期/备注保存、撤销 |
| `tests/list_editor_control_properties.test.py` + `tools/check_dfm_control_properties.py` | 按宿主/UniGUI 源码的 published 属性链校验生成 DFM：**新增控件属性前必须跑**（2026-09-18 曾因 `TUgDBNumberEdit` 没有 `EmptyText` 导致宿主生成失败） |
| `tests/ListEditorGenerateProbe.dpr` | 通用生成探针：拿精灵导出的现场配置直接跑生成器并校验 DFM 文本语法——复核“点完成报错”类问题时用它，不要临时拼探针 |
| `tools/check_dfm_control_properties.py`（类存在性 `check_dfm_classes`） | DFM 里的控件类必须在「宿主/UniGUI 源码 ∪ 本工程 ∪ 原版样例 ∪ 宿主二进制」里能找到，拼错类名会报出 |
| `tests/CdsDeltaProbe.dpr` | 实测 `TClientDataSet` 的 delta 复制看不到已删除行——替身据此改用 `BeforeDelete` 观察删除，不要再用「不可见即删除」的启发式 |
| `tests/MultipleScriptProbe.dpr` | 生成 FastScript 编译、事件注入及部分运行时替身验证 |
| `tests/ListEditorMaxIntRuntime.inc` | MaxInt 的取号、冲突、撤销、定位与故障路径 |
| `validation/LISTEDITOR_G1_20260918.md` | 早期只读阶段记录（部分状态已过时） |
| `validation/LISTEDITOR_G2_20260918.md` | 早期写入阶段记录（部分限制已被后续补齐） |
| `validation/LISTEDITOR_MAXINT_20260918.md` | MaxInt 与后续布局阶段记录 |

在重建目录执行：

```powershell
& 'C:\Program Files (x86)\Embarcadero\Studio\20.0\bin\dcc64.exe' tests/ListEditorMaxIntProbe.dpr '-Usrc;C:\VCL\FastReport\LibD26x64;C:\Program Files (x86)\Embarcadero\Studio\20.0\lib\win64\release' '-NSSystem;System.Win;Winapi;Vcl;Data;Xml;Soap' -Eprobe-bin -N0probe-bin
.\probe-bin\ListEditorMaxIntProbe.exe fixtures/list-editor/basic-unit-input-20260918.json validation/list-editor-current.dfm
.\probe-bin\MultipleScriptProbe.exe validation/list-editor-current.dfm all list-editor-maxint
.\probe-bin\MultipleScriptProbe.exe validation/list-editor-current.dbauto.dfm all list-editor-dbauto
.\probe-bin\ListEditorControlTypesProbe.exe fixtures/list-editor/control-types-20260918.json validation/list-editor-control-types-20260918.dfm
.\probe-bin\MultipleScriptProbe.exe validation/list-editor-control-types-20260918.dfm all list-editor-controls
```

最终 DLL 构建：

```powershell
cmd /d /c '"C:\Program Files (x86)\Embarcadero\Studio\20.0\bin\rsvars.bat" && msbuild UniGuiConfiguration.dproj /t:Build /p:Config=Debug /p:Platform=Win64 /v:minimal && msbuild UniGuiConfiguration.dproj /t:Build /p:Config=Release /p:Platform=Win64 /v:minimal'
```

模拟测试不能替代真实宿主和真实数据库验证，尤其是 `DBAutoincrement` 的服务端主键回填、分页定位、权限和浏览器视觉布局。

## 8. 当前交付包与验收状态

最新包：`deployment/list-editor-control-types-20260918/UniGuiConfiguration.dll`  
SHA-256：`C354040FA0066D95BFD701AE3C365C9B4D412379A7AA738109D3DF92EB45DCED`（记录区控件类型适配）  
前一包（删除/数据库自增/Upper-Lower/默认收起）：`deployment/list-editor-delete-autoincrement-case-20260918`，SHA-256 `EEC9C4E4EFAE721B3223087FF2D6C9E2A2C787A4E224987F4C20A7640FDB6B1E`，仍是这些能力的验收依据

本地已通过：Debug/Release 编译、DFM 解析、MaxInt 运行时探针、生成脚本 FastScript 编译、删除/数据库自增/Upper/Lower 配置生成检查。

用户已反馈通过的历史范围包括：只读联动、隐藏字段、Top/Left 布局、查询区域折叠、同窗新增/修改/保存/撤销、MaxInt 基本功能等。
2026-09-18 控件类型批（`deployment/list-editor-control-types-20260918`，DLL `C354040F…`）宿主确认：重新生成不再报 `EmptyText` 错误、记录区按字段类型呈现控件且随选中行联动、数值留空被拦/填 0 可保存。
仍待宿主抽查：复选/备注/日期时间/下拉的浏览器交互细节、真实库日期时间往返、`DBAutoincrement` 组合定位、删除与撤销在这些类型上的组合；“删除、数据库自增、Upper/Lower、默认收起”包此前未单独宿主回归。

## 9. 未完成或需重新验收的事项

以下不是已实现承诺，接手时必须先明确需求再开发：

1. 真实业务库下 `DBAutoincrement` 的回填与新增后精确定位；服务端不回填时当前只保证安全刷新，不保证定位。
2. 审计字段、层级/跨账号权限，以及其与删除和分页定位的组合。
3. 日期、时间、Memo、复选、固定下拉的写入适配**已完成**；**SqlText 下拉**（SQL 取回文本选项）**已完成**（2026-09-18 第二批，包 `list-editor-sqltext-dropdown-20260918`；2026-09-19 补多行 `mmText` 归一化）；**非查找字段的 `SqlQuery` 下拉、以及查找控件（非表格）的动态加载仍未接入**，配置时明确拒绝。记录区已覆盖精灵里全部可写字段类型；记录区的顺序/标题已接入（按 cdsTypesetting），**分组与列跨度因精灵无对应配置入口未做**，待用户给出界面形态后再实现。
   动态加载下拉的行数上限**已按驱动生成**（2026-09-19，包 `lookup-dialect-20260919`）；`mtDetail` 的动态加载下拉仍未接入（`DetailTemplate` 不处理 `cbDynamicLoading`），Oracle/MSAcc 分支未实测。
4. ~~顶部记录区独立字段布局、分组、列跨度~~ **已完成（2026-09-19 批次一）**：显隐/顺序/标题/分组/跨列/宽度/位置/列数均可配；**记录区高度仍按内容推导（上限 350 + 滚动条），未做成可配置**；控件类型仍由字段的「对象类型」决定（未做"同一字段在表格与记录区用不同控件类型"）。
5. 多选/批量删除、跨页选择、导入、导出、打印、附件、审批。
6. 多表/主从/关联写回、透视、树操作。
7. 大数据量逐页定位、并发冲突语义、多数据库差异、网络超时结果确认。
8. 真实浏览器下 Top/Left 收缩、窗口缩放、连续重开精灵和生命周期回归。

## 10. 接手原则

- 先读取本文件、最新交付包 README 和相邻代码；早期文档中“未实现”的文字不一定仍准确。
- 不要把 `mtMultiple` 的外部编辑窗体流程、`mtMasterSlave` 的主从逻辑或 `mtTree` 的层级逻辑整段复制进来。
- 顶部记录区与表格必须继续共享 `cdsMain`，按字段名绑定；禁止按列序号复制值。
- 每个写操作都必须处理：权限、编辑锁、异常、提交结果不确定、SweetAlert、焦点和重载。
- 修改共享 `MultipleTemplate` / `MultipleQueryControls` 后，必须回归 `mtMultiple`、`mtReport`、`mtListEditor` 生成与脚本编译。
- 每批独立创建 deployment 包，包含 DLL、README、哈希和验证记录；不得直接覆盖用户宿主运行目录。
