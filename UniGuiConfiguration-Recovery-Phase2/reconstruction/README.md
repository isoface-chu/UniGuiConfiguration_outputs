# UniGuiConfiguration 兼容重写工程

本目录是依据目标 DLL、宿主源码和七组 JSON/DFM 样例建立的可验证重写工程。它不宣称是原始源码，而是优先保持 DLL ABI、窗体资源和配置格式兼容。

> 2026-09-13 交接入口：[当前状态、构建与接手指南](handoff/START_HERE.md)、[开发沿革与技术约束](handoff/DEVELOPMENT_HISTORY.md)、[mtDetail 恢复计划和验收标准](handoff/MTDETAIL_RECOVERY_PLAN.md)。mtTree 本期已获用户最终验收；下文多轮追加的早期“未实现/待测”描述保留作历史，不能替代最新交接状态。本次仅整理文档，未启动 mtDetail 实现。

## 当前完成度

2026-09-08 动态 `mtMasterSlave` 已补入 `datetime`、`lookupedit`、`lookupeditextra`、`gridcombobox`、`gridcomboboxextra`：主表生成数据感知控件，明细生成列编辑器，并为查找控件建立独立候选数据集；GridCombo 动态加载、extra 显示字段和 lookup 分页标记均保留。参考及合成 DFM、四组 FastScript、45 项 recovery、Win64 Debug/Release、LoadLibrary 与 ABI 导出通过，待真实宿主验收，见 `validation/MASTER_SLAVE_OBJECT_TYPES_BUILD.md`。

2026-09-08 已创建不覆盖宿主的 Win64 可回退发布包 `deployment/UniGuiConfiguration-Phase2-Win64-20260908`：包含最新重建 DLL、原始 DLL 回退副本、当前已联调的 `UniGuiClient.exe`/BPL 基线及 SHA-256 清单。正常发布只替换 release DLL，BPL 基线不用于单文件混换，见包内 `README.md`。

2026-09-08 已完成 Win64 最终部署静态核对：最新重建 DLL、三项 ABI 导出、Delphi 10.3.3 Win64 编译依赖以及宿主 `bin64` 的 `fs26/uIndy26/uniGUI26` 包均已确认。宿主 BPL 与编译环境对应文件哈希不同但已通过多轮真实运行，不应盲目混换；UniGUI BPL 为 `.1567` 而本机 Web 资源目录名仍为 `.1555`，保留为目标服务器部署观察项，见 `validation/FINAL_WIN64_DEPLOYMENT_AUDIT.md`。

2026-09-08 `mtMasterSlave` 表格个性化 1–8 项真实宿主验证全部通过：列宽、列移动、列显隐、主从隐藏字段、用户设置隔离、配置开关、写回审批回归及重复完成生命周期均正常；`WriteIni/ReadIni` 自包含修复同时确认有效。本批次验收完成，DLL 不变，见 `validation/MASTER_SLAVE_GRID_PERSONALIZATION_BUILD.md`。

2026-09-08 修复 `mtMasterSlave` 动态表格个性化脚本缺少 `WriteIni/ReadIni` 声明：现已随生成脚本包含原版同等的 `TIniFile` 读写辅助函数，不再依赖宿主全局标识符。三组 FastScript、45 项 recovery、Win64 Debug/Release、LoadLibrary 与 ABI 导出通过；需使用最新 DLL 重新打开精灵并点击“完成”，见 `validation/MASTER_SLAVE_GRID_PERSONALIZATION_BUILD.md`。

2026-09-08 `mtMasterSlave` 动态模板已补齐明细表格个性化：字段宽度、字段移动、字段显隐分别遵守配置开关，主/从隐藏字段具有正确初始状态；列宽、顺序和显隐按模块 GUID 与用户名保存并在重开时恢复。生成/DFM、三组 FastScript、45 项 recovery、Win64 Debug/Release、LoadLibrary 与三项 ABI 导出均通过，待真实宿主集中验收，见 `validation/MASTER_SLAVE_GRID_PERSONALIZATION_BUILD.md`。

