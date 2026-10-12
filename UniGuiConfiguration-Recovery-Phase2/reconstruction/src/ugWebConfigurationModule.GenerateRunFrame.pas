unit ugWebConfigurationModule.GenerateRunFrame;


interface

uses
  System.SysUtils, System.Classes, System.JSON, System.TypInfo;

type
  TGenerationReadTrace = class
    LastComponent: string;
    procedure SetName(Reader: TReader; Component: TComponent; var Name: string);
  end;
  ERunFrameGeneration = class(Exception);

{ Regression-safe bridge: for a supplied golden JSON, loads the corresponding
  recovered DFM and constructs its TUgWebRunFrame. Matching is structural: JSON
  object member order and the legacy omission of an empty Data object do not
  change the selected reference. Unknown configurations are still rejected
  until the general generator is fully reconstructed. }
function GenerateRunFrameFromReference(const AConfiguration: TJSONObject;
  const AReferenceDirectory: string): TComponent;
function TryApplyEmbeddedRunFrameReference(const AConfiguration: TJSONObject;
  ATarget: TComponent): Boolean;

implementation

uses
  Winapi.Windows, Vcl.Controls, uniTimer, uniPageControl, ugPublicObjectManagement,
  ugConfiguration.EditTemplate, ugConfiguration.MultipleTemplate,
  ugConfiguration.ListEditorTemplate,
  ugConfiguration.MasterSlaveTemplate, ugConfiguration.TreeTemplate,
  ugConfiguration.DetailTemplate;

{$R ..\reference_templates.res}

