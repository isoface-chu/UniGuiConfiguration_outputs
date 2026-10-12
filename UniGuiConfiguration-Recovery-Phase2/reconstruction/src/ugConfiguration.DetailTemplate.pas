unit ugConfiguration.DetailTemplate;

interface

uses System.SysUtils, System.Classes, System.JSON;

// Generates the mtDetail run frame (main-record field panel + detail grid)
// from an mtDetail configuration. Returns False and an accurate Reason for
// configurations this batch cannot generate faithfully; it never silently
// drops a setting.
function TryBuildDetailTemplate(Config: TJSONObject; out DFM,
  Reason: string): Boolean;

implementation

uses ugConfiguration.DetailPlan;

function Obj(J: TJSONObject; const K: string): TJSONObject;
var V: TJSONValue;
begin
  Result := nil; if J = nil then Exit; V := J.GetValue(K);
  if V is TJSONObject then Result := TJSONObject(V);
end;

function Str(J: TJSONObject; const K: string): string;
var V: TJSONValue;
begin
  Result := ''; if J = nil then Exit; V := J.GetValue(K);
  if Assigned(V) and not (V is TJSONNull) then Result := V.Value;
end;

function Yes(const S: string): Boolean;
begin
  Result := SameText(S, 'True') or (S = '1') or (S = '-1');
end;

// DFM string literal: escapes quotes and non-ASCII so ObjectTextToBinary does
// not depend on the active code page.
function Q(const S: string): string;
var C: Char;
begin
  Result := '''';
  for C in S do
    if (Ord(C) < 32) or (Ord(C) > 126) then
      Result := Result + '''#' + IntToStr(Ord(C)) + ''''
    else if C = '''' then Result := Result + ''''''
    else Result := Result + C;
  Result := Result + '''';
end;

// 'alias.F1, alias.F2' for SQL SELECT / grid wiring.
function SqlList(const Alias: string; Fields: TStringList): string;
var I: Integer;
begin
  Result := '';
  for I := 0 to Fields.Count - 1 do
  begin
    if I > 0 then Result := Result + ', ';
    Result := Result + Alias + '.' + Fields[I];
  end;
end;

function TypeOf(Fields, Types: TStringList; const FieldName: string): string;
var I: Integer;
begin
  Result := '';
  I := Fields.IndexOf(FieldName);
  if (I >= 0) and (I < Types.Count) then Result := Types[I];
end;

function ControlClass(const ObjectType: string): string;
begin
  if SameText(ObjectType, 'number') then Result := 'TUgDBNumberEdit'
  else if SameText(ObjectType, 'datetime') then Result := 'TUgDBDateTimePicker'
  else if SameText(ObjectType, 'check') then Result := 'TUgDBCheckBox'
  else if SameText(ObjectType, 'memo') then Result := 'TUgDBMemo'
  else Result := 'TUgDBEdit';
end;

// 原版 mtDetail 主表只读面板的单元格高度：多行/勾选控件按类型缩短，
// 其余（edit/number/datetime）统一 50。
function ControlHeight(const ObjectType: string): Integer;
begin
  if SameText(ObjectType, 'check') then Result := 25
  else if SameText(ObjectType, 'memo') then Result := 170
  else Result := 50;
end;

// Visible = selected minus hidden, preserving configuration order.
function VisibleOf(Selected, Hidden: TStringList): TStringList;
var I: Integer;
begin
  Result := TStringList.Create;
  for I := 0 to Selected.Count - 1 do
    if Hidden.IndexOf(Selected[I]) < 0 then Result.Add(Selected[I]);
end;

function CaptionOf(Fields, Captions: TStringList; const FieldName: string): string;
var I: Integer;
begin
  Result := FieldName;
  I := Fields.IndexOf(FieldName);
  if (I >= 0) and (I < Captions.Count) then Result := Captions[I];
end;

function TryBuildDetailTemplate(Config: TJSONObject; out DFM,
  Reason: string): Boolean;
const
  CButtons: array[0..14] of string = ('btQuery', 'btFirst', 'btPrior', 'btNext',
    'btLast', 'btAppend', 'btDelete', 'btEditor', 'btImport', 'btSave',
    'btCancel', 'btExport', 'btPrint', 'btAnnex', 'btClose');
  CCaptions: array[0..14] of string = ('查询', '首项', '前项', '后项', '尾项',
    '新增', '删除', '修改', '导入', '保存', '撤销', '导出', '打印', '附件', '关闭');
  CIcons: array[0..14] of Integer = (0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 16, 17, 18, 23);
  CGroupOf: array[0..14] of string = ('', 'tabNoniusGroup', '', '', '',
    'tabEditorGroup', '', '', '', 'tabAppendUpdateGroup', '', 'tabOutputGroup',
    '', 'tabAnnexGroup', 'tabFormGroup');
  CButtonOrder: array[0..14] of string = ('btQuery', 'btFirst', 'btPrior',
    'btNext', 'btLast', 'btAppend', 'btDelete', 'btEditor', 'btImport',
    'btSave', 'btCancel', 'btExport', 'btPrint', 'btAnnex', 'btClose');
  // 原版 mtDetail 主表只读面板：固定高 190、列步进 210、单元格宽 200。
  CPanelHeight = 190;
  CColumnStep = 210;
var
  Plan: TDetailPlan;
  Code, Lines, MainVisible, DetailVisible, Editable: TStringList;
  I, X, Col, NextTop, Height, FrameWidth, PanelCols: Integer;
  F, Cap, Cls, CtlName, Options, SQLPrefix, CompareParams, ExclusionField,
    AppendArgs, EditArgs, FilterAdds, BackendAdds, ImportFields, ImportCaptions,
    UniqueLabel: string;
  HasFilter, HasColumns, HasCopy, HasMulti, HasSort: Boolean;
  HasNotice, HasConfirm, HasError: Boolean;
  SortMode: string;
  Bound: Integer;
  function Fail(const S: string): Boolean;
  begin Reason := S; Result := False; end;
  procedure A(const S: string);
  begin Code.Add(S); end;
  procedure L(const S: string);
  begin Lines.Add(S); end;
  // 参照 mtMasterSlave：把操作入口包在 try/except 中，异常统一用 SweetAlert 提示
  procedure WrapAction(const AName: string);
  var I, J: Integer;
  begin
    for I := 0 to Code.Count - 1 do
      if (Pos('Procedure ' + AName + '(', Code[I]) = 1) or
        (Pos('procedure ' + AName + '(', Code[I]) = 1) then
      begin
        J := I + 1;
        while (J < Code.Count) and (Code[J] <> 'begin') and (Code[J] <> 'Begin') do Inc(J);
        if J >= Code.Count then Exit;
        Code.Insert(J + 1, '  try');
        while (J < Code.Count) and (Code[J] <> 'end;') and (Code[J] <> 'End;') do Inc(J);
        if J < Code.Count then
        begin
          Code[J] := '  except ShowActionError(ExceptionMessage); end;';
          Code.Insert(J + 1, 'end;');
        end;
        Exit;
      end;
  end;
  // 编辑窗体只承载可编辑字段，其余字段不能取编辑窗体变量。
  function IsEditableField(const AField: string): Boolean;
  var K: Integer;
  begin
    Result := False;
    for K := 0 to Editable.Count - 1 do
      if SameText(Editable[K], AField) then Exit(True);
  end;
  // 从表非空字段：与 mtMasterSlave 一致，网格列标题标红。
  function IsRequiredField(const AField: string): Boolean;
  var K: Integer;
  begin
    Result := False;
    for K := 0 to Plan.RequiredDetailFields.Count - 1 do
      if SameText(Plan.RequiredDetailFields[K], AField) then Exit(True);
  end;
  // 从表唯一比较字段取值：编辑窗体字段取编辑窗体变量；关联从表取主表当前键值
  // （cdsDetailedBeforePost 同样用它回填）；其余从表字段未参与编辑，新增时按空值、
  // 修改时取当前行原值。
  function CompareArgOf(const AField: string; AAppend: Boolean): string;
  begin
    if IsEditableField(AField) then
      Result := 'VarToStr(TUgWebRunFrame(F.RunFrame).GetValue(' + QuotedStr('v' + AField) + '))'
    else if SameText(AField, Plan.DetailKeyField) then
      Result := 'VarToStr(cdsMain.FieldByName(' + QuotedStr(Plan.MainKeyField) + ').AsVariant)'
    else if AAppend then
      Result := QuotedStr('')
    else
      Result := 'VarToStr(cdsDetailed.FieldByName(' + QuotedStr(AField) + ').AsVariant)';
  end;
  function ButtonCaption(const Name: string): string;
  var K: Integer;
  begin
    Result := Name;
    for K := Low(CButtons) to High(CButtons) do
      if CButtons[K] = Name then begin Result := CCaptions[K]; Exit; end;
  end;
  function ButtonIcon(const Name: string): Integer;
  var K: Integer;
  begin
    Result := 0;
    for K := Low(CButtons) to High(CButtons) do
      if CButtons[K] = Name then begin Result := CIcons[K]; Exit; end;
  end;
  function ButtonGroup(const Name: string): string;
  var K: Integer;
  begin
    Result := '';
    for K := Low(CButtons) to High(CButtons) do
      if CButtons[K] = Name then begin Result := CGroupOf[K]; Exit; end;
  end;
  function IsMenuButton(const Name: string): Boolean;
  begin
    Result := SameText(Name, 'btImport') or SameText(Name, 'btPrint');
  end;
  // 原版菜单按钮（导入/打印）宽 75，普通按钮 60；按钮位置按“实际宽度 + 6”递进。
  function ButtonWidth(const Name: string): Integer;
  begin
    if IsMenuButton(Name) then Result := 75 else Result := 60;
  end;
  // 主表只读面板的列数（与真实排布同一规则：列优先、放不下换列）。
  // 原版线框宽度取 max(1069, 10 + 列数×210)：category 4 列 → 1069，16 字段 6 列 → 1270。
  function MainPanelColumns: Integer;
  var K, T, H: Integer;
  begin
    Result := 1; T := 10;
    for K := 0 to MainVisible.Count - 1 do
    begin
      H := ControlHeight(TypeOf(Plan.MainFields, Plan.MainTypes, MainVisible[K]));
      if (T + H > CPanelHeight - 10) and (T > 10) then
      begin
        Inc(Result); T := 10;
      end;
      Inc(T, H + 10);
    end;
  end;
  procedure EmitButton(const Name: string; AX: Integer);
  begin
    if IsMenuButton(Name) then L('    object ' + Name + ': TUgMenuButton')
    else L('    object ' + Name + ': TUgButton');
    L('      AlignWithMargins = True');
    L('      Left = ' + IntToStr(AX));
    L('      Top = 3');
    if IsMenuButton(Name) then L('      Width = 75') else L('      Width = 60');
    L('      Height = 26');
    L('      Hint = ''''');
    L('      Caption = ' + Q(ButtonCaption(Name)));
    L('      Align = alLeft');
    L('      TabOrder = 0');
    L('      Images = Imgs');
    L('      ImageIndex = ' + IntToStr(ButtonIcon(Name)));
    L('      AutoWidth = True');
    L('    end');
  end;
  procedure EmitGroup(const Name: string; AX: Integer);
  begin
    L('    object ' + Name + ': TUgContainerPanel');
    L('      AlignWithMargins = True');
    L('      Left = ' + IntToStr(AX));
    L('      Top = 5');
    L('      Width = 1');
    L('      Height = 22');
    L('      Hint = ''''');
    L('      Margins.Top = 5');
    L('      Margins.Bottom = 5');
    L('      ParentColor = False');
    L('      Color = 13093060');
    L('      Align = alLeft');
    L('      TabOrder = 0');
    L('    end');
  end;