2026-09-08 `mtMasterSlave` 导入、打印和附件剩余七项真实宿主验收全部通过：文本导入撤销不写库、Excel 导入、异常数据校验并保留编辑、打印菜单、附件主单关联、附件权限以及保存/撤销/审核/关闭综合回归均正常。结合此前已通过的导入即时连续项次修复，本功能批次验收完成；此次仅更新记录，DLL 不变，见 `validation/MASTER_SLAVE_IMPORT_PRINT_ANNEX_BUILD.md`。

2026-09-08 `mtMasterSlave` 文本导入后的空项次已修复并通过真实宿主验收：动态与内置参考路径均在导入完成后移除旧空占位行，按当前顺序立即生成连续 `Line`、补主从关联键并重建空白编辑行；保存前继续二次整理。三组 FastScript、45 项 recovery、Win64 Debug/Release、LoadLibrary 与三项 ABI 导出均通过。

2026-09-08 `mtMasterSlave` 导入、打印、附件已作为同一批接入动态模板：导入支持文本和电子表格并写入明细网格，保存前继续走关联键、项次、非空、唯一及数据引用校验；打印注册宿主报表菜单；附件按模块 GUID 与当前主单编号打开并依据实际可用业务按钮决定编辑权限。精确匹配内置参考模板时继续使用原版三项实现。完整配置生成/DFM、三组 FastScript、45 项 recovery、Win64 Debug/Release、LoadLibrary 与三项 ABI 导出均通过，待真实宿主集中验收，见 `validation/MASTER_SLAVE_IMPORT_PRINT_ANNEX_BUILD.md`。

2026-09-08 已补齐精确匹配 `UGREF_MTMASTERSLAVE` 的内置参考路径并通过真实宿主验收：删除或进入修改时发现后台单据已删除，会清空失效主从数据并刷新浏览状态后提示“界面已刷新”；编辑保存冲突仍保留输入。45 项 recovery、Win64 Debug/Release、LoadLibrary 与三项 ABI 导出均通过。

2026-09-08 `mtMasterSlave` 浏览状态并发冲突自动刷新已构建：进入修改、删除、审核、反审或打回时若发现后台版本变化/删除，先按当前主键重新读取主单、明细和按钮状态，再给出冲突提示；后台已删除时刷新为空记录状态。普通编辑保存冲突仍保留用户未保存内容。生成/DFM、普通及审批 FastScript、45 项 recovery、Win64 Debug/Release、LoadLibrary 与三项 ABI 导出均通过，待真实宿主复测，见 `validation/MASTER_SLAVE_APPROVAL_BUILD.md`。

2026-09-08 `mtMasterSlave` 新单首次保存的主从关联键顺序已修复并通过真实宿主验收：主表 `BeforePost` 生成自动编号后，先把编号同步到所有有效明细，再执行从表非空、唯一性和引用校验，第一次保存不再误报“BillCode不能为空”。生成/DFM、普通及审批 FastScript、45 项 recovery、Win64 Debug/Release、LoadLibrary 与三项 ABI 导出均通过，见 `validation/MASTER_SLAVE_AUTONUM_DETAILKEY_BUILD.md`。

2026-09-07 `mtMasterSlave` 并发版本复核和从表数据校验已构建：动态模板在修改、保存和删除前按主键参数化核对 `EditCount`，冲突时保留编辑；`fdDataCheck` 改为参数化引用查询并报告明细行、字段和值。生成/DFM、FastScript、45 项 recovery、Win64 Debug/Release、LoadLibrary 与三项 ABI 导出均通过，待真实宿主验收，见 `validation/MASTER_SLAVE_CONCURRENCY_DATACHECK_BUILD.md`。

`mtMasterSlave` 自动编号与主从唯一校验已通过真实宿主验收：重复主编号和重复明细组合会在提交前拦截，提示包含字段名、字段值及明细重复行号，且编辑内容保持。本次仅更新验收记录，DLL 不变，见 `validation/MASTER_SLAVE_AUTO_UNIQUE_BUILD.md`。

2026-09-07 `mtMasterSlave` 唯一冲突定位增强：主表提示组合字段名和值；明细提示当前行、首次重复行、组合字段名和值。动态与内置参考模板两条路径同步实现，并处理空明细边界。生成/FastScript/recovery 45 项、Win64 Debug/Release 与 DLL 检查通过，等待宿主验收。

