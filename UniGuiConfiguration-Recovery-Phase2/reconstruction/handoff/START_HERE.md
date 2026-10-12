# 配置精灵恢复工程：接手入口

更新：2026-09-13。用途：供后续模型或开发者在没有完整聊天历史时接手。此次仅整理文档，不修改业务代码、不生成新 DLL。

2026-10-12 总体交接总览：[PROJECT_HANDOFF_20261012.md](PROJECT_HANDOFF_20261012.md)。该文档优先说明模板验收状态、未测边界、宿主迁移和推荐接手顺序；本文件保留完整分批历史。

mtListEditor 更新（2026-09-19 批次一）：**记录区独立字段布局与分组布局已完成并获宿主验收通过**（用户 2026-09-19 反馈「记录区布局 测试通过」）——常规设置新增「记录区布局」(1015)，可配记录区位置(Top/Left)、列数(1..3)、每列宽度、分组标题，以及每字段的 显隐/顺序/标题/分组/跨列/宽度；未配置该区块时行为与之前完全一致。最新包 `deployment/list-editor-record-layout-20260919`（DLL `94F56D92…`，已含宿主第一轮反馈修复：布局取自常规设置、上移下移改真交换）。
mtListEditor 批次四 S2 第一片（2026-09-20 **宿主验收通过**：从表联动 + 明细区表头中文）：**从表（明细）只读联动**——从表结构/关联字段/关联从表/隐藏字段-从表 已接入，明细区在记录区下方只读显示并随主记录联动；**写模式 + 从表 明确拒绝**（明细写入/导入在后续片）。包 `deployment/list-editor-detail-readonly-20260920`（DLL `3800C975…`）；范围与后续片见 [MTLISTEDITOR_BATCH4_PLAN_20260919.md](MTLISTEDITOR_BATCH4_PLAN_20260919.md) §7/§8。
mtListEditor 导入（btImport）—— **已完成（2026-09-22 本地通过 / 宿主未测）**：批次三挂起的「导入」收口，语义按**原版证据**定案为**方案 B（把文本/电子表格批量导入当前列表）**——原版参考件 `fixtures/list-editor/user-reference-20260917.dfm` 里就是 `g := gridMain; fe := '<字段名;>'; fs := '<列标题;>';` + `UGMM.ImportText(g, fs)` / `UGMM.ImpExcel(g, Self.Caption, fe)`（§7.8 当时建议的"只做明细导入"是没看到这段证据时的推断）。按钮照原版：TUgMenuButton、位置在「修改」后「保存」前、`ImageIndex = 10`（＝`icon-ico_daoru_xuanzhong`），下拉 文本格式/电子表格。新增**导入暂存态** `LEState = 4`：导入行落在 cdsMain 未保存，保存＝逐行补号/补审计 + 全行校验（按行号报非空、组合唯一含数据库）+ 一次提交 + 刷新；撤销＝丢整批；查询/关闭前确认；暂存态下表格可用（能滚动查看）、其余入口按状态收敛。生成期三条拒绝：只读列表勾导入、「非空字段」落在复选/自动赋值字段上（复选列填不上，`TBooleanField.SetAsString` 只认 True/False 文本）、一个可导入字段都没有。踩坑两条已记：①`TDataSet.RecNo/RecordCount` 是 **public** 属性，脚本里引用会报 `Undeclared identifier`（编译闸门抓到）→ 改成不恢复光标；②未勾导入的模块**逐字节不变**（新发射全部 `if ImportOn then … else 原代码` 分流，另立 `tools/le_dfm_hash_guard.py` 守卫 10 个既有夹具）。包 `deployment/list-editor-import-20260922`（DLL `5A421B1C…`）；新增 `tests/list_editor_import.test.py`（7 用例）；全量 **89 文件 162 用例通过 0 失败**、`test_recovery.py` 退出码 0。诊断全文见 [MTLISTEDITOR_BATCH4_PLAN_20260919.md](MTLISTEDITOR_BATCH4_PLAN_20260919.md) 第二十轮。**未做**：宿主复测；"从别的模块/查询窗体多选记录导入"（需 list editor 的模态桥，单独一轮）。
「记录区布局」移植到 mtMasterSlave —— **已完成（2026-09-22 本地通过 / 宿主未测）**：常规设置「记录区布局」(1015) 现在**对 mtMasterSlave 也开放**，生成侧按布局排版记录区（位置 Top/Left、列数 1..3、每列宽度、字段顺序/标题/跨列/单字段宽度/分组/显隐），解析与拒绝口径与 mtListEditor **共用同一份**（`ugConfiguration.ListEditorLayout`）。两条关键做法：①**未配布局的模块逐字节不变**（改动前后 5 个场景 DFM 的 SHA-256 完全一致）；②**显隐用"控件照常生成 + `Visible=False`"**，不做"不生成控件"——脚本里 `a<字段>` 被 SetEditState/Loada\<字段\>Items/动态查找事件/必填聚焦/导入审批多处引用，少生成一个就是"标识符未宣告"（宿主编译闸门抓到过）。上一轮没查清的生成器 AV 已定位：`MainFields.IndexOf(...)` 后直接下标取值，布局里"当前数据结构已没有"的字段行会让下标变成 **-1**（`TStringList[-1]` 读野指针 → `Read of address FFFFFFFFFFFFFFFF`），现在所有布局查询都先判 -1、显示顺序也从构造上保证只含主表字段。包 `deployment/masterslave-record-layout-20260922`（DLL `C294F14A…`）；新增 `tests/masterslave_record_layout.test.py`（13 用例：生成契约/编译闸门/8 条拒绝/未配布局回归/宿主属性）；全量 **88 文件 155 用例通过 0 失败**、`test_recovery.py` 退出码 0。诊断全文见 [MTLISTEDITOR_BATCH4_PLAN_20260919.md](MTLISTEDITOR_BATCH4_PLAN_20260919.md) 第十八轮 / 第十八轮续 / 第十九轮。**未做**：宿主复测。
分隔线颜色调淡 + 记录区分隔线定位修正（2026-09-21 **本地通过 / 宿主未测**）：①各模板分隔线颜色统一 `$00C7C8C4`（十进制 13093060）—— 生成器源头 15 处 + 向导侧兜底替换（覆盖原版参考件自带的线，否则探针走不到、本地验证不了）；②分组路径下 `pMain` 是 `TUgScrollBox`，记录区那条线原来用 `alBottom` 贴的是**视口**底部（内容更高时跑到中间，宿主截图指出）→ 改为按内容高度绝对定位。包 `deployment/separator-color-20260921`（DLL `0809DD53…`）；全量 86/0。**下一件**：把「记录区布局」移植到 mtMasterSlave（宿主提出）。
mtMasterSlave 布局修正（2026-09-21 **本地通过 / 宿主未测**）：①明细工具条 pDetailBar 高度写死 30 而主工具条是 33 → 改成从 DFM 读 pToolbar 的实际高度；②补回原版的两条 1px 区域分隔线 `topline`（工具栏底部）与 `lbEditControls`（记录区底部）——生成器重排工具栏/记录区时漏发了，并给明细工具条补一条同风格 `detailBarLine`。附带修掉记录区分组重排把分隔线算进"控件数=字段数"而报 `Main group control count mismatch` 的问题（分组时跳过、重建后补回）。包 `deployment/ms-layout-lines-20260921`（DLL `D920F17F…`）；全量 86/0。
明细行按钮图标按宿主指定类名（2026-09-21 **本地通过 / 宿主未测**）：复制行 `icon-fuzhi`、插入行 `icon-caidanshouqi`、清空 `icon-guanbi2fill` 写进 Imgs（追加在末尾，列表 27→31 项，索引 28/29/30；展开查询 pingmufangda 是 27），mtListEditor 与 mtMasterSlave 两边索引完全一致。包 `deployment/detail-icons-20260921`（DLL `8FBB13AE…`）；全量 86/0、两边生成脚本都过编译闸门。
mtMasterSlave 明细区 7 个行按钮 + pDetailBar 宽度修正（2026-09-21 **本地通过 / 宿主未测**）：按宿主确认，明细行按钮（新增行/插入行/删除行/复制行/上移/下移/清空）现在 **mtListEditor 与 mtMasterSlave 都有**（目录项适用列表两者都放）；mtMasterSlave 的工具条是 alTop、插在 gridDetailed 之前，行操作沿用它的既有模型（空白占位行当场落库/父键当场补齐/RenumberDetails 排行号）。另修 pDetailBar 宽度：按钮 AlignWithMargins 要吃掉左右边距，按"按钮数×70+8"算（7 个=526），清空按钮不再被裁。包 `deployment/ms-detail-buttons-20260921`（DLL `FF1357F5…`）；全量 86/0、mtMasterSlave 生成脚本过宿主编译闸门。
mtListEditor 明细区 7 个行按钮（2026-09-21 **本地通过 / 宿主未测**）：按宿主指定把明细区按钮做成**按钮目录项**（功能按钮页新增分组「明细行功能」）：新增行/插入行/删除行/复制行/上移/下移/清空，**勾了才生成**；新做 插入行（当前行之前插入占位行）、上移/下移（与相邻行交换业务字段值）、清空（删当前主记录全部明细行，保存时落库）；三条拒绝（只读下勾/未配从表/只勾删除类）。图标位用 mtDetail 的 Imgs：7/1/8/2/20/21/25（插入/复制/清空暂取最接近的，待宿主给类名）。包 `deployment/list-editor-detail-buttons-20260921`（DLL `1FFCB9F7…`）；全量 85/0。**待确认**：这 7 个按钮是否也加到 mtMasterSlave 的明细区（其生成侧还没接，目录项目前只放 mtListEditor）。
mtListEditor 图标对齐（2026-09-21 **本地通过 / 宿主未测**）：宿主指定"Imgs 按 mtDetail 来 + 展开查询用 icon-pingmufangda"。内嵌模板的 Imgs.IconText 只有 14 项，而工具栏索引（导出16/打印17/附件18/关闭23）是按 mtDetail 的 27 项定的 → 生成时整体替换成 mtDetail 的 27 项并追加 pingmufangda（索引 27，既有索引不动）。包 `deployment/list-editor-iconlist-fix8-20260921`（DLL `B48354FE…`）；全量 85/0。**进行中**：明细区 7 个按钮（新增行/插入行/删除行/复制行/上移/下移/清空）做成按钮目录项，待确认是否同时加到 mtMasterSlave。
mtListEditor 批次四 S2 第二片修复七轮（2026-09-21 **本地通过 / 宿主未测**）：宿主反馈"查询条件标题中文乱码"——根因在 `MultipleQueryControls.Quoted()` 只做引号包裹、不把非 ASCII 转成 DFM 字符码（宿主按 DFM 文本编码解析成乱码）；已改成 DFM 正确形式（ASCII 引号包裹、非 ASCII 落引号外为 #NNN，纯 ASCII 输出不变）。新增通用防线：**生成 DFM 的属性区不得出现原始非 ASCII**。包 `deployment/list-editor-detail-write-fix7-20260921`（DLL `3C8DFD2C…`）；全量 85/0。
mtListEditor 批次四 S2 第二片修复六轮（2026-09-21 **本地通过 / 宿主未测**）：宿主新提两个细节——①「表格序号」要覆盖窗体上所有表格 → 明细表格镜像主表格的 dgRowNumbers；②顶部工具栏要分隔线、附件与展开查询要有图标、布局对齐 mtDetail → 新增 `RelayoutListEditorToolbar`，按原版参考件（user-reference-20260917.dfm，与 mtDetail 同表）重排：查询｜新增删除修改｜保存撤销｜导出打印｜附件 展开查询｜关闭，组间插 1px 分隔面板，图标位 0/7/8/9/11/12/16/17/18/23，步进＝宽+6。包 `deployment/list-editor-detail-write-fix6-20260921`（DLL `9A77A470…`）；全量 85/0、DFM 结构校验与编译闸门通过。
mtListEditor 批次四 S2 第二片修复五轮（2026-09-20 **本地通过 / 宿主未测**）：宿主第五轮反馈——①校验提示后明细被刷新掉/刷回原值（`LEDetailLoad` 绑在 `cdsMain.AfterScroll` 上无条件重载，报错后框架再同步主数据集就把用户的行冲掉了）→ 明细**有未提交改动时不重载**（`ChangeCount > 0` 判据，不用只在写模式声明的 LEInternal/LEState）；②浏览态明细网格还能编辑 → `gridDetail.ReadOnly := LEState <> 1;`；③新增行后"删除行/复制行"仍是灰的 → 三个明细按钮处理末尾补 `LERefresh;`。包 `deployment/list-editor-detail-write-fix5-20260920`（DLL `89A2FE6B…`）；全量 85/0、脚本过编译闸门。
mtListEditor 批次四 S2 第二片修复四轮（2026-09-20 **本地通过 / 宿主未测**）：宿主第四轮反馈"先弹图1、再弹校验提示"——触发者是挂在主数据集上的 `LEGuard`：在明细网格里编辑后点保存时，框架会先提交明细的网格编辑并顺带碰主数据集，守卫在此误报（比校验提示还早）。修法：**移除数据集事件守卫**（同族 mtMasterSlave 也没有，它只在按钮处理里显式检查状态），用户入口本来就按状态拦住（编辑态下主表格/分页禁用、查询/删除/关闭/新增各有检查）。包 `deployment/list-editor-detail-write-fix4-20260920`（DLL `C50062A6…`）；全量 85/0、脚本过编译闸门。
mtListEditor 批次四 S2 第二片修复三轮（2026-09-20 **本地通过 / 宿主未测**）：宿主第三轮反馈——①校验提示后又弹"请先保存或撤销当前编辑"（我上轮把异常抛出去，框架随后再碰数据集触发守卫）→ 明细校验失败改用**非阻塞** `ShowActionError` + Exit；②删除报 FireDACCommon 的 Access violation 但记录其实已删（宿主可能在已提交之后才报错）→ 失败时用 `LERecordExists` 复核主表与从表，都查不到即算成功（同族 mtMasterSlave 处理 CANNOT ROLLBACK 的同一手法）；④布局按宿主指定：无从表 `gridMain=alClient`，有从表 `gridMain=alLeft` + 明细区 `alClient` + 不生成 `capListEditorDetail` + `pDetailHead.Height` 与 `pButtons` 一致（读 DFM 实际值 33）。包 `deployment/list-editor-detail-write-fix3-20260920`（DLL `21359C9B…`）；全量 85/0、脚本过编译闸门。
mtListEditor 批次四 S2 第二片修复二轮（2026-09-20 **本地通过 / 宿主未测**）：宿主第二次反馈"第1项仍未过"——明细只填一个非空字段就保存，报 `Blocking method Execute() could not be called.`。根因不是非空判断，而是**校验失败的提示方式**：生成的 `WaitEditorError` 用 `errorAlert.Execute`（阻塞模态），而明细网格还挂着未提交编辑时宿主拒绝阻塞调用。修法：①保存处理开头先 `LEDetailFlushRow`（落库明细待提交行）；②**明细**校验失败改为交回宿主显示（同族 mtMasterSlave 的做法），**主记录**校验/行权限保持已验收行为。你上传的配置已固化为回归夹具 `fixtures/list-editor/detail-write-host-20260920.json` + 专项测试。包 `deployment/list-editor-detail-write-fix2-20260920`（DLL `40D2C7FF…`）；全量 85/0、脚本过编译闸门。
mtListEditor 批次四 S2 第二片修复一轮（2026-09-20 **本地通过 / 宿主未测**）：修掉宿主反馈的三条——①空明细行保存报 `Blocking method Execute() could not be called.`（新增行留在未落库的插入态，保存时服务端提交插入行需要客户端同步）；②连续"新增行"被明细守卫拦下（提示"请先提交或取消当前明细行的修改"）；③明细区按钮被网格盖住且要求右侧停靠。改为同族 mtMasterSlave 的**空白占位行**模型（新增行当场落库、保存时丢弃空行、只校验有内容的行），明细区改 `alRight` + `alTop` 头部容器放标题与工具条。包 `deployment/list-editor-detail-write-fix1-20260920`（DLL `A6D71564…`）；生成脚本仍过宿主编译闸门；全量 84/0。
mtListEditor 批次四 S2 第二片（2026-09-20 **本地通过 / 宿主未测**）：**从表（明细）写入**已接通——明细区新增行/删除行/复制行、父键回填、明细自动编号（MaxInt/Guid）与行号重排、从表唯一（当前主记录内）/从表非空（报第几行）、保存时主记录+明细一次原子提交、撤销一起回退、删主记录同事务连明细；精灵侧开放记录编号/明细编号/从表唯一/从表非空。包 `deployment/list-editor-detail-write-20260920`（DLL `B3087378…`）；复测清单见包内 README §5。生成脚本已过宿主编译闸门；**运行 profile 与宿主验收未做**。
mtListEditor 拒绝路径修复（2026-09-20 **本地通过 / 宿主未测**）：修掉 `3800C975…` 那份 DLL 里的两处缺陷——①所有"前置拒绝"路径会 `Free` 未初始化的 `DetailPlan`（表面是退出时 Access violation，实质**踩坏堆**；只读列表勾导出、记录区布局非法等被拒配置都会走到）；②「只读列表 + 配了审计字段」被静默接受（审计字段从克隆里摘掉后原校验一并消失）。包 `deployment/list-editor-reject-fix-20260920`（DLL `6F8AC28B…`，修复版 4145152 字节 / 未修复快照 4144640 字节可作判定），复测步骤见包内 README §3。**明细写入片仍未接通**（写模式+从表继续明确拒绝），执行设计见 [MTLISTEDITOR_WRITE_SLICE_DESIGN_20260920.md](MTLISTEDITOR_WRITE_SLICE_DESIGN_20260920.md)。
mtListEditor 批次三（2026-09-19 **宿主验收通过**）：**导出/打印/附件**（工具栏按钮，沿用宿主 ExpExcel/AddReport/OpenFileManager 入口，只浏览态可用；附件按当前记录主键）；**导入未接入**（需先确认“单条导入”还是“批量暂存”）。包 `deployment/list-editor-output-20260919`（DLL `83BE8B97…`）。
mtListEditor 批次二（2026-09-19 **宿主验收通过**）：新增 **审计字段**（录入/修改 × 用户/部门/时间，时间按列类型赋值、必填前填充、记录区只读）与 **层级/行权限**（查询部门 in 过滤、保存与删除按主键回库复核、空权限不成全表、admin 不豁免、开启层级权限时部门字段只读），包 `deployment/list-editor-audit-scope-20260919`（DLL `83613460…`）。
mtListEditor 支持（2026-09-19）：当前支持单根表同窗列表编辑、隐藏字段、Top/Left 查询区及默认收缩、Guid/MaxInt/数据库自增编号、新增/修改/保存/撤销和可选删除、普通文本 `Upper/Lower`，以及**按字段类型的记录区控件（文本/数值/备注/复选/日期/时间/固定下拉/SqlText 下拉/查找/多列下拉含动态加载，必填按类型判 NULL）**。最新交接状态、代码地图、测试和待办以 [MTLISTEDITOR_HANDOFF_20260918.md](MTLISTEDITOR_HANDOFF_20260918.md) 为准；最新测试包为 `deployment/lookup-dialect-20260919`（DLL `0D297C1A…`；**动态加载下拉的行数上限改为按数据库驱动生成**——宿主在 MSSQL 上点下拉报 `"limit" 附近有语法错误`，根因是照抄原版 MySQL 样例把上限写死成 `limit N`，现在 `MSSQL`/`MSAcc` 用 `top N`、`MySQL`/`SQLite` 保持 `limit N`、`Ora` 不加；`MasterSlaveTemplate` 的多列下拉动态查找同一处缺陷一并修；另修 `SqlText` 多行 `mmText` 的真换行进脚本常量导致 FastScript 编译失败；第二轮又修掉 `LIKE` 引号多一个导致宿主报「字符串 '      )' 后的引号不完整」的回归——常量只写到 ` like `，值的引号由 `quotedstr` 提供）。前序包（`list-editor-layout-order-20260919`、`list-editor-dynamic-lookup-20260919`、`list-editor-caption-fix-20260919`、`list-editor-gridcombobox-20260918`、`list-editor-sqltext-fix-20260918`、`list-editor-lookup-fields-20260918`、`list-editor-sqltext-dropdown-20260918`、`list-editor-control-types-20260918`）保留为历史；其中控件类型批宿主已确认基本生成/控件类型/数值必填三项通过。SQL 下拉/lookup/gridcombobox 的写入、审计/行权限、独立记录区布局（分组/列跨度）、输出、多表和真实数据库并发等仍未完成或需专项验收；`mtDetail` 的动态加载下拉仍未接入。

