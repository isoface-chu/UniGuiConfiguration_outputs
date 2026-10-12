# Windows 编译与验证报告

日期：2026-09-04  
平台：Delphi 10.3.3（Win64 compiler 33.0）、Win64

## 结论

- Debug 与 Release 均已真实编译成功，0 errors；保留 6 个未使用变量/赋值提示。
- 44 项 Phase 2 静态/黄金样例回归、9 组原生模板测试及数字脚本类型探针通过。
- 两个重建 DLL 都是 PE32+ / AMD64（Machine `0x8664`），可由 64 位进程加载和卸载。
- `AddDllControl`、`GetDllComponent`、`DelDllControl` 三个 ABI 导出均存在。
- FastWeb 宿主调用 `UGMM.GetDllComponent('UniGuiConfiguration>WebConfigurationModule', Self)` 已成功打开配置精灵。
- 输出位于重建目录自己的 `bin\Win64` 下，没有覆盖宿主原 DLL。
- 兼容基线已由用户确认为 UniGUI `1.90.0.1567`；本机实际安装并参与链接的 Win64 BPL 与该基线一致。

## 依赖路径核验

| 依赖 | 编译时路径 | 结果 |
| --- | --- | --- |
| FastScript `fs26` | `C:\VCL-\FastReport\LibD26x64\fs26.dcp` | Win64 DCP 已找到并加入工程本地 Search Path |
| `uIndy26` | `C:\Users\Public\Documents\Embarcadero\Studio\20.0\DCP\Win64\uIndy26.dcp` | 已解析 |
| UniGUI | `C:\Users\Public\Documents\Embarcadero\Studio\20.0\DCP\Win64\uniGUI26.dcp` | 已解析；对应 BPL 文件版本为 `1.90.0.1567` |
| UniGUI 运行时 BPL | `C:\Users\Public\Documents\Embarcadero\Studio\20.0\Bpl\Win64` | LoadLibrary 验证通过 |
| `TUniDBTreeGrid` | `C:\VCL-\UniGUI\Framework\uniGUI\source\Components\uniDBTreeGrid.pas` | 确认为该 UniGUI 安装自带控件，不是缺失的宿主私有控件 |
| 宿主源码路径 | Delphi 全局 Win64 Library Path 中包含 `D:\IsoFace\FastWeb\Source\unidsa\sources`、`D:\IsoFace\FastWeb\Source\baolib` 等 | 本重建工程此次没有产生额外宿主私有单元缺失错误 |

补充版本证据：Windows 卸载注册信息为 `FMSoft uniGUI Runtime v1.90.0.1567`；公共 Win32/Win64 `uniGUI26.bpl` 文件版本也均为 `1.90.0.1567`。当前 `C:\VCL-\UniGUI` 下部分 Web/HyperServer 资源目录仍显示 `1.90.0.1555`，宿主测试时仍需确认实际部署的 Web 资源与 `.1567` 运行时匹配。

## 编译修复记录

1. 首编译：`E2202 Required package 'fs26' not found`。
   - 原因：全局 DCP 路径没有包含 FastReport 的 Win64 专用目录。
   - 修复：工程本地加入 `C:\VCL-\FastReport\LibD26x64`。
2. 第二阶段：`F1026 File not found: 'true.dpr'`。
   - 原因：重建 `.dproj` 把 DLL 标为 Application，且 `DCC_DebugInformation` 使用了 Rio 不接受的布尔值。
   - 修复：改为 `AppType=Library`、`GenDll=true`，补齐 DLL 编译选项，并把调试信息值改为数值 `2`。
3. 源码首错：`E1030 Invalid compiler directive: 'CODEPAGE'`。
   - 修复：移除不兼容指令，并将相关 Pascal 单元保存为带 BOM 的 UTF-8。
4. 下一错：`E2004 Identifier redeclared: 'System.JSON'`。
   - 修复：删除 implementation uses 中的重复单元。
5. 下一错：Rio 不支持当前写法的字符串 `.IsEmpty`。
   - 修复：改为与 Delphi 10.3.3 兼容的空字符串比较。
6. 下一错：`TUniSplitter` 未声明。
   - 修复：加入正确的 `uniSplitter` 单元。
7. 下一错：对 `ActiveConfiguration` 函数结果直接使用 `Assigned` 导致 `E2036 Variable required`。
   - 修复：先保存到局部变量，再进行空值检查和调用。
8. Debug、Release 后续编译均成功。
9. 首次宿主调用 `UGMM.GetDllComponent('UniGuiConfiguration>WebConfigurationModule', Self)` 报错 `Ancestor for 'pColumns' not found`。
   - 原因：`ugWebConfiguration.DetailedStructure.dfm` 使用 `inherited pColumns` 等祖先节点，但恢复出的 `TWebDetailedStructure` 被错误声明为直接继承 `TWebConfigurationBase`。
   - 修复：恢复其真实祖先为 `TWebDataStructure`，删除子类中重复声明的祖先组件字段，并新增 DFM 祖先契约回归。
   - 结果：Debug、Release 重新编译成功；DLL 加载和三项 ABI 导出复检通过。
10. 修复继承关系后，宿主创建页面时报错 `A component named WebDataStructure already exists`。
   - 原因：`TWebDataStructure` 和其子类 `TWebDetailedStructure` 都由主窗体 `Self` 持有。子类加载祖先 DFM 时会暂时使用祖先根名称 `WebDataStructure`，与已创建的真实数据结构页发生 Owner 名称冲突。
   - 修复：八个配置 Frame 分别改由对应的 `TUniTabSheet` 持有；`CMOwner` 仍指向主配置窗体，保持业务上下文不变。
   - 回归：新增 `test_configuration_page_owner_isolation`，Debug/Release 串行重编译成功，LoadLibrary 和 ABI 导出复检通过。
11. 点击“查看 JSON”时报错 `Form Owner must be UniApplication`。
   - 原因：`TWebShowJson` 是 UniGUI Form，却使用配置精灵 `Self` 作为 Owner；同时原实现按 VCL 同步模态习惯在 `ShowModal` 后无条件释放窗体，不符合 UniGUI 的 `FreeOnClose` 生命周期。
   - 修复：改用 `TWebShowJson.Create(UniApplication)`，显式启用 `FreeOnClose`；正常关闭由 UniGUI 释放，仅在显示过程抛异常时主动回收。
   - 回归：新增 `test_unigui_modal_form_lifecycle`，Debug/Release 重编译成功，LoadLibrary 和 ABI 导出复检通过。
12. “查看 JSON”窗口只读，无法在该窗口中注入参考配置。
   - 核对：原始 DFM 明确设置 `mmInfo.ReadOnly = True`，因此该窗口本来就是输出预览，不是 JSON 编辑器。
   - 发现：主向导的 `ConfigurationStream` setter 原先调用共享旧代码的 `TUgConfigurationStream.Assign`；其 `AssignTo` 复制方向错误，会清空调用方流，导致宿主输入无法进入精灵。
   - 修复：setter 改为通过底层流执行 `LoadFromStream`，不再依赖错误的旧 `AssignTo`，且不会清空宿主传入的配置流。
   - 回归：新增 `test_configuration_stream_input_copy`；Debug/Release 重新编译成功，LoadLibrary 和三项 ABI 导出复检通过。
13. 点击“查看 JSON”后，“配置数据”页没有显示内容。
   - 原因：恢复代码错误地把 JSON 写入“精灵许可”页的 `mmInfo`；原始 DFM 中真正的 `pJSON` 页没有静态显示控件。
   - 修复：在 `pJSON` 中按需创建只读 `TUniMemo`，把 JSON 写入该控件并主动切换到“配置数据”页；许可页不再被覆盖。
   - 回归：新增 `test_show_json_uses_configuration_tab`；Debug/Release 编译、DLL 装载和三项 ABI 导出均通过。
14. 宿主脚本报错 `未知的类型: 'TWebConfigurationModule'`。
   - 原因：该窗体类是 DLL 私有实现类型，没有注册到宿主 FastScript；宿主不应声明或强转此类型。
   - 修复：DLL 路由在创建窗体后，通过传入 Owner 的已发布 `ConfigStream` 属性自动接入配置流；点击“完成”时再把保存结果写回该流。宿主继续使用原来的一行 `UGMM.GetDllComponent(...)`，无需认识 DLL 私有类型。
   - 编译过程首错：UniGUI 1.90.0.1567 的 `GetFormInstance` 返回 `TComponent`，补充 DLL 内部显式强转后通过。
   - 回归：新增 `test_host_config_stream_bridge`；Debug/Release、LoadLibrary 和三项 ABI 导出均通过。
15. 真实宿主中的“查看 JSON”已显示完整默认配置，但三个主数据集的 `TableStructure` 为空。
   - 原因：恢复 DFM 的 `FieldDefs` 为空，空白精灵尚未像参考配置那样创建运行期字段。
   - 修复：`TWebDataStructure.Create` 初始化 `cdsTables` 8 个字段、`cdsColumns` 16 个字段、`cdsTypesetting` 4 个字段，字段名、类型和长度与七份黄金 JSON 一致；继承的明细结构页复用同一初始化逻辑。
   - 同步：点击“下一步”时保存当前页面状态，并根据模块类型立即刷新后续标签页可见性。
   - 回归：新增 `test_empty_data_structure_schema` 和 `test_next_saves_and_refreshes_module_pages`；Debug/Release 均为 0 errors，装载和 ABI 导出通过。
16. 宿主截图显示节点数据库选项被合并、模块类型使用不合适的文本输入弹窗。
   - 节点原因：宿主 `GetDriverIDByNodeNames` 返回 `TStringList.Text`（CRLF 分行），恢复代码却按分号解析。
   - 节点修复：改为按行装载，并兼容旧的分号格式。
   - 模块类型原因：`InputQuery` 是恢复阶段的临时实现，提示文字在 UniGUI 弹窗中被截断，且允许输入无效值。
   - 模块类型修复：运行期创建只读下拉框，固定提供 `mtEditor`、`mtMultiple`、`mtTree`、`mtReport`、`mtMasterSlave`、`mtDetail` 六种合法类型；加载和保存均与该选择器同步。
   - 首次编译错误：`csDropDownList` 缺少 `Vcl.StdCtrls`；补齐后 Debug/Release 均为 0 errors。
   - 回归：新增 `test_node_list_and_module_type_selectors`；装载和 ABI 导出通过。
17. 数据结构页“新增/删除/修改”按钮点击无反应。
   - 原因：三个 DFM 事件虽然已连接，但恢复方法体仍是空的 TODO。
   - 修复：把已选节点上下文传给配置页；“新增”打开原 `TWebDataStructureSetup`，从宿主 `GetNodeDataTables` 读取表清单，确认后以 `GetNodeDataColumns` 读取字段元数据并填入 `cdsTables`/`cdsColumns`；自动生成表/字段 GUID、别名、标题及基础对象类型。“删除”按表 GUID 级联清理字段和排版记录。“修改”对空数据安全返回，对已有记录给出明确的尚未恢复提示。
   - 回归：新增 `test_data_structure_table_metadata_flow`；Debug/Release 均为 0 errors，装载和 ABI 导出通过。
18. 真实宿主已能选择两张数据表并取得字段元数据，但已选字段没有进入排版数据。
   - 实际 JSON 证据：`ElfDemo`、`mtTree`，`cdsTables` 2 条、`cdsColumns` 23 条，表 GUID 2 个且字段 GUID 23 个均唯一；其中 `fdSELECT=True` 11 条，但 `cdsTypesetting.Data` 为空。
   - 原因：`cdsColumnsBeforePost` 和 `cdsColumnsBeforeDelete` 仍为空实现，复选框虽能保存到字段数据，却没有维护排版数据。
   - 修复：字段提交时按 `fdGUID` 向 `cdsTypesetting` 新增或更新 `fdCOLUMN_NAME`、`fdCAPTION`、`fdGROUP`；取消选择或删除字段时同步删除。并为缺失 GUID、标题和对象类型增加兼容默认值。
   - 回归：新增 `test_column_selection_updates_typesetting`；Debug/Release 均为 0 errors，装载和 ABI 导出通过。
   - 真实宿主复测：`mtDetail` 的数据正确进入 `TWebDetailedStructure`；1 张表、18 个字段中选择 6 个后生成 6 条 `cdsTypesetting` 记录，6 个 GUID、字段名和标题全部一一对应。
19. 本轮二进制复检发现工程的 `DCC_ExeOutput` 仍指向旧的 `UniGui Design Demo\bin64`，导致隔离目录产物未更新。
   - 修复：输出目录改为 `.\bin\$(Platform)\$(Config)`，随后对 Debug/Release 执行完整 `Rebuild`。
   - 回归：新增 `test_build_output_is_isolated`，防止输出重新指向演示宿主或原始 DLL 目录。原始 `D:\IsoFace\FastWeb\bin64\UniGuiConfiguration.dll` 未被覆盖。
20. 排版区“上移/下移”按钮仍为空实现。
   - 修复：按当前记录与相邻记录交换完整字段值，实现物理顺序上移/下移；移动后光标继续停在被移动的记录上。
   - 边界：首行上移、末行下移和空数据集安全返回；按钮触发前若记录处于编辑状态则先提交。
   - 完整性：交换遍历 `cdsTypesetting` 的全部字段，确保 GUID、字段名、标题、分组不会错位，并兼容未来新增字段。
   - 回归：新增 `test_typesetting_move_buttons_swap_complete_rows`；Debug/Release 完整重建均为 0 errors，装载和 ABI 导出通过。
21. 首版上移/下移在真实宿主中点击后界面没有反应。
   - 原因：交换期间调用了 `TDataSet.DisableControls`；UniGUI 1.90.0.1567 的 `TUniCustomDBGrid.RecordChanged` 在 `ControlsDisabled` 时直接退出，因此浏览器端没有收到记录变化。
   - 修复：移动过程中不再屏蔽数据通知；整行交换并重新定位后调用 `gridTypesetting.Refresh`，强制客户端重新装载当前数据顺序。
   - 回归：更新 `test_typesetting_move_buttons_swap_complete_rows`，禁止重新引入 `DisableControls` 并要求显式刷新；19 项测试全部通过，Debug/Release 均为 0 errors。
   - 真实宿主复测：上移、下移均能立即更新界面，查看 JSON 时 `cdsTypesetting.Data` 的记录顺序也同步变化。
22. 字段列表和排版区的标题排序事件仍为空实现。
   - 证据：恢复出的运行脚本使用 `TClientDataSet.AddIndex` 创建动态索引；UniGUI 的 `Direction=True` 对应降序字段。
   - 修复：两个网格点击标题时按字段名重建各自的 `UgSortIndex_*` 索引，支持升序/降序，并先提交正在编辑的记录。
   - 兼容：排版区在临时排序状态下点击上移/下移，会先退出排序索引并按当前 GUID 重新定位，防止动态索引与手工顺序交换互相干扰。
   - 回归：新增 `test_data_structure_column_sorting`；20 项测试全部通过，Debug/Release 完整重建均为 0 errors，装载和 ABI 导出通过。
23. 真实宿主点击左右网格的“字段/标题”列头均未发生排序。
   - 原因：UniGUI 1.90.0.1567 的 `TUniDBGridColumn.Sortable` 默认值是 `False`；DFM 虽已连接 `OnColumnSort`，但四个目标列没有显式开启排序，浏览器因此不会发出排序事件。
   - 修复：为字段列表与排版区的 `fdCOLUMN_NAME`、`fdCAPTION` 四个列定义显式设置 `Sortable=True`。
   - 回归：扩展 `test_data_structure_column_sorting`，验证四个目标列均启用排序；20 项测试全部通过，Debug/Release 完整重建均为 0 errors，装载和 ABI 导出通过。
24. 显式启用 `Sortable=True` 后，真实宿主仍不能排序，并且原列头菜单/过滤入口消失。
   - 原因：UniGUI 1567 的远程排序与当前分组网格列头菜单存在冲突；直接占用 Ext JS 的 sortable 行为不能保持原交互。
   - 修复：撤销四列的 `Sortable=True`，显式恢复 `MenuEnabled` 和 `ColumnHideable`；两个网格启用独立的 `dgTitleClick/OnTitleClick`，由 DLL 自行记录当前排序字段和方向、重建数据集索引并刷新网格。
   - 行为：首次点击“字段/标题”为升序，再次点击同一列切换为降序；列头菜单与该点击事件相互独立。
   - 回归：更新 `test_data_structure_column_sorting`，检查两个 `dgTitleClick`、两个标题事件、四个菜单配置、方向切换及刷新调用；20 项测试全部通过，Debug/Release 均为 0 errors。
   - 真实宿主复测：列头点击排序、列头菜单以及排序后的字段同步均已通过。