2026-09-07 `mtMasterSlave` 内置参考模板唯一校验改为提交前修正：主表新增按参数化 `BillCode` 查重，明细按有效 `ItemCode` 建立集合查重且不再依赖项次，均在 `ApplyUpdatesCds` 前给出包含具体键值的友好提示。该改动针对 FastScript 无法捕获宿主提交异常的实际边界；recovery 45 项及 Win64 Debug/Release、DLL 检查通过，等待复测。

2026-09-07 `mtMasterSlave` 唯一提示第二次根因修正：确认完全匹配的配置优先加载内置参考 DFM，绕过了上一版动态生成器中的转换。现于参考 DFM 载入后对其两处原始提交异常出口注入主表/从表唯一约束转换；原始参考文件和其他模板保持不变。动态与内置参考两条路径均已覆盖，recovery 45 项及 Win64 Debug/Release、DLL 加载与导出检查通过，等待再次复测。

2026-09-07 `mtMasterSlave` 唯一冲突提示定向修正：真实 SQLite 宿主中主表和从表重复数据由数据库约束拦截，但曾直接显示 FireDAC 原始异常。现保留保存前预查，并仅对同时包含 `UNIQUE` 与对应配置表名的提交异常转换为兼容的主表/明细唯一提示；编辑内容继续保留，其他数据库错误不被吞掉。生成/FastScript/recovery 45 项及 Win64 Debug/Release、DLL 加载与 ABI 导出检查通过，等待两个重复场景复测，见 `validation/MASTER_SLAVE_AUTO_UNIQUE_BUILD.md`。

2026-09-07 `mtMasterSlave` 自动编号与唯一校验已构建：支持主关联字段的 `MaxCode` 前缀/固定位数/后缀编号、参数化主表组合唯一检查，以及当前有效明细的多字段组合唯一检查；失败保留编辑并允许改正重试。生成/DFM、FastScript、recovery 45 项、Win64 Debug/Release、DLL 加载与 ABI 导出均通过，等待真实宿主验收；其他编号方式、审批及并发复核仍明确拒绝，见 `validation/MASTER_SLAVE_AUTO_UNIQUE_BUILD.md`。

`mtMasterSlave` 基础主从写回 1–10 项已全部通过真实宿主验收：新增空白明细立即显示连续项次，主表或仅明细修改保存均正确增加一次编辑次数，保存失败后保留编辑并可成功重试且不会重复累计。本次仅更新验收记录，DLL 不变，见 `validation/MASTER_SLAVE_WRITE_BASIC_BUILD.md`。

2026-09-07 `mtMasterSlave` 基础写回定向修正已构建：新增时 5 条空白明细会立即显示连续项次 `1..5` 并预填关联值；审计字段和编辑次数改为在 `cdsMainBeforePost` 处理，主表修改或仅明细修改保存都会触发，且同一编辑会话只增加一次。生成/FastScript/recovery 45 项、Win64 Debug/Release、DLL 加载与 ABI 导出均通过；随后第 2、9、10 项宿主复测全部通过，见 `validation/MASTER_SLAVE_WRITE_BASIC_BUILD.md`。

`mtMasterSlave` 基础写回首轮宿主反馈：验收第 2 项为新增后的空白明细项次未立即显示 `1..5`，第 9 项为修改保存后编辑次数未增加；第 10 项保存失败重试暂缓至两项修复后。本条保留为修复前历史结果。

2026-09-07 `mtMasterSlave` 基础主从写回首批已构建：加入手工主键新增、修改、删除、明细网格增删、主从非空、关联键/项次、录入与修改审计字段、整批保存和撤销；失败保留编辑且编辑次数单次编辑只递增一次。生成/DFM、FastScript、recovery 45 项、Win64 Debug/Release、LoadLibrary 与 ABI 导出均通过，待真实宿主验收；自动编号、唯一、并发复核、审批和导入等仍明确拒绝，见 `validation/MASTER_SLAVE_WRITE_BASIC_BUILD.md`。

`mtMasterSlave` 第一阶段只读动态生成已通过用户真实宿主 1–7 项验收：生成与保存重开、查询窗体回传、主从关联、首/前/后/末导航、空数据边界、层级权限、重复完成及关闭生命周期均正常。本次仅更新验收记录，DLL 不变；下一阶段进入主从编辑与整批写回，见 `validation/MASTER_SLAVE_READONLY_BUILD.md`。

