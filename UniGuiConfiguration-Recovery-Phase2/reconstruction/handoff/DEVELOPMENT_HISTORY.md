# 配置精灵：开发沿革、实现地图与回归约束

整理：2026-09-13。当前状态和发布基线以 [START_HERE.md](START_HERE.md) 为入口。本文件按技术阶段归纳，不虚构每次用户测试的日期；详细过程保留在 validation 和 deployment。

## 1. 最初恢复了什么

依据 [第一阶段报告](../../PHASE1_REPORT.md)：目标为 Delphi 原生 Win64 DLL。解析 PACKAGEINFO 得到36个编译单元，其中22个业务/界面单元；提取29个PE资源，含25个二进制DFM，解码236个对象和77个事件绑定。从七组**生成样例**的 Codes.Strings/Events.Strings 得到3,754行PascalScript与115条事件绑定。

这些数字属于当时提取阶段，不能与后来重建工程单元/事件总数直接混比。事件名和窗体属性不是事件实现源码。机器码中的通用生成逻辑没有被完整恢复成原始Pascal，路线是接口兼容重建。

第二阶段建立DLL ABI、配置文档模型、数据集JSON转换、七组黄金输入输出和窗体资源工程。最早只能回放匹配样例，不支持任意新配置；这属于历史阶段，不应拿旧README中的拒绝限制判断现在所有模板。

## 2. 按阶段的开发过程

| 阶段 | 主要完成工作 | 关键纠错/结论 |
|---|---|---|
| 资源与骨架 | DLL导出、模块注册、原窗体、配置区块与默认数据 | ABI为AddDllControl/DelDllControl/GetDllComponent；不是原源码恢复 |
| Windows运行 | Delphi Win64编译、依赖包、设计器加载 | DetailedStructure真实继承DataStructure；DFM inherited不能改成普通基类；兼容基线.1567 |
| 动态编辑 | mtEditor控件、变量读写、下拉、必填、隐藏字段 | 宿主脚本类型与Delphi源码类型不完全相同；隐藏控件可不生成但回填变量需要保留 |
| 主从模板 | 单据导航/新增修改/撤销/审核消审撤回、明细关联/校验/编号/导入、布局 | 层级权限需开启才生效；查询窗体和导航都必须受权限限制；最终约定范围验收通过。**事件入口约定**：公开入口保留原名做异常边界包装（`ShowActionError`）与必填焦点复位（脚本全局 `vRequiredFocus`），真实实现放 `Execute<入口>`；按契约切片的测试要指向 `Execute<入口>`，单独编译包装片段需带脚本全局声明 |
| 精灵交互 | 别名同步、排序、静默勾选、导航页面、类型说明、批量选字段、非可视布局 | 改别名不能只改显示行；整份引用同步；字段序号数字升序；临时数据集不应进配置序列化 |
| 通用列表 | 查询控件/比较条件/IN、下拉、导入、编号、编辑重试、多选删、保存定位、关联 | 保存失败不关闭编辑窗；主键定位而非列/行位置；mtMultiple数据透视按原版排除 |
| 报表 | 汇总、明细钻取、参数、分页、筛选、分组表头、导出/打印 | 不分独立汇总/明细打印入口；仍用原AddReport配两个打印模板；本批验收通过 |
| 公共提示与生命周期 | SweetAlert、LT、必填标题/焦点、JSON泄露、空白弹窗、重复生成释放 | 异常仍中止业务；不做全局Ext补丁；两项编辑器故障注入未测保留 |
| 树形模板 | 树结构、节点CRUD、暂存保存、方向移动、权限、列布局、原打印附件、脚本/样式 | 修复空Delta、反向移动关闭数据集、编辑回填、隐藏校验和部门名称被审计逻辑忽略；用户本期验收通过 |
| 下一阶段 | mtDetail独立恢复 | 专项计划先确认业务模型、记录编号、关联范围，再实现 |
| mtDetail | 显式路由 + `DetailPlan/DetailTemplate`；宿主确认生成/界面/查询/首上下末导航，**本期验收通过（2026-09-13 用户宿主反馈：D01/D05/D06–D15/D19/D20/D22/D24）**；写路径（新增/修改/删除/导入/保存/撤销）脚本生成、FastScript 编译、原生数据集钩子 | 关联从表可推导、录入时间可省、行数限制按驱动；提示/确认/异常与从表非空参照 mtMultiple；保存前整表组合唯一；**从表唯一比较字段含「关联从表」时取主表当前键值，并用记录编号（未配记录字段时兜底）排除当前行**（宿主报 `No found variant named 'vFStockID'` 的根因是编辑子窗体只提供可编辑字段变量）；DBAutoincrement 由库端赋值，保存后按主记录重载回显；**非可视控件必须写设计期 Left/Top**（`TUgSweetAlert` 缺坐标被设计器堆到左上角）；**从表非空列标题标红**（`Title.Font.Color = clRed`，参照 mtMasterSlave） |