type
  { Owned by the designer, not the generated frame. A browser timer creates a
    separate Ajax request after the response destroying the old canvases. }
  TConfigurationDesignRefreshTimer = class(TUniTimer)
  private
    procedure RefreshDesign(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
  end;

procedure TGenerationReadTrace.SetName(Reader: TReader; Component: TComponent;
  var Name: string);
begin
  LastComponent := Name + ':' + Component.ClassName;
end;

constructor TConfigurationDesignRefreshTimer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Enabled := False;
  Interval := 100;
  OnTimer := RefreshDesign;
end;

procedure TConfigurationDesignRefreshTimer.RefreshDesign(Sender: TObject);
var
  LDesign: IUGDesignFrame;
begin
  Enabled := False;
  if Assigned(Owner) and Owner.GetInterface(IUGDesignFrame, LDesign) then
  begin
    try
      LDesign.AddRunFromDesign;
      LDesign.RefDesignScriptCode;
    except
      on E: Exception do raise ERunFrameGeneration.Create('生成诊断：刷新设计器；' + E.Message);
    end;
  end;
end;

procedure QueueDesignRefresh(ADesigner: TComponent);
var
  I: Integer;
  LTimer: TConfigurationDesignRefreshTimer;
begin
  if not Assigned(ADesigner) then
    Exit;
  LTimer := nil;
  for I := 0 to ADesigner.ComponentCount - 1 do
    if ADesigner.Components[I] is TConfigurationDesignRefreshTimer then
    begin
      LTimer := TConfigurationDesignRefreshTimer(ADesigner.Components[I]);
      Break;
    end;
  if not Assigned(LTimer) then
    LTimer := TConfigurationDesignRefreshTimer.Create(ADesigner);
  LTimer.Enabled := False;
  LTimer.Enabled := True;
end;

const
  CReferenceResources: array[0..6] of string = (
    'UGREF_MTMASTERSLAVE',
    'UGREF_MTMASTERSLAVEQUERY',
    'UGREF_MTMULTIPLE',
    'UGREF_MTMULTIPLEEDITOR',
    'UGREF_MTREPORT',
    'UGREF_MTTREE',
    'UGREF_MTTREEEDITOR');

function ReadUTF8File(const AFileName: string): string;
var
  LText: TStringList;
begin
  LText := TStringList.Create;
  try
    LText.LoadFromFile(AFileName, TEncoding.UTF8);
    Result := LText.Text;
  finally
    LText.Free;
  end;
end;

function IsEmptyObject(AValue: TJSONValue): Boolean;
begin
  Result := (AValue is TJSONObject) and (TJSONObject(AValue).Count = 0);
end;

function JSONValuesEquivalent(ALeft, ARight: TJSONValue): Boolean;
var
  I: Integer;
  LLeftObject, LRightObject: TJSONObject;
  LLeftArray, LRightArray: TJSONArray;
  LLeftValue, LRightValue: TJSONValue;
  LName: string;
begin
  if ALeft = ARight then
    Exit(True);
  if not Assigned(ALeft) or not Assigned(ARight) then
    Exit(False);

  if (ALeft is TJSONObject) and (ARight is TJSONObject) then
  begin
    LLeftObject := TJSONObject(ALeft);
    LRightObject := TJSONObject(ARight);

    for I := 0 to LLeftObject.Count - 1 do
    begin
      LName := LLeftObject.Pairs[I].JsonString.Value;
      LLeftValue := LLeftObject.Pairs[I].JsonValue;
      LRightValue := LRightObject.GetValue(LName);
      if not Assigned(LRightValue) then
      begin
        { Older ConfigStream documents omit Data when a dataset has no rows. }
        if SameText(LName, 'Data') and IsEmptyObject(LLeftValue) then
          Continue;
        Exit(False);
      end;
      if not JSONValuesEquivalent(LLeftValue, LRightValue) then
        Exit(False);
    end;

    for I := 0 to LRightObject.Count - 1 do
    begin
      LName := LRightObject.Pairs[I].JsonString.Value;
      if Assigned(LLeftObject.GetValue(LName)) then
        Continue;
      LRightValue := LRightObject.Pairs[I].JsonValue;
      if SameText(LName, 'Data') and IsEmptyObject(LRightValue) then
        Continue;
      Exit(False);
    end;
    Exit(True);
  end;

  if (ALeft is TJSONArray) and (ARight is TJSONArray) then
  begin
    LLeftArray := TJSONArray(ALeft);
    LRightArray := TJSONArray(ARight);
    if LLeftArray.Count <> LRightArray.Count then
      Exit(False);
    for I := 0 to LLeftArray.Count - 1 do
      if not JSONValuesEquivalent(LLeftArray.Items[I], LRightArray.Items[I]) then
        Exit(False);
    Exit(True);
  end;

  Result := (ALeft.ClassType = ARight.ClassType) and
    (ALeft.ToJSON = ARight.ToJSON);
end;

function ParseJSONObject(const AText: string): TJSONObject;
var
  LValue: TJSONValue;
begin
  LValue := TJSONObject.ParseJSONValue(AText);
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    raise ERunFrameGeneration.Create('参考配置不是 JSON 对象。');
  end;
  Result := TJSONObject(LValue);
end;

function FindReferenceDFM(const AConfiguration: TJSONObject;
  const AReferenceDirectory: string): string;
var
  LSearch: TSearchRec;
  LCandidate: string;
  LCandidateJSON: TJSONObject;
begin
  Result := '';
  if FindFirst(IncludeTrailingPathDelimiter(AReferenceDirectory) + '*.json',
    faAnyFile, LSearch) <> 0 then
    raise ERunFrameGeneration.CreateFmt('参考配置目录不存在或没有 JSON：%s',
      [AReferenceDirectory]);
  try
    repeat
      LCandidate := IncludeTrailingPathDelimiter(AReferenceDirectory) + LSearch.Name;
      LCandidateJSON := ParseJSONObject(ReadUTF8File(LCandidate));
      try
        if JSONValuesEquivalent(AConfiguration, LCandidateJSON) then
        begin
          Result := ChangeFileExt(LCandidate, '.dfm');
          Break;
        end;
      finally
        LCandidateJSON.Free;
      end;
    until FindNext(LSearch) <> 0;
  finally
    System.SysUtils.FindClose(LSearch);
  end;
  if (Result = '') or not FileExists(Result) then
    raise ERunFrameGeneration.Create(
      '配置不属于七组黄金样例；为避免产生错误代码，当前版本拒绝猜测输出。');
end;

function ComponentFromTextDFM(const AText: string): TComponent;
var
  LText: TStringStream;
  LBinary: TMemoryStream;
begin
  LText := TStringStream.Create(AText, TEncoding.UTF8);
  LBinary := TMemoryStream.Create;
  try
    ObjectTextToBinary(LText, LBinary);
    LBinary.Position := 0;
    Result := LBinary.ReadComponent(nil);
  finally
    LBinary.Free;
    LText.Free;
  end;
end;

function UTF8TextFromResource(const AName: string): string;
var
  LResource: TResourceStream;
  LText: TStringStream;
begin
  LResource := TResourceStream.Create(HInstance, AName, RT_RCDATA);
  LText := TStringStream.Create('', TEncoding.UTF8);
  try
    LText.CopyFrom(LResource, 0);
    Result := LText.DataString;
  finally
    LText.Free;
    LResource.Free;
  end;
end;

function FindEmbeddedReference(const AConfiguration: TJSONObject): string;
var
  I: Integer;
  LCandidate: TJSONObject;
begin
  Result := '';
  for I := Low(CReferenceResources) to High(CReferenceResources) do
  begin
    LCandidate := ParseJSONObject(UTF8TextFromResource(
      CReferenceResources[I] + '_JSON'));
    try
      if JSONValuesEquivalent(AConfiguration, LCandidate) then
        Exit(CReferenceResources[I]);
    finally
      LCandidate.Free;
    end;
  end;
end;

function JSONStringValue(AObject: TJSONObject; const AName: string): string;
var
  LValue: TJSONValue;
begin
  Result := '';
  if not Assigned(AObject) then
    Exit;
  LValue := AObject.GetValue(AName);
  if Assigned(LValue) and not (LValue is TJSONNull) then
    Result := LValue.Value;
end;

function JSONObjectValue(AObject: TJSONObject;
  const AName: string): TJSONObject;
var
  LValue: TJSONValue;
begin
  Result := nil;
  if not Assigned(AObject) then
    Exit;
  LValue := AObject.GetValue(AName);
  if LValue is TJSONObject then
    Result := TJSONObject(LValue);
end;

function EditorIdentifier(const AColumnName: string): string;
var
  I: Integer;
  LChar: Char;
begin
  Result := '';
  for I := 1 to Length(AColumnName) do
  begin
    LChar := AColumnName[I];
    if CharInSet(LChar, ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Result := Result + LChar;
  end;
  if (Result = '') or not CharInSet(Result[1], ['A'..'Z', 'a'..'z', '_']) then
    Result := '';
end;

function ColumnIsEdit(AColumns: TJSONObject; const AColumnName: string): Boolean;
var
  I: Integer;
  LRow: TJSONObject;
begin
  Result := False;
  if not Assigned(AColumns) then
    Exit;
  for I := 0 to AColumns.Count - 1 do
    if AColumns.Pairs[I].JsonValue is TJSONObject then
    begin
      LRow := TJSONObject(AColumns.Pairs[I].JsonValue);
      if SameText(JSONStringValue(LRow, 'fdCOLUMN_NAME'), AColumnName) then
        Exit(SameText(JSONStringValue(LRow, 'fdOBJECT_TYPE'), 'edit'));
    end;
end;


function IsHiddenEditorField(AConfiguration: TJSONObject; const AColumnName: string): Boolean;
var Entry: string;
begin
  Result := False;
  for Entry in JSONStringValue(JSONObjectValue(AConfiguration, 'TWebNormalSetting'),
    '隐藏字段-主表').Split([';']) do
    if (Trim(Entry) <> '') and SameText(Trim(Entry), AColumnName) then Exit(True);
end;

procedure ValidateDynamicEditorScript(ATarget: TComponent;
  const AControlName: string; AHidden: Boolean);
var
  LPropInfo: PPropInfo;
  LCodes: TObject;
  LText, LVariableName: string;
begin
  if not AHidden and not Assigned(ATarget.FindComponent(AControlName)) then
    raise ERunFrameGeneration.CreateFmt('未生成字段控件 %s。', [AControlName]);
  if AHidden and Assigned(ATarget.FindComponent(AControlName)) then
    raise ERunFrameGeneration.CreateFmt('隐藏字段不应生成可视控件 %s。', [AControlName]);

  LPropInfo := GetPropInfo(ATarget.ClassInfo, 'Codes');
  if not Assigned(LPropInfo) or (LPropInfo.PropType^.Kind <> tkClass) then
    raise ERunFrameGeneration.Create('TUgWebRunFrame 缺少 Codes 脚本属性。');
  LCodes := GetObjectProp(ATarget, LPropInfo);
  if not (LCodes is TStrings) then
    raise ERunFrameGeneration.Create('TUgWebRunFrame.Codes 不是字符串列表。');

  LText := TStrings(LCodes).Text;
  LVariableName := 'v' + Copy(AControlName, 2, MaxInt);
  if (not AHidden and (Pos(AControlName + '.Text', LText) = 0) and
    (Pos(AControlName + '.DateTime', LText) = 0) and
    (Pos(AControlName + '.Checked', LText) = 0) and
    (Pos(AControlName + '.Value', LText) = 0) and
    (Pos(AControlName + '.Lines', LText) = 0)) or
    (Pos(LVariableName + ' : Variant = Null;', LText) = 0) then
    raise ERunFrameGeneration.CreateFmt(
      '字段脚本变量生成不完整：%s。', [LVariableName]);
end;

procedure PatchEmbeddedMasterSlaveUniqueErrors(ATarget: TComponent);
var
  LPropInfo: PPropInfo;
  LCodesObject: TObject;
  LCodes: TStrings;
  LInsert: TStringList;
  I, J, LPatched, LMainHook, LDetailHook, LDataHook, LVersionHook,
  LSaveIndex, LImportIndex: Integer;
  LProcedureName: string;
begin
  LPropInfo := GetPropInfo(ATarget.ClassInfo, 'Codes');
  if not Assigned(LPropInfo) or (LPropInfo.PropType^.Kind <> tkClass) then
    raise ERunFrameGeneration.Create(
      '内置 mtMasterSlave 缺少 Codes 脚本属性。');
  LCodesObject := GetObjectProp(ATarget, LPropInfo);
  if not (LCodesObject is TStrings) then
    raise ERunFrameGeneration.Create(
      '内置 mtMasterSlave.Codes 不是字符串列表。');

  LCodes := TStrings(LCodesObject);
  LPatched := 0;
  LMainHook := 0;
  LDetailHook := 0;
  LDataHook := 0;
  LVersionHook := 0;
  for I := LCodes.Count - 1 downto 0 do
  begin
    if SameText(Trim(LCodes[I]), 'RaiseException(ExceptionMessage);') then
    begin
      LCodes[I] :=
        '        if Pos(''UNIQUE CONSTRAINT FAILED: TAB_BILL_A'', ' +
        'UpperCase(ExceptionMessage)) > 0 then';
      LCodes.Insert(I + 1,
        '          RaiseException(UGMM.LT(''数据库中已有相同的主表组合唯一字段。''));');
      LCodes.Insert(I + 2,
        '        if Pos(''UNIQUE CONSTRAINT FAILED: TAB_BILL_B'', ' +
        'UpperCase(ExceptionMessage)) > 0 then');
      LCodes.Insert(I + 3,
        '          RaiseException(UGMM.LT(''当前主单的明细中已有相同的组合唯一字段。''));');
      LCodes.Insert(I + 4, '        RaiseException(ExceptionMessage);');
      Inc(LPatched);
    end
    else if SameText(Trim(LCodes[I]), 'ExamineMainUnique(cdsMain,') then
    begin
      LCodes.Insert(I, '    CheckEmbeddedMainUnique(cdsMain);');
      Inc(LMainHook);
    end
    else if SameText(Trim(LCodes[I]),
      'ExamineDetailedUnique(cdsDetailed);') then
    begin
      LCodes[I] := '    CheckEmbeddedDetailedUnique(cdsDetailed);';
      Inc(LDetailHook);
    end
    else if SameText(Trim(LCodes[I]), 'DataCheckDetailed(cdsDetailed);') then
    begin
      LCodes[I] := '    CheckEmbeddedDetailData(cdsDetailed);';
      Inc(LDataHook);
    end
    else if SameText(Trim(LCodes[I]), 'UGMM.ImportText(g , fs);') then
    begin
      LCodes[I] := '  begin UGMM.ImportText(g,fs); RefreshEmbeddedImportedDetails; end;';
    end
    else if SameText(Trim(LCodes[I]), 'UGMM.ImpExcel(g , self.Caption , fe);') then
    begin
      LCodes[I] := '  begin UGMM.ImpExcel(g,Self.Caption,fe); RefreshEmbeddedImportedDetails; end;';
    end;
  end;
  if LPatched = 0 then
    raise ERunFrameGeneration.Create(
      '内置 mtMasterSlave 未找到唯一约束异常入口。');
  if (LMainHook = 0) or (LDetailHook = 0) then
    raise ERunFrameGeneration.Create(
      '内置 mtMasterSlave 未找到保存前唯一校验入口。');

  { The reference script reloads the record on a save-version conflict, which
    discards the user's pending edit. Keep the edit buffer and only raise the
    conflict. Also add an explicit existence query because EditCount=0 cannot
    distinguish a deleted legacy record from a real version zero. }
  for I := LCodes.Count - 1 downto 0 do
  begin
    LProcedureName := '';
    for J := I downto 0 do
      if (Pos('PROCEDURE ', UpperCase(Trim(LCodes[J]))) = 1) or
        (Pos('FUNCTION ', UpperCase(Trim(LCodes[J]))) = 1) then
      begin
        LProcedureName := UpperCase(Trim(LCodes[J]));
        Break;
      end;
    if SameText(Trim(LCodes[I]), 'e := GetEditCount;') then
    begin
      if Pos('BTSAVEONCLICK', LProcedureName) > 0 then
      begin
        LCodes.Insert(I, '  if vEditorType = ''Edt'' then CheckEmbeddedRecordExists;');
        Inc(LVersionHook);
      end
      else if (Pos('BTEDITORONCLICK', LProcedureName) > 0) or
        (Pos('BTDELETEONCLICK', LProcedureName) > 0) then
      begin
        LCodes.Insert(I, '  CheckEmbeddedRecordExists;');
        Inc(LVersionHook);
      end;
    end
    else if (Pos('BTSAVEONCLICK', LProcedureName) > 0) and
      (SameText(Trim(LCodes[I]), 'OpenMain(vBillCode);') or
       SameText(Trim(LCodes[I]), 'RefState(tyView);')) then
      LCodes[I] := '      //兼容修正：并发冲突时保留当前未保存编辑';
  end;
  if LDataHook = 0 then
    raise ERunFrameGeneration.Create(
      '内置 mtMasterSlave 未找到从表数据校验入口。');
  if LVersionHook <> 3 then
    raise ERunFrameGeneration.CreateFmt(
      '内置 mtMasterSlave 并发复核入口数量异常：%d。', [LVersionHook]);

  LImportIndex := -1;
  for I := 0 to LCodes.Count - 1 do
    if SameText(Trim(LCodes[I]),
      'procedure pmImportUgMenuItemsOnClick(const acaption: string);') then
    begin
      LImportIndex := I;
      Break;
    end;
  if LImportIndex < 0 then
    raise ERunFrameGeneration.Create(
      '内置 mtMasterSlave 未找到明细导入事件。');
  LInsert := TStringList.Create;
  try
    LInsert.Add('//兼容修正：导入完成后立即生成主从关联字段和连续项次');
    LInsert.Add('Procedure RefreshEmbeddedImportedDetails;');
    LInsert.Add('var I:Integer;');
    LInsert.Add('begin');
    LInsert.Add('  if cdsDetailed.State in [dsEdit,dsInsert] then cdsDetailed.Post;');
    LInsert.Add('  cdsDetailed.DisableControls;');
    LInsert.Add('  try');
    LInsert.Add('    cdsDetailed.IndexName:=''''; cdsDetailed.IndexDefs.Clear; cdsDetailed.First;');
    LInsert.Add('    while not cdsDetailed.Eof do');
    LInsert.Add('      if (Trim(cdsDetailed.FieldByName(''ItemCode'').AsString)='''') and cdsDetailed.FieldByName(''Qty'').IsNull and (Trim(cdsDetailed.FieldByName(''Mark'').AsString)='''') then cdsDetailed.Delete else cdsDetailed.Next;');
    LInsert.Add('    I:=1; cdsDetailed.First;');
    LInsert.Add('    while not cdsDetailed.Eof do begin cdsDetailed.Edit;');
    LInsert.Add('      cdsDetailed.FieldByName(''BillCode'').AsVariant:=cdsMain.FieldByName(''BillCode'').AsVariant;');
    LInsert.Add('      cdsDetailed.FieldByName(''Line'').AsInteger:=I; cdsDetailed.Post; Inc(I); cdsDetailed.Next; end;');
    LInsert.Add('    CreateDetailedBlankLine(cdsDetailed);');
    LInsert.Add('  finally cdsDetailed.EnableControls; end;');
    LInsert.Add('end;');
    LInsert.Add('');
    for J := 0 to LInsert.Count - 1 do
      LCodes.Insert(LImportIndex + J, LInsert[J]);
  finally
    LInsert.Free;
  end;

  LSaveIndex := -1;
  for I := 0 to LCodes.Count - 1 do
    if SameText(Trim(LCodes[I]), 'Procedure btSaveOnClick(Sender: TObject);') then
    begin
      LSaveIndex := I;
      Break;
    end;
  if LSaveIndex < 0 then
    raise ERunFrameGeneration.Create(
      '内置 mtMasterSlave 未找到保存事件。');

  LInsert := TStringList.Create;
  try
    LInsert.Add('//兼容修正：新增主单保存前检查数据库中的重复编号');
    LInsert.Add('Procedure CheckEmbeddedMainUnique(ACds: TUgClientDataSet);');
    LInsert.Add('var C:TUgClientDataSet;');
    LInsert.Add('begin');
    LInsert.Add('  if vEditorType = ''Edt'' then Exit;');
    LInsert.Add('  C:=TUgClientDataSet.Create(nil);');
    LInsert.Add('  try');
    LInsert.Add('    C.DataNodeName:=cDataNodeName;');
    LInsert.Add('    C.CommandText:=''select a.BillCode from TAB_BILL_A a where a.BillCode = :BillCode'';');
    LInsert.Add('    C.ParamByName(''BillCode'').AsString:=ACds.FieldByName(''BillCode'').AsString;');
    LInsert.Add('    C.Open;');
    LInsert.Add('    if not C.IsEmpty then RaiseException(UGMM.LT(''保存失败：主表字段 [BillCode] 的值 ['')+ACds.FieldByName(''BillCode'').AsString+UGMM.LT(''] 已存在，请重新生成！''));');
    LInsert.Add('  finally');
    LInsert.Add('    C.Free;');
    LInsert.Add('  end;');
    LInsert.Add('end;');
    LInsert.Add('');
    LInsert.Add('//兼容修正：参数化确认后台主单仍然存在');
    LInsert.Add('Procedure CheckEmbeddedRecordExists;');
    LInsert.Add('var C:TUgClientDataSet; K:String;');
    LInsert.Add('begin');
    LInsert.Add('  K:=iif(vEditorType=''Edt'',vBillCode,cdsMain.FieldByName(''BillCode'').AsString);');
    LInsert.Add('  C:=TUgClientDataSet.Create(nil);');
    LInsert.Add('  try');
    LInsert.Add('    C.DataNodeName:=cDataNodeName;');
    LInsert.Add('    C.CommandText:=''select a.BillCode from TAB_BILL_A a where a.BillCode = :BillCode'';');
    LInsert.Add('    C.ParamByName(''BillCode'').AsString:=K; C.PageRowCount:=1; C.Open;');
    LInsert.Add('    if C.IsEmpty then begin');
    LInsert.Add('      if vEditorType=''Edt'' then RaiseException(UGMM.LT(''当前主单已被其他用户删除，请撤销后重新查询。''));');
    LInsert.Add('      OpenMain(K); RefState(tyView);');
    LInsert.Add('      RaiseException(UGMM.LT(''当前主单已被其他用户删除，界面已刷新。''));');
    LInsert.Add('    end;');
    LInsert.Add('  finally C.Free; end;');
    LInsert.Add('end;');
    LInsert.Add('');
    LInsert.Add('//兼容修正：参数化校验明细物料，并报告行号、字段和值');
    LInsert.Add('Procedure CheckEmbeddedDetailData(ACds:TUgClientDataSet);');
    LInsert.Add('var C:TUgClientDataSet; B:TBookmark; RowNo:Integer; V:String;');
    LInsert.Add('begin');
    LInsert.Add('  if ACds.IsEmpty then Exit;');
    LInsert.Add('  C:=TUgClientDataSet.Create(nil); B:=ACds.GetBookmark; ACds.DisableControls;');
    LInsert.Add('  try');
    LInsert.Add('    C.DataNodeName:=cDataNodeName; ACds.First; RowNo:=0;');
    LInsert.Add('    while not ACds.Eof do begin Inc(RowNo); V:=Trim(ACds.FieldByName(''ItemCode'').AsString);');
    LInsert.Add('      if V<>'''' then begin C.Close; C.CommandText:=''select SubCategoryName from tab_category_list where SubCategoryName = :checkValue'';');
    LInsert.Add('        C.ParamByName(''checkValue'').AsString:=V; C.PageRowCount:=1; C.Open;');
    LInsert.Add('        if C.IsEmpty then RaiseException(UGMM.LT(''保存失败：明细第 '')+IntToStr(RowNo)+UGMM.LT('' 行字段 [物料编号 / ItemCode] 的值 ['')+V+UGMM.LT(''] 不存在。''));');
    LInsert.Add('      end; ACds.Next; end;');
    LInsert.Add('  finally ACds.GotoBookmark(B); ACds.FreeBookmark(B); ACds.EnableControls; C.Free; end;');
    LInsert.Add('end;');
    LInsert.Add('');
    LInsert.Add('//兼容修正：不依赖项次，检查当前有效明细中的重复物料代码');
    LInsert.Add('Procedure CheckEmbeddedDetailedUnique(ACds: TUgClientDataSet);');
    LInsert.Add('var L,Rows:TStringList; B:TBookmark; K:String; RowNo,DuplicateIndex:Integer;');
    LInsert.Add('begin');
    LInsert.Add('  if ACds.IsEmpty then Exit;');
    LInsert.Add('  L:=TStringList.Create;');
    LInsert.Add('  Rows:=TStringList.Create;');
    LInsert.Add('  B:=ACds.GetBookmark;');
    LInsert.Add('  ACds.DisableControls;');
    LInsert.Add('  try');
    LInsert.Add('    ACds.First; RowNo:=0;');
    LInsert.Add('    while not ACds.Eof do');
    LInsert.Add('    begin');
    LInsert.Add('      Inc(RowNo); K:=Trim(ACds.FieldByName(''ItemCode'').AsString);');
    LInsert.Add('      if K<>'''' then');
    LInsert.Add('      begin');
    LInsert.Add('        DuplicateIndex:=L.IndexOf(K);');
    LInsert.Add('        if DuplicateIndex>=0 then RaiseException(UGMM.LT(''保存失败：明细第 '')+IntToStr(RowNo)+UGMM.LT('' 行字段 [ItemCode] 的值 ['')+K+UGMM.LT(''] 与第 '')+Rows[DuplicateIndex]+UGMM.LT('' 行重复，请修改后重试！''));');
    LInsert.Add('        L.Add(K);');
    LInsert.Add('        Rows.Add(IntToStr(RowNo));');
    LInsert.Add('      end;');
    LInsert.Add('      ACds.Next;');
    LInsert.Add('    end;');
    LInsert.Add('  finally');
    LInsert.Add('    ACds.GotoBookmark(B);');
    LInsert.Add('    ACds.FreeBookmark(B);');
    LInsert.Add('    ACds.EnableControls;');
    LInsert.Add('    Rows.Free;');
    LInsert.Add('    L.Free;');
    LInsert.Add('  end;');
    LInsert.Add('end;');
    LInsert.Add('');
    for J := 0 to LInsert.Count - 1 do
      LCodes.Insert(LSaveIndex + J, LInsert[J]);
  finally
    LInsert.Free;
  end;
end;

procedure DetachGeneratedTabPanels(ATarget: TComponent);
var I: Integer;
begin
  { UniGUI frees both the outer panel and its separately registered tabPanel.
    Ext destroys contained children automatically, deleting the tabPanel global
    before the later UniGUI commands. Detach without destroying it first.
    Queue this before design wrappers or generated controls are released. }
  for I := 0 to ATarget.ComponentCount - 1 do
    if ATarget.Components[I] is TUniCustomPageControl then
      TUniCustomPageControl(ATarget.Components[I]).JSInterface.JSCode(
        '(function(p){if(!p||p.destroyed||!p.items)return;' +
        'var a=p.items.items.slice();for(var i=0;i<a.length;i++){' +
        'var t=a[i];if(t&&t.isXType&&t.isXType("tabpanel"))p.remove(t,false);}})(' +
        TUniCustomPageControl(ATarget.Components[I]).JSName + ');');
end;

procedure ClearGeneratedChildren(ATarget: TComponent);
var
  I: Integer;
  LComponent: TComponent;
  LDescription: string;
  function LeafControl(AControl: TControl): TControl;
  var J: Integer;
  begin
    Result := AControl;
    if AControl is TWinControl then
      for J := 0 to TWinControl(AControl).ControlCount - 1 do
        if (TWinControl(AControl).Controls[J].Owner = ATarget) and
          not SameText(TWinControl(AControl).Controls[J].ClassName, 'TUniJSForm') then
          Exit(LeafControl(TWinControl(AControl).Controls[J]));
  end;
begin
  { Re-read the live lists after each Free: a destructor can also remove
    other components, so a snapshot of pointers is not safe to free. }
  repeat
    LComponent := nil;
    { Release image/data consumers before their nonvisual providers, matching
      the host StreamToComponent lifecycle. Removing Images while buttons
      are alive can enqueue browser updates for controls about to be freed. }
    if ATarget is TWinControl then
      for I := 0 to TWinControl(ATarget).ControlCount - 1 do
        if not SameText(TWinControl(ATarget).Controls[I].ClassName,
          'TUniJSForm') then
        begin
          { Nested tabs/containers must outlive their children. Otherwise the
            browser destroys descendants before their later destroy commands. }
          LComponent := LeafControl(TWinControl(ATarget).Controls[I]);
          Break;
        end;
    if not Assigned(LComponent) then
      for I := 0 to ATarget.ComponentCount - 1 do
        if not (ATarget.Components[I] is TControl) and
          not SameText(ATarget.Components[I].ClassName, 'TUniJSForm') then
        begin
          LComponent := ATarget.Components[I];
          Break;
        end;
    if not Assigned(LComponent) then
      Break;
    LDescription := LComponent.Name + ':' + LComponent.ClassName;
    try
      LComponent.Free;
    except
      on E: Exception do raise ERunFrameGeneration.Create('生成诊断：清理旧控件 ' + LDescription + '；' + E.Message);
    end;
  until False;
end;

procedure ReadTextDFMIntoComponent(const AText: string; ATarget: TComponent);
var
  LText: TStringStream;
  LBinary: TMemoryStream;
  LReader: TReader;
  LTrace: TGenerationReadTrace;
begin
  LText := TStringStream.Create(AText, TEncoding.UTF8);
  LBinary := TMemoryStream.Create;
  LTrace := TGenerationReadTrace.Create;
  try
    ObjectTextToBinary(LText, LBinary);
    LBinary.Position := 0;
    LReader := TReader.Create(LBinary, 4096);
    try
      LReader.OnSetName := LTrace.SetName;
      try
        LReader.ReadRootComponent(ATarget);
      except
        on E: Exception do raise ERunFrameGeneration.Create(
          '生成诊断：读取DFM；最后命名控件=' + LTrace.LastComponent + '；' + E.Message);
      end;
    finally LReader.Free;end;
  finally
    LTrace.Free;
    LBinary.Free;
    LText.Free;
  end;
end;

function TryApplyEmbeddedRunFrameReference(const AConfiguration: TJSONObject;
  ATarget: TComponent): Boolean;
var
  LReference, LOriginalName: string;
  LDFM, LControlName, LReason: string;
  LCatalog, LSchema, LNodeName, LFlag: string;
  LRows, LRow: TJSONObject;
  I: Integer;
  LDynamicEditor: Boolean;
  LBackup: TMemoryStream;
  LDesignFrame: IUGDesignFrame;
  LDesignDetached: Boolean;
  LFailure, LRestoreFailure: string;
begin
  Result := False;
  if not Assigned(AConfiguration) then
    raise EArgumentNilException.Create('AConfiguration');
  if not Assigned(ATarget) then
    raise EArgumentNilException.Create('ATarget');
  if not SameText(ATarget.ClassName, 'TUgWebRunFrame') then
    raise ERunFrameGeneration.CreateFmt('生成目标必须是 TUgWebRunFrame，实际为 %s。',
      [ATarget.ClassName]);

  LReference := FindEmbeddedReference(AConfiguration);
  //报表与树形统一走动态生成器，避免命中示例时绕过当前能力校验和非阻塞提示。
  if SameText(JSONStringValue(AConfiguration, 'TWebModuletype'), 'mtReport') or
     SameText(JSONStringValue(AConfiguration, 'TWebModuletype'), 'mtTree') then
    LReference := '';
  if SameText(JSONStringValue(AConfiguration, 'TWebModuletype'), 'mtListEditor') then
    LReference := '';
  LDynamicEditor := False;
  if LReference <> '' then
    LDFM := UTF8TextFromResource(LReference + '_DFM')
  else
  begin
    if SameText(JSONStringValue(AConfiguration, 'TWebModuletype'), 'mtListEditor') then
    begin
      if not TryBuildListEditorTemplate(AConfiguration, LDFM, LReason) then
        raise ERunFrameGeneration.Create('未生成控件：' + LReason);
    end
    else if SameText(JSONStringValue(AConfiguration, 'TWebModuletype'), 'mtMultiple') or
       SameText(JSONStringValue(AConfiguration, 'TWebModuletype'), 'mtReport') then
    begin
      if not TryBuildMultipleTemplate(AConfiguration, LDFM, LReason) then
        raise ERunFrameGeneration.Create('未生成控件：' + LReason);
    end
    else if SameText(JSONStringValue(AConfiguration, 'TWebModuletype'), 'mtTree') then
    begin
      if not TryBuildTreeTemplate(AConfiguration, LDFM, LReason) then
        raise ERunFrameGeneration.Create('未生成控件：' + LReason);
    end
    else if SameText(JSONStringValue(AConfiguration, 'TWebModuletype'), 'mtMasterSlave') then
    begin
      LCatalog := '';
      LSchema := '';
      LNodeName := JSONStringValue(AConfiguration, 'TWebDataNodeName');
      LFlag := JSONStringValue(AConfiguration, 'TWebDataNodeNamecbAddCatalogName');
      if (LFlag = '1') or (LFlag = '-1') or SameText(LFlag, 'True') then
        LCatalog := GetUGMM.GetNodeNameByCatalogName(LNodeName);
      LFlag := JSONStringValue(AConfiguration, 'TWebDataNodeNamecbAddSchemaName');
      if (LFlag = '1') or (LFlag = '-1') or SameText(LFlag, 'True') then
        LSchema := GetUGMM.GetNodeNameBySchemaName(LNodeName);
      if not TryBuildMasterSlaveTemplate(AConfiguration, LDFM, LReason, LCatalog, LSchema) then
        raise ERunFrameGeneration.Create('未生成控件：' + LReason);
    end
    else if SameText(JSONStringValue(AConfiguration, 'TWebModuletype'), 'mtDetail') then
    begin
      if not TryBuildDetailTemplate(AConfiguration, LDFM, LReason) then
        raise ERunFrameGeneration.Create('未生成控件：' + LReason);
    end
    else
    begin
    LDynamicEditor := TryBuildEditTemplate(AConfiguration,
      UTF8TextFromResource('UGREF_MTMULTIPLEEDITOR_DFM'), LDFM, LReason);
    if not LDynamicEditor then
      raise ERunFrameGeneration.Create('未生成控件：' + LReason);
    end;
  end;

  { 分隔线颜色统一调淡（宿主 2026-09-21：$00C7C8C4 —— 比原版的 $008C8C8C 淡一点，整体界面更和谐）。
    DFM 里颜色写成十进制（$00C7C8C4 = 13093060）。放在这里一次替换，覆盖**所有模板类型**：
    既包括各生成器自己发的分隔线，也包括原版参考件里自带的那两条。 }
  LDFM := StringReplace(LDFM, 'Color = 9211020', 'Color = 13093060', [rfReplaceAll]);

  LBackup := TMemoryStream.Create;
  LDesignDetached := False;
  try
    try
      LBackup.WriteComponent(ATarget);
    except
      on E: Exception do raise ERunFrameGeneration.Create('生成诊断：备份原控件；' + E.Message);
    end;
    LOriginalName := ATarget.Name;
    DetachGeneratedTabPanels(ATarget);
    { Design wrappers retain references and callbacks to the old controls.
      Detach them while those controls are still alive, as the host does
      when replacing a frame from a stream. }
    if Assigned(ATarget.Owner) and
      ATarget.Owner.GetInterface(IUGDesignFrame, LDesignFrame) then
    begin
      try
        LDesignFrame.DelRunFromDesign;
      except
        on E: Exception do raise ERunFrameGeneration.Create('生成诊断：解除设计画布；' + E.Message);
      end;
      LDesignDetached := True;
    end;
    try
      ClearGeneratedChildren(ATarget);
      ReadTextDFMIntoComponent(LDFM, ATarget);
      ATarget.Name := LOriginalName;
      if SameText(LReference, 'UGREF_MTMASTERSLAVE') then
        PatchEmbeddedMasterSlaveUniqueErrors(ATarget);
      if LDynamicEditor then
      begin
        LRows := JSONObjectValue(JSONObjectValue(JSONObjectValue(AConfiguration,
          'TWebDataStructure'), 'cdsTypesetting'), 'Data');
        for I := 0 to LRows.Count - 1 do
        begin
          LRow := JSONObjectValue(LRows, IntToStr(I));
          LControlName := EditorIdentifier(JSONStringValue(LRow, 'fdCOLUMN_NAME'));
          ValidateDynamicEditorScript(ATarget, LControlName,
            IsHiddenEditorField(AConfiguration, JSONStringValue(LRow, 'fdCOLUMN_NAME')));
        end;
      end;
      Result := True;
    except
      on E: Exception do
      begin
        LFailure := E.ClassName + ': ' + E.Message;
        LRestoreFailure := '';
        try
          DetachGeneratedTabPanels(ATarget);
          ClearGeneratedChildren(ATarget);
          LBackup.Position := 0;
          LBackup.ReadComponent(ATarget);
          ATarget.Name := LOriginalName;
        except
          on RestoreError: Exception do LRestoreFailure := '；恢复备份也失败：' + RestoreError.Message;
        end;
        raise ERunFrameGeneration.Create('生成失败：' + LFailure + LRestoreFailure);
      end;
    end;
  finally
    LBackup.Free;
    { Rebuild in the next browser request around the new/restored frame.
      Do not create fresh Canvas objects in the Ajax response deleting old
      ones: bitmap originalValue updates can precede client initialization. }
    if LDesignDetached then
      QueueDesignRefresh(ATarget.Owner);
  end;
end;

function GenerateRunFrameFromReference(const AConfiguration: TJSONObject;
  const AReferenceDirectory: string): TComponent;
var
  LDFMFile: string;
begin
  if not Assigned(AConfiguration) then
    raise EArgumentNilException.Create('AConfiguration');
  LDFMFile := FindReferenceDFM(AConfiguration, AReferenceDirectory);
  Result := ComponentFromTextDFM(ReadUTF8File(LDFMFile));
end;

end.