25. 进入逐页验证后，功能按钮页仍缺少模块适配和组选择联动。
   - 证据：原 DLL 字符串包含 `fdSupportmodule like`、父组/选择条件和 `_post` 处理；现有数据也为每个组和按钮保留了 `fdSupportmodule`。
   - 修复：主向导刷新模块支持页时，把模块类型传给功能按钮页；该页用 `fdSupportmodule LIKE '%模块类型%'` 只显示当前模块支持的组和按钮。
   - 联动：选择/取消组会同步所有可见子按钮；逐项修改子按钮后会重新计算父组状态；JSON 仍只保存叶子按钮名，不保存 `* Group` 名称。
   - 回归：新增 `test_function_buttons_follow_module_and_group_selection`；21 项测试全部通过，Debug/Release 完整重建均为 0 errors，装载和 ABI 导出通过。
   - 真实宿主复测：模块过滤及父组选择子按钮已可操作；随后暴露“取消一个子按钮后父组仍保持全选”的时序问题。
26. 取消单个子按钮后，父组未取消全选。
   - 原因：复选框编辑时仅依赖数据集 `AfterPost` 更新父组，刷新发生在 UniGUI 网格的浏览器编辑流程完全结束之前，父组的新状态未能稳定反映到界面。
   - 二进制证据：原 DLL 包含 Ext JS `edit` 事件及 `ajaxRequest(sender, '_post', [], false)`，说明原实现会在编辑完成后追加一次服务端回调。
   - 修复：恢复 `edit -> _post` 客户端事件；`TreeAjaxEvent` 收到 `_post` 后确认提交编辑、重新计算父组、重建已选按钮字符串并刷新树。
   - 回归：扩展 `test_function_buttons_follow_module_and_group_selection`；21 项测试全部通过，Debug/Release 完整重建均为 0 errors，LoadLibrary 和三项 ABI 导出通过。
27. 恢复 `_post` 后，勾选父组时报“表格处于重写状态，无法应用更多更新”。
   - 原因：`cdsAfterPost` 仍在 UniGUI 树表格处理父组原始写入期间编辑并提交多条子记录，形成数据集更新重入；追加 `_post` 不能消除前一阶段已经发生的重入。
   - 修复：`cdsAfterPost` 不再修改或遍历数据集；把父选子、子算父、重建选择字符串和刷新界面的完整联动移入 `ApplyCurrentSelection`，且只由编辑完成后的 `_post` 回调调用。
   - 回归：21 项测试全部通过；Debug/Release Win64 完整重建均为 0 errors，LoadLibrary 和三项 ABI 导出通过，等待真实宿主复测。
28. 上述构建在真实宿主中勾选父组或普通子按钮仍报告“表格处于重写状态”。
   - 进一步原因：`_post` 回调仍重复执行 `cds.Post` 和 `Tree.Refresh`；普通子按钮即使不触发级联也会报错，证明冲突来自复选框 `AutoPost` 尚在处理时的重复提交/整表刷新，而非仅来自父组批量修改。
   - 修复：`_post` 不再强制提交当前记录；`ApplyCurrentSelection` 批量处理期间使用 `DisableControls/EnableControls` 合并数据通知，并取消冲突的 `Tree.Refresh`。复选框原值由 `AutoPost` 负责提交，回调只维护父子关系。
   - 回归：扩展测试以禁止 `_post` 中的重复 `cds.Post` 和联动中的强制 `Tree.Refresh`；21 项测试通过，Debug/Release 均为 0 errors，装载与 ABI 导出通过，等待真实宿主复测。
29. 消除重写状态异常后，真实宿主不再报错，但父组与子按钮没有联动。
   - 原因：`_post` 到达时数据集当前行未必仍是用户编辑行；同时批量联动时 `DisableControls` 屏蔽了程序修改行向 UniGUI 浏览器端的通知。
   - 修复：`cdsBeforePost` 仅捕获本次用户编辑的名称、父组和选择值；`_post` 使用该快照执行联动，不再依赖当前游标。程序级联期间恢复正常数据通知，使父/子行变化能够逐行同步到浏览器；由 `FUpdatingSelection` 防止程序提交覆盖用户快照。
   - 回归：21 项测试通过；Debug/Release Win64 均为 0 errors，LoadLibrary 与三项 ABI 导出通过，等待真实宿主复测。
30. 快照构建的四项父子联动均未生效，且偶发勾选子按钮后错误勾选其他父组。
   - 原因：无参数 `_post` 与复选框提交是两个相关请求，服务端共享的 `BeforePost` 快照仍受请求到达顺序影响；因此可能消费上一条操作的名称和状态，导致错组联动。
   - 修复：客户端 `edit` 回调直接随 `_post` 发送当前 `context.record` 的 `fdName`、`fdParent` 和 `fdSelect`；服务端按不可变的 `fdName` 唯一定位记录并联动，完全移除跨请求快照和当前游标依赖。
   - 回归：测试覆盖三项显式参数、服务端参数读取和按名称定位；21 项测试通过，Debug/Release 均为 0 errors，装载与 ABI 导出通过。
   - 真实宿主复测：仍未实现父组与子按钮双向联动；按用户决定暂缓处理，后续需结合浏览器端实际 `edit` 参数和 Ajax 请求顺序继续诊断。本项保持未通过状态。
31. 数据透视页主数据集、五个操作按钮及设置窗体均为空实现。
   - 修复：按黄金 JSON 初始化 `cdsDataPerspective` 的 8 个字段；主向导将数据结构页已选字段同步为透视设置窗体的字段来源。
   - 功能：恢复新增、修改、删除、上移、下移和列排序；设置窗体支持字段别名、表达式、标题、组别、分组/统计类型及统计项的双击跳转选项。
   - 生命周期：设置窗体使用 `UniApplication` 作为 Owner，并通过异步 `OnClose` 将结果写回数据集，避免 UniGUI 模态窗体 Owner 错误。
   - 回归：新增 `test_data_perspective_crud_and_source_columns`；22 项测试通过，Debug/Release 均为 0 errors，装载与 ABI 导出通过。
   - 真实宿主复测：`mtReport` 下字段来源、新增分组、新增统计、修改、删除、上移/下移及 `TWebDataPerspective` JSON 七项均通过。
32. 查询条件页的 9 字段数据集、批量新增、单项操作和设置窗体均为空实现。
   - 修复：按黄金 JSON 初始化 `cdsQueryCriteria`；同步数据结构页已选字段的名称、标题、对象类型和下拉选项。
   - 功能：恢复批量新增、新增、修改、删除、上移、下移和双击修改；设置窗体支持比较运算符、对象类型、独立条件及隐藏标题。单项新增允许同一字段配置多条条件，批量新增只补充尚不存在的字段。
   - 默认值：文本/备注字段默认使用 `like`，其他对象类型默认使用 `=`；排序字段在增删及移动后归一为连续序号。
   - 生命周期：设置窗体使用 `UniApplication` Owner 和异步 `OnClose` 写回。
   - 回归：新增 `test_query_criteria_crud_batch_and_source_columns`；23 项测试通过，Debug/Release 0 errors，装载和三项 ABI 导出通过。
   - 真实宿主复测：字段来源、批量新增及去重、同字段多条件、新增/修改/删除、上下移动、双击修改、独立条件/隐藏标题和 9 字段 JSON 均通过。
33. 常规设置页只有空数据集和 JSON 直拷逻辑，选择模块后没有可编辑的设置目录。
   - 二进制证据：从原 DLL UnicodeString 数据区恢复出设置序号、分组、名称、编辑类型、模块/按钮条件、默认值和说明；并以七组黄金 JSON 校准 `字段排序`、`字段宽度`、`隐藏字段-主表`、`关联从表` 等实际保存键名。
   - 修复：恢复基础设置、数据结构和从表结构共 34 项设置目录；按当前模块类型及已选功能按钮解析 `&&`/`||` 适用条件；恢复布尔、文本大小写、布局和排序方式的下拉选项以及列排序。
   - JSON：加载时把已有值覆盖到目录，同时把未知键作为“兼容设置”保留；保存时只输出当前上下文适用且已生效的记录。模块尚未选定时原样保留已有对象，避免向导前几步误写整套默认目录。
   - 集成：功能按钮页公开只读 `SelectedButtons`，主向导刷新支持页时将模块类型和按钮集合传给常规设置页。
   - 回归：新增 `test_normal_setting_catalog_context_and_roundtrip`；24 项测试通过，Debug/Release Win64 均为 0 errors，LoadLibrary 和三项 ABI 导出通过，等待真实宿主复测。
34. 常规设置首轮构建在选择数据节点并点击“下一步”时报告 `cdsNormalSetting: Field 'fdGroup:D' not found`。
   - 原因：常规设置网格初始化分组时触发降序排序；`TClientDataSet.IndexFieldNames` 不支持 `字段名:D` 语法，会把 `fdGroup:D` 整体解释为字段名。
   - 修复：改用 `AddIndex` 创建临时索引，并通过 `DescendingFields` 指定降序；应用新索引前退出旧索引并安全删除同名临时索引。
   - 回归：测试明确禁止 `IndexFieldNames := FSortField + ':D'` 并检查动态索引实现；24 项测试通过，Debug/Release Win64 均为 0 errors，LoadLibrary 和三项 ABI 导出通过，等待真实宿主复测。
35. 真实宿主选择功能按钮后，`TWebFunctionButton` 仍为空；到数据结构页后“下一步”不能正确前进。
   - 按钮原因：浏览器复选框的 AutoPost 与 `_post` 联动回调不同步，内存中的 `FSelectedButtons` 可能没有收到最后一次选择。
   - 按钮修复：`SaveConfigure` 在每次“下一步/查看 JSON/完成”保存前先提交当前编辑，再从数据集全部叶子记录重新汇总按钮字符串，不再依赖 `_post` 是否成功。
   - 导航原因：`RefSupportConfiguration` 刷新可见性时会短暂隐藏当前页，UniGUI 随即自动切换 `ActivePage`；后续循环从错误页索引寻找下一页。
   - 导航修复：刷新前保存当前页，所有页面可见性确定后恢复仍然有效的当前页，再由“下一步”按正确索引跳转。
   - 回归：新增 `test_navigation_keeps_active_page_during_visibility_refresh`，扩展按钮保存测试；25 项测试通过，Debug/Release Win64 均为 0 errors，LoadLibrary 和三项 ABI 导出通过，等待真实宿主复测。
36. 保存前扫描按钮数据集后，真实宿主的 `TWebFunctionButton` 仍为空。
   - JSON 证据：同一次保存中数据结构和常规设置均已正确写入，只有按钮标量为空，说明树形网格浏览器端复选框变化从未进入服务端 `cds.fdSelect`；问题不在保存顺序或 JSON 文档层。
   - 修复：功能按钮选择列改为只读渲染，关闭不可靠的 `CheckBoxField.AutoPost`；浏览器 `cellclick` 在选择列上自行切换显示值，并通过 `_select` 明确发送 `fdName`、`fdParent` 和新状态。服务端按按钮名更新数据集、父子关系和按钮字符串后刷新树。
   - 回归：扩展 `test_function_buttons_follow_module_and_group_selection`，检查选择列可编辑、关闭 AutoPost、延迟读取最终值、显式 `cellclick -> _select` 参数和服务端刷新；25 项测试通过。
   - 构建记录：Release 首次成功；并行 Debug 首次因两个 MSBuild 争用同一 `UniGuiConfiguration.vrc` 失败，改为串行重跑后 0 errors。最终 Debug/Release、LoadLibrary 和三项 ABI 导出均通过，等待真实宿主复测。
   - 真实宿主复测：功能按钮“选择”列恢复可编辑；选择子按钮后，`TWebFunctionButton` 已正确生成非空按钮字符串，本项通过。
37. 显式 `cellclick` 构建中，“选择”列因 `ReadOnly=True` 被 UniGUI 渲染成灰色，用户无法修改。
   - 修复：恢复选择列可编辑，仅显式设置 `CheckBoxField.AutoPost=False`；`cellclick` 延迟 25 ms，等待 Ext JS 完成本地勾选后读取最终 `fdSelect`，再发送 `_select` 到服务端，避免手动切换与内置编辑发生两次反转。
   - 回归：测试检查选择列不再只读、AutoPost 已关闭、延迟读取最终值；25 项测试通过，Debug/Release 串行完整构建均为 0 errors，LoadLibrary 和三项 ABI 导出通过，等待真实宿主复测。
38. 常规设置页“设置变量”下拉框展开后立即收起，无法选择。
   - 原因：共享 `TUniComboBox` 编辑器在自身 `OnClick` 中清空并重建 `Items`；UniGUI 1567 会在下拉展开过程中因选项集合改变而关闭弹层。
   - 修复：移除编辑器 `OnClick` 绑定，把选项准备提前到数据行选择、配置加载及模块上下文切换阶段；按 `fdSetupType` 缓存当前选项类型，同类型行切换不重复重建列表。
   - 回归：扩展常规设置测试，检查类型缓存并禁止在 `OnClick` 中重建普通下拉选项；25 项测试通过，Debug/Release Win64 均为 0 errors，LoadLibrary 和三项 ABI 导出通过，等待真实宿主复测。字段类设置所需的条件式 `OnClick` 后续见第 40 项。
   - 真实宿主复测：下拉列表能够保持展开并正常选择，问题已解决，本项通过。
39. 常规设置中的 `SelectField` 与 `MultiSelectField` 专用编辑窗体仍为空实现。
   - 修复：两个窗体按数据结构字段元数据初始化本地数据集，只载入上游已勾选字段；单选窗体返回当前字段，多选窗体恢复已有选择并以分号字符串返回全部勾选字段。
   - 来源：主向导把主表与从表 `cdsColumns` 同步给常规设置页；“从表结构”设置默认使用从表字段，“关联从表”仍使用主表字段。
   - 交互：恢复“设置变量”右侧触发按钮；按 `fdSetupType` 使用 `UniApplication` Owner 异步打开对应窗体，确认后由 `OnClose` 回写原设置行并刷新网格。
   - 回归：新增 `test_normal_setting_field_editors`；26 项测试通过，Debug/Release Win64 均为 0 errors，LoadLibrary 和三项 ABI 导出通过，等待真实宿主复测。
40. “关联字段”“隐藏字段-主表”“从表非空”“隐藏字段-从表”点击“设置变量”后没有字段数据。
   - 原因：这些设置使用专用字段选择窗体，普通下拉 `Items` 本来为空；上一轮为避免普通下拉自动收起而移除共享编辑器 `OnClick` 后，只剩附加触发事件能够打开窗体，点击单元格/下拉箭头不会进入字段选择流程。
   - 修复：恢复共享编辑器 `OnClick`，但仅对 `SelectField`、`MultiSelectField` 调用专用选择窗体；普通下拉不清空、不重建 `Items`，因此不会引入自动收起回归。增加打开状态保护，避免一次点击同时触发 `OnClick` 和 `OnTriggerEvent` 时重复创建窗体。
   - 回归：26 项测试全部通过；Debug/Release Win64 串行完整构建均为 0 errors，LoadLibrary 和 `AddDllControl`、`GetDllComponent`、`DelDllControl` 三项 ABI 导出均通过。
   - 真实宿主复测：主表单选、主表多选及从表字段来源均正确，本项通过。
41. 常规设置“自动编号”专用窗口仍为空实现。
   - 修复：窗口从当前主表或从表已选字段生成“编号字段”列表，并可恢复已有 JSON；支持 `Guid`、`SeqUence`、`MaxCode`、`DateTimeRandom`、`DBAutoincrement` 五种方式。`SeqUence` 通过宿主 `UGMM.GetSequences` 按当前数据节点读取序列；编号前缀、位数、后缀按编号方式动态显示。
   - 保存：确认后按黄金样例键名生成内层 JSON 字符串并回写“自动编号”或“记录编号”设置行；必选字段、编号方式、序列及编号位数均有校验。
   - 首次真实编译错误：`E2003 Undeclared identifier: 'csDropDownList'`；补入 Delphi 10.3 所需的 `Vcl.StdCtrls` 后解决，首次错误日志保留。
   - 回归：新增 `test_normal_setting_auto_number_editor`；27 项测试全部通过。Debug/Release Win64 第二轮均为 0 errors，LoadLibrary 和三项 ABI 导出通过。
   - 真实宿主复测：附件 JSON 中“自动编号”正确保存 `cbField=a.BillCode` 和 `cbAutoNumberType=DBAutoincrement`，本项通过。
42. 常规设置“主表唯一”“从表唯一”专用窗口仍为空实现。
   - 修复：窗口从对应结构页载入已选择字段；主表规则显示并要求记录编号字段，从表规则按黄金样例允许省略记录编号；复合唯一列表恢复已有选择并支持多字段勾选。
   - 保存：主表输出 `cbField` 与 `cdsMultiSelectFields`，从表至少输出 `cdsMultiSelectFields`；字段串保持分号结尾，匹配黄金样例。未选复合唯一字段时阻止确认。
   - 回归：新增 `test_normal_setting_unique_fields_editor`；28 项测试全部通过。Debug/Release Win64 均为 0 errors，LoadLibrary 和三项 ABI 导出通过。
   - 真实宿主复测：附件 JSON 中主表规则保存 `cbField=a.BillCode`、组合字段 `a.BillCode;`；从表规则保存 `a.BillCode;a.Line;`，重新载入正常，本项通过。