## 3. 代码地图：从配置到运行

| 层次 | 主要位置 | 接手注意 |
|---|---|---|
| DLL入口/注册 | `src/ugRegDllControl.pas`、`ugCallModular.pas`、工程dpr | 保持宿主ABI，不改导出名称 |
| 配置模型/序列化 | `ugConfiguration.Document.pas`、`DataSetJson.pas`、`ugWebConfigurationBase.pas` | JSON空值/数字键/未知配置保留；明确所有权 |
| 精灵控制器 | `ugWebConfigurationModule.pas` | 页面适用范围、当前页、导航/完成流程 |
| 通用结构/别名 | `ugWebConfiguration.DataStructure*`、`DetailedStructure*`、`ugConfiguration.TableAlias.pas` | 从表页继承主结构逻辑，避免只修一页 |
| 配置子窗 | `QueryCriteria*`、`DataPerspective*`、`NormalSetting*`、`DropDownOptions`、`DataCheck` | 编辑/确认/取消/再次打开/析构都要核对 |
| 生成与安装桥 | `ugWebConfigurationModule.GenerateRunFrame.pas` | 选模板、备份、解绑设计画布、清理旧控件、载DFM、校验、失败恢复 |
| 编辑模板 | `ugConfiguration.EditTemplate.pas` | 控件类型、输入输出变量、隐藏字段、标题、焦点、SweetAlert |
| 列表/报表 | `MultipleTemplate.pas`、`MultipleQueryControls.pas`、`MultipleRecord.pas`、`MultipleJoins.pas`、`MultiplePresentation.pas`、`ReportPlan.pas`、`Report*.inc` | mtReport经MultipleTemplate入口；共享修改会影响多个已验收模板 |
| 主从 | `MasterSlaveTemplate.pas`、`DetailLookupBridge.pas` | 后者是明细下拉桥，不是mtDetail模块实现 |
| 树形 | `TreePlan/TreeTemplate/TreeWrite/TreeMove/TreeAccess/TreePresentation/TreeScriptLayout.pas` | 各司配置验证、DFM脚本、写回、移动、权限、表现与格式 |

当前路由中 mtMultiple/mtReport→TryBuildMultipleTemplate；mtTree→TryBuildTreeTemplate；mtMasterSlave→TryBuildMasterSlaveTemplate；其余尝试编辑模板。mtDetail不能靠落到编辑模板分支获得正确实现。FindEmbeddedReference对部分类型仍存在，mtReport/mtTree明确强制动态；新增模板要防止黄金样例绕过能力检查。

`fixtures/reference/mtMasterSlaveQuery.json`的实际类型为mtMultiple，不是额外模块类型。mtTreeEditor/mtMultipleEditor也都是mtEditor示例。

## 4. 固定产品行为（不要重做成相反设计）