## 1. 先读这些结论

1. 工程是**接口和行为兼容重建**，不是原 DLL 原始 Pascal 源码的完整反编译。窗体资源可提取；生成逻辑是结合资源、宿主源码、原版输出样例和用户实测重建。
2. 当前用户明确确认 **mtTree 本期验收通过**：部门名称回写已解决，连续上下左右操作正常，控件样式/图标与脚本格式确认正常；后续需求另行调整。不要再把它标为未解决。
3. **mtDetail 本期验收通过（2026-09-13）**：原版 `mtDetail.json`/`mtDetail.dfm` 提供了行为证据（见 [MTDETAIL_EVIDENCE.md](../validation/MTDETAIL_EVIDENCE.md)）；已新增显式路由与 `ugConfiguration.DetailPlan/DetailTemplate` 生成器，Debug/Release 构建、DFM 语法、脚本 FastScript 编译均通过，记录见 [MTDETAIL_ACCEPTANCE.md](../validation/MTDETAIL_ACCEPTANCE.md)。宿主反馈已覆盖生成/界面/查询导航、写操作 D06–D15、D01/D05/D19/D20/D22/D24；D01–D25 逐项结论与保留边界见验收记录 §3.7/§3.8。保留：并发/大数据量/非标准标识符未测、Oracle 分支未验、查询窗体双击返回待重生成复测、两项扩充功能另行立项。
4. 用户已授权继续推进 mtDetail；仍未授权操作业务数据或替换宿主运行目录 DLL。写操作属 G2，未经宿主实测不得宣称通过。
5. 用户明确未测、排除、暂缓的项目不能因其他测试通过被转成通过。旧文档中同一事项会出现多次不同状态，按最新明确用户反馈、当前代码、具体版本证据核对。

