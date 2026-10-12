# UniGuiConfiguration.dll 第一阶段恢复报告

## 结论

目标是 Delphi 原生 Win64 DLL，不是 .NET 程序集，因此不能用普通反编译器恢复成完整、原样的 Pascal 源码。编译器已经删除局部变量名、注释、源文件结构和大量高级语义；没有目标 DLL 对应的 MAP/RSM/DCU，无法做到逐字还原。

不过，重建所需的关键材料已经足够完整：导出协议、编译单元清单、全部窗体资源、JSON 配置样例、生成后的 DFM 与 PascalScript、宿主源码、数据库和准确编译环境均已具备。可行路线是“接口兼容重写”，并用现有 7 个样例做回归验证。

## 已确认的二进制信息

- Win64 文件：`UniGui Design Demo/bin64/UniGuiConfiguration.dll`
- 大小：1,810,944 bytes
- SHA-256：`676d1b8736dc7d2cfa06cfaf20a72e4ca1669e872e3ec3ec4a10b87a3f1704de`
- 文件版本：64.0.2.7
- 类型：PE32+ x86-64，Delphi 原生代码，使用运行时 BPL
- Win32 对照文件：1,282,560 bytes，版本 32.0.2.7
- 业务导出：`AddDllControl`、`DelDllControl`、`GetDllComponent`
- 编译环境：Delphi 10.3.3、UniGUI 1.90.0.1568、Win64

32/64 位 DLL 的 25 个 DFM 资源逐文件一致，说明 UI 与默认数据可作为稳定的重建基线。

## 已恢复内容

1. 从 `PACKAGEINFO` 准确解析出 36 个 Delphi 单元，其中 22 个是本 DLL 的业务/界面单元。
2. 提取 29 个 PE 资源，包括 `PACKAGEINFO`、版本、平台信息和 25 个二进制 DFM。
3. 将所有二进制 DFM 解码为可读文本 DFM 和结构化 JSON：共 236 个对象、77 个事件绑定。
4. 从 7 个生成样例的 `Codes.Strings`/`Events.Strings` 中恢复 3,754 行 PascalScript 和 115 条事件绑定。
5. 确认配置 JSON 的十个顶层区块：数据节点、模块类型、功能按钮、主表结构、从表结构、数据透视、查询条件和常规设置等。
6. 根据宿主源码确认 DLL ABI：宿主传入 `TGlobalVariable`，DLL 注册/注销控件，并通过 `GetDllComponent` 返回模块实例。
7. 建立了工程入口、模块路由与注册钩子的重建骨架。

## 功能结构

主向导 `TWebConfigurationModule` 依次组织以下页面：

1. 数据节点 `TWebDataNodeName`
2. 模块类型 `TWebModuletype`
3. 功能按钮 `TWebFunctionButton`
4. 主表数据结构 `TWebDataStructure`
5. 从表结构 `TWebDetailedStructure`
6. 数据透视 `TWebDataPerspective`
7. 查询条件 `TWebQueryCriteria`
8. 常规设置 `TWebNormalSetting`

辅助窗口还包括下拉选项、数据校验、字段选择、多选字段、唯一规则、自动编号、审批规则、查询条件批量添加和 JSON 查看器。

## 当前资料是否仍有遗漏

重写工作已经可以启动，没有新的硬性阻塞。若能找到，下列任一项会显著提高恢复速度和一致性：

- `UniGuiConfiguration` 原始 `.pas/.dfm/.dpr/.dproj` 或旧备份；
- 与目标 DLL 同次编译生成的 `.map`、`.rsm`、`.tds` 或本 DLL 自有 `.dcu`；
- 更多 JSON → DFM 生成样例，尤其覆盖下拉列表、数据校验、审批规则、自动编号、唯一字段、从表与数据透视的组合；
- 精灵运行过程的操作录像或每一步截图，以及输入 JSON、输出 DFM 的对应关系；
- 目标版本实际使用的第三方/自研 BPL 和 DCU 搜索路径清单。

这些材料缺失不会阻止兼容重写，但会影响对隐藏边界条件和原始实现细节的复现程度。

## 下一阶段

先实现可加载的主精灵和 JSON 读写，再按页面逐个恢复设置逻辑；最后实现 `GenerateRunFrame`，以 7 组现有样例进行结构化对比。验收应比较 DFM 对象树、组件属性、事件绑定和生成脚本的行为，而不要求文本字节完全相同。