43. 常规设置“审批规则”专用窗口仍为空实现。
   - 修复：窗口的状态、对应、审核部门/用户/时间及驳回部门/用户/时间/备注九个字段选择框，统一从主表已选字段载入；校验类型提供 `0`、`1`、`2` 三个兼容值，并恢复已有内层 JSON。
   - 保存：数据状态、对应字段与校验类型为必填；确认后按黄金样例保存全部十个键，并由常规设置页异步关闭回调写回“审批规则”。
   - 回归：新增 `test_normal_setting_approval_rules_editor`；29 项测试全部通过。Debug/Release Win64 均为 0 errors，LoadLibrary 和三项 ABI 导出通过。
   - 真实宿主复测：字段列表、校验类型、审核及驳回字段保存与重新载入正常，本项通过。
44. 常规设置“编辑窗体”“查询窗体”的 `SelectRunFrame` 选择窗口仍为空实现。
   - 修复：窗口通过宿主 `UGMM.GetAllRunFrameList(..., 'WEB')` 读取可用 Web 运行框架，补回缺失的数据源绑定；以 `RecordID` 作为配置值，打开时定位现有选择，确认后回写常规设置。
   - 交互：列头排序采用动态 `TClientDataSet` 索引并支持升降序；运行框架选择不依赖数据结构字段，避免尚未选择字段时被错误拦截。
   - 回归：新增 `test_normal_setting_run_frame_editor`；30 项测试全部通过。Debug/Release Win64 均为 0 errors，LoadLibrary 和三项 ABI 导出通过。
   - 真实宿主复测：附件 JSON 中“编辑窗体”保存实际 `RecordID=2D7E0F48-4E09-457C-8870-7B74D1D2F572`，选择及回写正常，本项通过。
45. 向导完成与放弃操作的宿主流边界复核。
   - “下一步”仅更新 DLL 内部工作流并刷新页面可见性；“上一步”按可见页逆向移动。
   - “完成”依次校验当前页、保存内部流、复制到宿主传入的 `ConfigStream`，最后返回 `mrOk`；“放弃”只返回 `mrCancel`，不保存也不覆盖宿主流。
   - 回归：新增 `test_wizard_complete_and_cancel_contract`；31 项测试全部通过。DLL 源码未变化，继续使用第 44 项已验证的 Release 产物。
   - 真实宿主复测：修改配置后点击“完成”，重新打开时修改保留；再次修改后点击“放弃”，重新打开时回退到上次完成状态。宿主 `ConfigStream` 的提交与取消边界均正确，本项通过。
46. 数据结构字段的“下拉选项”专用窗口仍为空实现。
   - 修复：在字段表格“下拉选项”列点击或双击时，仅对 `combobox`、`lookupedit` 及其扩展类型打开专用窗口；以字段 GUID 锁定编辑记录，异步关闭后写回 `fdDropDownOptions`。
   - 配置：恢复 `SetText`、`SqlText`、`SqlQuery` 类型及 SQL/文本内容、动态加载、最大记录数、分页、展示字段/标题、搜索字段、引用字段和选项字段；重新打开时可解析并恢复已有内层 JSON。
   - 兼容：布尔值按黄金样例保存为 `-1/0`，其余键名与 `mtMasterSlave.json` 一致；`SqlQuery` 必须填写展示字段。
   - 回归：新增 `test_data_structure_dropdown_options_editor`；32 项测试全部通过。Debug/Release Win64 均为 0 errors，LoadLibrary 和三项 ABI 导出通过，等待真实宿主复测。
47. 真实宿主中对象类型为 `combobox` 或 `lookupedit` 时，点击/双击“下拉选项”没有弹窗。
   - 原因：UniGUI 1567 的 `ACol` 包含行指示等非数据列，与服务端 `gridColumns.Columns[]` 下标不一致，导致“下拉选项”被识别为相邻列。
   - 修复：浏览器 `cellclick` 通过 Ext JS 列管理器读取真实 `dataIndex`；仅当其为 `fdDropDownOptions` 时发送当前记录 `fdGUID`。服务端 Ajax 事件按 GUID 定位记录后打开窗口；原双击事件不再重复创建窗体。
   - 回归：扩展 `test_data_structure_dropdown_options_editor`，覆盖 `dataIndex -> ajaxRequest -> GUID Locate -> modal` 完整链路；32 项测试全部通过。Debug/Release Win64 均为 0 errors，LoadLibrary 和三项 ABI 导出通过，等待真实宿主复测。
48. 第 47 项构建在真实宿主中复测后，单击和双击仍然没有反应。
   - 根因：UniGUI 1567/Ext JS 的 `cellclick` 第一个参数是表格 View，而不是 Grid；原浏览器代码对 View 调用不存在的 `getColumnManager()`，JavaScript 在发送 Ajax 前已经中止。另外，刚在表格中选定的 `fdOBJECT_TYPE` 可能尚未提交到服务端数据集。
   - 修复：优先用 View 的 `getHeaderAtIndex()` 解析实际列，并以 `headerCt.getHeaderAtIndex()` 作为兼容后备；同时兼容按 `dataIndex=fdDropDownOptions` 和列标题“下拉选项”识别目标列。Ajax 现在一并提交当前行 `fdGUID` 与浏览器记录中的 `fdOBJECT_TYPE`；服务端先按 GUID 定位并同步对象类型，再打开专用窗口。
   - 回归：32 项测试全部通过；Debug/Release Win64 均为 0 errors，LoadLibrary 和 `AddDllControl`、`DelDllControl`、`GetDllComponent` 三项 ABI 导出检查全部通过。等待以全新 UniGUI 会话进行真实宿主复测。
49. 第 48 项构建打开配置精灵时立即出现 Ajax Error：`Unexpected string`。
   - 根因：新增客户端脚本中 `column.dataIndex` 与 `column.text` 的空字符串后备值在 Pascal 字符串内少了一层引号转义，Delphi 可以正常编译，但 UniGUI 输出到浏览器的 JavaScript 语法无效，导致窗体创建脚本整体中断。
   - 修复：改用不包含嵌套字符串引号的 `column&&column.dataIndex` 与 `column&&column.text` 安全表达式；其余列识别、GUID 和对象类型 Ajax 参数保持不变。
   - 回归：为生成脚本增加合法表达式及旧错误表达式禁止断言；32 项测试全部通过。Debug/Release Win64 均为 0 errors；Release 的 LoadLibrary 与 `AddDllControl`、`DelDllControl`、`GetDllComponent` 导出检查全部通过，等待真实宿主重新打开精灵并复测“下拉选项”。
50. 第 49 项构建可以打开精灵，但真实宿主中单击“下拉选项”仍未弹窗。
   - 版本证据：直接检查本机 UniGUI 1.90.0.1567 `uniDBGrid.pas` 后确认，`TUniDBGrid.OnCellClick` 的事件类型是 `procedure(Column: TUniDBGridColumn)`；框架在 `H_OnClick` 中根据 `CurrCol` 取得真实 `Columns[FCol]`，再把该列对象传给事件。重建代码原先错误声明为 `(Sender, ACol, ARow)`，与 1567 的事件 ABI 不匹配。
   - 修复：把 `gridColumnsCellClick` 改为 1567 的准确签名，直接检查 `Column.FieldName='fdDropDownOptions'` 并打开专用窗口；删除自定义 Ext JS `cellclick`、Ajax 路由及相关状态，彻底移除列偏移和浏览器事件参数依赖。DFM 保留原生 `OnCellClick` 绑定。
   - 回归：测试新增原生事件签名、字段识别以及禁止客户端/Ajax 绕行断言；32 项测试全部通过。Debug/Release Win64 均为 0 errors，两个产物的 LoadLibrary 与 `AddDllControl`、`DelDllControl`、`GetDllComponent` 导出检查全部通过。
   - 真实宿主复测：对象类型设为 `combobox`/`lookupedit` 后，单击“下拉选项”单元格已能正常显示配置窗口；本项通过。下一阶段验证窗口内配置保存、重新打开回载及外层 JSON。
51. “下拉选项”专用窗口的配置保存与外层 JSON 验证。
   - 真实宿主证据：`combobox` 字段已保存 `SetText` 配置及两行中文选项；`lookupedit` 字段已保存 `SqlQuery`、SQL 文本、动态加载 `-1`、最大行数、分页参数以及展示/搜索/引用/选项字段。
   - 兼容结论：`fdDropDownOptions` 为内嵌 JSON 字符串，十一项键名、`-1/0` 布尔格式及换行转义均与 `mtMasterSlave.json` 黄金样例一致；专用窗口到字段数据集再到主配置 JSON 的保存链通过。
   - 真实宿主复测：`SetText`、`SqlText`、`SqlQuery` 三种类型均已验证；保存后重新打开时全部控件和内容正确回载。本项完整通过。
52. “从表结构”页的“数据校验”窗口仍为空实现。
   - 修复：复用 UniGUI 1567 原生 `TUniDBGrid.OnCellClick(Column)` 事件，仅在 `fdDataCheck` 列打开窗口；以当前字段 GUID 锁定记录，异步关闭后回写，避免排序或光标变化写错行。
   - 数据来源：窗口按当前 `DataNodeName` 调用宿主 `UGMM.GetNodeDataTables` 载入关联表；切换表时调用 `GetNodeDataColumns` 载入校验字段。关联表和校验字段均改为只允许列表选择。
   - 保存与回载：确认前要求两项均已选择；按黄金样例保存 `cbTableName`、`cbField` 两个键，重新打开时解析内层 JSON、恢复表并重新载入对应字段列表。
   - 回归：新增 `test_detailed_structure_data_check_editor`；33 项测试全部通过。Debug/Release Win64 均为 0 errors，两个产物的 LoadLibrary 与 `AddDllControl`、`DelDllControl`、`GetDllComponent` 导出检查全部通过。
   - 真实宿主复测：关联表和校验字段选择、确认保存及重新打开回载均正常；附件 JSON 中从表字段 `ItemCode` 保存 `{"cbTableName":"TAB_BILL_B","cbField":"ItemCode"}`，内层结构与黄金样例一致。本项通过。
53. 恢复 `TUgWebRunFrame.ConfigStream` 的设计器属性编辑入口。
   - 原始证据：原 DLL 字符串同时包含 `AddWebRunFrameConfigStreamProperty`、`RegisterDialogProperty`、`TUgWebRunFrame` 和 `ConfigStream`；宿主 `TDialogProperty.LoadDialogProperty` 会把 `CustomDialogPropertys` 中的登记项统一桥接到 `UgRegisterPropertyEditor`。
   - 实现：`ugRegDllControl.AddDllControl` 通过 Delphi 类注册表取得宿主的 `TUgWebRunFrame`，登记 `TypeInfo(TUgConfigurationStream)` / `TUgWebRunFrame` / `ConfigStream`；属性按钮回调把选中的 RunFrame 作为 Owner 交给 `CallModular`，附接其 `ConfigStream` 后以模态方式打开 `TWebConfigurationModule`。`DelDllControl` 同步移除该登记项，避免卸载后遗留 DLL 回调地址。
   - 依赖边界：DLL 不直接引用宿主设计器的 `ugDesign.Inspector.*`，也不静态引用大型 `ugRunFrames` 单元；真正的 `UgRegisterPropertyEditor` 仍由宿主通用桥执行。
   - 回归：新增 `test_config_stream_dialog_property_registration`；34 项测试全部通过。Debug/Release Win64 均为 0 errors，两个产物的 LoadLibrary 与 `AddDllControl`、`DelDllControl`、`GetDllComponent` 导出检查全部通过，等待真实设计器点击 `ConfigStream` 属性按钮复测。
   - 真实设计器复测：选择 `TUgWebRunFrame` 后，已能从 `ConfigStream` 属性按钮正常打开配置精灵；属性登记、宿主桥接和模态窗体入口均通过。
54. 从 `ConfigStream` 打开原 DLL 配置过的模块时报错“缺少 JSON 对象：Data”。
   - 根因：原 DLL 的七组黄金配置均存在仅保存 `TableStructure`、省略 `Data` 的空数据集节点；重建解析器却把 `Data` 错误定义成必填对象。因此旧模块中未启用的从表结构、数据透视或查询条件等空数据集会在打开时中断。
   - 修复：保留 `TableStructure` 必填约束；`Data` 缺失或为 JSON null 时按零条记录加载。如果 `Data` 存在但不是对象，仍报告格式无效，避免掩盖损坏配置。保存时仍输出完整的 `TableStructure` 和 `Data`。
   - 回归：新增 `test_legacy_dataset_without_data_is_empty`，并逐份扫描七组原 DLL 黄金配置确认该兼容形态真实存在；35 项测试全部通过。Debug/Release Win64 均为 0 errors，两个产物的 LoadLibrary 与三项 ABI 导出检查全部通过。
   - 真实设计器复测：原 DLL 配置过的模块已能从 `ConfigStream` 正常打开精灵，并能查看原有配置信息；不再出现“缺少 JSON 对象：Data”。旧配置读取兼容通过。
   - 写回边界复测：旧配置模块的“放弃”回退及测试副本的“完成”写回均正常；重新打开后配置可继续读取，本项完整通过。
55. 旧配置保存时的未知扩展字段兼容审计。
   - 风险：文档根对象虽然会保留，但原 `TWebConfigurationBase.SaveConfigure` 会删除并重建整个页面区块，常规设置也会重建整个对象；宿主或未来 DLL 加入的未知区块成员、数据集附加元数据和未知常规设置可能在点击“完成”后丢失。
   - 修复：页面区块存在时原位更新，仅替换本向导负责的数据集；数据集只重建 `TableStructure`/`Data`，其余成员深拷贝保留。常规设置只更新当前目录中已知键，未识别键保持原值。根级未知字段仍由 `TUniGuiConfigurationDocument` 原样保留。
   - 回归：新增 `test_unknown_configuration_members_survive_save`；36 项测试全部通过。Debug/Release Win64 均为 0 errors，LoadLibrary 与三项 ABI 导出检查全部通过，等待旧配置测试副本再次完成/重开复测。
56. 原 DLL JSON 与重建 DLL 打开后 JSON 的结构化对比。
   - 相同：数据节点、Catalog/Schema 开关、模块类型和功能按钮五个标量完全一致；8 个数据集的字段定义、记录数及按 GUID 对齐后的每条记录内容完全一致。主数据结构的 24 条字段仅序号顺序变化；表、排版、透视、查询条件的记录顺序也一致。
   - 规范化差异：原配置中 3 个空的从表数据集省略 `Data`，重建输出补为 `"Data": {}`，语义均为零条记录。
   - 真实差异：原常规设置包含旧键 `表格排序=""`，重建查看时又自动启用了旧 JSON 中不存在的 `字段排序=ColumnSort`、字段宽度、字段移动、字段显隐和隐藏字段-主表。这是加载已有文档时错误应用目录默认值，不是原配置内容。
   - 修复：`ApplyLoadedSettings` 对已有文档中缺失的目录项设为“不生效”，不再仅因打开或查看 JSON 自动写入默认项；旧键继续作为兼容设置保留。新建配置不经过该回载分支，仍使用目录默认值。
   - 回归：新增 `test_existing_normal_settings_do_not_gain_defaults`；37 项测试全部通过。Debug/Release Win64 均为 0 errors，两个产物的 LoadLibrary 与三项 ABI 导出检查通过，等待同一旧模块重新生成第二份 JSON 复比。
   - 第二次实测复比：更新 DLL 后从同一模块取得的新 JSON，与上一次重建 DLL JSON 结构完全相同，规范化 SHA-256 均为 `F9B5E0765295A0E44DBDE79F67FC045762B64B04123D687BDDA1CD930023B533`。它仍包含 10 项常规设置并缺少旧键 `表格排序`，说明该模块的 `ConfigStream` 已在此前“完成”测试中写入了旧构建的结果；本次无法用它验证“从未改写的旧配置”加载分支。新代码不会猜测并删除已落盘设置，以免误删用户主动配置。
57. 第二组未改写旧模块（`mtMasterSlave`）的原 DLL/重建 DLL JSON 对比。
   - 相同：五个顶层标量完全一致；8 个数据集的字段定义、记录数及按 GUID 对齐后的每条记录内容完全一致。主表 18 条字段和 18 条排版记录仅顺序变化；其余有数据的表、从表字段/排版顺序一致。两个空数据集只存在缺省 `Data` 到 `{}` 的规范化差异。
   - 真实差异：常规设置由原来的 19 项增至 26 项，自动增加 `关联字段`、`关联从表`、字段宽度、字段移动、字段显隐、隐藏字段-主表和隐藏字段-从表，确认真实 UniGUI 数据绑定下仅依靠 `fdComeIntoEffect=False` 仍不足以防止回写默认项。
   - 修复：加载已有配置时记录原始设置键；保存时仅允许原始键或本轮经数据集 `BeforePost` 明确编辑过的键写入。由控件初始化或绑定状态造成的未触碰默认项不会进入 JSON；用户主动启用或修改的新设置仍可保存。
   - 回归：扩展 `test_existing_normal_settings_do_not_gain_defaults`；37 项测试全部通过。Debug/Release Win64 均为 0 errors，两个产物的 LoadLibrary 与三项 ABI 导出检查通过，等待同一未改写模块复测。
   - 最新 DLL 再测：新 JSON 与上一份重建 JSON 结构及规范化哈希完全相同（`65424F68C8954D59C499F28701257AC0418FE09DE614B9F9B8793C0676159253`），仍为 26 项。现场核验 `UniGuiClient` 进程实际加载 `D:\Projects\fastweb\UniGui Design Demo\bin64\UniGuiConfiguration.dll`；该文件 SHA-256 为最新构建 `903FFC6D3FD70DA90F9CE51554D24115245263C4162CDEAD257DBEA1DAF69611`，且进程启动晚于 DLL 生成时间，排除旧 DLL或未重启。
   - 结论：该同一模块的 `ConfigStream` 已在此前测试中持久化为 26 项；写回保护不会也不应猜测删除现存项。必须使用从未由旧重建版本点击“完成”的模块，或从备份恢复原始 `ConfigStream`，才能验证 19 项不扩充。