## 2. 工作位置和资料导航

> mtListEditor 剩余工作（用户清单最后一项）：**批次四方案**见 [MTLISTEDITOR_BATCH4_PLAN_20260919.md](MTLISTEDITOR_BATCH4_PLAN_20260919.md)（第一步"多表关联＝复用 mtMultiple 的关联表机制，只展示不写关联表"；第二步"从表"分只读展示/主从写入两案；另含导入 A/B 语义），实施前需用户确认三处决策。

| 项目 | 路径/入口 |
|---|---|
| 工作区 | `D:\Projects\fastweb` |
| 可编译重建工程 R | `D:\Projects\fastweb\outputs\UniGuiConfiguration-Recovery-Phase2\reconstruction` |
| 工程文件 | [UniGuiConfiguration.dproj](../UniGuiConfiguration.dproj)、[UniGuiConfiguration.dpr](../UniGuiConfiguration.dpr) |
| 全过程、代码地图、陷阱 | [DEVELOPMENT_HISTORY.md](DEVELOPMENT_HISTORY.md) |
| 宿主源码迁移清单（旧宿主 → 新宿主） | [HOST_SOURCE_MIGRATION_MANIFEST_20260925.md](HOST_SOURCE_MIGRATION_MANIFEST_20260925.md)（只列有证据的宿主改动；禁止整文件覆盖） |
| mtDetail 工作与验收计划 | [MTDETAIL_RECOVERY_PLAN.md](MTDETAIL_RECOVERY_PLAN.md) |
| mtDetail 原版证据与映射 | [MTDETAIL_EVIDENCE.md](../validation/MTDETAIL_EVIDENCE.md)（含样例 `mtDetail.json`/`mtDetail.dfm` 及解码脚本 `validation/mtdetail-g0/mtDetail.generated.script.pas`） |
| mtDetail 验收记录（本期验收通过） | [MTDETAIL_ACCEPTANCE.md](../validation/MTDETAIL_ACCEPTANCE.md)（范围/哈希/验证层级/能力矩阵/D01–D25 结论与保留边界） |
| mtMasterSlave 测试契约核对 | [MASTER_SLAVE_TEST_CONTRACTS_20260913.md](../validation/MASTER_SLAVE_TEST_CONTRACTS_20260913.md)（三项过时契约的修正与验证） |
| 原版布局对齐（已实现，待视觉确认） | [layout-align-20260914/README.md](../validation/layout-align-20260914/README.md)（原版 mtDetail+mtEditor 原件、排布规则、逐坐标回归结果、SeqUence 等待裁决项） |
| 扩充项取证（序号列 / 多选回传） | [EXPANSION_EVIDENCE_20260914.md](../validation/EXPANSION_EVIDENCE_20260914.md)（原版字符串表与 UniGUI 机制） |
| 引用明细（多选回传到明细）设计 | [DETAIL_MULTISELECT_DESIGN_20260914.md](../validation/DETAIL_MULTISELECT_DESIGN_20260914.md)（场景/规则/方案/未测项） |
| 最初恢复证据 | [PHASE1_REPORT.md](../../PHASE1_REPORT.md)、[PHASE2_REPORT.md](../../PHASE2_REPORT.md) |
| 原版黄金样例 | `R\fixtures\reference`（原七组 JSON/DFM，不是所有模板所有配置）；已新增原版 `mtDetail.json`/`mtDetail.dfm`（用户 2026-09-13 提供，最小配置） |
| 原 DLL 窗体提取 | `outputs\UniGuiConfiguration-Recovery-Phase2\extracted\pe64\dfm` |
| 宿主源码 | **`D:\Projects\fastweb\demo\Source`**（2026-09-25 起以新宿主为准；旧宿主 `D:\Projects\fastweb\UniGui Design Demo\Source` 仅作对照——本轮恢复改过的宿主单元见 [HOST_SOURCE_MIGRATION_MANIFEST_20260925.md](HOST_SOURCE_MIGRATION_MANIFEST_20260925.md)） |
| 分批测试/历史状态 | `R\validation` |
| 独立交付包 | `R\deployment`（每包 README、DLL、范围/哈希） |

