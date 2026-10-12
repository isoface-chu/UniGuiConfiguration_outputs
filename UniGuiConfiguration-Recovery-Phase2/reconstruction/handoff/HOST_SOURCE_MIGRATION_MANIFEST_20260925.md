# 宿主源码迁移清单（旧宿主 → 新宿主）

更新时间：2026-09-25  
旧宿主：`D:\Projects\fastweb\UniGui Design Demo\Source\UniGuiClient`  
新宿主：`D:\Projects\fastweb\demo\Source\UniGuiClient`

## 用途与边界

本清单只记录恢复工作中**有文档证据**的宿主端改动，用于将这些改动逐项迁移到新宿主。

旧、新宿主不是同一代码基线的简单副本，许多同名单元已有大范围历史差异；没有可用的 Git 提交记录可还原完整演变。因此：

- 不得以整文件覆盖方式迁移；
- 只移植下表列出的功能片段或成组功能；
- 未列入表中的单元仅表示“没有找到明确的本次恢复改动记录”，并不表示两个版本相同；
- 每项迁移后都必须重新编译新宿主并在浏览器实际验证。

## 总览

| 优先级 | 功能包 | 单元 | 新宿主状态 | 建议 |
|---|---|---|---|---|
| P0 | 设计器右键菜单兼容 | `Design\ugDesign.pas` | 已迁移 | 保留并回归验证 |
| P1 | 报表设计器右键菜单兼容 | `Design\Report\ugReport.Design.pas` | 未迁移 | 仅移植对应事件处理片段 |
| P1 | 通用暂存导入 | `ExcelOperation\ugImportText.pas`、`ugImportExcel.pas`、`ugUnitImportStaging.pas` | 未迁移 | 作为一个原子功能包迁移 |
| P2 | Excel 文件上传入口 | `ExcelOperation\ugUnitExcelReader.pas`、`ugUnitExcelUpload.pas`、`UniGuiClient.dpr` | 未迁移 | 仅旧配置/脚本仍调用 `LoadUnitExcel` 时迁移 |

## 1. 设计器右键菜单兼容（已迁移）

### 单元

`Design\ugDesign.pas`

### 已迁移内容

`TUGDesignFrame.RefreshDCDisableMouseRightClick` 中的浏览器脚本不再直接依赖非标准 `e.path.forEach`，改为依次使用：

1. `e.composedPath()`；
2. 浏览器遗留的 `e.path`；
3. 从 `e.target` 向父节点回溯构建路径。

同时对路径元素、控件 ID 做空值与类型保护，并以完整 ID 匹配禁用右键的控件列表。

### 当前确认

新宿主的 `Design\ugDesign.pas` 已包含 `composedPath` 兼容逻辑；此项无需再次迁移。

### 回归

- 设计器中右键普通区域、控件区域；
- 浏览器控制台不再出现 `Cannot read properties of undefined (reading 'forEach')`；
- 禁止右键的设计控件仍按原规则生效。

## 2. 报表设计器右键菜单兼容（待迁移）

### 单元

`Design\Report\ugReport.Design.pas`

### 迁移范围

与第 1 项相同，只迁移报表设计器中安装 document `contextmenu` 处理器的那一段 JS 逻辑。不要复制整个单元，也不要改变设计器布局、报表属性或其它事件。

### 迁移前检查

- 在新宿主定位原有 `e.path.forEach` / `oncontextmenu` 逻辑；
- 对比新宿主类名、控件 ID 变量、字符串拼接方式；
- 若新宿主已有其它右键拦截机制，先确认两者的执行顺序。

### 验收

- 报表设计器右键不报 `undefined.forEach`；
- 设计器已有的禁用右键范围不扩大、不缩小；
- 打开、关闭、重复打开报表设计器正常。

## 3. 通用暂存导入（待迁移，必须成组）

### 涉及单元

- `ExcelOperation\ugImportText.pas`
- `ExcelOperation\ugImportExcel.pas`
- `ExcelOperation\ugUnitImportStaging.pas`（旧宿主新增；新宿主当前不存在）

### 已记录的功能

- 依暂存数据集的字段定义和列顺序读取文本数据，保留两列旧格式兼容；
- 共享 `StageImportValue` 统一处理字段存在性、字符串长度与 Memo；
- Excel 导入移除 `Name` / `ReMark` 的固定字段假设，沿用工作表映射和默认值；
- 失败时清空暂存，在原窗口的“错误”页呈现错误，保留窗口用于修正重试；
- 暂存窗口执行路径不使用阻塞式 `ShowMessage`；
- 旧式非暂存导入分支不属于本功能包，不应被顺带重写。

### 迁移方式