58. 重新取得的可靠 `mtMasterSlave` 原 DLL/最新 DLL 对照组。
   - 兼容通过：根级键及五个标量完全一致；常规设置均为 26 项，键和值逐项完全一致；8 个数据集的字段定义、记录数及按 GUID 对齐后的记录内容完全一致，没有数据丢失或默认项扩充。
   - 规范化：原配置的空数据透视和空查询条件省略 `Data`，最新 DLL 输出 `{}`，均表示零条记录。
   - 顺序问题：主表 `cdsColumns` 与 `cdsTypesetting` 的 18 条记录内容一致但顺序改变。原 JSON 用连续数字键 `0..17` 明确记录顺序；Delphi `TJSONObject.Pairs[]` 的枚举顺序不能作为该顺序依据，排版顺序可能因此受到影响。
   - 修复：`LoadRows` 检测连续数字键并严格按 `0..N-1` 加载；仅对非数字或稀疏对象使用 Pairs 兼容回退，由此同时保持字段列表和排版列表的原始次序。
   - 回归：扩展旧数据集兼容测试，覆盖数字行键顺序；37 项测试全部通过。Debug/Release Win64 均为 0 errors，两个产物的 LoadLibrary 与三项 ABI 导出检查通过，等待最终同组复比。
   - 首次顺序修复实测未生效：宿主已确认加载 `BFFB1B6D...` 最新文件且进程在构建后启动，但输出顺序仍与修复前完全一致。根因进一步收敛为 Delphi Rio 的 `TJSONObject.GetValue('0')` 把数字成员名作为 JSON 路径处理，连续数字键检测失败后仍回退到无序 Pairs 枚举。
   - 二次修复：新增 `FindNamedObject`，直接比较每个 Pair 的 `JsonString.Value` 精确查找数字成员名，不再使用 `GetValue` 路径 API；数字顺序识别及逐行读取均走该函数。37 项回归、Debug/Release、LoadLibrary 和三项导出复检通过，等待再次实测。
   - 二次修复实测仍未改变输出顺序；部署哈希与进程时间再次排除旧 DLL。最终根因是 UniGUI 列头排序留下活动的 `TClientDataSet.IndexName`，`SaveDataSetToJSON` 按当前视图索引遍历，把显示排序序列化成了配置顺序。
   - 最终修复：保存前记录并暂时清除 `IndexName`/`IndexFieldNames`，按物理记录顺序输出，结束后恢复原索引与书签。列头排序因此只影响显示；排版上移/下移所交换的物理记录内容仍会正常保存。37 项回归、Debug/Release、LoadLibrary 和三项导出复检通过，等待新构建实测。
   - 最终真实复测：`F5DF0145...` 构建生成的新 JSON 中，主表 18 条字段、18 条排版记录以及其余所有非空数据集的 GUID 顺序均与原 DLL 完全一致；字段定义、记录内容、五个标量和 26 项常规设置也逐项一致。将缺失空 `Data` 与 `{}` 视为等价后，两份完整 JSON 完全相等，规范化 SHA-256 同为 `F014D6397265ED289EA270B902F56C12F41AF01E9A04311F57B16C34B4BFC3EA`。本项通过。
59. 可靠 `mtReport` 原 DLL/重建 DLL JSON 对照。
   - 已通过部分：五个标量一致；8 个数据集的字段定义、记录数、记录内容和 GUID 顺序全部一致，确认活动索引隔离修复有效；三个空从表数据集只存在缺失 `Data` 与 `{}` 的等价差异。
   - 剩余差异：原常规设置 9 项，重建输出 10 项，仅多出 `隐藏字段-主表=""`。原因是绑定编辑器仅初始化就使当前记录停留在编辑状态，查看 JSON 前的强制 `Post` 被 `BeforePost` 误记为用户明确修改。
   - 修复：`SetContext` 和 `SaveConfigure` 对被动提交设置内部加载保护标志，不写入 `FChangedSettingNames`；真实 UI AutoPost 在保护范围外，用户主动启用或修改的新设置仍可保存。
   - 回归：扩展 `test_existing_normal_settings_do_not_gain_defaults`；37 项测试全部通过。Debug/Release Win64 均为 0 errors，两个产物的 LoadLibrary 与三项 ABI 导出检查通过，等待最终 `mtReport` 复比。
60. `mtReport` 被动提交兼容规则二次修复。
   - 最新实测：五个标量、8 个数据集的字段定义、记录数、记录内容和 GUID 顺序仍与原 DLL 一致；三个空从表数据集仅为缺失 `Data` 与 `{}` 的等价差异。但 `TWebNormalSetting` 仍额外出现 `隐藏字段-主表=""`，说明真实 UniGUI 表格还会在保护范围外回写当前行的生效状态。
   - 修复：加载旧文档时，原配置不存在的新设置即使被表格标记为已修改，也只有在设置值非空时才允许新增。这样可屏蔽 `已生效 + 空值` 的绑定伪变更；用户通过字段选择器真正选择字段后值为非空，仍会正常写入。已有设置及新建配置的保存规则不变。
   - 回归：37 项测试全部通过；Debug/Release Win64 均为 0 errors，两个产物的 LoadLibrary 与 `AddDllControl`、`GetDllComponent`、`DelDllControl` 三项 ABI 导出检查通过，等待最终 `mtReport` 复比。
   - 二次实测：宿主进程确认加载的确为 `F3493CA3...` 构建，启动时间晚于 DLL 生成时间，但结果仍多出同一空项，排除部署缓存。旧配置中文键含有历史编码异常字符，`TStringList.IndexOf` 的默认本地化、不区分大小写比较可能把不同异常键误判为相同键。
   - 三次修复：设置名成员判断改为逐项使用 Delphi 字符串 `=` 做精确匹配，不再用 `TStringList.IndexOf`；空的新设置保护规则保持不变。37 项回归、Debug/Release、LoadLibrary 和三项导出检查再次通过，等待最终实测。
   - 三次实测：宿主确认加载 `43F03EC5...` 构建后结果仍多出同一空项，证明名称列表和编辑状态都不是可靠的最终保护边界。
   - 最终边界修复：`LoadConfigure` 深拷贝保存不可变的原始 `TWebNormalSetting` 对象；每次生成 JSON 时，在最终文档边界清除所有“原始对象不存在且当前值为空”的设置。原配置已有键仍可被用户清空，新选择字段等真实新增值为非空并可正常写入。37 项回归、Debug/Release、LoadLibrary 和三项导出检查通过，等待再次实测。
   - 重新取得原 DLL 当前基准：换回原 DLL后，同一 `mtReport` 模块生成的 JSON 与最早基准逐项完全一致，常规设置仍为 9 项且不含 `隐藏字段-主表`，规范化 SHA-256 同为 `46B78B078AFBBB385A383A161115DD41AEA52B193A25A95A6C8FBBDDAEFBAAD8`，确认模块没有被早期测试污染。
   - 定向兼容修复：7 份原 DLL 黄金配置中存在 11 个有意义的空常规设置，因此不能全局删除空值。依据 `mtReport` 当前实测及黄金配置，仅在模块类型为 `mtReport` 时省略空的 `隐藏字段-主表`；其值为空表示不隐藏任何字段，省略后业务语义不变，其他模块的原有空设置继续保留。37 项回归、Debug/Release、LoadLibrary 和三项导出检查通过，等待最终实测。
   - 最终真实复测：宿主进程确认加载 Release `912A7E21...` 构建；常规设置恢复为原 DLL 的 9 项且键值完全一致，不再新增空的 `隐藏字段-主表`。除三个空从表数据集由省略 `Data` 规范化为 `{}` 外，两份完整 JSON 完全一致，规范化 SHA-256 同为 `46B78B078AFBBB385A383A161115DD41AEA52B193A25A95A6C8FBBDDAEFBAAD8`。本项通过。
61. 可靠 `mtTree` 原 DLL/重建 DLL JSON 对照。
   - 已通过部分：五个标量完全一致；主数据结构的表、5 条字段和 2 条排版记录的字段定义、内容及顺序完全一致；其余空数据集仅由省略 `Data` 规范化为 `{}`。原 DLL 的 6 个有意义空常规设置均被保留。
   - 剩余差异：原常规设置 16 项，重建输出 17 项，仅多出空的 `隐藏字段-主表`。原 DLL 的 `mtTree` 黄金配置和本次真实结果均不输出该项。
   - 修复：把空 `隐藏字段-主表` 的定向省略规则由 `mtReport` 扩展到 `mtTree`；`mtMasterSlave`、`mtMultiple`、`mtEditor` 等原 DLL 确实保存该空项的模块不受影响。37 项回归、Debug/Release、LoadLibrary 和三项导出检查通过，等待最终实测。
   - 最终真实复测：宿主进程确认加载 Release `CD67E9AD...` 构建；常规设置恢复为原 DLL 的 16 项，键值完全一致，6 个有意义的空设置全部保留。除 5 个空数据集由省略 `Data` 规范化为 `{}` 外，两份完整 JSON 完全一致，规范化 SHA-256 同为 `5DA6E7E9E751DF361BDFB02CA370E5E60293A87164791C3529A3473076BBFDF5`。本项通过。
62. 可靠 `mtMultiple` 原 DLL/重建 DLL JSON 对照。
   - 五个标量完全一致；主数据结构的表、9 条字段、8 条排版记录以及 1 条查询条件的字段定义、内容和顺序完全一致。
   - 常规设置均为 20 项且键值完全一致；原 DLL 中有意义的空 `隐藏字段-主表` 被正确保留，确认 `mtReport`/`mtTree` 定向省略规则没有影响 `mtMultiple`。
   - 除 4 个空数据集由省略 `Data` 规范化为 `{}` 外，两份完整 JSON 完全一致，规范化 SHA-256 同为 `86027E685F173817FA2C8AE26EEB402A734D2702859EA2A240520C0DEB902F04`。本项通过，无需修改代码或重新构建。
63. 可靠 `mtEditor` 原 DLL/重建 DLL JSON 对照（当前编辑模块变体）。
   - 五个标量完全一致，功能按钮均为空；主数据结构的表、5 条字段和 2 条排版记录的字段定义、内容及顺序完全一致。
   - 常规设置均为 3 项且键值完全一致，其中非空字段为 `a.fdClassName;`、隐藏字段-主表为 `a.fdGuid;`。
   - 除 5 个空数据集由省略 `Data` 规范化为 `{}` 外，两份完整 JSON 完全一致，规范化 SHA-256 同为 `B33878E61F60F3A5FEA11F9B22610CB88B832363998D5B5ED35EDE823CB2DEBF`。本项通过，无需修改代码或重新构建。
64. 可靠 `mtEditor` 原 DLL/重建 DLL JSON 对照（第二编辑模块变体）。
   - 五个标量完全一致，功能按钮均为空；主数据结构的表、9 条字段和 2 条排版记录的字段定义、内容及顺序完全一致。
   - 常规设置均为 3 项且键值完全一致，其中非空字段为 `a.Name;`，空的 `隐藏字段-主表` 被正确保留，进一步确认定向省略规则没有影响 `mtEditor`。
   - 除 5 个空数据集由省略 `Data` 规范化为 `{}` 外，两份完整 JSON 完全一致，规范化 SHA-256 同为 `68EFC724425EAB39B38AAAD56399D3637E6F595C62093A97F9BCF88045ADE889`。本项通过，无需修改代码或重新构建。
65. 可靠 `mtMasterSlaveQuery` 原 DLL/重建 DLL JSON 对照。
   - 两份配置的实际 `TWebModuletype` 均为 `mtMultiple`；五个标量及 `btQuery;btExport;btPrint;btClose;` 功能按钮上下文完全一致。
   - 主数据结构的表、18 条字段、18 条排版记录以及 5 条查询条件的字段定义、内容和顺序完全一致；常规设置均为 12 项，原有空 `隐藏字段-主表` 正确保留。
   - 除 4 个空数据集由省略 `Data` 规范化为 `{}` 外，两份完整 JSON 完全一致，规范化 SHA-256 同为 `F91605F5BF36935AF9C14E89FD81438CD0651B80C6E8DEF5DDE8C0B3B3C16EA6`。本项通过，无需修改代码或重新构建。至此七组已知原 DLL 参考配置均已完成真实宿主对照。
66. 参考 DFM、`TUgWebRunFrame` 创建前置检查及 UniGUI 1567 部署核验。
   - 七组参考 JSON 均由参考生成器命中；生成到 `validation/generated-dfm` 的七份 DFM 与黄金文件逐字节相同，根对象均为 `TUgWebRunFrame`。
   - 使用 Delphi 10.3 Win64 和宿主导入路径相同的 `ObjectTextToResource` API 转换七份文本 DFM，全部通过；转换工具与日志保存在 `validation/ValidateDfmText.dpr` 和 `validation/build-validate-dfm-text.log`。
   - DFM 共引用 23 种组件类，宿主源码均有定义；`TUgWebRunFrame` 已由宿主注册。最终 `ReadComponentRes` 实例化仍须在已登录设计器会话逐份执行，因为它依赖 UniGUI Session 和宿主自定义类注册表。
   - 运行进程实际从宿主 `bin64` 加载完整 UniGUI/uIndy/fs26/Indy Win64 包组；`uniGUI26.bpl` 文件及产品版本均为 `1.90.0.1567`。宿主目录包与公共 BPL 同版本但哈希不同，当前进程未跨目录混用，部署时不得单独覆盖其中某个包。
   - 注册表实际运行时目录为 `C:\VCL\UniGUI\Framework\uniGUI`，包含 1567 与 Ext JS 7.5.1 资源；宿主页明确引用 `/uni-1.90.0.1567/` 和 `/ext-7.5.1/`，核心资源 HTTP 200，旧 1555 URL 为 404。Web 资源版本检查通过。
   - 完整记录及人工步骤见 `validation/DFM_DEPLOYMENT_VALIDATION.md`。
   - 首份宿主实测：`mtMultipleEditor.dfm` 已在设计器成功创建 `TUgWebRunFrame`；设计画布、组件树、属性检查器和 `Run[F9]` 预览均正常。
   - 最大样例宿主实测：`mtMasterSlave.dfm` 已成功创建；主从结构、设计器视图和 `Run[F9]` 预览均正常，未出现类、属性、祖先或组件重名错误。
   - 最终宿主实测：其余 `mtMasterSlaveQuery.dfm`、`mtMultiple.dfm`、`mtReport.dfm`、`mtTree.dfm`、`mtTreeEditor.dfm` 也全部完成 `Open`、设计画布/组件树/属性检查器检查以及 `Run[F9]` 预览。七份参考 DFM 均可创建并运行 `TUgWebRunFrame`，本项通过。
   - 快照修复实测：结果仍保留 `隐藏字段-主表=""`。该规则只有在传入向导的初始 `TWebNormalSetting` 已包含此键时才会保留它，说明当前被测模块的 `ConfigStream` 很可能已经写入该项，与早先保存的 9 项原 DLL 基准不再相同。扫描 7 份原 DLL 黄金配置发现其中 11 个空常规设置具有兼容意义，不能全局删除空值。下一步须换回原 DLL，对同一模块当前状态执行“打开 -> 查看 JSON -> 放弃”，重新取得可信基线。
67. `GenerateRunFrame` 通用化第一步：参考配置结构匹配。
   - 原实现直接比较 `TJSONObject.ToJSON` 文本，JSON 对象成员顺序变化便会误报未知配置；旧 `ConfigStream` 省略空数据集 `Data` 时也无法命中已验证的参考 DFM。
   - Delphi 生成桥现改为递归结构比较：对象成员不依赖书写顺序，数组及数据行顺序仍严格比较；缺失的空 `Data` 与 `Data={}` 视为等价。
   - Python 参考生成器同步使用相同兼容规则，并新增乱序对象及省略空 `Data` 回归。38 项静态/黄金回归全部通过。
   - Delphi 10.3.3 Win64 Debug/Release 均为 0 errors、仅 4 个既有提示；两个 DLL 的 LoadLibrary 均通过。日志为 `build-win64-debug-structural-generator.log`、`build-win64-release-structural-generator.log`。
   - 本步只扩大“已验证配置的等价表示”识别范围；字段、按钮或布局发生实际业务变化的未知配置仍明确拒绝，尚未宣称通用控件/脚本拼装完成。