- 初始化过程：`//运行脚本后`，`procedure UgWebRunFrameOnAfterRunScript(const sender: tobject);`；普通事件参数写作`Sender: TObject`，事件不随意添加Safe前缀，绑定同步修改。
- 脚本有段落、缩进、用途注释；不能仅靠换行破坏SQL或JS字符串。含中文Pascal源使用与工程一致的UTF-8 BOM；DFM脚本字符串应验证实际解码结果。
- 标题用配置Caption，必填标题clRed；提示关闭后定位失败控件/明细行，不只在提示前SetFocus。
- 提示/确认/输入/错误使用TUgSweetAlert及UGMM.LT。内部异常中止保存；取消与合法空值不同；完整配置编辑窗体不是全部换成SweetAlert。
- Upper/Lower不能改坏下拉返回的代码值。显示字段、返回字段、关联校验必须一致。
- 下拉输入停止后检索，旧请求/失焦回调不能重新打开或关闭错误的编辑器；保留已通过的防抖及定位修复。
- 非可视对象包括数据集、数据源、SweetAlert、桥对象及HiddenPanel，不能堆在左上角；参照对应已验收模板布局。
- “反审”显示为“消审”，“打回”显示为“撤回”；功能组和按钮中文名称只改展示，不改bt标识和业务含义。
- 精灵空模块从数据节点开始，有配置模块进常规设置；当前导航名称加粗、两端按钮不可用；功能按钮分组默认展开；“生效”勾选不重排闪烁。
- 权限与按钮初始许可分开记录，刷新状态不得重新启用原本无权的按钮。admin不自动豁免行权限。
- 提交成功但刷新失败明确说明已保存成功，禁止重复提交；重载后恢复。校验失败保留编辑窗及此前暂存记录。

## 5. 已踩过的关键问题

### 5.1 数据与脚本

- FastScript未注册IntToHex：树列布局文件名编码使用独立十六进制算法，不新增不受支持调用。
- TParams默认索引与宿主注册差异：SourceParams[I]出现String/Integer冲突，参数Assign链式调用曾AV。查当前参数复制实现和注册，不因Delphi能编译就推断脚本能运行。
- AddReport要求菜单按钮，树btPrint使用TUgMenuButton兼容TUniMenuButton，不能换成TUgButton。
- memo出现String/TCaption不兼容；读取属性必须采用已验证宿主适配方式。
- ChangeCount=0不保证没有修改行状态：字段改回原值后原生数据集曾复现。需要Delta时判断条件，无Delta用当前Data核对，不能访问未打开数据集或跳过唯一校验。
- 关联表只展示字段不能被写回；按字段名/变量名和稳定主键映射，不按当前列序号。多重匹配应报错而非任取一条。
- **SQL 方言不能照抄原版样例**：原版生成的动态取数例程用 MySQL 的 `limit N` 收行数（见 `fixtures/reference/mtMasterSlave.dfm` 的 `aCustCodeOnExtEditValueChange`），照抄到 MSSQL 节点就是宿主报的 `"limit"附近有语法错误`（2026-09-19 实测）。行数上限改为在脚本里按驱动现算：`cDataNodeDriver = UGMM.GetNodeNameByDriver(cDataNodeName)`，`MSSQL`/`MSAcc` 用 `top N`、`MySQL`/`SQLite` 用 `limit N`、`Ora` 不加，与 `DetailTemplate` 的导航取数同一约定。新增取数代码要一并考虑方言（`DetailTemplate` 的日期字面量、`top 1` 都是这么写的）。
- **配置 SQL 写进脚本常量前必须归一化换行**：`SqlText` 下拉的 `mmText` 若是多行，真换行会进到脚本的单引号常量里，FastScript 编译直接报 `Expression expected`（宿主表现为模块加载失败）。`tests/FsNewlineProbe.dpr` 是这条规则的取证探针；查找字段的 SQL 一直有这条归一化，`SqlText` 在 2026-09-19 才补上。
- **拼 `LIKE` 时值的引号只由 `quotedstr` 提供**：常量只写到 ` like `，**不要**把值的起始引号写进常量，否则与 `quotedstr('%' + value + '%')` 自带的引号重复，运行时拼出 `like ''%值%'`，MSSQL 报「字符串 '…' 后的引号不完整」（2026-09-19 实测，本批自己引入又修掉的回归）。原版写法就是 `' like ' + quotedstr('%' + value + '%')`。**并且**：片段断言（`Pos('where (… like')`）看不出引号多寡，`Flat()` 这种去引号的比较更是完全看不出来——这类缺陷必须靠**逐字符比对整条 SQL**（`MultipleScriptProbe` 两个 profile 已改成整条比对）或对解码后脚本原文的精确片段断言才能拦住。

