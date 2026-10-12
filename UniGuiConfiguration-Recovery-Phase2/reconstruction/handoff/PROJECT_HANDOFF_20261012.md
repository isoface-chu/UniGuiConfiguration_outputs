# UniGuiConfiguration 恢复工程：项目交接总览

更新：2026-10-12  
适用对象：后续接手模型、开发人员与测试人员  
工作区：`D:\Projects\fastweb\outputs\UniGuiConfiguration-Recovery-Phase2\reconstruction`

## 1. 项目是什么

本项目是对原 `UniGuiConfiguration.dll` 的**行为兼容重建**：根据从原 DLL 提取的 DFM、原版生成脚本/JSON、宿主源码、自动化探针和宿主实测反馈，恢复“模块配置精灵”及其生成运行窗体的能力。

它不是原 DLL 的完整 Pascal 源码反编译。因此后续工作必须以“原版样例 + 当前生成产物 + 宿主实测”作为事实来源，不应凭模板名称推断原版功能。

## 2. 代码与运行环境

| 项目 | 位置/说明 |
|---|---|
| 重建工程 | `reconstruction\UniGuiConfiguration.dproj` / `UniGuiConfiguration.dpr` |
| 主要源码 | `reconstruction\src` |
| 自动测试 | `reconstruction\tests` |
| 原版样例 | `reconstruction\fixtures\reference` |
| 用户提供的专项样例 | `reconstruction\fixtures\list-editor`、`fixtures\mtdetail*` 等 |
| 交付 DLL | `reconstruction\deployment\<批次目录>\UniGuiConfiguration.dll` |
| 验证与故障记录 | `reconstruction\validation` |
| 旧宿主源码 | `D:\Projects\fastweb\UniGui Design Demo\Source\UniGuiClient` |
| 新宿主源码 | `D:\Projects\fastweb\demo\Source\UniGuiClient` |

宿主使用 Delphi 10.3.3、Win64、UniGUI 1.90.0.1567 的记录为主。生成脚本运行于 FastScript；不要假设 Delphi `SysUtils` 的所有函数都能直接调用。

## 3. 当前整体状态

### 已有明确宿主验收结论的模板/能力

| 范围 | 状态 | 已确认核心内容 |
|---|---|---|
| 配置精灵通用流程 | 分批验收通过 | 数据结构、从表结构、别名编辑与排序、功能按钮、常规设置、页面导航、弹窗恢复、中文名称、查询条件批量新增等已多轮修复 |
| `mtMasterSlave` | 按约定范围验收完工 | 主从查询/编辑/保存/撤销/删除、审批、下拉、权限、布局、导入/打印/附件、SweetAlert 等；保留边界见下文 |
| `mtMultiple` | 核心范围分批通过 | 查询、写回、连续新增、保存定位、校验失败保留编辑、多选删除、关联展示/写回、导入、分页定位等；数据透视由用户明确标为不实现 |
| `mtReport` | 本批验收通过 | 汇总/明细、查询、分组、分页、统一原打印入口、参数处理与界面布局；报表专属边界仍需按样例扩展 |
| `mtEditor` | 已恢复并作为公共编辑能力使用 | 控件类型、下拉、回填、校验、SweetAlert、必填焦点与标题等功能已接入 |
| `mtTree` | 本期验收通过 | 单根表树展示、编辑、移动、权限、打印附件、列布局隔离；后续需求另立项 |
| `mtDetail` | 本期验收通过（含部分未测边界） | 独立路由、主从界面、查询/导航、写操作、导入、从表校验、编号、布局与隐藏字段；完整矩阵见 `MTDETAIL_ACCEPTANCE.md` |

### `mtListEditor`：仍需作为当前重点交接

`mtListEditor` 是“同窗列表 + 顶部/侧边记录编辑区”的新模板，不依赖独立查询窗体或编辑窗体。基础浏览、查询区 Top/Left、查询区收缩、隐藏字段、记录区布局、读写、编号、权限、导出/打印/附件以及部分从表能力均已开发。

状态必须按批次区分：

- **已获宿主反馈通过**：基础同窗浏览/写入、查询区布局与收缩、隐藏字段、记录区布局与分组、审计与层级权限、输出（导出/打印/附件）、从表只读联动等。
- **本地回归通过但应优先宿主复测**：从表写入及其多轮修复、明细行 7 按钮、工具栏/图标/分隔线对齐、记录区布局移植到 `mtMasterSlave`、`btImport` 批量暂存导入。
- **仍未实现或需单独立项**：从其它模块/查询窗体多选记录后导入当前列表的模态桥；复杂多表写入、真实并发和更广泛数据库方言。