68. 恢复“完成”时立即生成控件的宿主链路（七份已验证配置）。
   - 用户用原 DLL 确认：点击“完成”会立即在当前 `TUgWebRunFrame` 生成控件，同时保存 `ConfigStream`。
   - 属性编辑入口现在把当前 `TUgWebRunFrame` 连同其 `ConfigStream` 一并交给向导；“完成”时对已验证配置读取内嵌 DFM，并写回同一个根框架实例，保留其原名称。
   - 七份 JSON/DFM 已作为 `RCDATA` 嵌入 DLL，运行时不依赖重建目录或外部模板文件。
   - 应用前会序列化备份当前框架；清理/读取模板发生异常时恢复备份，避免设计器停留在半更新状态。未知配置暂不改写控件，但仍保存 `ConfigStream`，保持此前精灵流程不回退。
   - 第一轮真实编译错误为 `E2010 Incompatible types: NativeUInt and TSearchRec`，原因是加入 `Winapi.Windows` 后 `FindClose` 名称冲突；明确限定为 `System.SysUtils.FindClose` 后修复。失败日志 `build-win64-debug-embedded-generator.log`，成功日志 `build-win64-debug-embedded-generator-final.log`、`build-win64-release-embedded-generator-final.log`。
   - 39 项回归全部通过，Debug/Release 均 0 errors、4 个既有提示，LoadLibrary 均通过；等待真实设计器验证点击“完成”后的即时控件刷新。
   - 真实设计器复测通过：在 `mtMultipleEditor.dfm` 临时删除 `aReMark` 后，从根框架打开配置精灵并点击“完成”，`aReMark` 立即恢复，证明目标传递、内嵌匹配、同根框架覆盖和设计器刷新链路均已生效。
69. 通用生成第一条动态分支：双字段 `mtEditor`。
   - 对不属于七份完整黄金 JSON 的 `mtEditor`，读取主数据结构的两条排版记录，动态派生编辑控件名、脚本变量名和字段标题，并以已验证的编辑器骨架生成控件及脚本。
   - 当前安全范围限定为：恰好两个排版字段、两者对象类型均为 `edit`、标准单字符表别名，并且第一字段属于“非空字段”。不满足条件时仍只保存 `ConfigStream`，不猜测生成。
   - 字段名会同步替换编辑器脚本中的控件和变量引用；标题在组件加载后写入 `FieldLabel`。异常仍使用整框架备份回滚。
   - 新增动态编辑器回归；40 项全部通过。Debug/Release 均 0 errors、4 个既有提示，LoadLibrary 通过。日志：`build-win64-debug-dynamic-editor.log`、`build-win64-release-dynamic-editor.log`；等待真实设计器用非黄金配置验证。
70. 动态生成后的设计器对象树及脚本缓存刷新。
   - 真实设计器验证发现：控件已生成到画布，但对象树要手动刷新后才显示，脚本编辑器中也看不到按字段名替换后的变量。
   - “完成”成功生成后，现在通过宿主 `IUGDesignFrame` 依次调用 `DelRunFromDesign`、`AddRunFromDesign`、`RefDesignScriptCode`，重建设计包装/对象树并重新载入当前 `TUgWebRunFrame.Codes`。
   - 动态双字段编辑器增加生成后校验：两个字段控件必须真实存在，`Codes` 必须同时包含两个控件名及对应的 `v...` 脚本变量；不完整时触发原有整框架回滚，不留下半生成结果。
   - 41 项回归全部通过。Delphi 10.3.3 Win64 Debug/Release 均 0 errors、仅 4 个既有提示，两个 DLL 的 LoadLibrary 均通过。日志：`build-win64-debug-designer-refresh.log`、`build-win64-release-designer-refresh.log`；等待真实设计器确认无需手动刷新。

71. 再次点击“完成”时的控件/设计包装释放顺序修复。
   - 用户确认首次生成、对象树刷新、保存重开后的控件和脚本均正常；但再次生成出现 rtl260.bpl Access violation，随后关闭 IDE 出现 JavaScript 对象未定义。
   - 检查发现第 70 项的设计包装移除发生在旧控件释放之后，包装仍可能引用旧控件。改为在生成器已匹配模板、已保存备份后，先调用 `DelRunFromDesign`，再清理旧控件/读取 DFM；在 finally 中重建包装并刷新脚本，回滚后也恢复设计状态。此顺序与宿主粘贴组件的生命周期一致。
   - 清理控件不再持有一批待释放指针；每次释放后重新读取当前存活的组件列表，避免析构联动释放其他组件后再次使用旧指针。
   - 扩展生命周期顺序回归，41 项静态/黄金回归通过；Win64 Debug/Release 均编译通过，0 errors、4 个既有提示；两个 DLL LoadLibrary 通过。原始 DLL SHA-256 不变。未在工具中复现真实宿主异常，需用户验证连续多次“完成”和正常关闭 IDE，不能仅凭静态测试认定异常完全消除。

72. 第二次完成仍出现浏览器对象未定义：对齐宿主的可视/非可视组件释放顺序。
   - 第 71 项实测仍未通过重复生成：第一次完成正常，第二次出现 `O16B6 is not defined`，截图片段包含 base64 图像更新；本次未报告服务端 Access violation。截图不足以确定 O16B6 的具体组件身份。
   - 对比宿主 `ugDesign.Classes.StreamToComponent.ClearAllComponent`，发现宿主先释放可视子控件，再释放非可视组件；重建清理循环顺序相反。UniGUI `uniButton.pas` 的 Notification 在 Images 被删除时会设置 Images=nil，可产生更新链路，因此先删除图像提供者具有引用失效风险。
   - 改为每轮优先删除存活可视子控件，再删除非可视提供者；保留 TUniJSForm、先解绑设计包装及失败回滚流程。此为有源码依据的定向修复，尚未宣称真实宿主问题已解决。
   - 新增顺序回归，42 项静态/黄金回归通过；Debug/Release 编译均 0 errors、4 条既有提示，LoadLibrary 均通过，原 DLL 校验不变。待验证同一模块连续完成及关闭 IDE；若复现，需要完整 Ajax Error 文本以定位失效对象，而不只是截图片段。

73. 完整 Ajax 报文指向设计器 Canvas 位图同步，分离销毁和重建响应。
   - 第 72 项实测仍失败。用户完整报文含多组 `originalValue=undefined;_sfv_(...,0,"data:image/png;base64,...")`，PNG 尺寸分别对应根框架及子控件（220x162、220x32、75x26 等），不能继续把它归因于按钮图像列表。
   - 本机 UniGUI `uniCanvas.pas` 中 NotifyAjax -> PreparePNGStream -> SetOriginalValue 生成该类位图同步；宿主 `TUgCustomDesignControl` 为每个包装创建 CanvasLine/CanvasDots 并绘制边框。现阶段的证据指向设计画布初始化/销毁时序，缺少浏览器完整创建响应，不能断言具体对象何时失效。
   - 增加设计器所有的一次性 TUniTimer：旧包装解绑及生成仍在完成事件执行；新包装 AddRunFromDesign 改在后续浏览器定时回调执行，回调先禁用自身，再重建对象树并刷新脚本。每个设计器复用一只定时器，不保留生成控件指针，设计器销毁时自动释放。回滚后也排队恢复设计包装。
   - 43 项静态/黄金回归通过，Debug/Release 0 errors、4 条既有提示，LoadLibrary 均通过，原始 DLL SHA-256 不变。
   - 用户真实宿主复测通过：同一模块连续多次点击“完成”无报错；保存、关闭并重新打开模块后再次进入精灵完成，控件和脚本正常；关闭设计器无 Ajax Error 或访问异常。本轮重复生成/设计画布刷新问题在上述已测试场景关闭。其他模块类型的动态生成覆盖及暂缓的按钮父子联动不在本次通过范围内。

74. 动态 mtEditor 由双字段扩展为任意正数量 edit 字段。
   - 新增纯模板生成单元 `ugConfiguration.EditTemplate`，按 cdsTypesetting.Data 的数字行键读取顺序，逐项生成控件、标签、变量声明、加载/回写、焦点链及纵向布局。复用原编辑器公共脚本和按钮骨架，节点常量改为当前选择节点，不再固定 ElfDemo。
   - 当前约束仍为全部 edit、单字符表别名、合法无冲突控件/变量名，且“非空字段”精确为第一排版字段。拒绝不支持的配置时仍不改写现有控件。标题及脚本字符串经过 DFM 引号/换行转义，避免名字顺序替换误伤。已验证的七份完整黄金配置仍优先命中原模板。
   - Delphi 原生控制台测试直接调用生产生成函数：1、2、3、12 字段均通过，包含逆序插入 JSON 数字键、单引号/换行标题、变量声明和回写、旧字段残留检查、不支持类型/非空规则/重名拒绝；生成 DFM 经 ObjectTextToBinary 解析通过。日志 `test-multi-edit-native.log`。该测试不等同于宿主运行 FastScript。
   - 首轮真实错误 F2613（新增单元未列入 DPR）已补入口；随后 E1030（不受 Delphi 支持的 CODEPAGE 指令）改用 UTF-8 BOM。原生探针首次因编译工作目录导致路径错误，改从 tests 目录编译；相关失败日志保留。
   - 43 项静态/黄金回归通过（`test-multi-edit-regression.log`），Debug/Release 最终 0 errors、仅四条既有提示，LoadLibrary 均通过，原 DLL 校验不变。
   - 用户确认四项真实宿主测试全部正常：按 3～5 个 edit 字段、仅第一字段非空的测试方案生成；控件数量、顺序、标题及变量正确；预览运行的首字段必填提示及输入回写正常；保存重开和连续完成无异常。本轮多字段 edit 生成在上述测试范围通过，其他控件类型及多个/非首字段非空规则仍未纳入支持范围。

75. 动态 mtEditor 支持无必填、任意字段和多个字段非空。
   - 解析“非空字段”的分号列表，忽略空项和首尾空格，大小写不敏感匹配已排版字段；缺失/空设置不生成非空检查。按排版顺序逐项产生变量判空、对应控件 SetFocus 和 FieldLabel 提示，重复设置不产生重复校验。保持原模板空字符串语义，不对用户输入额外 Trim。
   - 配置引用不存在或未排版字段时拒绝动态生成，避免静默丢失规则；其他 edit 类型与命名安全边界保持不变。原始黄金配置仍优先使用已验证模板。
   - 原生探针在 1、2、3、12 字段下覆盖无设置、空列表、末字段必填、多字段逆序配置、大小写/重复项、不存在字段拒绝，检查实际生成的校验成员/顺序/焦点/标题及 DFM 解析。日志 `test-required-fields-native.log`，43 项静态/黄金回归通过（`test-required-fields-regression.log`）。
   - Win64 Debug/Release 均首次编译通过，0 errors、四条既有提示；LoadLibrary 均通过，原 DLL SHA-256 不变。待宿主验证提示、焦点跳转、规则修改后的旧校验移除、保存重开及重复完成。

76. 非空规则功能通过，修复生成脚本中文提示乱码。
   - 用户确认第 75 项四项功能全部通过，但非空提示中文乱码。新增实际 DFM -> 二进制 -> TComponent.Codes 读回测试，在修复前复现 `decoded required message must be exact Unicode`，证明只检查 DFM 可解析不足以验证文本无损。
   - 原 DFMString 输出裸 UTF-8 中文，ObjectTextToBinary 的当前读取链路发生编码误解；现对非 ASCII 字符及控制字符统一输出 Delphi DFM 数字码点，单引号仍按 DFM 规则转义。该公共转换同时覆盖脚本、字段标题和节点常量，不改变非空逻辑。
   - 修复后原生 1/2/3/12 字段全部通过，并核对读回 Codes 含精确 Unicode“不能为空”。前后日志 `test-unicode-before-final.log` / `test-unicode-after.log`；新增测试自身的首次边界定位失败另保留日志。43 项静态/黄金回归通过；Debug/Release 0 errors、4 条既有提示、LoadLibrary 通过，原 DLL 校验不变。
   - 用户确认中文提示乱码问题复测正常。本轮中文提示问题关闭；结合第 75 项四项功能实测，当前 edit 字段的无必填、任意字段及多个字段必填规则已通过宿主验证。

77. mtEditor 支持 memo 多行文本及 edit/memo 混排。
   - 核对宿主 `ugMemo.pas`、`fs.ugMemo.pas` 及参考 `mtMasterSlaveQuery.dfm`：控件类为 TUgMemo，Text 可经 FastScript 读写，参考默认高度为 170。动态分支现支持 edit/memo，其他未支持类型仍拒绝生成。
   - 按实际高度累加字段 Top 和根框架/内容区/按钮区尺寸，edit 高 50、memo 高 170、间距 10；纯 edit 布局不变。两者均使用 Text 变量读写、当前必填规则和已修复的 DFM Unicode 编码，异步设计画布重建流程不变。
   - 原生探针增加单 memo、三字段混排、三 memo、十二字段混排，加原四组 edit 共 8 组通过；核对实际类名、Top/Height、根高度、DFM 解析、变量/必填规则、中文脚本读回。日志 `test-memo-native.log`；43 项静态/黄金回归通过（`test-memo-regression.log`）。原生测试不代替真实宿主多行输入/换行回写及 FastScript 运行验证。
   - Debug/Release 首轮编译通过，0 errors、4 条既有提示，LoadLibrary 通过，原始 DLL SHA-256 不变。待宿主验证混排、多行中文输入回写、memo 必填及重新生成/保存重开。

78. 修复 memo 生成时 Error reading aBillMark.Text。
   - 宿主反馈完成时 Text 属性不存在。核对 UniGUI 1567 uniMemo.pas，TUniMemo.Text 位于 public 而非 published，脚本可访问并不代表 DFM 可反序列化；第 77 项错误地把 edit 的空 Text 属性也输出给 memo。
   - memo DFM 不再写 Text，保留默认空 Lines；edit 初始化及两种控件的脚本 Text 读写不变。原生八组测试新增检查 memo 控件块不得包含 Text，避免只做 DFM 语法解析漏掉属性契约。
   - 八组原生测试、43 项静态/黄金回归、Debug/Release 编译（0 errors、4 条既有提示）、LoadLibrary 均通过；原始 DLL 校验不变。日志 `test-memo-text-native.log`、`test-memo-text-regression.log`。
   - 用户在重新生成、多行中文输入、必填提示和保存重开的复测请求后反馈“测试通过”。本轮 memo.Text 加载问题关闭，memo 支持在本次宿主测试范围内通过。

79. 第一批多类型 mtEditor：日期/时间/日期时间、数值、复选框、固定下拉。
   - 新增 date/time/datetime -> TUgDateTimePicker，number -> TUgNumberEdit（fdCOLUMN_SCAL 控制 0～15 位小数），check -> TUgCheckBox，combobox -> TUgComboBox（仅 SetText 逐行文本）。保留 edit/memo、命名/必填安全边界及异步画布重建。
   - 按本机 UniGUI 及宿主 FastScript 注册源码区分 public/published 属性；不向日期/数值/复选框 DFM 写 Text，不向日期/复选框写 SelectOnFocus。number 脚本通过 Clear/Text 判空并用 Value 读写；date/datetime 用 DateTime，零日期视为空；time 使用 RemoteValue[0] 区分午夜零值与空提交；check 使用 Checked，False 为有效布尔值而不是空值。
   - combobox 接受 fdDropDownOptions 的对象或序列化 JSON，严格要求 SetText；SQL、动态加载及显示/实际值映射拒绝生成。Items 经过现有 DFM Unicode 转义。
   - 原生九组测试通过（新增九字段混排），覆盖类名、布局、数值精度、分类型回写、必填生成、午夜判空代码、JSON 两种形式、SQL 拒绝、Unicode 及 DFM 解析。43 项静态/黄金回归通过；这些不等同于浏览器空值/回写和 FastScript 运行测试。
   - 首轮探针 E2010（Clone 返回 TJSONAncestor）已显式转换修复；随后消除 Col 未初始化警告。首次编译失败后执行到的旧探针结果不计为本批通过，最终以 `test-batch-controls-native-verified.log` 为准。
   - Debug/Release 最终 0 errors、4 条既有提示，LoadLibrary 通过，原 DLL 哈希不变。待按 `validation/BATCH_CONTROLS_CHECKLIST.md` 集中验证，特别是 0、负数、小数、清空、午夜及变量值类型。

80. 完成后无生成/刷新：增加拒绝原因，等待真实 JSON 定位。
   - 用户反馈新 DLL 完成后无控件生成或刷新。已确认存在配置守卫返回 False 后静默跳过生成的路径，但尚无本次配置 JSON，不能认定具体拦截项。已请求用户提供完整配置。
   - TryBuildEditTemplate 增加原因输出重载，覆盖模块类型、数据/行键、别名、标识符冲突、对象类型、小数位、下拉 JSON/类型/动态加载/映射/空选项及非空字段来源；生成桥在任何组件清理之前抛出带字段和原因的提示。精灵保持打开，不再假装完成，也不向宿主 ConfigStream 提交本次未生成的配置。
   - 原生九组测试及原因断言、43 项回归通过。Debug/Release 0 errors，6 条提示（4 条原有未使用变量、2 条改为显式拒绝后的冗余 Result 赋值提示），LoadLibrary 通过，原始 DLL 校验不变。此版本用于定位，不宣称用户当前配置已修复。