1. 先把 `ugUnitImportStaging.pas` 作为新单元加入新宿主工程；
2. 在新宿主版本的 `ugImportText.pas`、`ugImportExcel.pas` 中，只合并暂存导入相关代码；
3. 处理 uses、窗体字段名和新宿主已有 API 差异；
4. 编译通过后，分别验证文本与 Excel；
5. 如生成脚本仍使用旧接口，必须与配置 DLL 的生成逻辑一并核对。

### 特别注意

旧宿主的 `ugImportText.pas`、`ugImportExcel.pas` 曾由 CP936 机械转换为 UTF-8 BOM 后编辑。新宿主文件当前编码与旧文件可能不同；迁移时必须保持新宿主原编码，避免“无业务修改但全文件乱码/大差异”。

### 验收

- 两列旧格式导入仍正常；
- 多列、中文、空尾列、引号分隔字段、Memo 正常；
- 空内容、列数不符、字段不存在、长度超限时在错误页提示，可修正后重试；
- 嵌套导入窗口不出现 `Blocking method ShowMessage() can not be called here`；
- 取消、失败不残留半批数据；
- 旧式非暂存导入流程不回归。

## 4. Excel 文件上传入口（条件迁移）

### 涉及单元

- `ExcelOperation\ugUnitExcelReader.pas`（旧宿主新增；新宿主当前不存在）
- `ExcelOperation\ugUnitExcelUpload.pas`（旧宿主新增；新宿主当前不存在）
- `UniGuiClient.dpr`（需要显式引用）

### 判断是否需要迁移

先全局搜索新宿主及现存模块脚本是否调用 `LoadUnitExcel`：

- **存在调用**：本功能包为必迁移，否则模块会出现未声明入口或无法上传；
- **没有调用**：暂不迁移，避免引入旧版仅面向 `Name/ReMark` 两列上传面板的历史功能。

### 已记录的旧功能限制

上传 `.xls/.xlsx`，读取首个工作表，并只把文本填入导入面板；旧实现固定首行 `Name/ReMark`、最多 500 行、5 MB，拒绝公式、单元格内换行和 Tab。它不访问业务数据集，也不直接保存。

### 验收

- 仅在确认需要迁移后执行；
- `.xls`、`.xlsx`、中文、空备注、取消上传均正常；
- 错误表头、额外列、公式、超限文件被明确拒绝；
- 不影响当前通用暂存导入和普通导入。

## 不应因本清单自动迁移的内容

以下只是在此前分析、编译或运行中被引用/检查过，**没有找到明确的“本次恢复修改”证据**，不得仅据此从旧宿主覆盖到新宿主：

- `MainModule`、`ServerModule`；
- UniGUI 原生控件或第三方 BPL 单元；
- FastScript 注册及运行时单元；
- 各模板生成器 DLL 的源码。

它们如有差异，应按独立需求和实际调用链另行评估。

## 推荐执行顺序

1. 保留已迁移的 `ugDesign.pas` 修改；
2. 迁移并验证 `ugReport.Design.pas` 的同类右键兼容片段；
3. 若当前模块继续使用宿主导入窗口，再整体迁移“通用暂存导入”三单元；
4. 只有确认 `LoadUnitExcel` 仍有调用时，再迁移 Excel 上传入口；
5. 每一项独立提交/备份、单独编译、单独验收，便于回退。

## 证据文档

- `validation\WIZARD_DIALOG_CONTEXTMENU_20260912.md`
- `validation\NATIVE_GENERIC_IMPORT_FIX_20260911.md`
- `validation\MULTIPLE_NATIVE_IMPORT_BUILD.md`
- `validation\MULTIPLE_EXCEL_UPLOAD_BUILD.md`


---

## 附录 A（2026-09-25 补）：本清单之外、但**生成侧已经依赖**的旧宿主单元

本清单正文只列了"有明确迁移记录"的四组。下面这些单元同样是旧宿主独有（新宿主 `demo` 不存在），
而且**我们的生成器已经发射了对它们的引用**，因此优先级高于正文的 P1/P2，必须先评估再谈迁移：

| 单元（旧宿主） | 谁在依赖 | 新宿主影响 |
|---|---|---|
| `UniGuiClient\ugNullableTimePicker.pas`（类 `TUgDBTimePicker`） | `ugConfiguration.MasterSlaveTemplate.pas`、`ugConfiguration.ListEditorTemplate.pas` 的 `time` 字段控件类 | **新宿主没有这个类**：含 `time` 字段的模块在新宿主加载 DFM 会报类不存在。记录见 [MASTER_SLAVE_TIME_BUILD.md](../validation/MASTER_SLAVE_TIME_BUILD.md) |
| `UniGuiClient\ugNullableTimeValue.pas` | `TUgDBTimePicker` 的值解析（先解析后编辑、Null 与午夜 0 分离） | 同上；`tests\NullableTimeValueProbe.dpr` 直接编译它（钉在旧宿主） |
| `UniGuiClient\ugLookupPaging.pas`、`ugLookupPagingQuery.pas` | 查询窗体的窗口分页与纯 SQL 构造 | 新宿主不存在；`tests\test_lookup_paging.py`、`tests\LookupPagingQueryProbe.dpr` 钉在旧宿主；记录见 `WINDOWS_BUILD_REPORT.md` §… 与 [validation](../validation/) |

