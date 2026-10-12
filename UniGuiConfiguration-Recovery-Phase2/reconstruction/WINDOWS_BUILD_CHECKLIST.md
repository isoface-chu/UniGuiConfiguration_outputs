# Windows 首次编译检查表

兼容基线：Delphi 10.3.3、Win64、UniGUI `1.90.0.1567`。

## 命令行编译

先运行 RAD Studio 10.3 的 `rsvars.bat`，再进入本目录执行：

```bat
msbuild UniGuiConfiguration.dproj /t:Build /p:Config=Debug /p:Platform=Win64 /v:minimal
```

若 IDE 的全局 Library Path 尚未配置 UniGUI/自研包，优先在 IDE 中打开工程编译，以沿用原宿主项目的环境配置。

## 错误处理顺序

1. `F1026 File not found`：补充宿主源码、UniGUI、`uIndy26`、`fs26` 的 Search/Library Path。
2. `E2003 Undeclared identifier` 且标识符是 UniGUI 类型：核对该版本的具体单元名，只调整 `uses`。
3. DFM `Error reading ...`：记录完整组件名和属性名；不要先删除 DFM 属性。
4. `Incompatible types` 出现在事件处理器：记录该事件的期望类型，修正对应方法签名。
5. DLL 编译完成后，将其与原 DLL 分目录保存，不要直接覆盖唯一副本。

## 宿主烟雾测试

1. DLL 能被 `LoadLibrary` 加载；
2. `AddDllControl`、`GetDllComponent`、`DelDllControl` 均能找到；
3. 宿主调用 `UGMM.GetDllComponent('UniGuiConfiguration>WebConfigurationModule', Owner)`，并确认返回非空组件；宿主解析 DLL 名后，DLL 导出层收到的组件名是 `WebConfigurationModule`；
4. 主向导能显示八个配置页；
5. 通过主向导的 `ConfigurationStream` 属性分别注入七个
   `fixtures/reference/*.json`；“查看 JSON”窗口按原 DFM 设计为只读，仅用于核对
   当前精灵生成结果，不作为 JSON 输入编辑器；
6. 保存后的 JSON 与输入做结构化比较；
7. 使用参考生成器加载对应 DFM，确认宿主能打开生成的 `TUgWebRunFrame`。

请保留首次编译的完整输出；第一条错误及其上下文通常比只提供最终错误数量更有价值。