每轮诊断日志保存在本目录的 `build-win64-*.log` 文件中；最终成功日志为：

- `build-win64-debug-round13.log`
- `build-win64-release-round1.log`
- `build-win64-debug-configstream.log`
- `build-win64-release-configstream.log`
- `build-win64-debug-showjson-content.log`
- `build-win64-release-showjson-content.log`
- `build-win64-debug-host-stream-bridge.log`（保留首次真实编译错误）
- `build-win64-debug-host-stream-bridge-round2.log`
- `build-win64-release-host-stream-bridge.log`
- `build-win64-debug-schema-init.log`
- `build-win64-release-schema-init.log`
- `build-win64-debug-selectors.log`（保留首次 `csDropDownList` 编译错误）
- `build-win64-debug-selectors-round2.log`
- `build-win64-release-selectors.log`
- `build-win64-debug-table-add.log`
- `build-win64-release-table-add.log`
- `build-win64-debug-column-typesetting-rebuild.log`
- `build-win64-release-column-typesetting-rebuild.log`
- `build-win64-debug-typesetting-order.log`
- `build-win64-release-typesetting-order.log`
- `build-win64-debug-typesetting-refresh.log`
- `build-win64-release-typesetting-refresh.log`
- `build-win64-debug-data-structure-sort.log`
- `build-win64-release-data-structure-sort.log`
- `build-win64-debug-sortable-columns.log`
- `build-win64-release-sortable-columns.log`
- `build-win64-debug-title-sort-menu.log`
- `build-win64-release-title-sort-menu.log`
- `build-win64-debug-function-buttons.log`
- `build-win64-release-function-buttons.log`
- `build-win64-debug-function-button-post.log`
- `build-win64-release-function-button-post.log`
- `build-win64-debug-function-button-no-reentry.log`
- `build-win64-release-function-button-no-reentry.log`
- `build-win64-debug-function-button-autopost.log`
- `build-win64-release-function-button-autopost.log`
- `build-win64-debug-function-button-snapshot.log`
- `build-win64-release-function-button-snapshot.log`
- `build-win64-debug-function-button-explicit-row.log`
- `build-win64-release-function-button-explicit-row.log`
- `build-win64-debug-data-perspective.log`
- `build-win64-release-data-perspective.log`
- `build-win64-debug-query-criteria.log`
- `build-win64-release-query-criteria.log`
- `build-win64-debug-normal-setting.log`
- `build-win64-release-normal-setting.log`
- `build-win64-debug-normal-setting-sort-fix.log`
- `build-win64-release-normal-setting-sort-fix.log`
- `build-win64-debug-button-save-navigation.log`
- `build-win64-release-button-save-navigation.log`
- `build-win64-debug-button-cellclick.log`（保留并行构建的 `.vrc` 占用错误）
- `build-win64-debug-button-cellclick-rerun.log`
- `build-win64-release-button-cellclick.log`
- `build-win64-debug-button-editable.log`
- `build-win64-release-button-editable.log`
- `build-win64-debug-normal-dropdown.log`
- `build-win64-release-normal-dropdown.log`
- `build-win64-debug-normal-field-editors.log`
- `build-win64-release-normal-field-editors.log`
- `build-win64-debug-normal-field-editor-click.log`
- `build-win64-release-normal-field-editor-click.log`
- `build-win64-debug-auto-number.log`（保留首次 `csDropDownList` 编译错误）
- `build-win64-debug-auto-number-round2.log`
- `build-win64-release-auto-number.log`
- `build-win64-debug-unique-fields.log`
- `build-win64-release-unique-fields.log`
- `build-win64-debug-approval-rules.log`
- `build-win64-release-approval-rules.log`
- `build-win64-debug-run-frame.log`
- `build-win64-release-run-frame.log`
- `build-win64-debug-dropdown-options.log`
- `build-win64-release-dropdown-options.log`
- `build-win64-debug-dropdown-options-ajax.log`
- `build-win64-release-dropdown-options-ajax.log`
- `build-win64-debug-dropdown-options-view.log`
- `build-win64-release-dropdown-options-view.log`
- `build-win64-debug-dropdown-options-jsfix.log`
- `build-win64-release-dropdown-options-jsfix.log`
- `build-win64-debug-dropdown-options-native.log`
- `build-win64-release-dropdown-options-native.log`
- `build-win64-debug-data-check.log`（保留首次无害的局部变量赋值提示）
- `build-win64-debug-data-check-round2.log`
- `build-win64-release-data-check.log`
- `build-win64-debug-property-editor.log`
- `build-win64-release-property-editor.log`
- `build-win64-debug-legacy-empty-data.log`
- `build-win64-release-legacy-empty-data.log`
- `build-win64-debug-preserve-unknown.log`
- `build-win64-release-preserve-unknown.log`
- `build-win64-debug-existing-normal-settings.log`
- `build-win64-release-existing-normal-settings.log`
- `build-win64-debug-normal-setting-write-guard.log`
- `build-win64-release-normal-setting-write-guard.log`
- `build-win64-debug-numeric-json-order.log`
- `build-win64-release-numeric-json-order.log`
- `build-win64-debug-numeric-pair-lookup.log`
- `build-win64-release-numeric-pair-lookup.log`
- `build-win64-debug-save-physical-order.log`
- `build-win64-release-save-physical-order.log`
- `build-win64-debug-passive-normal-post.log`
- `build-win64-release-passive-normal-post.log`
- `build-win64-debug-empty-absent-setting.log`
- `build-win64-release-empty-absent-setting.log`
- `build-win64-debug-exact-setting-name.log`
- `build-win64-release-exact-setting-name.log`
- `build-win64-debug-original-setting-snapshot.log`
- `build-win64-release-original-setting-snapshot.log`
- `build-win64-debug-mtreport-empty-hidden.log`
- `build-win64-release-mtreport-empty-hidden.log`
- `build-win64-debug-mttree-empty-hidden.log`
- `build-win64-release-mttree-empty-hidden.log`
- `build-win64-debug-structural-generator.log`
- `build-win64-release-structural-generator.log`
- `build-win64-debug-embedded-generator.log`（保留首次真实编译错误）
- `build-win64-debug-embedded-generator-final.log`
- `build-win64-release-embedded-generator-final.log`
- `build-win64-debug-dynamic-editor.log`
- `build-win64-release-dynamic-editor.log`
- `build-win64-debug-designer-refresh.log`
- `build-win64-release-designer-refresh.log`
- `build-win64-debug-regenerate-lifecycle.log`
- `build-win64-release-regenerate-lifecycle.log`
- `build-win64-debug-visual-first.log`
- `build-win64-release-visual-first.log`
- `build-win64-debug-deferred-canvas.log`
- `build-win64-release-deferred-canvas.log`
- `build-win64-debug-multi-edit.log`（F2613）
- `build-win64-debug-multi-edit-final.log`（E1030）
- `build-win64-debug-multi-edit-utf8.log`
- `build-win64-release-multi-edit.log`
- `build-win64-debug-required-fields.log`
- `build-win64-release-required-fields.log`
- `build-win64-debug-unicode-dfm.log`
- `build-win64-release-unicode-dfm.log`
- `build-win64-debug-memo.log`
- `build-win64-release-memo.log`
- `build-win64-debug-memo-text.log`
- `build-win64-release-memo-text.log`
- `build-win64-debug-batch-controls.log`
- `build-win64-release-batch-controls.log`
- `build-win64-debug-generation-reason.log`
- `build-win64-release-generation-reason.log`

## 回归与二进制结果

`tests\test_recovery.py`：43 项 PASS（含结构化参考匹配、内嵌模板生成链、动态双字段编辑器、设计器刷新、可视控件优先释放及一次性浏览器回调回归）。

- `test_golden_reference` PASS
- `test_recovered_form_units` PASS
- `test_inherited_dfm_contract` PASS
- `test_configuration_page_owner_isolation` PASS
- `test_unigui_modal_form_lifecycle` PASS
- `test_show_json_uses_configuration_tab` PASS
- `test_configuration_stream_input_copy` PASS
- `test_host_config_stream_bridge` PASS
- `test_empty_data_structure_schema` PASS
- `test_next_saves_and_refreshes_module_pages` PASS
- `test_node_list_and_module_type_selectors` PASS
- `test_data_structure_table_metadata_flow` PASS
- `test_column_selection_updates_typesetting` PASS
- `test_typesetting_move_buttons_swap_complete_rows` PASS
- `test_data_structure_column_sorting` PASS
- `test_data_structure_dropdown_options_editor` PASS
- `test_function_buttons_follow_module_and_group_selection` PASS
- `test_navigation_keeps_active_page_during_visibility_refresh` PASS
- `test_wizard_complete_and_cancel_contract` PASS
- `test_data_perspective_crud_and_source_columns` PASS
- `test_query_criteria_crud_batch_and_source_columns` PASS
- `test_normal_setting_catalog_context_and_roundtrip` PASS
- `test_normal_setting_field_editors` PASS
- `test_normal_setting_auto_number_editor` PASS
- `test_normal_setting_unique_fields_editor` PASS
- `test_normal_setting_approval_rules_editor` PASS
- `test_normal_setting_run_frame_editor` PASS
- `test_config_stream_dialog_property_registration` PASS
- `test_legacy_dataset_without_data_is_empty` PASS
- `test_unknown_configuration_members_survive_save` PASS
- `test_existing_normal_settings_do_not_gain_defaults` PASS
- `test_configuration_schema` PASS
- `test_pascal_unit_completeness` PASS
- `test_dpr_sources_exist` PASS
- `test_build_output_is_isolated` PASS
- `test_generated_scripts_are_complete` PASS

产物：

| 配置 | 大小 | SHA-256 | LoadLibrary |
| --- | ---: | --- | --- |
| Debug | 2992128 bytes | `26A15BDC76FF74A3F994E3A5498647C2AEA2C2D47365965657749F22CD819BA8` | PASS |
| Release | 2992128 bytes | `B43CCB22CC3FDC93A9D987692791ED0976F1103BCD73125558F3700B6C9B08C2` | PASS |

作为原始基准检查的 `D:\IsoFace\FastWeb\bin64\UniGuiConfiguration.dll` 仍为 1770496 bytes，SHA-256：

`B3D1984E7406247B74533582157E32F89A7008FECE5B94291B9CAC58972DC95D`

## 81. number 脚本判空类型兼容（2026-09-04）

用户报告 `if aEditCount.Text = '' then` 所在脚本出现“不相容的类型”。检查宿主注册发现继承的 `TUniFormControl.Text` 使用 `TCaption`，而 `Value` 使用 `Real`。FastScript 的 AddProperty 在注册时确定类型，不会随之后注册的类型别名自动修正。

新增 `tests/NumberScriptProbe.dpr`，使用本机 FastScript 引擎和模拟属性绑定：先注册 Text 后注册 TCaption 时，旧比较稳定重现 Incompatible types；先注册别名时旧比较正常。此探针证明这一注册顺序可触发同类故障，未声称已捕获实际宿主的初始化顺序。

生成模板改用 `if VarToStr(aEditCount.Text) = '' then`，数字仍通过 `.Value` 回写，不经过字符串转数字，不使用 0 或 BlankValue 作为空值哨兵。探针验证空值→Null、0、-1、正负小数原值回写；两种别名注册顺序均覆盖。EditTemplateProbe 同时断言真实生成代码含归一化判空且不含旧直接比较。

验证：43 项 Python 回归通过；9 组原生模板测试通过；数字脚本探针复现旧故障并通过新逻辑。Debug/Release 编译均 0 errors、6 hints，LoadLibrary/FreeLibrary 均通过。日志为 `build-win64-debug-number-caption.log`、`build-win64-release-number-caption.log`、`build-number-caption-template-probe.log`、`build-number-script-probe.log`。探针初次构建因缺少命名空间路径失败，补充 System/System.Win/Vcl/Winapi 后编译通过；一次模板探针从错误目录调用，修正工作目录后通过。

| 当前构建 | 大小 | SHA-256 |
| --- | --- | --- |
| Debug | 2992128 | `5743FBA3BF32D222AE9A7E97465B8589030545A6DF9587C5F50DEF600A30D5A7` |
| Release | 2992128 | `346271A512CAB1ABCC76E332A6EC486D06B5EA51DFD9A106C45C476EF6E197DA` |

原始 DLL 哈希仍为 `B3D1984E7406247B74533582157E32F89A7008FECE5B94291B9CAC58972DC95D`，未覆盖。实际浏览器/宿主执行仍待用户复测；替换 DLL 不会自动改写已保存脚本，需重新打开精灵并完成生成，或手工替换原判空行。建议先备份测试模块，再测试空、0、-1、正负小数及必填规则。

## 82. 精灵 time 类型入口补全（2026-09-04）

用户确认 number 修复及上一轮除 time 外的日期相关测试正常；time 因下拉列表没有该选项而未测试。此前动态生成端已支持 time，但 DataStructure 的 edObjectType.Items 和查询条件对象类型列表遗漏入口。

本轮在 date 与 datetime 之间增加 time，主数据结构及继承它的从表结构均可选择；查询条件设置列表同步增加 time。未改动数据库类型自动推断、已有配置内容或其它模块的生成边界。mtEditor 动态生成仍使用 TUgDateTimePicker、Kind=tUniTime、TimeFormat=HH:mm:ss，变量按 DateTime 回写，依据 RemoteValue[0] 区分空值和午夜。

新增静态入口/继承/生成连通回归，原生模板探针增加 tUniTime 精确断言。44 项静态/黄金回归、9 组原生模板测试、NumberScriptProbe 均通过。Win64 Debug/Release 编译均 0 errors、6 hints；两个 DLL 加载和卸载均通过。

日志：`build-win64-debug-time-option.log`、`build-win64-release-time-option.log`、`build-time-option-template-probe.log`。

| 当前构建 | 大小 | SHA-256 |
| --- | --- | --- |
| Debug | 2992128 | `1E8988F5A21DCB7CB59A94055D18B76B19936976314CB533659C40DDA5121207` |
| Release | 2992128 | `BDA9C82A0988422BFD64895CCCF9A2252E487765783A333FDF4E72D66CCC543D` |

原始 DLL 哈希仍为 `B3D1984E7406247B74533582157E32F89A7008FECE5B94291B9CAC58972DC95D`，未覆盖。time 的真实宿主保存回载、运行空值/00:00/必填仍待验证；测试方式见 BATCH_CONTROLS_CHECKLIST.md。

## 83. time 午夜初始提交同步（2026-09-04）

用户澄清：清空会触发非空提示，但 00:00:00 也被拒绝。UniGUI 1567 源码显示 tUniTime 的 UpdateText 会把 DateTime=0 格式化为午夜，即使 ShowBlankDate=True；之前 OnShow 只设置 DateTime，没有初始化脚本判空使用的 RemoteValue[0]。

在动态 time 的 OnShow 日期时间赋值之后增加 `RemoteValue[0] := VarToStr(Text)`，令初始提交状态匹配可见时间。仅在初始化同步，提交时不重新同步，避免把用户清空后留下的空槽又变为午夜。保留原有初值显示策略（Null 初值仍显示午夜）；本轮不扩展成“初值 Null 自动显示空白”的新行为。

新建 TimeScriptProbe，使用真实 FastScript 加模拟控件绑定，复现未初始化提交槽时午夜被视为 Null；验证同步后的午夜为有效 0、普通时间保持、随后清空为 Null 并触发必填。测试不是实际浏览器复现，宿主根因和 Ajax 同步完整路径仍需复测确认。EditTemplateProbe 断言生成的初始化同步语句存在。

44 项静态/黄金回归、9 组原生模板测试、5 组时间脚本场景通过。Debug/Release 编译均 0 errors、6 hints，加载/卸载成功。日志：`build-win64-debug-time-midnight.log`、`build-win64-release-time-midnight.log`、`build-time-midnight-script-probe.log`、`build-time-midnight-template-probe.log`。

| 当前构建 | 字节数 | SHA-256 |
| --- | --- | --- |
| Debug | 2992640 | `678C4890A903CE117085B9D4DC6E69F862B4E732E2A70A5E44E1D714D57B404E` |
| Release | 2992640 | `DE97E0DF8B3A15C2DFF56BD465479F59C53E2689355A351ADDDB380A00944D0E` |

原始 DLL 哈希仍为 `B3D1984E7406247B74533582157E32F89A7008FECE5B94291B9CAC58972DC95D`，未覆盖。用户需替换测试 DLL 并通过精灵完成重新生成脚本，测试初始午夜直接提交、清空提交、清空后输入午夜再提交。

## 84. time 使用浏览器同请求提交状态（2026-09-04）

宿主诊断确认：午夜与清空两种输入，在提交事件内均得到 `Text=[00:00:00] Remote=[] DateTime=[0]`。第 83 轮初始化同步方案未通过实测，旧 TimeScriptProbe 的模拟属性假设不足以覆盖宿主行为，不能作为该方案成功的依据。

