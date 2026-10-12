# 明细写入片（从表可编辑/主从写入）执行设计 —— 2026-09-20

> 本文是 `MTLISTEDITOR_BATCH4_PLAN_20260919.md` §9 的**执行附件**：§9 是"做什么/顺序"，本文是"改写哪几个函数、
> 生成的脚本长什么样"。上一轮失败的直接原因是拿 `tools/patch_write_slice_*.py` 按文本块切改生成器，
> 把 `btSaveOnClick` 的提交块切坏了。**本轮一律整函数替换**（先用 Read 看全函数，再用 Edit 换掉整个 body），
> 每步做完立刻过三绿门（见 §6）。

## 1. 目标语义（已定，不再讨论）

一次编辑会话提交主记录与明细：**原子提交**（`ApplyUpdatesCds(node,[cdsMain,cdsDetailed])`）+ **父键回填** +
**明细行号**（删除/复制后重排）+ **明细编号**（MaxInt 优先，可配 Guid）+ **从表唯一**在**当前主记录内**比较 +
**从表非空**按行号报错 + **不做级联删除**（删主记录时同事务删除它自己的明细，这是"属于该主记录的从表行"，
不算级联）；`DBAutoincrement` 主键 + 从表 → **明确拒绝**（提交前拿不到父键）。

## 2. 生成侧改动清单（文件 → 函数 → 整函数替换）

| # | 文件 | 函数 | 替换后的职责 |
|---|---|---|---|
| 1 | `ugConfiguration.ListEditorDetail.pas` | `AddListEditorDetailPanel` | 增参 `AWritable: Boolean`：可写时网格去 `dgEditing, ` 只读、加明细区工具条（`pDetailBar` + 三个按钮） |
| 2 | 同上 | `AddListEditorDetailScript` | 增参 `AWritable`：拆成"取数"(LEDetailLoad/LEDetailRefresh) 与"写入"(§3 骨架) 两段；写入段仅可写时生成 |
| 3 | 同上 | `AddListEditorDetailGuardEvents`（新增） | 明细数据集的 `BeforePost/BeforeDelete/BeforeScroll/BeforeClose` 守卫与 `cdsMain.AfterScroll` 联动绑定 |
| 4 | `ugConfiguration.ListEditorTemplate.pas` | `TryBuildListEditorTemplate` | ① 去掉"写模式 + 从表 → 拒绝"的分支；② `AddListEditorDetailPanel(..., WriteMode)`；③ 把 `DetailPlan` 传给 `AddListEditorInit`/写入生成器（已有参数位） |
| 5 | `ugConfiguration.ListEditorWrite.pas` | `AddListEditorWrite` 的提交/撤销/删除三块 | 提交改 `ApplyUpdatesCds(cDataNodeName,[cdsMain,cdsDetailed])`；撤销 `Cancel+CancelUpdates` 作用于两个数据集；删主记录改单事务脚本删明细+主表；四类分支与提示文案不变 |
| 6 | 同上 | `AddListEditorWrite` 的 `LERefresh` 块 | 明细分集也参与启用/禁用与 `Self.IsEditor` 收敛（明细只读时行为与现在一致） |

`TryPlanListEditorDetail` **不改**：`记录编号`（唯一字段）/编号方式（MaxInt/Guid/前缀/后缀/补位）/父键字段
的解析与拒绝（含 `DBAutoincrement`+从表）已在上一轮做完并有拒绝用例。**仍缺的解析**：`从表唯一`（字段列表）、
`从表非空`（字段列表）、`行号`字段名 → 一并加进 `TListEditorDetailPlan`（同一函数内补齐，仍属整函数替换）。

## 3. 生成的脚本骨架（新增/改动部分，名字沿用现有命名）