不要把“本地通过 / 宿主未测”写成“验收通过”。详见 `START_HERE.md` 顶部的 2026-09-19 至 2026-09-22 批次记录，以及 `MTLISTEDITOR_BATCH4_PLAN_20260919.md`。

## 4. 模板路由与代码地图

| 模板/职责 | 主要源码 |
|---|---|
| DLL 入口、注册、调用 | `src\ugRegDllControl.pas`、`ugCallModular.pas`、工程 `.dpr` |
| JSON/配置模型 | `ugConfiguration.Document.pas`、`DataSetJson.pas`、`ugWebConfigurationBase.pas` |
| 配置精灵控制器 | `ugWebConfigurationModule.pas` |
| 数据结构、从表、别名 | `ugWebConfiguration.DataStructure*`、`DetailedStructure*`、`ugConfiguration.TableAlias.pas` |
| 查询条件、数据透视、常规设置、下拉配置 | `QueryCriteria*`、`DataPerspective*`、`NormalSetting*`、`DropDownOptions*`、`DataCheck*` |
| 生成入口与安装桥 | `ugWebConfigurationModule.GenerateRunFrame.pas` |
| 通用编辑模板 | `ugConfiguration.EditTemplate.pas` |
| 多表/报表 | `MultipleTemplate.pas`、`MultipleQueryControls.pas`、`MultipleRecord.pas`、`MultipleJoins.pas`、`MultiplePresentation.pas`、`ReportPlan.pas`、`Report*.inc` |
| 主从 | `MasterSlaveTemplate.pas`、`DetailLookupBridge.pas` |
| 树 | `TreePlan.pas`、`TreeTemplate.pas`、`TreeWrite.pas`、`TreeMove.pas`、`TreeAccess.pas`、`TreePresentation.pas`、`TreeScriptLayout.pas` |
| 明细模板 | `DetailPlan.pas`、`DetailTemplate.pas` |
| 同窗列表编辑器 | `ListEditor*.pas`、`ListEditorLayout.pas`，以及与 Multiple/编辑模板复用的控件与布局代码 |

路由原则：`mtMultiple`/`mtReport` 走 Multiple 体系，`mtTree` 走 Tree 体系，`mtMasterSlave` 走主从体系，`mtDetail` 必须显式走 `DetailPlan/DetailTemplate`；不能让 `mtDetail` 回退到普通编辑模板。

## 5. 已固定的公共行为

- 生成脚本初始化签名固定为：`procedure UgWebRunFrameOnAfterRunScript(const sender: tobject);`。
- 普通事件签名使用 `Sender: TObject`；不要再新增 `Safe` 前缀事件名，事件绑定与过程名必须一致。
- 用户可见提示、确认、输入、错误尽量统一由 `TUgSweetAlert` 实现；校验失败后需把焦点放回实际必填控件，并使用控件标题而不是字段物理名提示。
- 生成脚本抛出面向用户的异常时，用 `UGMM.LT(...)` 做多语言处理。
- DFM 属性区不可直接输出非 ASCII 中文；需按 DFM 文本编码规则生成（避免设计器中文乱码）。
- 非可视控件也必须有设计期位置，避免设计器左上角重叠；运行窗体中的非可视对象布局参照 `mtMasterSlave`。
- 隐藏字段应区分“不能生成控件”和“因脚本仍有引用必须生成后 `Visible=False`”两种情形，不能一律省略。
- `Upper/Lower` 只影响普通人工文本输入；下拉选值和用于数据库匹配的保存值不能被错误转换。
- 向导弹窗、精灵重新打开/完成、关闭销毁都属于回归项；曾出现空白窗、错误销毁顺序和 JSON 所有权泄露，不得删减生命周期保护。

## 6. 关键技术陷阱

1. **FastScript 不是完整 Delphi RTL。** 例如 `IntToHex` 曾在运行脚本中未声明；生成脚本应先过 FastScript 编译闸门。
2. **数据集事件时机敏感。** 明细网格未提交行、校验失败、滚动重载、保存/撤销之间可能丢失用户输入；避免无条件 `AfterScroll` 重载覆盖脏明细。
3. **UniGUI 嵌套模态不能用阻塞 API。** 导入/明细编辑过程中使用 `ShowMessage` 或 `SweetAlert.Execute` 可能出现 `Blocking method ... can not be called here`；改用非阻塞提示/错误页并让用户继续修正。
4. **配置弹窗的 ExtJS 布局可能折叠内层窗体。** 不要引入全局布局补丁；只对目标窗口恢复内容尺寸，并验证重复开关和销毁。
5. **编码必须保留。** 宿主旧代码中既有 CP936 也有 UTF-8 BOM；不能因局部修复造成整文件编码变更和无关大差异。
6. **权限不可仅过滤界面。** 层级权限、行权限必须在查询与写回/删除时均复核；管理员不应被隐式豁免，除非原版证据或用户明确要求。
7. **分页定位。** 保存、修改或新增后定位记录需同时考虑排序与跨页；查询空结果要清空顶部记录区。
8. **JSON 所有权。** 临时数据集或异常读取 JSON 行必须明确释放，避免精灵多次打开/保存累积泄露。