文中 R 是文档简写，不是已设置的环境变量。Markdown 相对链接按当前文档目录解析。

## 3. 当前模板状态

| 类型 | 已知现状 | 不可扩大解释 |
|---|---|---|
| mtMasterSlave | 约定范围最终验收通过；后续必填标题/焦点等补丁也有用户通过反馈 | 不是任意数据库/任意 SQL 全兼容；查看最终验收边界 |
| mtMultiple | 查询、编辑、导入、定位、关联等分批通过，随后转入 mtReport | 数据透视用户明确不实现；多条独立条件优先级等未确认边界仍保留 |
| mtReport | 本批汇总/明细、分组表头等验收通过 | 统一原打印入口；排序边界为已加载页，不承诺任意全库排序 |
| mtEditor | 已恢复并用于列表/树编辑；分批控件、回填、校验通过 | 两项故障注入未测和跨窗体错误焦点等公共边界单列 |
| mtTree | **2026-09-13 本期验收通过** | 当前单根表、GUID、既定父键/排序规则；新增需求另立项 |
| mtDetail | **本期验收通过（2026-09-13 用户宿主反馈；2026-09-14 界面布局按原版件对齐，待重新生成后视觉确认）**：显式路由 + `DetailPlan/DetailTemplate`；宿主确认生成/界面/查询打开/首上下末导航正常；查询窗体双击返回与表格多选默认值已修（共享 mtMultiple)；常规设置目录已按原版截图对齐（分组、关联从表），**宿主确认分组/关联从表/分组顺序正确**。G2 已用原生数据集验证 BeforePost 关联回填与从表唯一（内存+后台），并参照 mtMasterSlave 增加保存前整表组合唯一校验（记录字段可省略）、提示/确认/异常与从表非空改参照 mtMultiple（含保存前按行号报必填）；并按原版样例接入 DateTimeRandom/DBAutoincrement 编号与从表列排序（函数清单 36/36 对齐、脚本编译通过）；从表唯一比较字段含「关联从表」的取值与自身排除已修（宿主报 `No found variant named 'vFStockID'`），非可视控件（`TUgSweetAlert`）补设计期坐标（宿主报左上角堆叠）；从表非空列标题标红（参照 mtMasterSlave），见 §4 验收通过基线；引用明细的“字段不完全同名映射”与“引用后权限/未保存暂存边界”2026-09-14 已收口（原生探针阶段 A–H，见 [QUOTE_MAPPING_AND_STATE_BOUNDARY_20260914.md](../validation/QUOTE_MAPPING_AND_STATE_BOUNDARY_20260914.md)）；记录见 `validation/MTDETAIL_ACCEPTANCE.md` §3.4 | 主表编辑态可输入但保存只提交从表（已按原版 DFM/脚本核对，一致）；多设备并发、非标准标识符未测；SeqUence/MaxCode 原版不支持（不适用）；从表非空已实现（列标题 clRed）；D01–D25 逐项结论表见 MTDETAIL_ACCEPTANCE §3.7，验收结论与保留边界见 §3.8（D01/D04/D05/D06–D15/D19/D20/D22/D23/D24 通过；D02/D03/D17/D21/D25 部分通过；D16/D18 及 D23 两子项不适用）；隐藏字段有 g8 样例与断言 |