```pascal
{ —— 明细写入：取号 / 回填 / 校验 / 行号 —— }

// 明细编号：按明细表内 MaxInt 取号（Guid 时取 Guid；两者都提交前可知）
procedure LEDetailNextKey;
begin
  // MaxInt: select max(<编号字段>) from <从表>  → +1（保留 mtMasterSlave 的并发提示语义）
  // Guid  : UGMM.CreateGuid
end;

// 新增一行明细：取号 + 带父键（父键此刻可能还是空——新增主记录时先暂存，保存前统一回填）
procedure LEDetailAppendRow;
begin
  cdsDetailed.Append;  … 赋值取号结果 …
  cdsDetailed.Post;              // 行号与父键在 BeforePost 里统一处理
  if gridDetail.CanFocus then gridDetail.SetFocus;
end;

// 复制行：复制当前明细行的业务字段（不含编号与行号），编号重新取
procedure LEDetailCopyRow;
begin … end;

// 删除行：删当前行 → 重排行号
procedure LEDetailDeleteRow;
begin … end;

// 行号重排（删除/复制后调用；行号不参与从表唯一校验）
procedure LEDetailRenumber;
begin … end;

// 父键回填 + 行号 + 唯一/非空校验（明细数据集 BeforePost）
procedure LEDetailBeforePost(DataSet: TDataSet);
begin
  // 1) 父键：取 cdsMain 的「关联字段」值；主记录主键为空 → 保持暂存（父键留空，保存前 LEFillParentKeys 再补）
  // 2) 行号：若配置了行号字段，按当前行位置写入
  // 3) 从表唯一：在当前主记录范围内比较（同主记录内重复 → 报错并保留编辑态）
  // 4) 从表非空：空值 → 报错，提示带**明细第几行**
end;

// 保存前：把暂存明细的父键补齐（主记录取号完成后）
procedure LEFillParentKeys;
begin … end;
```

明细区的三个按钮与主工具条同构：

```pascal
procedure btDetailAppendOnClick(Sender: TObject);
begin
  if not btDetailAppend.Enabled then Exit;   // 与其它事件入口一致：程序化调用不绕过状态
  … LEDetailAppendRow …
end;
```

提交块（`btSaveOnClick` 的核心，保留现有四类分支）：

```pascal
  LEFillParentKeys;                                   // 先补父键
  if not UGMM.ApplyUpdatesCds(cDataNodeName, [cdsMain, cdsDetailed]) then …  // 提交失败 → 保留编辑态可重试
  // 提交成功 → 刷新；刷新失败**不重复提交**，提示"结果不确定先核实"
  // 撤销：cdsDetailed.Cancel + CancelUpdates; cdsMain.Cancel + CancelUpdates;
  // 删主记录：UGMM.ExecSqlSeparator(delete from <从表> where <关联从表>=:key; delete from <主表> where <主键>=:key)
```

## 4. 守卫与状态机（§9.9）

- 明细数据集挂 `BeforePost/BeforeDelete/BeforeScroll/BeforeClose`：`LEState` 允许的时机之外一律
  `RaiseException(UGMM.LT('请先保存或撤销当前编辑。'))`（复用 `LEGuard` 语义，不另造一套）。
- 切主记录/翻页/查询/关闭前有未保存明细改动 → 阻止并提示；新增主记录时明细可先暂存。
- 三个明细按钮的可用时机：`LEState <> 1`（未处于"编辑中"以外的时机收敛，与 `LERefresh` 同处收敛）。

## 5. 精灵侧（§9.11，**必须在生成侧之后**同批开）

`明细编号` / `从表唯一` / `从表非空` 的适用模块加 `mtListEditor`；新增 `复制行` 目录项（Editor Group，仅 mtListEditor）。
顺序理由：提前开会出现"配了不生效"的设置项（批次四只读片就是这么处理的）。
回归防线沿用 `tests/normal_setting_mtdetail_alignment.test.py` 的写法（钉住适用列表行本身）。

## 6. 每步的三绿门（不许跳）

1. `build-win64.bat` → 0 错误（用 `grep -a`，日志含 NUL）；
2. `build-list-editor-probes.bat` → 0 错误，且**探针退出码 0**（断言全过但退出码非 0 = 有缺陷，上一轮就是这么抓到的）；
3. 全量 `tests/*.py` 81 通过 / 0 失败 + `tests/test_recovery.py` 退出码 0。

任一步红：**先修再往下**，不要"先攒着一起看"。

## 7. 测试与运行 profile（§9.12）

- 生成契约：明细区三按钮存在且事件绑定、可写/只读两种模式的结构差异、父键回填与取号语句存在、
  提交块是 `ApplyUpdatesCds(node,[cdsMain,cdsDetailed])`、撤销同时作用于两个数据集、删主记录是单事务两步、
  `DBAutoincrement`+从表与"明细查找/多列下拉"被拒绝。
- 编译闸门：沿用 `MultipleScriptProbe <dfm> all list-editor-compile`。
- 运行 profile `list-editor-detail-write`：主记录 A(2 条明细)/B(1 条)/C(0 条)，覆盖新增行/删除行/复制行/
  行号重排/同主记录内唯一冲突/非空报错带行号/原子提交成功与失败/撤销回退/删主记录连明细。
- 对照 §8 的 E01–E18 逐项给结论（通过 / 未测，不允许含糊）。

## 8. 本轮明确不做

多表关联（用户已确认不需要）；除"删主记录连明细"之外的任何级联；明细导入（下一轮：文本/Excel → 当前主记录明细区）。