- **新增单元要同时登记 `.dproj` 与 `.dpr`**：只往 dproj 加 `DCCReference`、忘了 dpr 的 `uses`，会报 `F2613 Unit not found`；而 `build-win64.bat` 只看 msbuild 的退出码、日志里含 NUL 字节时 `grep` 又会退化成"Binary file matches"一行摘要，**构建失败会被静默漏掉**。检查构建结果一律用 `grep -a`，并核对 DLL 的时间戳与哈希是否变化。
- **配置里的"布局类"数据要跟着数据结构自愈**：换表后 `cdsTypesetting`/记录区布局里会残留旧字段。「排版」表一直是"以当前字段为准"同步（取消勾选就删行），记录区布局原本却是"先按旧配置建行、再补新字段"，于是新旧字段混在一张表里，生成时还会因残留字段报错卡住（宿主 2026-09-19）。布局类区块统一按自愈处理：字段不存在/未勾选就丢弃，全部丢弃后才拒绝并提示重新确认。
- **DFM 属性值里的非 ASCII 必须用字符码、且不能被引号包住**：`Title.Caption = #26126#32454` 是对的，`Title.Caption = '#26126#32454'` 会让宿主把 `#26126` 当普通文本显示出来（宿主 2026-09-20 实测）。工程里两类编码器分工要记牢：**属性值里的中文用纯字符码式（`Enc`）**，引号包裹式（`Q`）只适合 ASCII；两者的实现现在都保证"ASCII 输出不变"。
- **功能可用性＝生成侧 + 精灵侧两侧都通**：从表明细第一版只做了生成器，从表结构页签与相关设置项仍只对mtMasterSlave/mtDetail 可见，用户在精灵里**根本配不出来**（宿主 2026-09-20 反馈）。新功能落地前要同时检查：页签路由（`ugWebConfigurationModule` 的 TabVisible）、目录项适用列表（`NormalSetting`/`FunctionButton` 的 Support 串）、以及"配了暂时不生效"的设置项**宁可先不开放**也不要静默忽略。
- **生成的脚本里“调用”与“定义”必须成对**：条件定义的辅助过程若被无条件调用，就会出现“调用了未定义的例程”（宿主 2026-09-19 报 “标识符未宣告: LEAuditFill”：审计字段一个都没配时定义被省略、调用还在）。要么两边用同一个条件，要么把定义做成空操作后始终生成。**并且：这类缺陷只有“真的编译一遍生成的脚本”才能拦住**——本轮为此给控件类型与布局两个用例加了 list-editor-compile 编译闸门。
- **测试不能读陈旧的生成产物**：运行时用例如果读磁盘上以前生成的 DFM，生成器的改动就不会被覆盖（本轮就是这么漏掉上面那条的）。用例必须“先按当前生成器生成、再编译、再执行”。
- **脚本变量的声明条件要覆盖所有使用它的分支**：`LEIsNew` 原先只在 MaxInt/自增编号下声明，Guid 编号的模块一旦引用就报"标识符未宣告"（宿主 2026-09-19）。新增共享变量前先列出所有引用点，声明条件取并集；这类缺陷只有"真的编译一遍生成的脚本"才能拦住（本轮为此给脚本探针加了 `list-editor-compile` 只编译模式）。
- **`for ... do` 后跟多条语句必须 `begin/end`**：生成器里漏了大括号，`for` 只吃掉紧随的一条语句，后面的 `if` 会退化成"循环结束后执行一次"，还会用到陈旧的循环变量下标（本批记录区只读循环就是这么错的：脚本里出现了 `leField20`，而 DFM 只有 20 个控件）。生成器写循环要逐条核对结构，不能只看生成结果"大致对"。
- **记录区/编辑器脚本里引用控件名要先确认控件存在**：`leFieldN` 是按“记录区字段序号”拼出来的，一旦某字段没有控件（隐藏、未放进记录区），`leFieldN.SetFocus` / `Labels[I]` 就会指向不存在的控件或越界。生成侧要么跳过聚焦，要么在生成期明确拒绝，不能假定“所有字段都有控件”。