参考：`validation/MASTER_SLAVE_FINAL_ACCEPTANCE.md`、`MULTIPLE_NEXT_ACCEPTANCE.md`、`REPORT_FEATURES_PENDING_20260912.md`、`EDITOR_AUDIT_20260912.md`。这些文件下方保留历史阶段文字，不能只搜索到“待验收”就判定当前未完成。

## 4. 当前交付基线

- 最新本会话交付并获用户验证的 DLL：[tree-department-input-20260913](../deployment/tree-department-input-20260913/README.md)。
- **mtDetail 本期验收通过基线（业务）**：[mtdetail-required-red-20260913](../deployment/mtdetail-required-red-20260913/README.md)（DLL `CD9DB0EA…`）。用户 2026-09-13 宿主反馈在该包上覆盖 D01/D05/D06–D15/D19/D20/D22/D24；通过范围与保留边界见 [MTDETAIL_ACCEPTANCE.md](../validation/MTDETAIL_ACCEPTANCE.md) §3.8。
- **待宿主验收候选（布局对齐 + 表格序号 + 导入窗体）**：[import-frames-20260914](../deployment/import-frames-20260914/README.md)，Release DLL SHA256 `B921B27CEC02D83AA513606CAE43CBB483AB3962B5020ED4C9697ABCCBD4DBF8`（布局与控件对齐、`表格序号`、`导入窗体`（列表：标题/查询窗体/多选，支持 mtDetail 与 mtMasterSlave）；2026-09-14 第二批又收口“来源与从表字段不完全同名时的映射”与“引用后的权限/未保存暂存边界”，并修掉 `LSkips` 提前释放导致未复制字段永远显示不出来的生成侧缺陷，见包内 §3.8/§3.9）。需重新生成模块后做宿主验收；**2026-09-14 宿主已验证查询窗体单选/多选与导入明细三项通过**；本包早先的 DLL `3D7F53CA…F50B9F4D` 已被同包内的 `B921B27C…DB4DBF8` 取代；前序包保留为历史。
- 文件：`R\deployment\tree-department-input-20260913\UniGuiConfiguration.dll`。
- SHA256：`415E9A30DEECFA77D2FD4C22574AC7062EED18627436E0BFD5D1E8CF502987D9`（整理时实际核对）。
- 含此前 tree-script-style 的格式/图标修复，以及本包部门字段业务输入修复。
- 用户最后确认的两项：连续反向移动无 closed dataset、即时显示；控件样式/图标/脚本段落缩进注释正常。
- 这是交付文件基线，不代表已自动核对当前运行进程加载的 DLL 哈希。
- 不向运行宿主目录自动覆盖 DLL。新包必须隔离交付，退出宿主、备份、替换、重启、重新生成模块由明确部署流程执行。