## 7. 宿主源码迁移状态

恢复工程与宿主源码是两条交付线，不能混为一谈。

- 新宿主 `demo\Source\UniGuiClient\Design\ugDesign.pas` 已合并设计器右键菜单兼容修复。
- `Design\Report\ugReport.Design.pas` 的同类修复尚未迁移。
- 通用暂存导入需要整体迁移 `ugImportText.pas`、`ugImportExcel.pas`、新增 `ugUnitImportStaging.pas`；新宿主当前缺新增单元。
- Excel 上传入口只在仍有脚本调用 `LoadUnitExcel` 时迁移。

详情、范围与验收清单见 `HOST_SOURCE_MIGRATION_MANIFEST_20260925.md`。旧、新宿主不是同一基线，**禁止整文件覆盖**。

## 8. 已知保留边界

以下不能因为主体功能通过而视为已完全兼容：

- `SeqUence` 自动编号：现有 SQLite 样本不可运行，保持暂缓；不可用 MaxCode 模拟替代。
- Catalog/Schema：按原版保持禁用，不作为当前支持能力。
- 多数据库方言、Oracle、保留字/特殊标识符、大数据量、并发取号等只做有限验证或未测。
- `mtMultiple` 数据透视：用户明确决定不实现。
- `mtDetail` 的组头、复杂下拉联动、并发、个别查询窗体双击回传等有部分未测项；以 `MTDETAIL_ACCEPTANCE.md` 的 D01–D25 矩阵为准。
- `mtListEditor` 后期从表写入、导入、按钮及视觉对齐功能需要优先宿主回归，不能仅凭自动测试归档。

## 9. 推荐接手顺序

1. 阅读本文件、`START_HERE.md` 与涉及模板的验收文档，先确认目标是“修缺陷、宿主迁移”还是“新增模板”。
2. 若继续 `mtListEditor`，先用 2026-09-20 至 2026-09-22 最新 DLL/配置做宿主回归，再处理新缺陷；不要从早期包重新开始。
3. 若迁移宿主，按 `HOST_SOURCE_MIGRATION_MANIFEST_20260925.md` 的 P0→P2 顺序，每项独立备份、编译、浏览器验证。
4. 若新增模板，先收集原版 DFM、JSON、生成脚本与实际运行截图，写出能力矩阵，再创建独立 Plan/Template/Probe；不要直接复制 `mtMasterSlave`。
5. 每轮最少完成：Debug/Release 构建、DFM 解析、生成脚本 FastScript 编译、相关探针/回归，并将“本地通过”和“用户宿主通过”分开记录。

## 10. 必读资料

| 文档 | 用途 |
|---|---|
| `handoff\START_HERE.md` | 历史批次、当前模板状态、路径总入口 |
| `handoff\DEVELOPMENT_HISTORY.md` | 架构演变和常见坑 |
| `handoff\MTLISTEDITOR_HANDOFF_20260918.md` | mtListEditor 基础设计与第一轮能力 |
| `handoff\MTLISTEDITOR_BATCH4_PLAN_20260919.md` | mtListEditor 从表、写入、导入等后续批次详情 |
| `handoff\HOST_SOURCE_MIGRATION_MANIFEST_20260925.md` | 旧/新宿主源码迁移范围 |
| `validation\MASTER_SLAVE_FINAL_ACCEPTANCE.md` | 主从模板最终验收边界 |
| `validation\MTDETAIL_ACCEPTANCE.md` | mtDetail D01–D25 能力与未测矩阵 |
| `validation\MULTIPLE_NEXT_ACCEPTANCE.md` | mtMultiple 历史范围与明确不实现项 |

## 11. 交接结论

项目的主干恢复已完成，多个成熟模板已有用户验收基线。后续最稳妥的工作不是大范围重构，而是：

1. 对 `mtListEditor` 近期本地通过功能做宿主回归；
2. 按清单迁移确有需要的宿主修复；
3. 对新的模板或新功能先建立原版证据和验收矩阵，再增量实施。

任何未列入上述已验收范围的能力，都应先视为“待核对”，而不是默认已支持。