本轮移除动态脚本中全部 time RemoteValue 读取/初始化。含 time 的 mtEditor 在生成的按钮 click 客户端事件内，以 getRawValue 区分清空，非空时检查有效的 getValue Date，并传当天秒数；空传 blank，午夜传 0。数据与提交动作在同一次 `ug-time-submit` Ajax 请求里发送，不依赖先发 change 事件的时序。查找使用当前根框架的标记与字段标记，不使用全局同名控件。

按钮脚本事件由 OnClick 改为 OnAjaxEvent，避免两个服务器提交入口。服务器对缺失参数、非整数及越界秒数拒绝处理，blank→Null，合法秒数/86400→时间 Variant，继续使用原必填检查和 mrOk。无 time 模块保持原 OnClick 路径。原始 DFM 黄金样例不修改。Null 初始值显示午夜的现有策略不在本轮改变。

验证：44 项静态/黄金回归、9 组原生模板生成/DFM 解析通过；新 TimeSubmitScriptProbe 用真实 FastScript 验证 midnight、blank、普通时间、日末、缺失/非法/越界共 8 项；test_time_submit.js 执行实际生成的 JS，模拟 Ext 控件树，覆盖午夜、清空、再次输入午夜、普通时间、日末、无效输入、字段缺失以及单请求和限定框架查找。数字脚本探针复测通过。测试不等同实际 Ext/UniGUI 宿主端到端验证，待用户验收。

Win64 Debug/Release 均编译成功（0 errors、6 hints）、加载/卸载成功，均为 2997248 bytes，SHA-256 `603D47002ED43E6825C427B7303698876A0EDAD52B4DE60923BF6B1AE21EC98F`。日志：`build-win64-debug-time-raw.log`、`build-win64-release-time-raw.log`、`build-time-raw-template-probe.log`、`build-time-raw-script-probe.log`。生成浏览器测试 DFM 在 `probe-bin/time-submit-generated.dfm`，可用 `node tests/test_time_submit.js probe-bin/time-submit-generated.dfm` 复测。

原始 DLL 哈希仍为 `B3D1984E7406247B74533582157E32F89A7008FECE5B94291B9CAC58972DC95D`，未覆盖。部署后必须重新通过精灵点完成，以同时刷新按钮绑定、客户端事件及脚本，删除临时 TIME诊断代码；只改旧提交脚本不足以启用新路径。

## 85. 普通 lookupedit / SqlQuery 首轮生成（2026-09-04）

用户明确选择普通 lookupedit：选中客户后只显示客户代码。输入样例为附件 53f875b2-86aa-4849-b62e-62395c6e6937，mtEditor 共 12 个排版字段；a.CustCode 使用 ElfDemo 节点，SqlQuery 查询 tab_Customer，最多 100 行、分页 Close，列表字段 custCode@客户代码 / custName@客户名称，值字段 custCode。

动态模板新增 TUgLookupEdit 和同根持有的独立 TUgClientDataSet（ugLookupDataaCustCode），通过 LookupData、LookupValueField、LookupFields 连接，字段标题与窗口标题使用现有 Unicode DFM 转义。SQL 的字面量反斜杠换行恢复成实际换行；数据集默认不活动，在模块 OnShow 先 Close/Open 后加载代码到控件，提交读取 Text 到 vCustCode。数据节点、最大行数、关闭分页均显式生成。

本轮明确范围：SqlQuery、正整数最大行数、关闭分页、普通代码显示。每次打开模块重新加载候选列表；cbDynamicLoading=-1 此轮不实现按输入远程检索/点击时延迟加载。edOptionDisplay 仍保留在 JSON，但按用户选择不生成名称显示区；普通控件使用 LookupFields 自带列表过滤，未将 edOptionFields 扩展为多字段联动。SqlText、分页和 lookupeditextra 不在本轮范围，不把它们静默生成成普通控件。未改变源码宿主控件自身的弹窗生命周期。

新增 LookupTemplateProbe 读取用户完整配置，断言实际控件类型、数据集引用、代码值字段、名称列表列、限额、SQL 解码、加载顺序、变量回写、time Ajax 提交保留及 DFM 二进制解析。该测试通过；44 项静态/黄金回归、9 组原生模板测试、time 生成 JS 测试通过。没有连接客户数据库执行查询或宣称宿主控件已验收。

Delphi 10.3.3 / Win64 / UniGUI 1567 Debug/Release 编译成功，0 errors、6 hints，两个 DLL 加载/卸载成功。日志：build-win64-debug-lookup.log、build-win64-release-lookup.log、build-lookup-template-probe.log。生成样例：probe-bin/lookup-user-generated.dfm。

| 构建 | 字节数 | SHA-256 |
| --- | --- | --- |
| Debug | 3003904 | `D398C76FFBC8790477A25D5C536AEB46BFBE2754847853C7DDA929B610256AFD` |
| Release | 3003904 | `74A79DAD2B8F085DE8474C6BAA0A3F7BA245D163EC99A74993FE94633E173D86` |

原始 DLL 哈希仍为 `B3D1984E7406247B74533582157E32F89A7008FECE5B94291B9CAC58972DC95D`，未覆盖。待用户重新完成生成并测试客户列表、选中代码回写、清空/必填、保存重开与重复完成。

用户此前已确认 time 午夜/空值及保存重开通过；同 IDE 同时打开两个模块受宿主限制未测。固定 combobox/SetText 的生成、选择回写、必填、保存重开四项通过。

## 86. lookupeditextra 代码/名称双栏生成（2026-09-04）

用户确认普通 lookupedit 第 85 轮测试通过，并授权继续 lookupeditextra。沿用客户配置生成 TUgLookupEditExtra，LookupValueField=custCode、LookupDisplayField=custName，代码栏宽 120、控件宽 360，有 extra 时根框架宽 380。只设置已核实发布的属性，不写只读 DisplayText，不自行重建该控件内部 Code/Name 子组件。

数据集仍先于 Text 回载加载；宿主额外控件的 Text 表示代码，SetText 会查询候选数据以恢复只读名称，提交 vCustCode 仍读取 Text。显示字段缺失/非法时明确拒绝。保留首轮 SqlQuery、关闭分页、打开模块重载、最大 100 条的边界，不扩展远程逐字查询。普通 lookupedit 生成路径不变。

LookupTemplateProbe 先运行原始用户配置，再仅在内存将 a.CustCode 改为 lookupeditextra，验证双字段映射、宽度、代码回写、不写 DisplayText、DFM 解析，并验证缺失显示字段/开启分页拒绝。原始用户附件未修改。上述测试、44 项静态/黄金回归、9 组原生生成测试、time 生成 JS 执行测试均通过。未启动真实客户数据库或宿主界面，双栏显示/选择/清空/回载仍待用户验证。

Debug/Release（Delphi 10.3.3、Win64、UniGUI 1567）编译成功，0 errors、6 hints；加载卸载成功。

| 构建 | 字节数 | SHA-256 |
| --- | --- | --- |
| Debug | 3004928 | `54B320818FAE23D11379E1F9AD3BCDBFED92D248971C7E749CA1C5E7EE1DCD3F` |
| Release | 3004928 | `FEE08981F3B6F6002CBB9B4E0A08CF8989AA01934C1FF5368B93F6B584F1D959` |

日志：build-win64-debug-lookup-extra.log、build-win64-release-lookup-extra.log、build-lookup-extra-template-probe.log。生成测试样例在 probe-bin/lookup-user-generated.dfm.extra.dfm。原始 DLL 未覆盖，哈希仍为 `B3D1984E7406247B74533582157E32F89A7008FECE5B94291B9CAC58972DC95D`。

## 87. 宿主扩展授权与隔离基线构建（2026-09-04）

用户确认 lookupeditextra 四项宿主测试通过，随后授权尝试修改并重建宿主查找控件。当前阶段先建立可运行基线，未修改 lookup 控件源码或实现分页。确认当前进程为 UniGuiClient.exe，使用对应 UniGuiClient.dproj。

基线经历 fs26 缺失、uniGUIISAPI 缺失、安装 DCU 编译器/依赖版本不兼容后，使用工作区原有 Win64UniGuiClient.dpr DCU 查找路径编译通过。日志 build-host-lookup-baseline.log 至 round6.log；最终 498585 lines，存在原有 warnings/hints。输出到 host-test/bin 与 host-test/dcu，未覆盖正在运行的 EXE 或原始 DLL。44 项配置重建回归通过。

隔离 EXE 为 18326016 bytes，SHA256 `3FBAFF109A53D06FF367D9ADE8FD53320B649C5BCC9782BE4432F3ACD1E02C1F`。完整依赖边界和宿主测试步骤见 host-test/README.md。真实启动/设计器功能验证待用户执行；通过后再接入分页和查询，避免将基线兼容问题与新功能混淆。

## 88. 宿主查找窗口数据库分页/查询（2026-09-04）

用户确认新编译基线宿主两项测试通过后授权继续。先备份该 EXE 和 ugLookupEdit 原字节文件；CP936 无损往返校验后将 ugLookupEdit.pas 转为 UTF-8 BOM，再添加窗口分页挂接、确认交回数据、缓存未命中时精确查询三处集成（普通/DB 类型共用，extra 通过内部普通控件使用）。新增 ugLookupPaging.pas 和纯 SQL 构造单元 ugLookupPagingQuery.pas，未修改数据集类的二进制布局。

配置生成器新增 Open / Close 分页识别和每页 1～500 校验。Open 将页大小写入生成候选数据集 Tag；只有 ugLookupData 前缀且 Tag>0 的数据集走新路径，Close 和其它旧控件保持原路径。需要同时更新宿主和配置 DLL。

窗口增加查询框与翻页，文本列表列参数化包含查询；每次查询回第一页，数据库按唯一代码排序/取指定页，无总记录数全量扫描。独立窗口数据集仅在双击确认时交回源数据；精确代码查询用于跨页名称回载。限制为无原始参数、不含 ORDER BY 的单条 SELECT，查询不支持逐字实时请求；不改用户 SQL 为猜测语义。

完整宿主 Release/Win64 编译通过（498791 lines，原有 warnings/hints）；日志 host-test/build-paging.log。配置 DLL Debug/Release 均编译通过（0 errors、6 hints），加载/卸载通过。44 项静态/黄金回归、9 组原生模板、lookup 与 extra/分页参数、time 浏览器生成代码和 time/number FastScript 探针通过。纯 Delphi SQL 构造探针输出实际 SQL，并在 251 行合成 SQLite 数据上验证分页/跨 100 条代码及名称查询、通配符转义、注入字符串不扩展匹配、无结果及精确回载；取消不转交源数据还做了静态断言，尚非 UI 实测。

新宿主 SHA256 `59039CA660F742B51C1FB9EA4C319B5A23A3CEA647495F023B736B1DD3EA9917`，新 DLL 均 3005440 bytes，SHA256 `8E28A1B3981055AE9F7E6BB6D72FBAF9CEC768C159306DDA1CAEE9898814DD05`。运行目录中 EXE 仍为用户已测试的基线哈希 3FBAFF...，未由本轮覆盖。原始配置 DLL 哈希仍 B3D1984E...。部署、范围、回退及待验收清单见 host-test/PAGING_VALIDATION.md。

## 89. 分页查找查询参数与关闭释放修复（2026-09-04）

用户确认上一页/下一页正常，查询报 Argument out of range，关闭选择窗口报 uniGUI26.bpl 读取地址 8 的 AV。检查发现两处问题：查询在 CommandText 自动解析参数后再次 CreateParam；分页对象析构时解引用网格并恢复绑定，可能触碰窗体已销毁控件或触发销毁中的网格刷新。

新增 SetLookupParameter：本模块生成的 SQL 只含一个逻辑参数，清除自动生成的重复项再创建一项，搜索和精确代码回载均使用它。实际 TClientDataSet 原生探针打印自动参数数 2、旧追加后 3，新路径验证参数数 1，文本值正确。未修改宿主通用 OpenCds 的参数绑定行为。

关闭路径改为两种 lookup 的 modal finally 都先调用 DetachLookupPaging，并用 finally 保证 F.Free；分页析构只释放自身资源，不再访问网格。静态测试断言两处调用存在且析构没有 FGrid.DataSource 访问。实际关闭异常没有本地 UI 复现，仍需用户复测。

宿主 Release Win64 编译成功（498815 lines，无新增单元 warning/error，仍有原项目 warnings/hints）；host-test/build-paging.log 为本轮日志，上一轮日志保存在 build-paging-before-params-fix.log。原生参数复现/修正、251 行 SQLite 查询、44 项配置回归、lookup/extra/分页生成探针通过。配置 DLL 未修改（仍 8E28A1B3...），无需重新生成模块。

修复 EXE 18337280 bytes，SHA256 `E36CB369D33B09EB9305B95A3CE1D1AF550B25FDFDAF6EB4C2BED7C5EE0D270A`；运行目录仍是上一版 59039CA6...，未覆盖。已验证基线备份仍为 3FBAFF10...。待验收步骤见 host-test/PAGING_VALIDATION.md。

## 宿主环境验证进展

## 90. gridcombobox / gridcomboboxextra 输入动态查询首轮

2026-09-04：用户同意按照原参考脚本恢复表格下拉输入查询。保留已通过的 lookupedit/extra 手工查询弹窗及其服务端分页，不修改宿主 EXE 或已部署文件。

EditTemplate 新增两控件类、GridLookupDataSet、GridValueField、extra 的 GridDisplayField/GridValueWidth、原生 GridWebOptionPaged/PageSize 和 OnExtEditValueChange 事件。edOptionFields 是显示列，edOptionLookupFields 是查询列，分别映射；未勾选动态时使用原生数据集过滤，开启时初始化 schema-only、每次输入重新执行有限条数查询。SQL 使用每字段唯一命名参数，避免前轮重复占位符参数绑定错误，也避免输入拼入 SQL。

原生探针首编发现 Data 命名空间未加入，以及测试中的 Delphi 字符串数组/循环变量语法错误；仅修正测试后通过。检查现有 FastScript RTTI 发现无 Params.Clear/CreateParam，生成器改用已注册的 ParamByName/AsString，实际提取生成事件交由 FastScript 执行五种输入通过。数据库 Open 为测试替身；尚未验证浏览器 UI 与实际节点数据库。

最终 Debug/Release 编译均成功（8616 lines，0 errors，6 existing hints），日志 build-win64-debug-gridcombo.log / build-win64-release-gridcombo.log。两 DLL LoadLibrary/ABI 通过。四组 gridcombo 生成/DFM 解析，44 项结构回归，9 组编辑器生成，lookup/extra，time JS/FastScript、number 及 251 行分页查询回归通过。详见 validation/GRIDCOMBO_VALIDATION.md 和 test-grid-probe.log。

Release：3016704 bytes，SHA256 `236F4A06D9D7BB3DF8A44F54359312F7F50A372B5B782201F381DE558FCD7FB2`。Debug：`79AD3E8CD64AC5D8BFF10A20AF61F80BC53CE3E9433D5BF58E0EA3C5D29B43A9`。原 DLL SHA256 仍为 `B3D1984E7406247B74533582157E32F89A7008FECE5B94291B9CAC58972DC95D`，未覆盖。

## 历史宿主验证清单

## 91. 修正 gridcombobox 的 DFM 属性混用和候选数据集缺失

用户把客户字段改为 gridcombobox 后，完成时报 LookupData 属性不存在。确认是生成器分支错误：lookupedit 属性块错误包含 IsGrid，而末尾候选数据集生成块反而遗漏 IsGrid。修正两个条件，保留原 lookupedit/extra 行为。

新增反向属性断言及候选数据集声明断言，修改前实际失败于 `grid must not emit lookupedit LookupData`（test-grid-property-before.log）。修复后，用附件 47e5688b-b51f-4c16-b4d8-f19c85278740 的真实配置仅改变对象类型，两种 grid 类型均通过生成/DFM 语法解析；另四组动态开关/脚本参数测试通过。测试工具固定字段名断言曾与新附件 cusCode 不符，已拆分真实配置验证与显式标准化的合成脚本测试。

44 项结构回归、lookup/extra 生成探针通过。Debug/Release 均编译成功（8616 lines、6 hints），日志 build-win64-debug-grid-property.log / build-win64-release-grid-property.log。测试仍不等于真实 UniGUI 会话组件流式创建；需要宿主复测完成及输入动态查询。

Release DLL 3016704 bytes，SHA256 `473AC298EA61959BE8C9BB546467830B52C410B82ABF24E7C6DDE3B447317713`。原 DLL 哈希仍为 B3D1984E...，未覆盖部署文件。

## 历史宿主验证清单（续）

## 92. 表格下拉验收及基线归档

用户连续确认第 91 节修复后生成与动态查询通过；extra 显示/代码提交、分页换词、保存重开均正常；关闭动态加载正常且未影响 lookupedit。已复制 Release DLL 到 baselines/2026-09-04-gridcombo-473AC298/UniGuiConfiguration.dll，并确认 SHA256 为 473AC298EA61959BE8C9BB546467830B52C410B82ABF24E7C6DDE3B447317713。未修改或部署运行目录文件。