## 5. 明确保留的事项

| 项目 | 状态/处理 |
|---|---|
| Catalog Name / Schema Name | 用户要求对齐原版禁用，暂不测试，不重新打开功能 |
| SeqUence | 历史明确暂缓，不能宣称已支持全部数据库序列 |
| DBAutoincrement 名称 | 用户曾明确不是原版编号方式；mtMultiple 历史有兼容实现，不能反推为原版配置或推广到 mtDetail |
| mtMultiple 数据透视 | 原版不支持，排除，不列缺陷 |
| editor-lookup-alert 第2项 | 动态检索故障场景未测，保持未测 |
| editor-init-alert 第4项 | 初始化故障场景未测，保持未测 |
| 统一 SweetAlert | 已有模板成果保留；精灵自身全范围迁移仍为公共待办 |
| 跨编辑子窗体服务器校验焦点 | 继续按具体入口核对，不以本地必填焦点通过代替 |
| 全量旧测试 | 三项 mtMasterSlave 过时契约已逐条核对修正（2026-09-13），当前全量 73 通过 / 0 失败；后续若再出现失败仍按“逐条核对后修正、不得删断言凑全绿”处理 |
| 数据库并发/大数据/非标准标识符 | 没有全范围兼容承诺；未实测项在各模板边界记录 |
| ~~查询窗体多选并批量回传多条明细 ID~~ | **2026-09-14 已实现并宿主验证**：升级为「导入窗体」列表配置（标题/查询窗体/多选，`基础设置.表格`，支持 mtDetail 与 mtMasterSlave）；mtMultiple 新增 `btOK` 确认按钮，查询窗体单选/多选由自身“表格多选”二选一（多选=双击不关窗+确认提交；单选=双击即返回）；单据侧模态打开来源窗体、勾选后逐条追加到从表（父键由 BeforePost 覆盖）。宿主确认三项通过（2026-09-14）。原版无此能力（取证见 [EXPANSION_EVIDENCE_20260914.md](../validation/EXPANSION_EVIDENCE_20260914.md) §2）；设计与规则见 [DETAIL_MULTISELECT_DESIGN_20260914.md](../validation/DETAIL_MULTISELECT_DESIGN_20260914.md) |
| ~~表格“序号”列~~ | **2026-09-14 已落地**：新增精灵配置项 `基础设置.表格/表格序号`（默认关闭），勾选后五个模板的网格 `Options` 带 `dgRowNumbers`（UniGUI 渲染 Ext RowNumberer）；原版 DLL 无此能力（字符串表无序号/RowNumberer 串），属精灵新增功能，取证见 [EXPANSION_EVIDENCE_20260914.md](../validation/EXPANSION_EVIDENCE_20260914.md) |
| ~~mtDetail 记录编号 SeqUence / MaxCode~~ | 用户 2026-09-13 确认原版不支持，标不适用，不实现；生成器配置时明确拒绝 |
| mtDetail 从表非空 | ~~原版不支持、拒绝~~ **已作废**：用户 2026-09-13 更正后按 mtMultiple 实现（编辑入口字段提示 + 保存前按明细行号报告），见 MTDETAIL_ACCEPTANCE §3.4 |
| ~~引用明细：字段不完全同名 / 引用后权限与暂存边界~~ | **2026-09-14 已收口**：同名字段照名复制、来源缺的列留空并在提示里列出未复制清单、完全没有同名列则拒绝且不追加；引用行与手工暂存行同属未保存变更（保存一起落库、撤销一起丢弃），无主记录/未就绪/未勾选/取消均拒绝或不动。原生探针阶段 A–H 通过；宿主侧真实权限拒绝与落库仍未测；跨页勾选按用户要求不做。见 [QUOTE_MAPPING_AND_STATE_BOUNDARY_20260914.md](../validation/QUOTE_MAPPING_AND_STATE_BOUNDARY_20260914.md) |
| ~~mtDetail 记录编号 SeqUence / MaxCode~~ | 用户 2026-09-13 确认原版不支持，标不适用，不实现；生成器配置时明确拒绝 |
| ~~mtMasterSlave 过时契约测试 3 项~~ | **已于 2026-09-13 逐条核对修正**：`copy_append`/`approval_optional` 改断言真实实现 `Execute<入口>` 体内契约并另断言包装委托与异常边界；`masterslave_eventnames` 的编译桩补带生成脚本全局声明。**未减少任何断言**，未改生成逻辑；全量回归转 73 通过 / 0 失败，详见 [MASTER_SLAVE_TEST_CONTRACTS_20260913.md](../validation/MASTER_SLAVE_TEST_CONTRACTS_20260913.md)、MTDETAIL_ACCEPTANCE §4 |
| 全量旧测试 | mtMasterSlave 三项过时契约（2026-09-13）与 `test_recovery.py` 45 项契约漂移（2026-09-14：编辑器行步进游标改名、新增目录项、`字段排序` 标题按原版对齐、`AddIndex` 参数、固定列顺序约定）均已逐条核对修正，**未减少任何断言**；当前全量（`tests/*.py`）全部通过，后续若再出现失败仍按“逐条核对后修正、不得删断言凑全绿”处理 |