2026-09-07 `mtMasterSlave` 只读动态生成首批已构建：支持查询窗体回传、主从关联加载、首/前/后/末导航、层级权限二次校验、表格复制及只读界面；主记录为空或越权时不加载明细，空数据集导航不访问无效参数。写回、审批和导入配置仍明确拒绝。生成/DFM 探针、recovery 45 项、Win64 Debug/Release、LoadLibrary 与三项 ABI 导出均通过，待真实宿主验收，见 `validation/MASTER_SLAVE_READONLY_BUILD.md`；分阶段计划见 `validation/MASTER_SLAVE_DYNAMIC_PLAN.md`。

mtMultiple 编辑校验重试四项已全部通过用户验收：新增或修改遇到重复/校验错误时保留同一 `mtEditor1` 及输入内容，改正后可提交，取消不产生无效记录。本次仅更新验收记录，DLL 不变。

2026-09-07 编辑校验重试：修复 mtMultiple 新增/修改发生非空或唯一校验错误后关闭 `mtEditor1` 的问题，现按原版保留同一编辑窗体和输入内容，允许改正后再次提交。Top/Left 写回重试、脚本、输出、排序、recovery 45 项及 Win64 Debug/Release 通过；仅更新 DLL，待宿主验收，见 `validation/MULTIPLE_EDITOR_RETRY_BUILD.md`。

2026-09-07 `mtMultiple` 脚本可读性：根据原 DLL 对照恢复生成脚本的中文注释、功能段落、空行及展开的事件过程，同时保留新版已验收逻辑。生成、FastScript、写回、导入、输出、排序、recovery 45 项及 Win64 Debug/Release 均通过；仅更新 DLL，待宿主查看脚本并做轻量功能回归，见 `validation/MULTIPLE_SCRIPT_STYLE_BUILD.md`。

`mtMultiple` 普通单表最终组合回归 1–9 项已全部通过用户验收：覆盖重复完成与保存重开、完整分页、表格交互、新增编辑与审计字段、未保存保护、导入导出打印、层级权限及最终生命周期。保存失败状态仍因无安全条件待测，“提交成功但刷新失败”继续按用户决定跳过。本次仅更新验收记录，DLL 不变，见 `validation/MULTIPLE_FINAL_COMBINATION_CHECKLIST.md`。

常规设置的表格复制、表格多选和层级权限已全部通过用户验收。层级范围、查询/翻页保持、关闭恢复及缺少部门映射时的安全拒绝均验证正常。本次仅更新验收记录，DLL 不变。

表格复制和表格多选已通过用户验收：复制开关正确控制拖选及 Ctrl+C，多选开关正确控制复选列及多行选择，查询、编辑和分页无回归。本次仅更新验收记录，DLL 不变；层级权限仍待宿主验证。

2026-09-07 表格复制修正：用户验收确认静态 DFM `beforeInit` 在动态生成模块中未生效，现已改为原版的运行时 `gridMain.ClientEvents.UniEvents.Values['beforeInit']` 赋值。生成、FastScript、输出及 recovery 回归和 Win64 Debug/Release 编译通过；仅更新 DLL，真实拖选复制待重新验收，见 `validation/MULTIPLE_COPY_MULTI_LEVEL_BUILD.md`。

2026-09-07 常规设置：mtMultiple 补齐“表格复制”和“表格多选”的 True/False 生成，并按原版部门字段逻辑实现“层级权限”；空部门安全拒绝全部结果。生成/脚本回归及 Win64 Debug/Release 通过，仅更新 DLL，真实浏览器复制和部门权限范围待验收，见 `validation/MULTIPLE_COPY_MULTI_LEVEL_BUILD.md`。

查询区/表格 UI 用户验收：交付的七项全部通过，包括 Top 查询布局、表格复选多选、列宽/过滤、分页和工具栏状态回归及 Left 布局。本次仅更新记录，DLL 不变。

2026-09-07 查询区/表格 UI：Top 查询区恢复最小高 190、200×50 控件及分隔线，网格恢复 120 列宽、行指示、复选多选等原版选项。字段标题仍取配置数据。本地生成/脚本回归及 Debug/Release 编译通过，仅更新 DLL；待宿主验收，见 `validation/MULTIPLE_QUERY_GRID_UI_BUILD.md`。