核对控件目录：edit/memo/number/date/time/datetime/check/combobox/lookupedit/lookupeditextra/gridcombobox/gridcomboboxextra 均已有动态 mtEditor 生成分支，不等于所有子模式均已实现。下一候选增量是普通 combobox 的 SQL 模式，当前生成器仅支持 SetText。现有黄金样例未查到 SqlText 配置；需用户提供原 DLL 的该模式 JSON 与相关生成脚本，以确定返回列/显示值语义。本轮未修改源码或重新编译。

## 历史宿主验证清单（续二）

## 93. 普通 combobox SqlText 支持

取得原版实际 SqlText 配置和完整加载脚本后实现：独立 ugComboData 数据集，在 OnAfterRunScript 节点绑定之后加载指定字段到 Items，清空并关闭候选数据集；OnShow 仅恢复 Text。遵循原版初始化查询时机、逐行加入、代码文本提交，无显示值映射和动态输入查询。本实现使用 finally 确保异常也关闭数据集。SQL 首轮限定无参数/注释的单条 SELECT。

SqlTextTemplateProbe 使用实际附件，验证属性隔离、候选声明、返回字段、加载时机、DFM 解析和非法配置拒绝。SqlTextScriptProbe 提取实际生成脚本，使用 FastScript + 内存 TClientDataSet 验证三行、重复加载、空结果和模拟 Open 异常；候选数正确，数据集均关闭。真实宿主仍待用户验收。

Debug/Release 编译通过（8681 lines，6 existing hints），日志 build-win64-Debug-sqltext.log / build-win64-Release-sqltext.log。44 项结构回归、9 组编辑器、time JS、lookup/extra、gridcombo 生成与脚本回归通过。测试说明 validation/SQLTEXT_VALIDATION.md。

Release DLL 3021312 bytes，SHA256 256092C625CDA692FCC8184E7D188C11C821AFE53AF4E66BA03C39C810B10D71。没有更改宿主 EXE 和部署文件。原 DLL 哈希保持 B3D1984E...；上轮基线仍保留。

## 历史宿主验证清单（续三）

## 94. SqlText 宿主验收及下一模式资料核对

用户确认第 93 节普通 SqlText 的候选加载、代码提交、保存重开正常；补测空结果、中文与单引号客户代码亦通过。确认运行目录与 Release 哈希均为 256092C625CDA692FCC8184E7D188C11C821AFE53AF4E66BA03C39C810B10D71，复制至 baselines/2026-09-04-sqltext-256092C6 并校验一致，未替换运行目录或原始 DLL。

扫描现有 fixtures/reference 主从字段配置，未找到普通 combobox 的 SqlQuery 样例。当前下拉设置窗体有通用 SqlQuery 设置，但不能据此认定原版普通 combobox 的生成语义。下一步需原 DLL 配置 JSON 与生成脚本；如可提供 aCustCode 的生成 DFM，亦可核对原版是否换用其他控件类。本轮无源码修改或新编译。

## 历史宿主验证清单（续四）

## 95. 撤回普通 combobox + SqlQuery 扩展计划

用户核实原始 DLL：普通 combobox 不支持 SqlQuery。第 92、94 节及基线说明中要求此模式样例的计划作废，不属于缺失兼容功能。保留生成器 SetText / SqlText 支持和对 SqlQuery 的明确拒绝；不扩大原版支持范围。本轮仅修正文档，没有修改源码、重新编译或部署。普通 combobox 的已确认两种模式已有宿主验收。

## 历史宿主验证清单（续五）

## 96. 恢复功能按钮父子联动专项

继续先前暂缓项。源码核实 uniDBGrid.JSConfigColumn 将数字 ColID 用作 dataIndex，原 FunctionButton cellclick 的 record.get(fdName/fdSelect) 因此不符合数据格式。修正为 beforecellclick 读取真实 ColID，反转明确布尔值，取消默认编辑并发送一个 _select 请求。服务端 Locate 成功后从实际数据行获取父组，拒绝未知名称/非法选中值；批量更新期间暂停数据通知，保留空 AfterPost 避免递归联动。

新 test_button_selection.js 执行提取的真实 JS 并通过数字键/列位置变化/布尔值/单请求断言；test_recovery 中旧的延时与字段名断言改为新契约，44 项通过。Debug/Release 编译通过（8686 lines、6 hints），日志 build-win64-Debug-button-link.log / build-win64-Release-button-link.log。没有实际浏览器测试；尤其 beforecellclick 是否完全阻止默认更新需用户复测。

Release 3022848 bytes，SHA256 5696143B971D83AE5E12E44814D38FC96CF12772654E852E3255906DE0555436。原 DLL 哈希仍为 B3D1984E...，未覆盖原始或部署 DLL。验收说明 validation/BUTTON_LINK_VALIDATION.md。

## 历史宿主验证清单（续六）

## 97. 按用户角色树参考恢复原生勾选提交与逐行刷新

用户确认第 96 轮仍无联动，提供 D:/Projects/fastweb/角色.pas 和 角色.dfm，其中 treeRolePerms 为已工作示例。读取后确认 AutoPost=True、edit->_post、RefreshCurrentRow(True) 及批量更新逐行 RefreshCurrentRow(False) 的组合；撤销 beforecellclick 拦截。AfterPost 仅捕获已提交节点标识和值，独立回调 FlushSelection 后执行批量联动；保存/切模块类型也 FlushSelection。FUpdatingSelection 防止程序级联 Post 再次排队。父级逻辑保持全选语义，不照搬参考的任一子权限即选父级及 Next 同级权限包含逻辑。

Debug/Release 编译通过（8691 lines、6 hints），build-win64-Debug-button-role.log / build-win64-Release-button-role.log。44 项结构回归及实际客户端 edit 事件提取执行测试通过；完整 UniGUI 编辑时序和 UI 联动需用户测试，尚未宣称解决。参考两文件与宿主 EXE 未修改，未部署 DLL。

Release DLL 3021824 bytes，SHA256 A3745C568E8B13A03ACD2C2BE43F2DB991061FCD5215FCE6D3C396EAF051EC5E。上一轮 SqlText 已验证基线仍保留。

## 历史宿主验证清单（续七）

## 98. 修正父子联动延迟到下一次点击

用户第 97 轮反馈：勾选父组后，必须点击另一父组才更新前组子项。结合原生 SetCellValue 在 AutoPost 时调用 DataSet.Post 的路径，当前客户端 edit->_post 存在先于实际提交执行的时序风险，导致 FlushSelection 尚无本次目标。

移除客户端 edit 回调，AfterPost 捕获目标后启用窗体拥有的一次性 TUniTimer（Interval=1）；下一独立请求禁用计时器并 FlushSelection。只在真实提交完成后调度，避免回调读到上一轮目标。批量修改仍由 FUpdatingSelection 防止再次调度，保存/载入清理计时器和待处理状态。保留 AutoPost=True 和逐行刷新。

Debug/Release 编译通过（8703 lines，6 hints），build-win64-Debug-button-afterpost.log / build-win64-Release-button-afterpost.log。44 项结构回归及静态提交时序契约通过；未验证真实浏览器事件时序，待用户复测第一次点击后不再操作是否自动联动。测试不声称响应在 1ms 完成，仍需一次浏览器往返。

Release SHA256 FDD3E495B2D4C13FB1BC221DB48AF1041B1165B53F535C17C0AA9C5A5060828E，3021824 bytes。未替换部署文件，已验证 SqlText 基线仍保留。

## 历史宿主验证清单（续八）

## 99. 按用户明确要求改为父级任一选中语义

用户确认父组点击已自动更新子按钮，但要求父组选中表示至少一个子按钮选中，而非全部子按钮选中。ApplySelection 子级操作汇总和 UpdateGroupSelection 初始化/模块过滤汇总同时由 all 改为 any；父组直接点击仍全选/全取消当前可见组成员。不更改已修正的提交后一次性回调时序。

Debug/Release 编译通过（8703 lines、6 hints），日志 build-win64-Debug-button-any.log / build-win64-Release-button-any.log；44 项结构回归、时序契约检查通过。新增断言两个汇总路径使用 LAnySelected 且不再出现 LAllSelected。新规则宿主待验收。

Release SHA256 EBD32F3B9F94DB9A35A9EEA9A347C94D7FB4FCEF83E9BDE1CCAE4BB2A87AB014。没有覆盖部署文件、原 DLL 或已验证基线。

## 历史宿主验证清单（续九）

## 100. 功能按钮验收及完整流程回归准备

用户确认第 99 轮父子联动问题解决。当前 Release 与运行目录 DLL 哈希均为 EBD32F3B9F94DB9A35A9EEA9A347C94D7FB4FCEF83E9BDE1CCAE4BB2A87AB014。

用户同意完整回归后，核对生成器仍为参考匹配优先，否则只支持动态 mtEditor。更正先前直接建议任意配置 mtMasterSlave 并完成生成的范围错误；流程拆分为 mtEditor 完整生成/保存/重复完成/放弃，以及主从配置页面与已知参考生成。清单 validation/FULL_FLOW_REGRESSION.md。

本轮无源码更改，无新编译或部署。重新运行 44 项结构回归、编辑器 9 例、time JS、lookup/extra、gridcombo、SqlText 生成和脚本、251 行分页查询测试通过。功能按钮静态时序检查通过。宿主完整流程待用户确认，暂不把候选 DLL 宣称为综合验收完成版本。

## 历史宿主验证清单（续十）

## 101. mtEditor 完整流程用户验收通过

用户确认 mtEditor 类型已测试通过，对应第 100 轮生成、保存重开、重复完成和放弃回退清单。运行目录与 Release 哈希再次核对均为 EBD32F3B9F94DB9A35A9EEA9A347C94D7FB4FCEF83E9BDE1CCAE4BB2A87AB014，复制并校验基线 baselines/2026-09-04-mtEditor-EBD32F3B/UniGuiConfiguration.dll。

本轮仅记录验收和归档，不修改源码或部署。其他模块类型任意新配置的动态生成仍待扩展，已知参考配置匹配能力与通用生成必须区分。

## 历史宿主验证清单（续十一）

## 102. mtMultiple 动态生成首阶段（只读查询，未完整实现）

按用户要求开始扩展 mtMultiple。新增 ugConfiguration.MultipleTemplate：配置决定单表 SQL、选中列、标题、edit 查询条件、查询/关闭和 50 行分页控件；查询参数化，无写回代码。生成桥保持参考匹配优先，非参考 mtMultiple 走新分支，仍在清理宿主控件前验证配置。未实现的按钮/高级设置明确拒绝。

首次真实编译报新单元未找到，已在 dpr 显式加入源码路径。Debug/Release 最终均通过（8918 lines、7 hints），日志 build-win64-Debug-multiple.log / build-win64-Release-multiple.log。MultipleTemplateProbe 的非黄金表/字段/DFM/保护测试通过；MultipleScriptProbe 执行真实生成脚本，模拟 provider，覆盖空条件、单引号参数、重复查询和页大小。45 项结构回归、9 组编辑器、time JS、SqlText 脚本和按钮时序检查通过。

仍未完成完整 mtMultiple：写回、编辑子窗体、多表、高级规则等留待后续阶段；实际 UniGUI 组件创建、数据库分页也待用户验收。测试说明 validation/MULTIPLE_DYNAMIC_VALIDATION.md。Release SHA256 FAB9CAFF5DD774175E8AC93E1AB1AA8918D734CB270425AD1DA9304420D33193，3043328 bytes。未部署，原 DLL 哈希 B3D1984E... 保持不变；已验证 mtEditor 基线保留。

## 历史宿主验证清单（续十二）

已完成：

1. 使用隔离目录中的重建 DLL 启动宿主；
2. 宿主通过 `UGMM.GetDllComponent('UniGuiConfiguration>WebConfigurationModule', Self)` 成功取得组件；
3. 配置精灵成功显示，DLL 路由、UniGUI 会话上下文和继承 DFM 创建链已贯通。
4. “查看 JSON”的“配置数据”页已在真实宿主中显示完整默认 JSON；标量为空、数据集结构和数据为空，符合尚未选择数据节点及尚未执行数据结构业务操作时的初始状态。
5. 修复选择器后，真实宿主选择 `ElfDemo` 和 `mtTree`，点击“下一步”再查看 JSON，两个标量均正确保存；`TWebDataStructure` 与 `TWebDetailedStructure` 中 `cdsTables`、`cdsColumns`、`cdsTypesetting` 的字段结构逐项匹配 `mtTree.json` 黄金样例，数据行均为 0，符合尚未新增数据表的状态。
6. 数据结构页已在真实宿主中成功读取 2 张表和 23 个字段，表关联、别名、类型映射及 GUID 完整；实际 JSON 暴露的“11 个已选字段、0 条排版记录”问题已在新构建中修复。
7. 新构建已通过真实宿主复测：选择 `ElfDemo`、`mtDetail`，在明细结构页加入 1 张表并选择 6/18 个字段后，JSON 中 `TWebDetailedStructure.cdsTypesetting.Data` 正确生成 6 条记录；与所选字段的 GUID、字段名、标题完全一致，无缺失或多余记录。
8. 排版区上移、下移已通过真实宿主复测；界面显示和 JSON 记录顺序同步变化。
9. 字段列表与排版区的列头排序、列头菜单以及排序后的字段同步均通过真实宿主复测。
10. 数据透视页已通过真实宿主复测：数据结构已选字段可作为新增来源；分组和统计记录可新增；修改、删除、上移、下移均正常；JSON 的 8 个字段及记录顺序正确。
11. 查询条件页已通过真实宿主复测：批量新增及去重、同字段多条件、完整增删改与顺序调整、两个布尔选项以及 `TWebQueryCriteria` JSON 均正常。
12. 功能按钮页已通过保存复测：选择列可操作，选择子按钮后 `TWebFunctionButton` 能正确保存按钮内容。父组/子按钮双向联动仍按既定决定暂缓。
13. 常规设置页基础下拉编辑已通过真实宿主复测：列表不再自动收起，选项可以正常选择。
14. 常规设置字段选择已通过真实宿主复测：“关联字段”“隐藏字段-主表”“从表非空”“隐藏字段-从表”均能显示正确来源的字段并保存。
15. 数据结构字段“下拉选项”单元格已通过真实宿主复测：`combobox`/`lookupedit` 行单击后可正常显示专用配置窗口。
16. “下拉选项”的 `SetText`、`SqlText`、`SqlQuery`、动态加载、分页、字段配置、外层 JSON 及重新打开回载均已通过真实宿主复测。
17. “从表结构”的“数据校验”窗口、关联表/字段联动、保存回载及 `fdDataCheck` JSON 已通过真实宿主复测。
18. 向导“完成”后配置持久保留；“放弃”后未提交修改并恢复上次配置，宿主 `ConfigStream` 边界已通过真实宿主复测。
19. 可靠的原 DLL/重建 DLL `mtMasterSlave` 完整 JSON 对照已通过：除空数据集 `Data` 的等价规范化外，配置内容和全部业务顺序一致。
20. 可靠的原 DLL/重建 DLL `mtReport` 完整 JSON 对照已通过：常规设置均为 9 项；除三个空从表数据集 `Data` 的等价规范化外，完整配置内容和全部业务顺序一致。
21. 可靠的原 DLL/重建 DLL `mtTree` 完整 JSON 对照已通过：常规设置均为 16 项并保留 6 个原有空值；除 5 个空数据集 `Data` 的等价规范化外，完整配置内容和全部业务顺序一致。
22. 可靠的原 DLL/重建 DLL `mtMultiple` 完整 JSON 对照已通过：20 项常规设置及原有空 `隐藏字段-主表` 均正确保留；除 4 个空数据集 `Data` 的等价规范化外，完整配置内容和全部业务顺序一致。
23. 可靠的原 DLL/重建 DLL `mtEditor` 当前变体完整 JSON 对照已通过：3 项常规设置、主数据结构及全部顺序一致；除 5 个空数据集 `Data` 的等价规范化外，完整配置一致。
24. 第二种 `mtEditor` 变体完整 JSON 对照已通过：原有空 `隐藏字段-主表` 正确保留，3 项常规设置、主数据结构及全部顺序一致。
25. `mtMasterSlaveQuery` 参考配置完整 JSON 对照已通过：实际模块类型为 `mtMultiple`，12 项常规设置、18 条字段/排版和 5 条查询条件均一致。至此七组已知参考配置全部通过真实宿主对照。
26. 七份参考 DFM 均已在真实设计器中成功创建并预览 `TUgWebRunFrame`；UniGUI 1.90.0.1567 Web 资源、Ext JS 7.5.1 和宿主 Win64 BPL 组部署检查通过。

下一步：

1. 对其余模块类型的黄金 JSON 做结构化加载/保存比较，确认未知字段仍被保留。
2. 从宿主 `ConfigStream` 向向导注入其余黄金 JSON，复核各模块类型页面和数据回载。
3. 加载相应参考 DFM，确认宿主可创建 `TUgWebRunFrame`。
4. 确认宿主部署的 UniGUI Web 资源和 Win64 BPL 均与 `1.90.0.1567` 基线匹配。
5. 功能按钮页父组/子按钮双向联动暂缓；后续通过浏览器事件参数捕获和 Ajax 时序日志专项恢复。