用户已验证树打印附件、跨账号权限、列布局隔离，明确无需重复安排；实现共享代码有影响时仍需开发侧相关回归，但不得无故重新要求用户重复验收。

## 6. 构建、验证和发布

已验证环境：Delphi 10.3.3 / Win64 compiler 33.0；UniGUI 基线 1.90.0.1567；FastScript fs26、uIndy26、uniGUI26 运行时包。旧最初报告出现 .1568，后续 Windows 核对以 .1567 为准。Web 资源与运行包版本曾有差异，勿随意替换 BPL。

在 R 中用 PowerShell 调用：

```powershell
cmd /d /c '"C:\Program Files (x86)\Embarcadero\Studio\20.0\bin\rsvars.bat" && msbuild UniGuiConfiguration.dproj /t:Build /p:Config=Debug /p:Platform=Win64 /v:minimal && msbuild UniGuiConfiguration.dproj /t:Build /p:Config=Release /p:Platform=Win64 /v:minimal'
```

输出 `bin\Win64\Debug` 和 `bin\Win64\Release`。已有编译警告不等于零警告；记录新增警告、错误和退出码。

测试工具位置（使用前检查仍存在）：

- Delphi：`C:\Program Files (x86)\Embarcadero\Studio\20.0\bin\dcc64.exe`。
- FastReport/FastScript：`C:\VCL\FastReport\LibD26x64`。
- Python：`C:\Program Files\PostgreSQL\14\pgAdmin 4\python\python.exe`。
- Node：`C:\Users\isoface\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe`。