### 5.2 树部门名称最终修复

用户配置：`录入部门=a.fdClassName`，`层级权限=False`，业务字段fdClassName可编辑。旧脚本只GetValue(vfdClassExplain)，忽略名称回传，新记录名称为空时用登录ClassName填充。不是第一行/列位置错位。

当前TreeWrite规则：不启用层级权限且部门字段可见可编辑→业务输入优先，不做部门自动覆盖；开启层级权限→保护部门归属；隐藏/不可编辑部门→保留审计填充。审计字段重复/结构字段冲突仍检查。只改树生成器，不能无差别推广所有审计字段。

回归：`tests/tree_department_input.test.py`四组合；`tree_write_state.test.py`用财务部/财务二部及独立描述测试真实生成动作。当前用户已确认通过。

### 5.3 内存与界面生命周期

- 批量新增临时数据集无名称，却进入通用配置保存；空JSON键不接管对象，引发整棵JSON泄露。临时副本独立管理，空名数据集不序列化。
- JSON行读取字段前就建立父对象所有权，字段读取抛异常也能释放。局部压力测试无增长不是证明宿主所有路径绝无泄露。
- 空白弹窗不只是高度：锁定分组表格BufferedRenderer行高同步异常导致layout挂起，后续窗口也空。局部元数据表格禁用缓冲渲染；不全局重置计数，不恢复旧DialogLayout高度补丁。
- 报表页签重复生成：外层销毁先递归销毁内层tabPanel，随后独立销毁引用报undefined。生成桥先局部分离内层、保留UniGUI释放流程。注入JS用实际JSName；该路径`#1`不会自动替换。
- 不能硬编码O6CB等动态ID修复产品，不能用全局Ext覆盖/异常吞掉来掩盖所有权问题。
- **统一 cleanup 的指针必须在所有退出点之前初始化**（2026-09-20）：`TryBuildListEditorTemplate` 末尾统一 `DetailPlan.Free`，但计划要到函数后段才 `DetailPlan := nil;` —— 于是所有**前置拒绝**（只读+输出按钮、布局非法、未知按钮…）都会去 Free 一个未初始化的局部指针。表面症状是探针"跑完全部断言后退出时 Access violation"（读 `0xFFFFFFFFFFFFFFFF`，即把野指针当空串索引），实质是**堆被踩坏**：这条路径在宿主里同样会跑到（配置非法时点"完成"），只是宿主对内存错误的可见度更低。教训有两层：① 指针变量在 `var` 段或函数开头就置 nil，不要在用到它的地方才初始化；② 这类错误**只有"退出码"能抓到**（断言全过、消息全对），所以探针测试必须断言 `returncode == 0`，不能只看输出里的 `PASS`。
- **从克隆里摘掉设置项 = 连带摘掉了被复用生成器的校验**（同上）：`mtListEditor` 复用 `mtMultiple` 生成器，为了不让 `mtMultiple` 误判，我们把「审计字段（录入用户/录入时间/修改用户/修改部门/修改时间）」等设置从克隆里摘掉，改为自己的写入生成器负责。摘掉之后，"只读列表 + 配了审计字段"就**没人校验**了，被静默接受（批次二探针 `无写按钮时审计设置未被拒绝` 抓到）。现在由 `ListEditorTemplate` 自己给出同义拒绝（「录入部门」除外：只读下它是层级权限的查询过滤，`mtMultiple` 也是这么放行的）。教训：复用别的生成器并摘字段时，必须逐条列出**被摘掉字段原本由谁校验**，并在自己这侧补上。同理，摘除清单要随功能补齐（「记录编号」是从表设置，漏摘就会在宿主里报 `mtMultiple 首批尚未实现常规设置：记录编号`）。
- **统一收尾函数不要释放"要交接给调用方"的对象**（2026-09-20，第三次踩同一族）：`TryPlanListEditorDetail` 的成功路径原先和失败路径共用同一个 `Release`（内含 `FreeAndNil(Plan)`），调用方拿到的是悬空指针——探针当次就 AV。成功与失败两条出口必须分开（`ReleaseTemps` 只收临时清单 / `Release` 连计划一起放掉）。
- **不要自己发明宿主设置项的 JSON 键名**：先读精灵目录项（`ugWebConfiguration.NormalSetting.pas` 的 `AddSetting` + 对应 `Setup*` 对话框写出的键）与先例模板的读取代码（`mtMasterSlave` 读 `从表唯一`/`从表非空`/`明细编号`）再定形状。本轮据此确定：`记录编号` 是**从表结构分组**的明细自动编号（3000，JSON：cbField+cbAutoNumberType+edPrefix/edSuffix/seDigitCapacity），`明细编号` 是单个从表字段（行号列），`从表唯一` 是 `{cbField, cdsMultiSelectFields}`，`从表非空` 是分号分隔字段清单。