### 与本轮「mtListEditor 导入」相关的差异

新宿主**有** `ExcelOperation\ugImportText.pas`（4,881 字节 / 2023-04-25）与 `ugImportExcel.pas`（17,898 字节 / 2024-04-22），
但都是**未含暂存导入改进的旧版**（旧宿主对应文件 5,603 / 19,118 字节，2026-09-11）。所以：

- 生成器发出的 `UGMM.ImportText(gridMain, fs)` / `UGMM.ImpExcel(gridMain, Self.Caption, fe)` 在新宿主**能调到**（入口存在）；
- 但正文 P1 记录的那些改进（依暂存数据集字段定义读列、`StageImportValue` 统一校验、失败清空并留在错误页可修正重试、
  **不使用阻塞式 `ShowMessage`**）**不会生效**；
- 由此可能重现 [NATIVE_GENERIC_IMPORT_FIX_20260911.md](../validation/NATIVE_GENERIC_IMPORT_FIX_20260911.md) 里
  "嵌套导入窗口报 `Blocking method ShowMessage() can not be called here`" 这一类问题 —— 在新宿主上复测导入时需要重点看这一条。

## 附录 B（2026-09-25）：本轮把工具链路径切到新宿主

用户 2026-09-25 指定：宿主以 `D:\Projects\fastweb\demo` 为准，FastReport 目录为 `C:\VCL\FastReport\LibD26x64`。

| 项 | 结果 |
|---|---|
| FastReport 单元路径 | 9 个 `build-*.bat` + `UniGuiConfiguration.dproj` 的 `DCC_UnitSearchPath`：`C:\VCL-\FastReport\LibD26x64` → `C:\VCL\FastReport\LibD26x64`（新目录只有 .pas、没有 .dcu，探针改为从源码编译 FastScript，实测 0 错误） |
| 宿主源码/编译依赖 | `UniGuiConfiguration.dpr` / `.dproj` 早已指向 `demo`（含 `ugPublicObjectManagement.pas` 与 `Debugger_HostApplication`）；`tools\check_dfm_control_properties.py`、`host-test\build-paging.ps1` 也早已是 demo |
| 隔离断言 | `tests\test_recovery.py::test_build_output_is_isolated` 增加"输出目录不得是 `demo\bin64`"（旧宿主路径保留作历史防线） |
| JS 回归 | `dialog_layout_contextmenu`：`ugDesign.pas` 从 demo 读（已迁移）、`ugReport.Design.pas` 仍从旧宿主读（未迁移，正文 P1）；`grid_popup_alignment` / `wizard_locked_grid`：JS 与 Ext 运行时改指 `demo\bin64\library\...`，32 位对照件仍取旧宿主 `Bin\ThirdPartyLibrary\`（`demo` 无 `Bin`）；三个 JS 测试复跑通过 |
| 明确**钉在旧宿主**的测试 | `tests\NullableTimeValueProbe.dpr`、`tests\LookupPagingQueryProbe.dpr`、`tests\native_import_staging.test.py`、`tests\test_lookup_paging.py`（它们读/编译的是上表那些旧宿主独有的单元），已在文件头写明原因 |

### `ugPublicObjectManagement.pas` 接口差异（编译依赖，已实测）

新宿主的这个单元与旧宿主**不是同一版本**，接口有签名变更：

- `ApplyUpdatesCds`/`ApplyUpdatesCds1..6`、`ExecSql`：`procedure` → **`function ...: boolean`**；
- `GetWebSubForm(ACaption)` → `GetWebSubForm(ACaption, AMenuFlag, AType)`；`GetAppSubForm` 同理多两个参数；
- 新增 `ReadSession`、`BBWSLib_NotifytheClient`，`TGetSource` 增加 `gsBean`，uses 增加 `uBBClasses`。

DLL 已按**新宿主**版本编译通过（Debug/Release 0 错误）。注意：我们的**生成脚本**里
`UGMM.ApplyUpdatesCds(...)` / `UGMM.ExecSql(...)` 是当语句调用的，而新宿主它们是函数
（返回 Boolean）——Delphi 允许丢弃返回值，FastScript 是否同样允许**需要在宿主上实测**；
探针替身（`tests\MultipleScriptProbe.dpr` 等）目前仍按 procedure 注册，覆盖不到这个差异。