树探针示例（R 中）：

```powershell
& 'C:\Program Files (x86)\Embarcadero\Studio\20.0\bin\dcc64.exe' tests/TreeTemplateProbe.dpr '-Usrc;C:\VCL\FastReport\LibD26x64;C:\Program Files (x86)\Embarcadero\Studio\20.0\lib\win64\release' '-NSSystem;System.Win;Winapi;Vcl;Data;Xml;Soap' -Eprobe-bin -N0probe-bin
.\probe-bin\TreeTemplateProbe.exe fixtures/reference/mtTree.json validation/tree-move-20260912.dfm move
& 'C:\Program Files\PostgreSQL\14\pgAdmin 4\python\python.exe' tests/tree_write_state.test.py
& 'C:\Program Files\PostgreSQL\14\pgAdmin 4\python\python.exe' tests/tree_department_input.test.py
```

探针 EXE 可能陈旧，改共享单元后先重编译对应探针。部分 Python 测试读取特定 `validation/*.pas` 生成文件，先看测试头部并重新生成；不能仅对旧样本运行后声称新代码通过。

已固化的脚本（R 根目录，改 mtDetail 生成器后按序执行）：

```bat
build-detail-probes.bat        REM 重编 DetailTemplateProbe/DetailScriptProbe/DetailWriteProbe 到 probe-bin
build-keyunique-probe.bat      REM 重编 tests/DetailKeyUniqueProbe.dpr（原生 TClientDataSet 从表唯一行为）
regen-mtdetail-fixtures.bat    REM 用 g1–g7 配置重新生成 validation/mtdetail-g*/ 样例并跑 FastScript 编译
build-win64.bat                REM Debug/Release 构建，日志重定向到 build-win64-*.log
build-list-editor-probes.bat   REM 重编 mtListEditor 探针 11 个到 probe-bin（含 ListEditorLayoutProbe/LayoutRowsSwapProbe）
build-masterslave-probes.bat   REM 重编 mtMasterSlave 探针 4 个到 tests/（含通用生成探针 MasterSlaveGenerateProbe）
```

**每步过三绿门**（改生成器后按此顺序，别跳）：① `build-win64.bat` Debug/Release 0 错误；
② 上面两个探针脚本 0 错误（**探针 EXE 必须重编**，否则测的是旧代码）；③ 全量 `tests/*.py` 用
`C:\Program Files\PostgreSQL\14\pgAdmin 4\python\python.exe` 跑（直接敲 `python` 在这台机器上是坏的），
外加 `tests/test_recovery.py` 退出码 0。

**改已验收模板的生成器时的额外铁律**：**未勾选新功能的模块必须逐字节不变**。两个守卫工具
（用法相同：改之前 `capture <目录>`、改完 `verify <目录>`，比对既有夹具生成的 DFM SHA-256，
不一致会打印差异行并退出码 1）：

- `tools/ms_dfm_hash_guard.py` — mtMasterSlave：原版参考配置 / case-upper / memo / 分组 / 隐藏字段 5 个场景；
- `tools/le_dfm_hash_guard.py` — mtListEditor：只读明细 / 明细写入 / 宿主配置 / 记录区布局 / 审计层级 /
  Guid / SqlText / 控制类型 / 输出按钮 等 10 个场景。

只跑测试不够 —— 2026-09-22 就是靠哈希比对抓到"分组路径列游标没复位导致老模块控件坐标漂移"；
同一天做导入时也靠它确认"未勾导入的模块一个字节都没变"。

验证分层：源码契约 → DFM 解码/加载 → 完整生成脚本 FastScript 编译 → 原生数据集/故障桩行为 → Debug/Release → 用户真实宿主验收。控件替身、JS 模型和数据库内存测试不能替代最后一层。

发布需建立独立 `deployment/<主题>-<日期>`，附 README（范围/未测/哈希/更新步骤）并记录实际配置 JSON、DFM、脚本。更新后必须重新生成模块，单换 DLL 不会改变已有模块脚本。严禁直接修用户业务表来掩盖生成器错误。

## 7. 给后续模型的启动指令

> 先阅读本文件、DEVELOPMENT_HISTORY.md、MTDETAIL_RECOVERY_PLAN.md。保留 mtTree 已验收基线，不重新处理已解决事项。当前下一对象是 mtDetail，先盘点原版输入输出及宿主调用约定，记录“已证实/待核对/不适用”。未经原版证据，不把主从内嵌明细或报表明细当作 mtDetail。进入实现前先提交范围与证据缺口；用户已授权的后续开发按分阶段计划执行。所有构建、测试、交付区分本地通过、宿主通过与未测，不覆盖生产 DLL 或写业务数据库。

## 8. 文档维护规则

每批更新此入口的“当前基线/状态”，在专项文档记录实际断言、测试结果及用户反馈。保留历史文档，不把旧候选包当最新发布包。优先记录可描述的测试行为，而非孤立的“1–5通过”。新增未测项给出名称和原因；收尾不允许用笼统“全兼容”覆盖边界。