begin
  DFM := '';
  Result := False;
  Reason := '';
  if not TryReadDetailPlan(Config, Plan, Reason) then Exit;
  try
    MainVisible := VisibleOf(Plan.MainSelected, Plan.HiddenMainFields);
    DetailVisible := VisibleOf(Plan.DetailSelected, Plan.HiddenDetailFields);
    Editable := TStringList.Create;
    try
      if MainVisible.Count = 0 then
        Exit(Fail('主表显示字段全部被隐藏，请至少保留一个可见字段。'));
      if DetailVisible.Count = 0 then
        Exit(Fail('从表显示字段全部被隐藏，请至少保留一个可见字段。'));
      for I := 0 to Plan.EditableFields.Count - 1 do
        Editable.Add(Plan.EditableFields[I]);

      // Capability diagnostics: refuse rather than silently degrade.
      if (Plan.HasButton('btAppend') or Plan.HasButton('btEditor')) and
        (Trim(Plan.EditorFrame) = '') then
        Exit(Fail('新增/修改需要配置编辑窗体。'));
      if Plan.HasButton('btQuery') and (Trim(Plan.QueryFrame) = '') then
        Exit(Fail('查询按钮需要配置查询窗体。'));
      if (Plan.ImportCaptions.Count > 0) and not Plan.HasButton('btImport') then
        Exit(Fail('配置「导入窗体」需要启用导入按钮（入口在导入下拉菜单中）。'));
      if (Plan.NumberField <> '') and (Plan.NumberKind = dnkNone) then
        Exit(Fail('记录编号缺少编号方式（cbAutoNumberType）。'));
      if (Plan.NumberField <> '') and (Plan.NumberKind <> dnkGuid) and
        (Plan.NumberKind <> dnkDateTimeRandom) and
        (Plan.NumberKind <> dnkDBAutoincrement) then
        Exit(Fail('记录编号方式 ' + Plan.NumberKindText +
          ' 原版 mtDetail 不支持（仅 Guid / DateTimeRandom / DBAutoincrement）。'));

      SortMode := Trim(Str(Obj(Config, 'TWebNormalSetting'), '字段排序'));
      HasSort := SameText(SortMode, 'ColumnSort') or SameText(SortMode, 'MultiColumnSort');
      { 引用明细要用 ShowNotice 回报「哪些字段因来源没有同名列而未复制」，
        所以配了导入窗体的 mtDetail 即使没有保存按钮也要声明提示例程。 }
      HasNotice := Plan.HasButton('btSave') or (Plan.ImportCaptions.Count > 0);
      HasConfirm := Plan.HasButton('btDelete') or Plan.HasButton('btCancel') or
        Plan.HasButton('btClose');
      HasError := Plan.HasButton('btAppend') or Plan.HasButton('btEditor') or
        Plan.HasButton('btDelete') or Plan.HasButton('btSave') or
        Plan.HasButton('btCancel') or Plan.HasButton('btImport') or
        Plan.HasButton('btAnnex');
      HasFilter := Yes(Str(Obj(Config, 'TWebNormalSetting'), '表格过滤'));
      HasColumns := Yes(Str(Obj(Config, 'TWebNormalSetting'), '字段宽度')) or
        Yes(Str(Obj(Config, 'TWebNormalSetting'), '字段移动')) or
        Yes(Str(Obj(Config, 'TWebNormalSetting'), '字段显隐'));
      HasCopy := Yes(Str(Obj(Config, 'TWebNormalSetting'), '表格复制'));
      HasMulti := Yes(Str(Obj(Config, 'TWebNormalSetting'), '表格多选'));

      // 从表唯一在修改时要排除当前行自身：优先用配置的记录字段；未配置时用
      // 从表记录编号（主键）兜底；两者都没有则无法标识自身，修改时不做提前校验。
      ExclusionField := Plan.UniqueRecordField;
      if (ExclusionField = '') and (Plan.NumberField <> '') and
        (Plan.DetailFields.IndexOf(Plan.NumberField) >= 0) then
        ExclusionField := Plan.NumberField;

      Code := TStringList.Create;
      Lines := TStringList.Create;
      try
        SQLPrefix := 'select ' + SqlList(Plan.MainAlias, Plan.MainFields) +
          ' from ' + Plan.MainTable + ' ' + Plan.MainAlias + ' where ' +
          Plan.MainAlias + '.' + Plan.MainKeyField + ' = ';

        A('//定义全局常量');
        A('Const');
        A('  //数据节点');
        A('  cDataNodeName   = ' + QuotedStr(Plan.DataNodeName) + ';');
        A('  cDataNodeDriver = UGMM.GetNodeNameByDriver(cDataNodeName);');
        A('  //编辑窗体');
        A('  cEditorFrame = ' + QuotedStr(Plan.EditorFrame) + ';');
        A('  //查询窗体');
        A('  cQueryFrame = ' + QuotedStr(Plan.QueryFrame) + ';');
        A('  //从表空白行数');
        A('  cBlankLineCount = 20;');
        A('  //浏览状态');
        A('  tyView   = 0;');
        A('  //编辑状态【添加、编辑】');
        A('  tyEditor = 1;');
        A('  //获取导航类型');
        A('  tyFirst  = 1;');
        A('  tyPrior  = 2;');
        A('  tyNext   = 3;');
        A('  tyLast   = 4;');
        A('  tyAppend = 5;');

        // ---- RefState ----
        A('//刷新按钮状态');
        A('Procedure RefState(Const AValue:Integer);');
        A('Begin');
        if Plan.HasButton('btQuery') then
        begin
          A('  //查找功能');
          A('  btQuery.Enabled   := cdsDetailed.ChangeCount = 0;');
        end;
        A('  //游标状态');
        for I := 1 to 4 do
        begin
          F := CButtonOrder[I];
          if Plan.HasButton(F) then
            A('  ' + F + '.Enabled   := cdsDetailed.ChangeCount = 0;');
        end;
        A('  //编辑功能');
        if Plan.HasButton('btAppend') then
          A('  btAppend.Enabled  := (AValue = tyView)and(cdsDetailed.Active)And(cdsMain.RecordCount > 0);');
        if Plan.HasButton('btDelete') then
          A('  btDelete.Enabled  := (AValue = tyView)and(Not cdsDetailed.IsEmpty);');
        if Plan.HasButton('btEditor') then
          A('  btEditor.Enabled  := (AValue = tyView)and(Not cdsDetailed.IsEmpty);');
        if Plan.HasButton('btImport') then
          A('  btImport.Enabled  := (AValue = tyView)and(cdsDetailed.Active)And(cdsMain.RecordCount > 0);');
        A('  //保存功能');
        if Plan.HasButton('btSave') then
          A('  btSave.Enabled    := (AValue = tyEditor)or(cdsDetailed.ChangeCount > 0);');
        if Plan.HasButton('btCancel') then
          A('  btCancel.Enabled  := (AValue = tyEditor)or(cdsDetailed.ChangeCount > 0);');
        A('  //输出功能');
        if Plan.HasButton('btExport') then
          A('  btExport.Enabled  := (AValue = tyView)and(cdsDetailed.Active);');
        if Plan.HasButton('btPrint') then
          A('  btPrint.Enabled   := (AValue = tyView);');
        if Plan.HasButton('btAnnex') then
          A('  btAnnex.Enabled   := (AValue = tyView);');
        A('  //数据集');
        A('  dsMain.AutoEdit     := AValue = tyEditor;');
        A('  dsDetailed.AutoEdit := AValue = tyEditor;');
        A('  //表单状态');
        A('  gridDetailed.ReadOnly := AValue = tyView;');
        A('  //编辑状态');
        A('  Self.IsEditor     := (AValue = tyEditor)or(cdsDetailed.ChangeCount > 0);');
        A('  //验证模块权限');
        A('  UGMM.VerifyRunFramePerm(Self);');
        A('End;');
        if HasError then
        begin
          A('//操作入口统一显示异常，内部校验仍通过异常中止当前操作');
          A('procedure ShowActionError(const AMessage: string);');
          A('begin');
          A('  errorAlert.TitleText := UGMM.LT(''操作未完成'');');
          A('  errorAlert.ConfirmButtonText := UGMM.LT(''确定'');');
          A('  errorAlert.Show(AMessage);');
          A('end;');
          A('//编辑校验失败时先等待提示确认，再重新进入编辑模态循环');
          A('procedure WaitEditorError(const AMessage: string);');
          A('begin');
          A('  errorAlert.TitleText := UGMM.LT(''请修改后重试'');');
          A('  errorAlert.ConfirmButtonText := UGMM.LT(''确定'');');
          A('  errorAlert.Text := AMessage;');
          A('  errorAlert.Execute;');
          A('end;');
        end;
        if HasNotice then
        begin
          A('//使用非阻塞SweetAlert显示普通提示，不承担确认或异常控制流');
          A('procedure ShowNotice(const AMessage: string);');
          A('begin');
          A('  noticeAlert.TitleText := UGMM.LT(''提示'');');
          A('  noticeAlert.ConfirmButtonText := UGMM.LT(''确定'');');
          A('  noticeAlert.Show(AMessage);');
          A('end;');
        end;
        if HasConfirm then
        begin
          A('//同步确认：取消、ESC或关闭均不继续业务操作');
          A('function ConfirmAction(const AMessage: string): Boolean;');
          A('begin');
          A('  confirmAlert.TitleText := UGMM.LT(''请确认'');');
          A('  confirmAlert.Text := UGMM.LT(AMessage);');
          A('  confirmAlert.ConfirmButtonText := UGMM.LT(''确定'');');
          A('  confirmAlert.CancelButtonText := UGMM.LT(''取消'');');
          A('  Result := confirmAlert.Execute;');
          A('end;');
        end;

        // ---- record number ----
        if (Plan.NumberField <> '') and
          ((Plan.NumberKind = dnkGuid) or (Plan.NumberKind = dnkDateTimeRandom)) then
        begin
          Bound := 99999;
          if (Plan.NumberDigits >= 1) and (Plan.NumberDigits <= 9) then
          begin
            Bound := 1;
            for I := 1 to Plan.NumberDigits do Bound := Bound * 10;
            Dec(Bound);
          end;
          A('//获取记录编号');
          A('Function GetAuotNumber:String;');
          if Plan.NumberKind = dnkDateTimeRandom then
          begin
            A('Const');
            A('  cPrefix        = ' + QuotedStr(Plan.NumberPrefix) + ';');
            A('  cDigitCapacity = ' + QuotedStr(IntToStr(Plan.NumberDigits)) + ';');
            A('  cSuffix        = ' + QuotedStr(Plan.NumberSuffix) + ';');
            A('var');
            A('  c : TUgClientdataSet;');
            A('begin');
            A('  Result := cPrefix + FormatDateTime(''yyyyMMddhhmmsszzz'',now) + IntToStr(RandomInt(' +
              IntToStr(Bound) + ')) + cSuffix');
            A('end;');
          end
          else
          begin
            A('begin');
            A('  Result := UGMM.CreateGuid;');
            A('end;');
          end;
        end;

        // ---- detail uniqueness ----
        if Plan.UniqueCompareFields.Count > 0 then
        begin
          CompareParams := '';
          AppendArgs := '';
          EditArgs := '';
          FilterAdds := '';
          BackendAdds := '';
          for I := 0 to Plan.UniqueCompareFields.Count - 1 do
          begin
            F := Plan.UniqueCompareFields[I];
            if I > 0 then
            begin
              CompareParams := CompareParams + ',';
              AppendArgs := AppendArgs + ', ';
              EditArgs := EditArgs + ', ';
            end;
            CompareParams := CompareParams + 'a' + F;
            AppendArgs := AppendArgs + CompareArgOf(F, True);
            EditArgs := EditArgs + CompareArgOf(F, False);
            FilterAdds := FilterAdds +
              '                + ' + QuotedStr(' and ' + F) +
              ' + iif(a' + F + ' = '''', '' is null'', '' = '' + quotedstr(a' + F + '))';
            BackendAdds := BackendAdds +
              '                   + ' + QuotedStr('   and ' + Plan.DetailAlias + '.' + F) +
              ' + iif(a' + F + ' = '''', '' is null'', '' = '' + quotedstr(a' + F + '))';
          end;
          A('//判断从表唯一');
          if ExclusionField <> '' then
            A('Procedure ExamineDetailedUnique(ACds : TUgClientdataset;ARecordCode:String;' +
              CompareParams + ':String);')
          else
            A('Procedure ExamineDetailedUnique(ACds : TUgClientdataset;' +
              CompareParams + ':String);');
          A('var');
          A('  c : TUgClientDataSet;');
          A('begin');
          A('  //判断内存表');
          A('  c := TUgClientDataSet.Create(nil);');
          A('  try');
          A('    c.Data := ACds.Data;');
          A('    c.Filtered := False;');
          A('    c.Filter   := ' + QuotedStr(' 1 = 1'));
          if ExclusionField <> '' then
            A('                + ' + QuotedStr(' and ' + ExclusionField) +
              ' + iif(ARecordCode = '''', '' is not null'', '' <> '' + quotedstr(ARecordCode))');
          A(FilterAdds + ';');
          A('    c.Filtered := True;');
          A('    if c.RecordCount > 0 then');
          A('    RaiseException(UGMM.LT(''维护的数据已存在当前列表中''));');
          A('  finally');
          A('    c.free;');
          A('  end;');
          A('  //判断后台表');
          A('  c := TUgClientDataSet.Create(Nil);');
          A('  try');
          A('    c.DataNodeName := cDataNodeName;');
          A('    c.Close;');
          A('    c.CommandText := ' + QuotedStr(' select'));
          if ExclusionField <> '' then
            A('                   + ' + QuotedStr('   ' + Plan.DetailAlias + '.' + ExclusionField))
          else
            A('                   + ' + QuotedStr('   ' + Plan.DetailAlias + '.' + Plan.UniqueCompareFields[0]));
          A('                   + ' + QuotedStr(' from ' + Plan.DetailTable + ' ' + Plan.DetailAlias));
          A('                   + ' + QuotedStr(' where 1 = 1'));
          if ExclusionField <> '' then
            A('                   + ' + QuotedStr('   and ' + Plan.DetailAlias + '.' + ExclusionField) +
              ' + iif(ARecordCode = '''', '' is not null'', '' <> '' + quotedstr(ARecordCode))');
          A(BackendAdds + ';');
          A('    c.open;');
          A('    if c.RecordCount > 0 then');
          A('    RaiseException(UGMM.LT(''维护的数据已存在后台列表中''));');
          A('  finally');
          A('    c.free;');
          A('  end;');
          A('end;');
        end;

        // ---- hierarchy permission ----
        if Plan.Scoped then
        begin
          A('//获取当前部门及下级部门');
          A('Function GetSubClassName:String;');
          A('var');
          A('  l : TStringList;');
          A('begin');
          A('  l := TStringList.Create;');
          A('  try');
          A('    l.Text := ReplaceText(UGMM.Informations.Values[''ClassName''] + UGMM.Informations.Values[''SubClassName''] , '';'' , #$d#$a);');
          A('    result := '''';');
          A('    while l.Count > 0 do');
          A('    begin');
          A('      if trim(l[0]) <> '''' then');
          A('      result := result + iif(result = '''' , '''' , '' , '') + quotedstr(trim(l[0]));');
          A('      l.Delete(0);');
          A('    end;');
          A('    result := ''('' + result + '')'';');
          A('  finally');
          A('    l.Free;');
          A('  end;');
          A('end;');
        end;

        // ---- navigation ----
        A('//获取游标');
        A('Function GetNavigCode(Const ANavig:Integer):String;');
        A('Var');
        A('  c : TUgClientdataset;');
        A('  s : String;');
        A('  d : TDateTime;');
        A('  v : Integer;');
        A('begin');
        A('  c := TUgClientdataset.Create(nil);');
        A('  try');
        A('    if cdsMain.IsEmpty then');
        A('      v := tyLast');
        A('    else begin');
        A('      v := ANavig;');
        if Plan.TimeKind = ttkDateTime then
        begin
          A('      d := cdsMain.Fieldbyname(' + QuotedStr(Plan.TimeField) + ').AsDateTime;');
          A('      if cDataNodeDriver = ''Ora''then');
          A('      s := ''To_Date(''+ Quotedstr(FormatDateTime(''yyyy-MM-dd HH:mm:ss'', d )) + '','' + Quotedstr(''yyyy-mm-dd hh24:mi:ss'') + '')''');
          A('      else if cDataNodeDriver = ''MSAcc''then');
          A('      s := ''#'' + FormatDateTime(''yyyy-MM-dd HH:mm:ss'', d ) + ''#''');
          A('      else if (cDataNodeDriver = ''MSSQL'') or (cDataNodeDriver = ''SQLite'')then');
          A('      s := Quotedstr(FormatDateTime(''yyyy-MM-dd HH:mm:ss.zzz'', d ))');
          A('      else');
          A('      s := Quotedstr(FormatDateTime(''yyyy-MM-dd HH:mm:ss'', d ));');
        end
        else if Plan.TimeKind = ttkNumber then
          A('      s := VarToStr(cdsMain.Fieldbyname(' + QuotedStr(Plan.TimeField) + ').AsString);')
        else
          A('      s := Quotedstr(cdsMain.Fieldbyname(' + QuotedStr(Plan.TimeField) + ').AsString);');
        A('    end;');
        A('    c.DataNodeName := cDataNodeName;');
        A('    c.Close;');
        A('    c.CommandText := '' select''');
        // 原版按驱动生成行数限制：MSSQL/MSAcc 用 top 1，MySQL/SQLite/其他用 limit 1，Oracle 不加。
        A('                   + iif((cDataNodeDriver = ''MSSQL'') or (cDataNodeDriver = ''MSAcc''), '' top 1'', '''')');
        A('                   + ''   ' + Plan.MainAlias + '.' + Plan.MainKeyField + '''');
        A('                   + '' from ' + Plan.MainTable + ' ' + Plan.MainAlias + '''');
        A('                   + '' where 1 = 1''');
        if Plan.Scoped then
        begin
          A('                   //添加层级权限');
          A('                   + ''   and ' + Plan.MainAlias + '.' + Plan.DepartmentField + ' in '' + GetSubClassName');
        end;
        A('                   + iif(v = tyFirst ,');
        A('                     '' order by ' + Plan.MainAlias + '.' + Plan.TimeField + ''','''')');
        A('                   + iif(v = tyPrior ,');
        A('                     ''   and ' + Plan.MainAlias + '.' + Plan.TimeField + ' < '' + s');
        A('                   + '' order by ' + Plan.MainAlias + '.' + Plan.TimeField + ' Desc'','''')');
        A('                   + iif(v = tyNext ,');
        A('                     ''   and ' + Plan.MainAlias + '.' + Plan.TimeField + ' > '' + s');
        A('                   + '' order by ' + Plan.MainAlias + '.' + Plan.TimeField + ''','''')');
        A('                   + iif(v = tyLast ,');
        A('                     '' order by ' + Plan.MainAlias + '.' + Plan.TimeField + ' Desc'','''')');
        A('                   + iif(v = tyAppend ,');
        A('                     ''   and 1 = 2'','''');');
        A('    c.CommandText := c.CommandText');
        A('                   + iif((cDataNodeDriver = ''MSSQL'') or (cDataNodeDriver = ''MSAcc'') or (cDataNodeDriver = ''Ora''), '''', '' limit 1'');');
        A('    c.Params.Clear;');
        A('    c.open;');
        A('    if c.RecordCount > 0 then');
        A('    begin');
        A('      Result := c.FieldByName(' + QuotedStr(Plan.MainKeyField) + ').AsString;');
        A('      Exit;');
        A('    end else begin');
        A('      if v in [tyFirst,tyLast] then');
        A('      begin');
        A('        Result := '''';');
        A('        Exit;');
        A('      end;');
        A('      if v = tyPrior then');
        A('        Result := GetNavigCode(tyFirst);');
        A('      if v = tyNext then');
        A('        Result := GetNavigCode(tyLast);');
        A('    end;');
        A('  finally');
        A('    c.free;');
        A('  end;');
        A('end;');

        // ---- open detail / main ----
        A('//打开从表');
        A('Procedure OpenDetailed(aKey : String);');
        A('Var');
        A('  c : TUgClientdataset;');
        A('begin');
        A('  c := cdsDetailed;');
        A('  c.close;');
        A('  c.CommandText := ' + QuotedStr('select ' + SqlList(Plan.DetailAlias, Plan.DetailFields) +
          ' from ' + Plan.DetailTable + ' ' + Plan.DetailAlias + ' where ' +
          Plan.DetailAlias + '.' + Plan.DetailKeyField + ' = ') + ' + Quotedstr(aKey);');
        A('  c.Open;');
        A('end;');
        A('//打开主表');
        A('Procedure OpenMain(aKey : String);');
        A('Var');
        A('  c : TUgClientdataset;');
        A('begin');
        A('  c := cdsMain;');
        A('  c.close;');
        A('  c.CommandText := ' + QuotedStr(SQLPrefix) + ' + Quotedstr(aKey);');
        A('  c.Open;');
        A('  OpenDetailed(aKey);');
        A('end;');

        // ---- GetInSqlText (kept from the original script) ----
        A('//生成IN查询列表,一般用在按单号查询使用[分隔是回车]');
        A('function GetInSqlText(AFieldName,AText: String): String;');
        A('var');
        A('  l:TStringList;');
        A('  i:integer;');
        A('  Codes,iSql:String;');
        A('begin');
        A('  l:=TStringList.Create;');
        A('  Try');
        A('    l.Text:= AText;');
        A('    iSql  := '''';');
        A('    Codes := '''';');
        A('    for i:= 0 to l.Count - 1 do');
        A('    Begin');
        A('      if Codes <> '''' then');
        A('      Codes := Codes + '','';');
        A('      Codes := Codes + Quotedstr(l.Strings[i]);');
        A('      if (i + 1) mod 1000 = 0 then');
        A('      Begin');
        A('        if iSql <> '''' then');
        A('        iSql := iSql + '' OR '';');
        A('        iSql := iSql + AFieldName + '' IN ('' + Codes + '')'';');
        A('        Codes := '''';');
        A('      End;');
        A('    End;');
        A('    if Codes <> '''' then');
        A('    Begin');
        A('      if iSql <> '''' then');
        A('      iSql := iSql + '' OR '';');
        A('      iSql := iSql + AFieldName + '' IN ('' + Codes + '')'';');
        A('    End;');
        A('    if iSql = '''' then');
        A('    Result := AFieldName + '' IN (''''*'''')''');
        A('    else');
        A('    Result := iSql;');
        A('  Finally');
        A('  //Except{ExceptionMessage}');
        A('    FreeAndNil(l);');
        A('  End;');
        A('end;');

        // ---- query ----
        if Plan.HasButton('btQuery') then
        begin
          A('//查询');
          A('Procedure btQueryOnClick(Sender: TObject);');
          A('var');
          A('  F : TUniForm;');
          A('  D : TClientDataSet;');
          A('begin');
          A('  F := UGMM.GetWebSubForm(cQueryFrame);');
          A('  try');
          A('    F.Caption := UGMM.LT(cQueryFrame);');
          A('    if F.ShowModal = mrOK then');
          A('    begin');
          A('      D := TClientDataSet(TUgWebForm(F).RunFrame.FindComponent(''cdsMain''));');
          A('      OpenMain(D.FieldByName(' + QuotedStr(Plan.MainKeyField) + ').AsString);');
          A('      RefState(tyView);');
          A('    end;');
          A('  finally');
          A('    //UGMM.DelWebSubForm(cQueryFrame);');
          A('  end;');
          A('end;');
        end;

        // ---- navigation handlers ----
        if Plan.HasButton('btFirst') then
        begin
          A('//首项');
          A('Procedure btFirstOnClick(Sender: TObject);');
          A('begin');
          A('  OpenMain(GetNavigCode(tyFirst));');
          A('  RefState(tyView);');
          A('end;');
        end;
        if Plan.HasButton('btPrior') then
        begin
          A('//前项');
          A('Procedure btPriorOnClick(Sender: TObject);');
          A('begin');
          A('  OpenMain(GetNavigCode(tyPrior));');
          A('  RefState(tyView);');
          A('end;');
        end;
        if Plan.HasButton('btNext') then
        begin
          A('//后项');
          A('Procedure btNextOnClick(Sender: TObject);');
          A('begin');
          A('  OpenMain(GetNavigCode(tyNext));');
          A('  RefState(tyView);');
          A('end;');
        end;
        if Plan.HasButton('btLast') then
        begin
          A('//尾项');
          A('Procedure btLastOnClick(Sender: TObject);');
          A('begin');
          A('  OpenMain(GetNavigCode(tyLast));');
          A('  RefState(tyView);');
          A('end;');
        end;

        // ---- add / edit through the editor sub-form ----
        if Plan.HasButton('btAppend') then
        begin
          A('//新增');
          A('Procedure btAppendOnClick(Sender: TObject);');
          A('var');
          A('  F : TUgWebForm;');
          A('  b : boolean;');
          A('  e : String;');
          A('begin');
          A('  F:= TUgWebForm(UGMM.GetWebSubForm(cEditorFrame));');
          A('  try');
          A('    F.Caption := UGMM.LT(''新增数据'');');
          A('    b := True;');
          A('    while b do');
          A('    begin');
          A('      if e <> '''' then');
          A('      WaitEditorError(e);');
          A('      e := '''';');
          A('      b := False;');
          A('      if F.ShowModal = mrOK then');
          A('      try');
          if Plan.UniqueCompareFields.Count > 0 then
          begin
            if ExclusionField <> '' then
              A('        ExamineDetailedUnique(cdsDetailed, '''', ' + AppendArgs + ');')
            else
              A('        ExamineDetailedUnique(cdsDetailed, ' + AppendArgs + ');');
          end;
          for I := 0 to Plan.RequiredDetailFields.Count - 1 do
            if IsEditableField(Plan.RequiredDetailFields[I]) then
            begin
              A('        if Trim(VarToStr(TUgWebRunFrame(F.RunFrame).GetValue(' +
                QuotedStr('v' + Plan.RequiredDetailFields[I]) + '))) = '''' then');
              A('          RaiseException(UGMM.LT(' +
                QuotedStr(CaptionOf(Plan.DetailFields, Plan.DetailCaptions, Plan.RequiredDetailFields[I])) +
                ') + UGMM.LT('' 不能为空。''));');
            end;
          A('        cdsDetailed.Append;');
          for I := 0 to Editable.Count - 1 do
            A('        cdsDetailed.FieldByName(' + QuotedStr(Editable[I]) +
              ').AsVariant := TUgWebRunFrame(F.RunFrame).GetValue(' + QuotedStr('v' + Editable[I]) + ');');
          A('        cdsDetailed.Post;');
          A('        //刷新状态');
          A('        RefState(tyView);');
          A('      except');
          A('        b := True;');
          A('        e := ExceptionMessage;');
          A('      end;');
          A('    end;');
          A('  finally');
          A('    UGMM.DelWebSubForm(cEditorFrame);');
          A('  end;');
          A('end;');
        end;
        if Plan.HasButton('btEditor') then
        begin
          A('//修改');
          A('Procedure btEditorOnClick(Sender: TObject);');
          A('var');
          A('  F : TUgWebForm;');
          A('  b : boolean;');
          A('  e : String;');
          A('begin');
          A('  F:= TUgWebForm(UGMM.GetWebSubForm(cEditorFrame));');
          A('  try');
          A('    F.Caption := UGMM.LT(''修改数据'');');
          for I := 0 to Editable.Count - 1 do
            A('    TUgWebRunFrame(F.RunFrame).SetValue(' + QuotedStr('v' + Editable[I]) +
              ',cdsDetailed.FieldByName(' + QuotedStr(Editable[I]) + ').AsVariant);');
          A('    b := True;');
          A('    while b do');
          A('    begin');
          A('      if e <> '''' then');
          A('      WaitEditorError(e);');
          A('      e := '''';');
          A('      b := False;');
          A('      if F.ShowModal = mrOK then');
          A('      try');
          if Plan.UniqueCompareFields.Count > 0 then
          begin
            if ExclusionField <> '' then
            begin
              A('        ExamineDetailedUnique(cdsDetailed,');
              A('                              cdsDetailed.FieldbyName(' +
                QuotedStr(ExclusionField) + ').AsString,');
              A('                              ' + EditArgs + ');');
            end
            else
              A('        //未配置记录编号/唯一记录字段，无法标识当前行自身，修改时不做提前校验，保存时按行号校验组合唯一。');
          end;
          for I := 0 to Plan.RequiredDetailFields.Count - 1 do
            if IsEditableField(Plan.RequiredDetailFields[I]) then
            begin
              A('        if Trim(VarToStr(TUgWebRunFrame(F.RunFrame).GetValue(' +
                QuotedStr('v' + Plan.RequiredDetailFields[I]) + '))) = '''' then');
              A('          RaiseException(UGMM.LT(' +
                QuotedStr(CaptionOf(Plan.DetailFields, Plan.DetailCaptions, Plan.RequiredDetailFields[I])) +
                ') + UGMM.LT('' 不能为空。''));');
            end;
          A('        cdsDetailed.Edit;');
          for I := 0 to Editable.Count - 1 do
            A('        cdsDetailed.FieldByName(' + QuotedStr(Editable[I]) +
              ').AsVariant := TUgWebRunFrame(F.RunFrame).GetValue(' + QuotedStr('v' + Editable[I]) + ');');
          A('        cdsDetailed.Post;');
          A('        //刷新状态');
          A('        RefState(tyView);');
          A('      except');
          A('        b := True;');
          A('        e := ExceptionMessage;');
          A('      end;');
          A('    end;');
          A('  finally');
          A('    UGMM.DelWebSubForm(cEditorFrame);');
          A('  end;');
          A('end;');
        end;

        // ---- delete ----
        if Plan.HasButton('btDelete') then
        begin
          A('//删除');
          A('Procedure btDeleteOnClick(Sender: TObject);');
          A('Begin');
          A('  if gridDetailed.SelectedRows.Count = 0 then');
          A('  RaiseException(UGMM.LT(''请选中要删除的数据''));');
          A('  //提示是否要删除记录');
          A('  if ConfirmAction(UGMM.LT(''是否删除选中的记录?'')) then');
          A('  begin');
          A('    //删除选中的记录');
          A('    gridDetailed.SelectedRows.Delete;');
          A('    //刷新状态');
          A('    RefState(tyView);');
          A('  end;');
          A('end;');
        end;

        // ---- import ----
        if Plan.HasButton('btImport') then
        begin
          ImportFields := '';
          ImportCaptions := '';
          for I := 0 to Editable.Count - 1 do
          begin
            ImportFields := ImportFields + Editable[I] + ';';
            ImportCaptions := ImportCaptions +
              CaptionOf(Plan.DetailFields, Plan.DetailCaptions, Editable[I]) + ';';
          end;
          A('//导入 >> 文本格式或电子表格');
          A('procedure pmImportUgMenuItemsOnClick(const acaption: string);');
          A('var');
          A('  g : TUgDBGrid;');
          A('  fe,fs : String;');
          A('begin');
          A('  //赋值表格地址');
          A('  g := gridDetailed;');
          A('  //赋值必填项');
          A('  fe := ' + QuotedStr(ImportFields) + ';');
          A('  fs := ' + QuotedStr(ImportCaptions) + ';');
          A('  if acaption = UGMM.LT(''文本格式'') then');
          A('  UGMM.ImportText(g , fs);');
          A('  if acaption = UGMM.LT(''电子表格'') then');
          A('  UGMM.ImpExcel(g , Self.Caption , fe);');
          for I := 0 to Plan.ImportCaptions.Count - 1 do
          begin
            A('  if acaption = UGMM.LT(' + QuotedStr(Plan.ImportCaptions[I]) + ') then');
            A('  QuoteDetailsFromQuery(' + QuotedStr(Plan.ImportFrames[I]) + ', ' +
              Plan.ImportMultiSelect[I] + ');');
          end;
          A('  //刷新状态');
          A('  RefState(tyView);');
          A('end;');
          if Plan.ImportCaptions.Count > 0 then
          begin
            A('//引用明细：把来源查询窗体的记录逐条追加到从表（扩充项，父键由 BeforePost 覆盖）');
            A('Procedure QuoteDetailsFromQuery(const AFrame: string; const AMultiSelect: Boolean);');
            A('Var');
            A('  F : TUgWebForm;');
            A('  g : TUgDBGrid;');
            A('  s : TUgClientDataSet;');
            A('  bm, cb : TBookmark;');
            A('  i, n, nFound : Integer;');
            A('  v : Variant;');
            A('  LSkips : TStringList;');
            A('begin');
            A('  if cdsMain.IsEmpty then');
            A('    RaiseException(UGMM.LT(''请先选择主记录，再引用明细。''));');
            A('  F := TUgWebForm(UGMM.GetWebSubForm(AFrame));');
            A('  try');
            A('    F.Caption := UGMM.LT(AFrame);');
            A('    //以模态窗体打开来源查询窗体：查询并勾选后点确定，再读取选择');
            A('    if F.ShowModal <> mrOK then');
            A('      Exit;');
            A('    g := TUgDBGrid(F.RunFrame.FindComponent(''gridMain''));');
            A('    s := TUgClientDataSet(F.RunFrame.FindComponent(''cdsMain''));');
            A('    if (g = nil) or (s = nil) then');
            A('      RaiseException(UGMM.LT(''查询窗体尚未就绪，请先查询出要引用的记录。''));');
            A('    if not s.Active then');
            A('      RaiseException(UGMM.LT(''查询窗体尚未就绪，请先查询出要引用的记录。''));');
            A('    n := g.SelectedRows.Count;');
            A('    if AMultiSelect then');
            A('    begin');
            A('      if n = 0 then');
            A('        RaiseException(UGMM.LT(''请先选择要引用的明细记录。''));');
            A('    end');
            A('    else');
            A('      n := 1;');
            A('    //来源与从表明细没有任何同名字段时不予引用，避免追加空行');
            A('    nFound := 0;');
            for I := 0 to Editable.Count - 1 do
            begin
              A('    try');
              A('      v := s.FieldByName(' + QuotedStr(Editable[I]) + ').AsVariant;');
              A('      Inc(nFound);');
              A('    except');
              A('    end;');
            end;
            A('    if nFound = 0 then');
            A('      RaiseException(UGMM.LT(''来源记录与从表明细没有同名字段，无法引用，请检查字段命名。''));');
            A('    bm := s.GetBookmark;');
            A('    LSkips := TStringList.Create;');
            A('    s.DisableControls;');
            A('    try');
            A('      for i := 0 to n - 1 do');
            A('      begin');
            A('        if AMultiSelect then');
            A('        begin');
            A('          cb := g.SelectedRows[i];');
            A('          s.GotoBookmark(cb);');
            A('        end;');
            A('        cdsDetailed.Append;');
            for I := 0 to Editable.Count - 1 do
            begin
              A('        //来源没有同名列时跳过，并在引用结果里列出未复制的字段');
              A('        try');
              A('          cdsDetailed.FieldByName(' + QuotedStr(Editable[I]) +
                ').AsVariant := s.FieldByName(' + QuotedStr(Editable[I]) + ').AsVariant;');
              A('        except');
              A('          LSkips.Add(' + QuotedStr(
                CaptionOf(Plan.DetailFields, Plan.DetailCaptions, Editable[I])) + ');');
              A('        end;');
            end;
            A('        cdsDetailed.Post;');
            A('      end;');
            { 回报要读 LSkips，必须放在释放它的 finally 之前。 }
            if HasNotice then
            begin
              A('    if LSkips.Count > 0 then');
              A('      ShowNotice(UGMM.LT(''已引用 '') + IntToStr(n) + UGMM.LT('' 条明细；来源中无同名列、未复制的字段：'') + LSkips.CommaText)');
              A('    else');
              A('      ShowNotice(UGMM.LT(''已引用 '') + IntToStr(n) + UGMM.LT('' 条明细。''));');
            end;
            A('    finally');
            A('      s.GotoBookmark(bm);');
            A('      s.FreeBookmark(bm);');
            A('      s.EnableControls;');
            A('      LSkips.Free;');
            A('    end;');
            if Plan.RequiredDetailFields.Count > 0 then
              A('    CheckDetailRequired;');
            if Plan.UniqueCompareFields.Count > 0 then
              A('    CheckDetailUnique;');
            A('    RefState(tyView);');
            A('  finally');
            A('    UGMM.DelWebSubForm(cQueryFrame);');
            A('  end;');
            A('end;');
          end;
          A('//导入');
          A('Procedure btImportOnClick(Sender: TObject);');
          A('begin');
          A('  pmImportUgMenuItemsOnClick(UGMM.LT(''文本格式''));');
          A('end;');
        end;

        // ---- save / cancel ----
        if Plan.HasButton('btSave') then
        begin
          A('//保存');
          if Plan.RequiredDetailFields.Count > 0 then
          begin
            A('//按配置校验从表必填字段，并报告明细行号（参照 mtMultiple）');
            A('procedure CheckDetailRequired;');
            A('var');
            A('  RowNo: Integer;');
            A('begin');
            A('  if cdsDetailed.IsEmpty then Exit;');
            A('  RowNo := 0;');
            A('  cdsDetailed.First;');
            A('  while not cdsDetailed.Eof do');
            A('  begin');
            A('    Inc(RowNo);');
            for I := 0 to Plan.RequiredDetailFields.Count - 1 do
            begin
              A('    if Trim(VarToStr(cdsDetailed.FieldByName(' +
                QuotedStr(Plan.RequiredDetailFields[I]) + ').AsVariant)) = '''' then');
              A('      RaiseException(UGMM.LT(''第 '') + IntToStr(RowNo) + UGMM.LT('' 行：'') + UGMM.LT(' +
                QuotedStr(CaptionOf(Plan.DetailFields, Plan.DetailCaptions, Plan.RequiredDetailFields[I])) +
                ') + UGMM.LT('' 不能为空。''));');
            end;
            A('    cdsDetailed.Next;');
            A('  end;');
            A('end;');
          end;
          if Plan.UniqueCompareFields.Count > 0 then
          begin
            UniqueLabel := '';
            for I := 0 to Plan.UniqueCompareFields.Count - 1 do
            begin
              if I > 0 then UniqueLabel := UniqueLabel + ', ';
              UniqueLabel := UniqueLabel + Plan.UniqueCompareFields[I];
            end;
            A('//检查暂存明细的组合唯一值，并报告首行和重复行（参照 mtMasterSlave）');
            A('procedure CheckDetailUnique;');
            A('var');
            A('  L,Rows:TStringList;');
            A('  K,V,FieldValues:String;');
            A('  B:TBookmark;');
            A('  RowNo,DuplicateIndex:Integer;');
            A('  HasValue:Boolean;');
            A('begin');
            A('  if cdsDetailed.IsEmpty then Exit;');
            A('  L:=TStringList.Create; Rows:=TStringList.Create;');
            A('  B:=cdsDetailed.GetBookmark; cdsDetailed.DisableControls;');
            A('  try');
            A('    cdsDetailed.First; RowNo:=0;');
            A('    while not cdsDetailed.Eof do');
            A('    begin');
            A('      Inc(RowNo); K:=''''; FieldValues:=''''; HasValue:=False;');
            for I := 0 to Plan.UniqueCompareFields.Count - 1 do
            begin
              A('      V:=VarToStr(cdsDetailed.FieldByName(' + QuotedStr(Plan.UniqueCompareFields[I]) + ').AsVariant);');
              A('      if V <> '''' then HasValue:=True;');
              A('      K:=K+IntToStr(Length(V))+'':''+V+''|'';');
              A('      if FieldValues<>'''' then FieldValues:=FieldValues+'', '';');
              A('      FieldValues:=FieldValues+' + QuotedStr(Plan.UniqueCompareFields[I] + '=') + '+V;');
            end;
            A('      if HasValue then');
            A('      begin');
            A('        DuplicateIndex:=L.IndexOf(K);');
            A('        if DuplicateIndex>=0 then');
            A('          RaiseException(''保存失败：明细第 ''+IntToStr(RowNo)+'' 行组合唯一字段 [''+FieldValues+''] 与第 ''+Rows[DuplicateIndex]+'' 行重复，请修改后重试！'');');
            A('        L.Add(K); Rows.Add(IntToStr(RowNo));');
            A('      end;');
            A('      cdsDetailed.Next;');
            A('    end;');
            A('  finally');
            A('    cdsDetailed.GotoBookmark(B); cdsDetailed.FreeBookmark(B);');
            A('    cdsDetailed.EnableControls; Rows.Free; L.Free;');
            A('  end;');
            A('end;');
          end;
          A('Procedure btSaveOnClick(Sender: TObject);');
          A('var');
          A('  K : String;');
          A('begin');
          if Plan.UniqueCompareFields.Count > 0 then
            A('  //保存前先校验暂存明细的组合唯一');
          if Plan.RequiredDetailFields.Count > 0 then
            A('  CheckDetailRequired;');
          if Plan.UniqueCompareFields.Count > 0 then
            A('  CheckDetailUnique;');
          A('  //提交');
          A('  try');
          A('    cdsDetailed.SubmitUpdates;');
          A('  except');
          if Plan.UniqueCompareFields.Count > 0 then
            A('    if (Pos(''UNIQUE'',UpperCase(ExceptionMessage))>0)and(Pos(' +
              QuotedStr(UpperCase(Plan.DetailTable)) +
              ',UpperCase(ExceptionMessage))>0)then RaiseException(''保存失败：明细组合唯一字段 [' +
              UniqueLabel + '] 存在重复，请修改后重试！'');');
          A('    RaiseException(ExceptionMessage);');
          A('  end;');
          A('  //提示');
          A('  ShowNotice(UGMM.LT(''数据保存成功.''));');
          A('  //保存成功后按当前主记录重新加载：数据库自增等由库端赋值的字段需要回显');
          A('  K := cdsMain.FieldByName(' + QuotedStr(Plan.MainKeyField) + ').AsString;');
          A('  try');
          A('    OpenMain(K);');
          A('  except');
          A('    ShowActionError(UGMM.LT(''已保存成功，但重新加载失败，请手动查询确认。''));');
          A('  end;');
          A('  //刷新状态');
          A('  RefState(tyView);');
          A('end;');
        end;
        if Plan.HasButton('btCancel') then
        begin
          A('//撤消');
          A('Procedure btCancelOnClick(Sender: TObject);');
          A('begin');
          A('  if not ConfirmAction(UGMM.LT(''是否放弃保存?'')) then');
          A('  Exit;');
          A('  //撤消更新');
          A('  cdsDetailed.CancelUpdates;');
          A('  //刷新界面');
          A('  gridDetailed.Refresh;');
          A('  //刷新状态');
          A('  RefState(tyView);');
          A('end;');
        end;

        // ---- export ----
        if Plan.HasButton('btExport') then
        begin
          A('//导出');
          A('Procedure btExportOnClick(Sender: TObject);');
          A('var');
          A('  g : TUgDBGrid;');
          A('begin');
          A('  g := gridDetailed;');
          A('  UGMM.ExpExcel(g,Self.Caption,Self.Caption);');
          A('end;');
        end;

        // ---- annex ----
        if Plan.HasButton('btAnnex') then
        begin
          A('//附件');
          A('Procedure btAnnexOnClick(Sender: TObject);');
          A('var');
          A('  s : String;');
          A('  //获取文件管理权限');
          A('  Function getEditor:Boolean;');
          A('  begin');
          A('    Result := False;');
          A('    if (self.FindComponent(''btDelete'')<> nil)');
          A('    and(TUniControl(self.FindComponent(''btDelete'')).Visible)');
          A('    and(TUniControl(self.FindComponent(''btDelete'')).Enabled) then');
          A('    begin');
          A('      Result := True;');
          A('      exit;');
          A('    end;');
          A('    if (self.FindComponent(''btEditor'')<> nil)');
          A('    and(TUniControl(self.FindComponent(''btEditor'')).Visible)');
          A('    and(TUniControl(self.FindComponent(''btEditor'')).Enabled) then');
          A('    begin');
          A('      Result := True;');
          A('      exit;');
          A('    end;');
          A('    if (self.FindComponent(''btAudit'')<> nil)');
          A('    and(TUniControl(self.FindComponent(''btAudit'')).Visible)');
          A('    and(TUniControl(self.FindComponent(''btAudit'')).Enabled) then');
          A('    begin');
          A('      Result := True;');
          A('      exit;');
          A('    end;');
          A('    if (self.FindComponent(''btUnAudit'')<> nil)');
          A('    and(TUniControl(self.FindComponent(''btUnAudit'')).Visible)');
          A('    and(TUniControl(self.FindComponent(''btUnAudit'')).Enabled) then');
          A('    begin');
          A('      Result := True;');
          A('      exit;');
          A('    end;');
          A('    if (self.FindComponent(''btRepulse'')<> nil)');
          A('    and(TUniControl(self.FindComponent(''btRepulse'')).Visible)');
          A('    and(TUniControl(self.FindComponent(''btRepulse'')).Enabled) then');
          A('    begin');
          A('      Result := True;');
          A('      exit;');
          A('    end;');
          A('  end;');
          A('begin');
          A('  //获取单据编号');
          A('  s := cdsMain.FieldbyName(' + QuotedStr(Plan.MainKeyField) + ').AsString;');
          A('  //打开文件管理器');
          A('  UGMM.OpenFileManager(self.Guid,s ,31457280(*空间容量*),getEditor);');
          A('end;');
        end;

        // ---- close ----
        if Plan.HasButton('btClose') then
        begin
          A('//关闭');
          A('Procedure btCloseOnClick(Sender: TObject);');
          A('Var');
          A('  p:TComponent;');
          A('Begin');
          A('  if not Self.IsEditor then');
          A('  Self.IsEditor := cdsDetailed.ChangeCount > 0;');
          A('  p:=Self.Parent;');
          A('  if (p is TUgWebForm)Or(p is TWebMainForm) then');
          A('  Begin');
          A('    if (Self.IsEditor)');
          A('    And(not ConfirmAction(UGMM.LT(''注意：窗体处于编辑状态，是否放弃保存并关闭窗体？''))) then');
          A('    Exit;');
          A('    if p is TUgWebForm then');
          A('    TUgWebForm(p).Close;');
          A('    if p is TWebMainForm then');
          A('    UniSession.Terminate(UGMM.LT(''会话已关闭''));');
          A('  End;');
          A('  if p is TUniTabSheet then');
          A('  TUniTabSheet(p).Close;');
          A('end;');
        end;

        // ---- grid filter ----
        if HasFilter then
        begin
          A('//从表过滤');
          A('Procedure gridDetailedOnColumnFilter(Sender: TUniDBGrid;const Column: TUniDBGridColumn;const value: Variant);');
          A('Var');
          A('  c : TUGClientDataSet;');
          A('  v : Variant;');
          A('  k : Integer;');
          A('Begin');
          A('  c := TUGClientDataSet(sender.DataSource.DataSet);');
          A('  if c.Active then');
          A('  begin');
          A('    c.FilterParams.Clear;');
          A('    for k := 0 to Sender.Columns.Count - 1 do');
          A('      if (Sender.Columns[k].Filtering.Enabled)');
          A('      and(Vartostr(Sender.Columns[k].Filtering.VarValue)<> '''') then');
          A('      begin');
          A('        v := Sender.Columns[k].Filtering.VarValue;');
          A('        c.FilterParams.Values[Sender.Columns[k].FieldName] := ''%'' + VarToStr(v) + ''%'';');
          A('      end;');
          A('    c.ReFilter;');
          A('  end;');
          A('End;');
          A('//清除从表过滤数据');
          A('procedure gridDetailedOnClearFilters(sender: tobject);');
          A('var');
          A('  c : TUGClientDataSet;');
          A('  i : Integer;');
          A('begin');
          A('  c := TUGClientDataSet(TUniDBGrid(sender).DataSource.DataSet);');
          A('  if c.Active then');
          A('  begin');
          A('    for i := 0 to c.FilterParams.Count -1  do');
          A('    c.FilterParams.Values[c.FilterParams.Names[i]] := '''';');
          A('    c.ReFilter;');
          A('  end;');
          A('end;');
        end;

        // ---- column settings persistence ----
        if HasColumns then
        begin
          A('//读取ini配置信息');
          A('function ReadIni(filename,Section,Ident:String;Const Default:String = ''''):String;');
          A('var');
          A('  i : TIniFile;');
          A('begin//读取配置文件');
          A('  i := TIniFile.create(filename);');
          A('  try');
          A('    Result := i.readstring(Section,Ident,Default)');
          A('  finally');
          A('    i.Free;');
          A('  end;');
          A('end;');
          A('//写入ini配置信息');
          A('procedure WriteIni(filename,section,Ident,Values:String);');
          A('var');
          A('  i:TIniFile;');
          A('begin');
          A('  i:=TIniFile.Create(filename);');
          A('  try');
          A('    i.WriteString(section,Ident,Values);');
          A('  finally');
          A('    i.Free;');
          A('  end;');
          A('end;');
          A('//保存表格配置');
          A('procedure SaveGridUserSettings(aGrid : TUgDBGrid; aName:String);');
          A('var');
          A('  i : Integer;');
          A('  j : TJSONObject;');
          A('  v : TJSONArray;');
          A('  c : TJSONObject;');
          A('  s : String;');
          A('begin');
          A('  try');
          A('  j := TJSONObject.Create;');
          A('    v := TJSONArray.Create;');
          A('    j.AddPair(''name'',aName);');
          A('    j.AddPair(''date'',now);');
          A('    j.AddPair(''columns'',v);');
          A('    for i := 0 to aGrid.Columns.Count - 1 do');
          A('    begin');
          A('      c := TJSONObject.Create;');
          A('      v.AddJSONObject(c);');
          A('      c.AddPair(''index'',aGrid.Columns[i].index);');
          A('      c.AddPair(''fieldName'',aGrid.Columns[i].fieldName);');
          A('      c.AddPair(''titleCaption'',aGrid.Columns[i].Title.caption);');
          A('      c.AddPair(''visible'',aGrid.Columns[i].visible);');
          A('      c.AddPair(''width'',aGrid.Columns[i].width);');
          A('    end;');
          A('    //用户设置目录');
          A('    s := ''..\UserSettings\'' + Self.Guid + ''\'';');
          A('    //检查目录是否存在，不存在则创建目录');
          A('    CheckDirectory(s);');
          A('    //存储用户设置');
          A('    WriteIni(s + UGMM.Informations.Values[''UserName''] + ''.ini'', aGrid.ClassName, aName, j.ToString);');
          A('  finally');
          A('    j.Free;');
          A('  end;');
          A('end;');
          A('//加载表格配置');
          A('procedure LoadGridUserSettings(aGrid : TUgDBGrid; aName:String);');
          A('var');
          A('  s : string;');
          A('  i : Integer;');
          A('  j : TJSONObject;');
          A('  v : TJSONValue;');
          A('  a : TJSONArray;');
          A('  c : TUniBaseDBGridColumn;');
          A('begin');
          A('  s := ''..\UserSettings\'' + Self.Guid + ''\'' + UGMM.Informations.Values[''UserName''] + ''.ini'';');
          A('  //无用户配置则不执行加载表格配置');
          A('  if not FileExists(s) then');
          A('  exit;');
          A('  //读取JSON配置信息');
          A('  j := TJSONObject.Create;');
          A('  try');
          A('    v := j.ParseJSONValue(ReadIni(s, aGrid.ClassName, aName, ''{}''), false, false);');
          A('    //判断是否有列信息');
          A('    if v.FindValue(''columns'') = nil then');
          A('    exit;');
          A('    a := TJSONArray(v.FindValue(''columns''));');
          A('    for i := 0 to a.Count - 1 do');
          A('    if (a.A[i].FindValue(''fieldName'') <> nil)');
          A('    and(aGrid.ColumnByName(a.A[i].FindValue(''fieldName'').Value) <> nil) then');
          A('    begin');
          A('      c         := aGrid.ColumnByName(a.A[i].FindValue(''fieldName'').Value);');
          A('      c.Index   := StrToIntDef(a.A[i].FindValue(''index'').Value, c.Index);');
          A('      c.Width   := StrToIntDef(a.A[i].FindValue(''width'').Value, c.Width);');
          A('      c.Visible := StrToBoolDef(a.A[i].FindValue(''visible'').Value, c.Visible);');
          A('    end;');
          A('  finally');
          A('    j.Free;');
          A('    v.Free;');
          A('  end;');
          A('end;');
          A('//表格Ajax事件');
          A('Procedure gridDetailedOnAjaxEvent(sender: tcomponent;eventname: string;params: tunistrings);');
          A('begin');
          A('  if eventname in [''columnhide'',''columnshow'',''columnresize'',''columnmove''] then');
          A('  SaveGridUserSettings(TUgDBGrid(sender), Sender.Name);');
          A('end;');
        end;

        // ---- detail grid sorting ----
        if HasSort then
        begin
          A('//设置数据集排序功能');
          A('Procedure setDataSetSort(Const ADataSet:TClientdataset; Const aSortFields,aDecFields : String);');
          A('var');
          A('  d : TClientdataset;');
          A('  vSortIndex : String = ''UgSortIndex_'' + ADataSet.Name;');
          A('begin');
          A('  //设置排序索引');
          A('  d := ADataSet;');
          A('  d.IndexDefs.Update;');
          A('  if d.IndexDefs.IndexOf(vSortIndex) >= 0 then');
          A('  d.DeleteIndex(vSortIndex);');
          A('  if aSortFields <> '''' then');
          A('  begin');
          A('  d.AddIndex(vSortIndex, aSortFields, 0, aDecFields, '''', 0);');
          A('  d.IndexDefs.Update;');
          A('  d.IndexName := vSortIndex;');
          A('  end else');
          A('  d.IndexName := '''';');
          A('  d.First;');
          A('end;');
          A('//从表单列排序功能');
          A('Procedure gridDetailedOnColumnSort(column: tunidbgridcolumn;direction: boolean);');
          A('begin');
          A('  setDataSetSort(cdsDetailed, Column.Fieldname, iif(direction,Column.Fieldname,'''')' + ');');
          A('end;');
          A('//从表多列排序功能');
          A('Procedure gridDetailedOnMultiColumnSort(columns: tunidbgridcolumnarr;directions: tunisortdirections);');
          A('begin');
          A('  setDataSetSort(cdsDetailed, Columns, directions);');
          A('end;');
        end;

        // ---- before post ----
        A('//从表保存前');
        A('procedure cdsDetailedBeforePost(dataset: tdataset);');
        A('begin');
        A('  //关联字段');
        A('  dataset.FieldbyName(' + QuotedStr(Plan.DetailKeyField) +
          ').AsVariant := cdsMain.FieldbyName(' + QuotedStr(Plan.MainKeyField) + ').AsVariant;');
        if (Plan.NumberField <> '') and
          ((Plan.NumberKind = dnkGuid) or (Plan.NumberKind = dnkDateTimeRandom)) then
        begin
          A('  //记录编号');
          A('  if dataset.FieldByName(' + QuotedStr(Plan.NumberField) + ').IsNull then');
          A('  dataset.FieldbyName(' + QuotedStr(Plan.NumberField) + ').AsVariant := GetAuotNumber;');
        end;
        A('end;');

        // ---- startup ----
        A('//运行脚本后');
        A('procedure UgWebRunFrameOnAfterRunScript(const sender: tobject);');
        A('var');
        A('  i : integer;');
        A('  e : TUgEdit;');
        A('begin');
        A('  //翻译界面');
        A('  UGMM.LC(Self);');
        A('  //验证模块权限');
        A('  UGMM.VerifyRunFramePerm(Self);');
        if Plan.HasButton('btPrint') then
        begin
          A('  //添加打印机');
          A('  UGMM.AddReport((*附加按钮*) btPrint,');
          A('                 (*编辑权限*) UGMM.Informations.Values[''AllowLandingType''] <> ''系统用户;'',');
          A('                 (*窗体地址*) self.Guid);');
        end;
        A('  //数据集绑定节点库');
        A('  for i := 0 to Self.ComponentCount - 1 do');
        A('  if Self.Components[i] is TUgClientdataset then');
        A('  TUgClientdataset(Self.Components[i]).DataNodeName := cDataNodeName;');
        A('  //打开主从数据集');
        A('  OpenMain(GetNavigCode(tyLast));');
        if Plan.HasButton('btImport') then
        begin
          A('  //导入按钮附加文本格式和电子表格的功能');
          A('  btImport.DropdownMenu := pmImport.PopupMenus;');
        end;
        A('  //刷新状态');
        A('  RefState(tyView);');
        if HasCopy then
        begin
          A('  //gridDetailed增加允许复制功能');
          A('  gridDetailed.ClientEvents.UniEvents.Values[''beforeInit''] := ''function beforeInit(sender, config)''');
          A('                                                            + ''{''');
          A('                                                            + ''  config.viewConfig.enableTextSelection = true;''');
          A('                                                            + ''}'';');
        end;
        if HasFilter then
        begin
          A('  //gridDetailed增加过滤功能');
          A('  for i := 0 to gridDetailed.Columns.Count - 1 do');
          A('  if not gridDetailed.Columns[i].actioncolumn.enabled then');
          A('  Begin');
          A('    with gridDetailed.Columns[i] do');
          A('    Begin');
          A('      e:=TUgEdit.Create(Self);');
          A('      e.Parent := pHiddenPanel;//必须指定');
          A('      e.Name := ''e'' + fieldname + ''Detailed'';');
          A('      e.EmptyText := Title.Caption + ''...'';');
          A('      e.CharEOL := #13;');
          A('      Filtering.Enabled := True;');
          A('      Filtering.Editor := e;');
          A('    end;');
          A('  end;');
        end;
        if HasSort then
        begin
          A('  //gridDetailed增加排序功能');
          A('  gridDetailed.MultiColumnSort := ' + BoolToStr(SameText(SortMode, 'MultiColumnSort'), True) + ';');
          A('  for i := 0 to gridDetailed.Columns.Count - 1 do');
          A('  gridDetailed.Columns[i].Sortable := true;');
        end;
        if HasColumns then
        begin
          A('  //加载表格配置功能');
          A('  LoadGridUserSettings(gridDetailed, gridDetailed.Name);');
        end;
        A('end;');
        A('');
        A('begin');
        A('end.');
        if HasError then
        begin
          WrapAction('btQueryOnClick');
          WrapAction('btFirstOnClick');
          WrapAction('btPriorOnClick');
          WrapAction('btNextOnClick');
          WrapAction('btLastOnClick');
          WrapAction('btAppendOnClick');
          WrapAction('btDeleteOnClick');
          WrapAction('btEditorOnClick');
          WrapAction('btImportOnClick');
          WrapAction('pmImportUgMenuItemsOnClick');
          WrapAction('btSaveOnClick');
          WrapAction('btCancelOnClick');
          WrapAction('btExportOnClick');
          WrapAction('btAnnexOnClick');
          WrapAction('btCloseOnClick');
        end;

        // ---------------------------------------------------------------
        // DFM assembly
        // ---------------------------------------------------------------
        PanelCols := MainPanelColumns;
        FrameWidth := 1069;
        if 10 + PanelCols * CColumnStep > FrameWidth then
          FrameWidth := 10 + PanelCols * CColumnStep;
        L('object UgWebRunFrame: TUgWebRunFrame');
        L('  Left = 0');
        L('  Top = 0');
        L('  Width = ' + IntToStr(FrameWidth));
        L('  Height = 650');
        L('  Hint = ''''');
        L('  ParentColor = False');
        L('  TabOrder = 0');
        L('  SyntaxType = ''PascalScript''');
        L('  Events.Strings = (');
        for I := 0 to High(CButtonOrder) do
        begin
          F := CButtonOrder[I];
          if not Plan.HasButton(F) then Continue;
          if SameText(F, 'btPrint') then Continue;
          if SameText(F, 'btImport') then
          begin
            L('    ' + Q('pmImport|<This>.UgMenuItemsOnClick:pmImportUgMenuItemsOnClick'));
            L('    ' + Q('btImport|<This>.OnClick:btImportOnClick'));
          end
          else
            L('    ' + Q(F + '|<This>.OnClick:' + F + 'OnClick'));
        end;
        if HasFilter then
        begin
          L('    ' + Q('gridDetailed|<This>.OnColumnFilter:gridDetailedOnColumnFilter'));
          L('    ' + Q('gridDetailed|<This>.OnClearFilters:gridDetailedOnClearFilters'));
        end;
        if HasSort then
        begin
          L('    ' + Q('gridDetailed|<This>.OnColumnSort:gridDetailedOnColumnSort'));
          L('    ' + Q('gridDetailed|<This>.OnMultiColumnSort:gridDetailedOnMultiColumnSort'));
        end;
        if HasColumns then
          L('    ' + Q('gridDetailed|<This>.OnAjaxEvent:gridDetailedOnAjaxEvent'));
        L('    ' + Q('cdsDetailed|<This>.BeforePost:cdsDetailedBeforePost'));
        L('    ' + Q('Self|<This>.OnAfterRunScript:UgWebRunFrameOnAfterRunScript') + ')');
        L('  Codes.Strings = (');
        for F in Code do L('    ' + Q(F));
        L('  )');

        // toolbar
        L('  object pButtons: TUgContainerPanel');
        L('    Left = 0');
        L('    Top = 0');
        L('    Width = ' + IntToStr(FrameWidth));
        L('    Height = 33');
        L('    Hint = ''''');
        L('    ParentColor = False');
        L('    Align = alTop');
        L('    TabOrder = 0');
        L('    object topline: TUgContainerPanel');
        L('      Left = 0');
        L('      Top = 32');
        L('      Width = ' + IntToStr(FrameWidth));
        L('      Height = 1');
        L('      Hint = ''''');
        L('      ParentColor = False');
        L('      Color = 13093060');
        L('      Align = alBottom');
        L('      TabOrder = 0');
        L('    end');
        X := 3;
        for I := 0 to High(CButtonOrder) do
        begin
          F := CButtonOrder[I];
          if not Plan.HasButton(F) then Continue;
          if ButtonGroup(F) <> '' then
          begin
            EmitGroup(ButtonGroup(F), X);
            Inc(X, 7);
          end;
          EmitButton(F, X);
          Inc(X, ButtonWidth(F) + 6);
        end;
        L('  end');

        // main-record field panel
        L('  object pEditControls: TUgContainerPanel');
        L('    Left = 0');
        L('    Top = 33');
        L('    Width = ' + IntToStr(FrameWidth));
        L('    Height = 190');
        L('    Hint = ''''');
        L('    ParentColor = False');
        L('    Align = alTop');
        L('    TabOrder = 0');
        L('    object lbEditControls: TUgContainerPanel');
        L('      Left = 0');
        L('      Top = 189');
        L('      Width = ' + IntToStr(FrameWidth));
        L('      Height = 1');
        L('      Hint = ''''');
        L('      ParentColor = False');
        L('      Color = 13093060');
        L('      Align = alBottom');
        L('      TabOrder = 0');
        L('    end');
        Col := 0; NextTop := 10;
        for I := 0 to MainVisible.Count - 1 do
        begin
          F := MainVisible[I];
          Cls := ControlClass(TypeOf(Plan.MainFields, Plan.MainTypes, F));
          CtlName := Plan.MainAlias + F;
          Cap := CaptionOf(Plan.MainFields, Plan.MainCaptions, F);
          Height := ControlHeight(TypeOf(Plan.MainFields, Plan.MainTypes, F));
          { 列优先：单元格 200 宽、高按类型；行步进 = 上一个控件高 + 10；
            放不下（Top + Height > 面板高 − 10）就换右一列，新列 Top = 10。 }
          if (NextTop + Height > CPanelHeight - 10) and (NextTop > 10) then
          begin
            Inc(Col);
            NextTop := 10;
          end;
          L('    object ' + CtlName + ': ' + Cls);
          L('      Left = ' + IntToStr(10 + Col * CColumnStep));
          L('      Top = ' + IntToStr(NextTop));
          L('      Width = 200');
          L('      Height = ' + IntToStr(Height));
          L('      Hint = ''''');
          L('      DataField = ' + Q(F));
          L('      DataSource = dsMain');
          if SameText(Cls, 'TUgDBCheckBox') then
            L('      Caption = ' + Q(Cap))
          else
          begin
            L('      TabOrder = ' + IntToStr(I + 1));
            if SameText(Cls, 'TUgDBDateTimePicker') then
            begin
              L('      DateFormat = ''yyyy-MM-dd''');
              L('      TimeFormat = ''HH:mm:ss''');
              { 原版还带 DateMode = dtmDateTime；其 DateTime 设计期时间戳是原版生成时的
                “当前时间”，不作复刻（会让 DFM 非确定）。 }
              L('      DateMode = dtmDateTime');
            end;
            L('      FieldLabel = ' + Q(Cap));
            L('      FieldLabelAlign = laTop');
          end;
          if SameText(Cls, 'TUgDBNumberEdit') then
          begin
            { 原版：数字框同样带 SelectOnFocus，标签在 SelectOnFocus 之后。 }
            L('      SelectOnFocus = True');
            L('      FieldLabel = ' + Q(Cap));
            L('      FieldLabelAlign = laTop');
            L('      DecimalSeparator = ''.''');
          end
          else if SameText(Cls, 'TUgDBEdit') then
          begin
            L('      SelectOnFocus = True');
            L('      EmptyText = ''''');
          end;
          if SameText(Cls, 'TUgDBCheckBox') then
          begin
            L('      TabOrder = ' + IntToStr(I + 1));
            L('      ParentColor = False');
            L('      Color = clBtnFace');
          end;
          L('    end');
          Inc(NextTop, Height + 10);
        end;
        L('  end');

        // detail grid
        L('  object pGridLayout: TUgContainerPanel');
        L('    Left = 0');
        L('    Top = 223');
        L('    Width = 1069');
        L('    Height = 427');
        L('    Hint = ''''');
        L('    ParentColor = False');
        L('    Align = alClient');
        L('    TabOrder = 0');
        L('    object gridDetailed: TUgDBGrid');
        L('      Left = 0');
        L('      Top = 0');
        L('      Width = 1069');
        L('      Height = 427');
        L('      Hint = ''''');
        L('      DataSource = dsDetailed');
        Options := 'dgEditing, dgTitles, dgIndicator';
        // 扩充项“表格序号”：勾选后 Options 带 dgRowNumbers（UniGUI 渲染 Ext RowNumberer）。
        if Yes(Str(Obj(Config, 'TWebNormalSetting'), '表格序号')) then
          Options := Options + ', dgRowNumbers';
        if Yes(Str(Obj(Config, 'TWebNormalSetting'), '字段宽度')) then
          Options := Options + ', dgColumnResize';
        if Yes(Str(Obj(Config, 'TWebNormalSetting'), '字段移动')) then
          Options := Options + ', dgColumnMove';
        Options := Options + ', dgColLines, dgRowLines, dgRowSelect';
        if HasMulti then Options := Options + ', dgCheckSelect, dgConfirmDelete, dgMultiSelect';
        Options := Options + ', dgAutoRefreshRow';
        L('      Options = [' + Options + ']');
        L('      WebOptions.Paged = False');
        L('      LoadMask.Message = ''Loading data...''');
        L('      Align = alClient');
        L('      TabOrder = 0');
        L('      StoreUserSettings = False');
        L('      Columns = <');
        for I := 0 to DetailVisible.Count - 1 do
        begin
          F := DetailVisible[I];
          L('        item');
          L('          FieldName = ' + Q(F));
          L('          Title.Caption = ' + Q(CaptionOf(Plan.DetailFields, Plan.DetailCaptions, F)));
          if IsRequiredField(F) then
            L('          Title.Font.Color = clRed');
          L('          Width = 120');
          L('        end');
        end;
        L('      >');
        L('    end');
        L('  end');

        // hidden panel for filter editors
        if HasFilter then
        begin
          L('  object pHiddenPanel: TUgHiddenPanel');
          L('    Left = ' + IntToStr(FrameWidth - 170));
          L('    Top = 384');
          L('    Width = 160');
          L('    Height = 256');
          L('    Hint = ''''');
          L('    Visible = True');
          L('  end');
        end;

        // icon list
        L('  object Imgs: TUGIconClsList');
        L('    Left = 20');
        L('    Top = 550');
        L('    IconText = ' + Q(
          'icon iconfont icon-chaxun'#13#10'icon iconfont icon-quanxuan'#13#10 +
          'icon iconfont icon-fanxuan'#13#10'icon iconfont icon-skipprevious'#13#10 +
          'icon iconfont icon-xiangzuo'#13#10'icon iconfont icon-xiangyou'#13#10 +
          'icon iconfont icon-skipnext'#13#10'icon iconfont icon-addEdge'#13#10 +
          'icon iconfont icon-shanchu1'#13#10'icon iconfont icon-xiugai1'#13#10 +
          'icon iconfont icon-ico_daoru_xuanzhong'#13#10'icon iconfont icon-baocun'#13#10 +
          'icon iconfont icon-chexiao4'#13#10'icon iconfont icon-shenhe'#13#10 +
          'icon iconfont icon-quxiaoshenhe'#13#10'icon iconfont icon-dahui'#13#10 +
          'icon iconfont icon-web-icon-'#13#10'icon iconfont icon-dayin4'#13#10 +
          'icon iconfont icon-fujian'#13#10'icon iconfont icon-bangdingpingtai'#13#10 +
          'icon iconfont icon-xiangshang'#13#10'icon iconfont icon-xiangxia'#13#10 +
          'icon iconfont icon-guanbishixin'#13#10'icon iconfont icon-guanbi3'#13#10 +
          'icon iconfont icon-gouxuan'#13#10'icon iconfont icon-cuocha_kuai'#13#10 +
          'icon iconfont icon-shezhi_2'#13#10));
        L('  end');

        // import popup
        if Plan.HasButton('btImport') then
        begin
          L('  object pmImport: TUgPopupMenu');
          L('    Left = 100');
          L('    Top = 550');
          L('    Items = <');
          L('      item');
          L('        Caption = ' + Q('文本格式'));
          L('      end');
          L('      item');
          L('        Caption = ' + Q('电子表格'));
          L('      end');
          for I := 0 to Plan.ImportCaptions.Count - 1 do
          begin
            L('      item');
            L('        Caption = ' + Q(Plan.ImportCaptions[I]));
            L('      end');
          end;
          L('      >');
          L('  end');
        end;

        // datasets
        // 非可视控件必须带设计期坐标：Imgs/pmImport 与数据集排在 550 行 20..420，
        // 三个弹窗沿用 80 间距排在其后，否则设计器会把它们堆到左上角 (0,0)。
        if HasError then
        begin
          L('  object errorAlert: TUgSweetAlert');
          L('    Left = 500');
          L('    Top = 550');
          L('    AlertType = atError');
          L('    ShowConfirmButton = True');
          L('    ShowCancelButton = False');
          L('  end');
        end;
        if HasNotice then
        begin
          L('  object noticeAlert: TUgSweetAlert');
          L('    Left = 580');
          L('    Top = 550');
          L('    AlertType = atInfo');
          L('    ShowConfirmButton = True');
          L('    ShowCancelButton = False');
          L('  end');
        end;
        if HasConfirm then
        begin
          L('  object confirmAlert: TUgSweetAlert');
          L('    Left = 660');
          L('    Top = 550');
          L('    AlertType = atQuestion');
          L('    ShowConfirmButton = True');
          L('    ShowCancelButton = True');
          L('    FocusCancel = True');
          L('    AllowOutsideClick = False');
          L('    AllowEscapeKey = True');
          L('  end');
        end;
        L('  object cdsMain: TUgClientDataSet');
        L('    Aggregates = <>');
        L('    Params = <>');
        L('    Left = 180');
        L('    Top = 550');
        L('    SelectMaxRecCount = 0');
        L('  end');
        L('  object dsMain: TUgDataSource');
        L('    DataSet = cdsMain');
        L('    Left = 260');
        L('    Top = 550');
        L('  end');
        L('  object cdsDetailed: TUgClientDataSet');
        L('    Aggregates = <>');
        L('    Params = <>');
        L('    Left = 340');
        L('    Top = 550');
        L('    SelectMaxRecCount = 0');
        L('  end');
        L('  object dsDetailed: TUgDataSource');
        L('    DataSet = cdsDetailed');
        L('    Left = 420');
        L('    Top = 550');
        L('  end');
        L('end');

        DFM := Lines.Text;
        Result := True;
      finally
        Lines.Free;
        Code.Free;
      end;
    finally
      Editable.Free;
      MainVisible.Free;
      DetailVisible.Free;
    end;
  finally
    Plan.Free;
  end;
end;

end.