工具栏状态用户验收：七项中第 1、2、3、4、6、7 项通过；第 5 项保存失败后的状态因无复现条件暂未测试。本次只更新记录，DLL 不变。下一轮继续查询区和表格 UI 对齐。

2026-09-05 工具栏状态：已接入未查询、空结果、有记录、未保存修改及保存/撤销/失败后的启用状态，并与宿主权限取交集。本地生成/脚本回归及 Debug/Release 编译通过，仅更新 DLL；待宿主验收，见 `validation/MULTIPLE_TOOLBAR_STATE_BUILD.md`。其余截图中的查询区和表格外观仍待对齐。

完整分页栏用户验收：交付的四项测试已全部通过（跳页、切换每页行数、保存后同步、未保存保护）。本次仅更新记录，DLL 不变；查询区、表格外观及保存/撤销按钮状态等其他界面差异仍待对齐。

2026-09-05 完整分页栏：按原版参考恢复首页/末页、页码输入、每页行数及总行数/页数/耗时统计。Top/Left 生成、FastScript 和保存/导入/未保存分页保护回归及 Debug/Release 编译通过；仅更新 DLL，真实宿主待验收，见 `validation/MULTIPLE_FULL_PAGER_BUILD.md`。

2026-09-05 工具栏恢复：Left 四项功能用户验收通过。按原版 DFM 恢复 mtMultiple 的紧凑按钮尺寸、自动宽度、分组线、按钮顺序及 iconfont 图标列表。编译与本地回归通过，仅更新 DLL；实际外观待验收，见 `validation/MULTIPLE_TOOLBAR_BUILD.md`。

2026-09-05 最新：已确认名为 `mtMasterSlaveQuery.json` 的参考配置实际是 `mtMultiple`、`界面布局=Left`，保留原文件名避免破坏资源映射。动态单表生成已补入左侧纵向查询区、右侧表格和分页区，保留 Top 布局。Debug/Release 与生成/脚本回归通过，实际宿主布局待验收；本轮只更新 DLL，详见 `validation/MULTIPLE_LEFT_LAYOUT_BUILD.md`。此前原生导入及分页四项已获用户验收，下面旧阶段状态仅供历史参考。

最新修正：依照原 `mtMultiple.dfm` 恢复导入菜单及宿主文本/Excel 窗口，先独立暂存再校验接入主表；独立上传面板不再生成。需 EXE/DLL 配套更新，编译及脚本回归通过，窗口交互待验收。见 `validation/MULTIPLE_NATIVE_IMPORT_BUILD.md`。以下上传版说明属于历史记录。

最新：Z_Unit 新增 Excel 文件上传到导入草稿的入口，支持第一表固定 Name/ReMark 表头的 .xls/.xlsx；上传不直接写数据，沿用已验证的暂存/保存流程。本轮需要 EXE 和 DLL 配套更新，见 `validation/MULTIPLE_EXCEL_UPLOAD_BUILD.md`。编译、文件读取及脚本回归通过，实际宿主上传待验收。

2026-09-04 增量：`Z_Unit` 普通单表动态模块新增两列粘贴导入（Name、ReMark），支持校验、自动赋值、整批暂存/失败回退及手工保存/撤销；暂不支持 Excel 文件上传。编译及脚本回归通过，宿主待验收，参见 `validation/MULTIPLE_IMPORT_BUILD.md`。此前导出与打印四项用户测试通过。下方旧阶段描述仅供历史参考。

最新增量：`mtMultiple` 新增非黄金配置的首批动态生成，仅单表只读网格、edit 文本查询（= / like）及分页/关闭；新增修改删除与高级规则尚未实现，非空不支持配置会拒绝。编译与本地脚本测试通过，宿主待验收。参见 `validation/MULTIPLE_DYNAMIC_VALIDATION.md`。`mtEditor` 完整流程已验收并归档；勿将下面历史阶段描述等同于最新范围。

2026-09-04 最新增量：动态 mtEditor 新增 `gridcombobox / gridcomboboxextra` 的 SqlQuery 输入查询、代码/名称映射及原生网格分页。仅动态开启时初始打开空结构，输入事件按配置查询字段发送参数化查询；关闭时采用有限候选本地筛选。已通过编译与本地脚本回归，宿主交互待验收，详见 `validation/GRIDCOMBO_VALIDATION.md`。此前 lookup 弹窗分页查询/关闭修复已获用户确认正常，未在本轮修改。