相关记录：[WIZARD_MEMORY_AUDIT](../validation/WIZARD_MEMORY_AUDIT.md)、[WIZARD_LOCKED_GRID](../validation/WIZARD_LOCKED_GRID_20260912.md)、[REPORT_TAB_DISPOSAL](../validation/REPORT_TAB_DISPOSAL_20260912.md)。具体文档的后续旧“待验收”文字需结合用户后续通过反馈。

## 6. 回归入口建议

| 修改区域 | 应选择的现有测试（先读前置输入） |
|---|---|
| 树 | TreeTemplateProbe、tree_write_state.test.py、tree_department_input.test.py、tree_access.test.py、tree_presentation.test.py |
| 编辑/隐藏/参数传递 | EditTemplateProbe、editor_hidden_validation.test.py、editor_audit.test.py、editor_initialize.test.py |
| 列表共享写回 | MultipleConfigProbe/MultipleWriteProbe、multiple_validation.test.py、相关multiple_*脚本 |
| 报表共享/页签 | report_summary、report_features、report_print、report_headers、generated_tabs_cleanup、generation_cleanup |
| 精灵结构/内存/窗口 | wizard_memory、wizard_locked_grid、query_batch、wizard_ui相关测试 |

文件均在tests；后缀可能为.test.py/.test.js/.dpr，先列目录再运行。旧test_recovery.py有断言还要求单表限制或旧分支等，更新需记录为何过时，不整体删除。mtDetail引入时新增专项测试，不只跑其他模板样例。

## 7. 历史资料的优先级

1. 最新明确用户反馈对应的具体操作与配置；
2. 当前源码和实际交付哈希；
3. 专项测试及其覆盖层级；
4. 原版输入/输出与资源证据；
5. 历史计划和旧候选说明。

若冲突，记录差异并核对，不能静默把计划当实现，或把已修的历史问题又列为未实现。当前根README含多轮追加记录，接手先读本目录。原版范围由证据决定；新增优化应明确说明与原版不同，如主表分组是用户同意的扩展。