- 已建立 Delphi 10.3.3 / Win64 工程文件；
- DLL 入口、`GetDllComponent('WebConfigurationModule')` 路由和控件注册钩子已恢复；
- 23 个目标业务单元及其原始 DFM 已进入 `src`；
- 236 个组件字段、90 个 DFM 事件入口均有对应声明；
- 主向导可以创建八个配置页，执行前进、后退、完成、取消和 JSON 查看；
- 配置流可以加载、保存，并保留未知 JSON 字段；
- 主表、从表、数据透视和查询条件支持通用 `TClientDataSet ↔ JSON` 转换；
- 数据节点、模块类型、功能按钮和常规设置支持无损往返；
- 七组黄金配置及其等价 JSON 表示（对象成员乱序、旧格式省略空 `Data`）均可由参考生成器返回字节一致的已知 DFM。
- 七份已验证 JSON/DFM 已嵌入 DLL；从 `ConfigStream` 打开的向导点击“完成”时，可把匹配的生成结果立即应用到当前 `TUgWebRunFrame`，并在异常时回滚原框架。
- 通用生成支持非黄金配置：一个或多个 `edit`/`memo` 排版字段的 `mtEditor`，按数字行键顺序生成字段控件、标题、变量、读写脚本和纵向布局（edit 高 50、memo 高 170，间隔 10）。非空规则支持无必填、任意一个或多个已排版字段必填；字段需使用单字符表别名及合法且无冲突的标识符。edit 及非空规则已通过宿主实测；memo/混排已通过原生生成测试，待宿主验证多行读写。

Windows 后续状态：兼容基线已确认为 UniGUI `1.90.0.1567`。Delphi 10.3.3 Win64 的 Debug/Release 已在该版本上真实编译成功，静态回归与 DLL 加载/ABI 导出检查通过；七份参考 DFM 也已在真实宿主设计器中完成创建和运行预览。详见 `WINDOWS_BUILD_REPORT.md`。

尚未声称完成的部分：功能按钮父子联动，以及任意新配置的通用 `GenerateRunFrame` 控件/脚本拼装。当前只有七份已验证配置及其等价 JSON 表示会改写设计框架；未知配置仍保存 `ConfigStream`，但不会猜测生成控件。

## 目录

- `UniGuiConfiguration.dpr/.dproj`：重建工程入口；
- `src/`：Delphi 源码和恢复出的 DFM；
- `fixtures/reference/`：七组 JSON/DFM 黄金样例；
- `reference_generator.py`：只接受黄金配置的确定性参考生成器；
- `tests/test_recovery.py`：资源、源码结构和黄金样例回归测试。

## Delphi 编译

`lookupeditextra` 已加入动态生成，映射 edOptionValue / edOptionDisplay 为代码/名称双栏，Text 及脚本变量仍保存代码。须使用 SqlQuery、关闭分页、有效显示字段；使用与普通 lookupedit 相同的候选加载方式。普通 lookupedit 已获宿主确认通过，extra 本轮待验收。

普通 `lookupedit` 首轮支持已加入动态 mtEditor：SqlQuery、关闭分页、有限行数；独立候选数据集在模块每次打开时重载，弹窗显示配置列表列，选择后输入框及变量只保留值字段。暂不实现按输入远程查询、分页或 lookupeditextra，尚待真实宿主验收。time 午夜/清空及固定 combobox 四项已获用户确认通过。

第一批多类型生成现另支持 `date`、`time`、`datetime`、`number`（整数/小数）、`check` 和纯 `SetText` 的 `combobox`；已通过原生生成测试，尚待宿主集中验收，参见 `validation/BATCH_CONTROLS_CHECKLIST.md`。SQL 下拉和 lookupedit 仍不在本批范围。

1. 使用 Delphi 10.3.3 打开 `UniGuiConfiguration.dproj`，平台选择 Win64。
2. 确认 UniGUI 1.90.0.1567、FastReport `fs26`、`uIndy26` 及宿主自研控件包位于 IDE Library Path。
3. 确认运行时包列表与工程中的 `DCC_UsePackage` 一致。
4. 编译前把宿主工程使用的自研控件源码路径加入 Search Path，尤其是 `TUniDBTreeGrid` 所在单元。
5. 编译输出默认位于 `bin\Win64\Debug` 或 `bin\Win64\Release`。

当前工程已在 Windows 上使用 Delphi 10.3.3 完成 Win64 Debug/Release 编译。静态回归覆盖单元引用、DFM 事件、组件声明、JSON 结构、黄金输出、动态编辑器生成以及生成后的设计器对象树/脚本刷新。

## 回归测试

在仓库根目录执行：

```bash
python3 work/unigui_recovery/reconstruction/tests/test_recovery.py
```

参考生成器示例：

```bash
python3 work/unigui_recovery/reconstruction/reference_generator.py \
  work/unigui_recovery/reconstruction/fixtures/reference/mtTree.json \
  /tmp/mtTree.dfm
```

七份黄金配置使用已验证的内嵌模板；通用生成目前另支持上述安全边界内的多字段 `mtEditor`。超出支持范围时明确提示原因并保持精灵打开，不改写控件或提交宿主 `ConfigStream`，不再静默跳过生成。

动态生成成功后会在一次性浏览器回调中通过宿主 `IUGDesignFrame` 重建对象树并刷新脚本编辑器；每个动态字段均校验控件及对应 `v...` 脚本变量已经写入 `TUgWebRunFrame.Codes`。原生测试 `tests/EditTemplateProbe.dpr` 覆盖 1、2、3、12 字段及 DFM 解析；用户已确认多字段显示、变量与必填校验、保存重开和连续完成四项宿主测试通过（仅 edit、仅第一字段非空）。

宿主侧应通过 `UGMM.GetDllComponent('UniGuiConfiguration>WebConfigurationModule', Self)` 调用。`UniGuiConfiguration` 由宿主管理器用于选择 DLL；宿主解析后，传入 DLL 导出函数的组件名为 `WebConfigurationModule`。

2026-09-08：动态 `mtMasterSlave` 的 `datetime`、`lookupedit`、`lookupeditextra`、`gridcombobox`、`gridcomboboxextra` 已完成首批生成。候选数据集现在同时在初始化和动态查询前显式绑定 `cDataNodeName`，修复真实宿主“修改→保存”时节点数据库为空的问题。详见 `validation/MASTER_SLAVE_OBJECT_TYPES_BUILD.md`。

2026-09-08：`mtMasterSlave` 工具栏初始化时保存宿主授予的按钮权限，之后按“宿主权限 AND 原版业务状态”完整重算。修复点击修改后删除、修改和三个审批按钮被宿主权限检查重新启用的问题，同时避免旧 `Enabled=False` 阻止审核后的反审按钮恢复。生成脚本保持统一拆行和缩进格式化。详见 `validation/MASTER_SLAVE_TOOLBAR_STATE_BUILD.md`。

2026-09-08 用户验收：上述 `mtMasterSlave` 工具栏权限与业务状态合并修复已在真实宿主中测试通过，纳入回归基线；本次仅更新验收记录，DLL 不变。

2026-09-08：动态 `mtMasterSlave` 开始原版界面对齐：框架恢复 1270 宽度，主表字段恢复每列三行布局，避免审批字段被裁掉；工具栏恢复 iconfont 图标、原版索引、尺寸、左对齐及业务分组线。五组 DFM/FastScript、45 项 recovery、Win64 Debug/Release 和 DLL ABI 检查通过，待真实宿主验收，见 `validation/MASTER_SLAVE_LAYOUT_STYLE_BUILD.md`。

2026-09-08 用户验收：`mtMasterSlave` 界面对齐 1–5 项全部正常，包括工具栏外观、字段完整显示、查找控件布局、窗口缩放及按钮状态回归；纳入正式回归基线，本次仅更新记录，DLL 不变。

2026-09-08：明细 lookupedit/lookupeditextra/gridcomboboxextra 新增单元格弹窗编辑桥接，gridcombobox 进入修改时恢复候选 SQL 并清除过滤。第一轮真实宿主未通过；第二轮改为同窗体浮动面板，普通 gridcombobox 在原生展开过滤后恢复静态候选。四组脚本、45 项 recovery、Win64 Debug/Release 及 DLL 加载/导出检查通过，第二轮真实宿主待验收，详见 validation/MASTER_SLAVE_DETAIL_LOOKUP_BUILD.md。
