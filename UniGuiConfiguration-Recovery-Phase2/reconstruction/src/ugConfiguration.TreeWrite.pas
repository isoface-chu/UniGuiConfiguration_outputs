unit ugConfiguration.TreeWrite;
interface
uses System.Classes,System.SysUtils,System.JSON,ugConfiguration.TreePlan;
function AddTreeWrite(Config:TJSONObject;const P:TTreePlan;Fields,Captions,Editable,Buttons,Code:TStrings;out Reason:string):Boolean;
implementation
uses ugConfiguration.MultipleRecord,ugConfiguration.TreeMove,System.RegularExpressions;
function Text(O:TJSONObject;const K:string):string;
var V:TJSONValue;
begin Result:='';if O=nil then Exit;V:=O.GetValue(K);if Assigned(V)and not(V is TJSONNull)then Result:=V.Value;end;
function Nested(O:TJSONObject;const K:string):TJSONObject;
var V,Parsed:TJSONValue;
begin
  Result:=nil;V:=O.GetValue(K);
  if V is TJSONObject then Result:=TJSONObject(V.Clone)
  else if V<>nil then begin
    Parsed:=TJSONObject.ParseJSONValue(V.Value);
    if Parsed is TJSONObject then Result:=TJSONObject(Parsed) else Parsed.Free;
  end;
end;
function AddTreeWrite(Config:TJSONObject;const P:TTreePlan;Fields,Captions,Editable,Buttons,Code:TStrings;out Reason:string):Boolean;
var Settings,UniqueRule,Auto:TJSONObject;Required,UniqueFields,Init,Temp,EditorInputs:TStringList;
  F,S:string;I,J:Integer;Audit:array[0..5]of string;AuditNames:array[0..5]of string;Scoped,EditableDepartment:Boolean;
  procedure A(const S:string);begin Code.Add(S);end;
  function Fail(const S:string):Boolean;begin Reason:=S;Result:=False;end;
  function ReadFields(const Value:string;Target:TStrings):Boolean;
  var Part,N,Entry:string;
  begin Result:=False;for Entry in Value.Split([';'])do if Trim(Entry)<>''then begin
    Part:=Trim(Entry);
    if not SameText(Copy(Part,1,Length(P.AliasName)+1),P.AliasName+'.')then Exit;
    N:=Copy(Part,Length(P.AliasName)+2,MaxInt);if Fields.IndexOf(N)<0 then Exit;
    if Target.IndexOf(N)<0 then Target.Add(N);
  end;Result:=True;end;
  procedure Handler(const Name,Action:string);
  var HintText:string;
  begin
    if Buttons.IndexOf(Name)<0 then Exit;
    HintText:=Name;
    if Name='btAppend' then HintText:='新增当前节点的子节点，编辑确认后暂存';
    if Name='btEditor' then HintText:='修改选中节点的业务字段，保留主键与审计字段';
    if Name='btDelete' then HintText:='确认后暂存删除，不允许删除含子节点的记录';
    if Name='btSave' then HintText:='校验并提交暂存修改，区分提交成功与刷新失败';
    if Name='btCancel' then HintText:='撤销暂存修改并恢复树视图';
    if Name='btUp' then HintText:='当前节点在同级中上移';
    if Name='btDown' then HintText:='当前节点在同级中下移';
    if Name='btLeft' then HintText:='当前节点连同子树提升一级';
    if Name='btRight' then HintText:='当前节点连同子树移入前一个同级节点';
    A('//'+HintText+'；异常提示后恢复按钮状态');
    A('procedure '+Name+'OnClick(Sender: TObject);');A('begin');
    A('  if TreeBusy or not TreeReady or not '+Name+'.Enabled then Exit;');
    A('  TreeBusy := True;');A('  try');A('    try');A('      '+Action);
    A('    except ShowTreeError(ExceptionMessage); end;');
    A('  finally TreeBusy := False; RefreshTreeState; end;');A('end;');
  end;
begin
  Result:=False;Reason:='';Settings:=Config.GetValue<TJSONObject>('TWebNormalSetting');
  Scoped:=SameText(Text(Settings,'层级权限'),'True')or(Text(Settings,'层级权限')='1')or(Text(Settings,'层级权限')='-1');
  AuditNames[0]:='录入用户';AuditNames[1]:='录入部门';AuditNames[2]:='录入时间';
  AuditNames[3]:='修改用户';AuditNames[4]:='修改部门';AuditNames[5]:='修改时间';
  for F in TArray<string>.Create('btSave','btCancel')do if Buttons.IndexOf(F)<0 then Exit(Fail('树形编辑必须同时启用保存和撤销按钮。'));
  if ((Buttons.IndexOf('btAppend')>=0)or(Buttons.IndexOf('btEditor')>=0))and(P.EditorFrame='')then Exit(Fail('请设置树形模块的编辑窗体。'));
  if ((Buttons.IndexOf('btAppend')>=0)or(Buttons.IndexOf('btEditor')>=0))and(Editable.Count=0)then Exit(Fail('请选择至少一个非主键、非父键、非排序的编辑字段。'));
  UniqueRule:=nil;Auto:=nil;Required:=TStringList.Create;UniqueFields:=TStringList.Create;Init:=TStringList.Create;Temp:=TStringList.Create;
  EditorInputs:=TStringList.Create;
  try
    EditorInputs.Assign(Editable);
    UniqueRule:=Nested(Settings,'主表唯一');
    if not ReadFields(Text(UniqueRule,'cdsMultiSelectFields'),UniqueFields)then Exit(Fail('组合唯一字段必须属于树形根表。'));
    if not ReadFields(Text(Settings,'非空字段'),Required)then Exit(Fail('非空字段必须属于树形根表。'));
    if Buttons.IndexOf('btAppend')>=0 then begin
      Auto:=Nested(Settings,'自动编号');
      if not SameText(Text(Auto,'cbAutoNumberType'),'Guid')or not SameText(Text(Auto,'cbField'),P.AliasName+'.'+P.KeyField)then
        Exit(Fail('本批树形新增请将自动编号设置为节点主键字段的 Guid 方式。'));
    end;
    EditableDepartment:=False;
    for I:=0 to 5 do begin
      F:=Text(Settings,AuditNames[I]);Audit[I]:='';if F=''then Continue;
      Temp.Clear;if not ReadFields(F,Temp)or(Temp.Count<>1)then Exit(Fail('无效审计字段：'+AuditNames[I]));
      Audit[I]:=Temp[0];
      if SameText(Audit[I],P.KeyField)or SameText(Audit[I],P.ParentField)or SameText(Audit[I],P.OrderField)then Exit(Fail('审计字段不能覆盖树形结构字段。'));
      for J:=0 to I-1 do if SameText(Audit[J],Audit[I])then Exit(Fail('不同审计设置不能共用同一字段。'));
      J:=Editable.IndexOf(Audit[I]);
      // Without hierarchy filtering, a visible editable department field is
      // business input. Keep hidden audit fields and scoped ownership protected.
      if (I=1)and not Scoped and(J>=0)then EditableDepartment:=True
      else if J>=0 then Editable.Delete(J);
    end;
    // Clear only after validating all audit mappings, preserving collision checks.
    if EditableDepartment then Audit[1]:='';
    Temp.Clear;
    if ((Buttons.IndexOf('btAppend')>=0)or(Buttons.IndexOf('btEditor')>=0))and(Editable.Count=0)then
      Exit(Fail('请选择至少一个非审计字段的编辑字段。'));
    if Required.IndexOf(P.KeyField)<0 then Required.Add(P.KeyField);
    A('//仅在读取权限后保存允许状态，刷新按钮不会覆盖权限禁用');
    A('var TreeBusy: Boolean = False; TreeNeedsReload: Boolean = False;');
    A('  TreeParent, TreeOrder: string;');
    for F in Buttons do if F<>''then A('  Allow'+F+': Boolean = False;');
    A('procedure CaptureTreePermissions;');A('begin');
    for F in Buttons do if F<>''then A('  Allow'+F+' := '+F+'.Enabled;');
    A('end;');
    AddTreeMoveAvailability(Code,P);
    A('procedure RefreshTreeState;');
    A('var CanUp, CanDown, CanLeft, CanRight: Boolean;');A('begin');
    A('  CanUp := False; CanDown := False; CanLeft := False; CanRight := False;');
    A('  if TreeReady and not TreeBusy and not TreeNeedsReload then TreeMoveAvailability(CanUp, CanDown, CanLeft, CanRight);');
    for F in Buttons do if F<>''then begin
      S:='TreeReady and not TreeBusy and Allow'+F;
      if(F<>'btClose')and(F<>'btQuery')and(F<>'btCancel')then S:=S+' and not TreeNeedsReload and cdsMain.Active';
      if(F='btEditor')or(F='btDelete')or(F='btUp')or(F='btDown')or(F='btLeft')or(F='btRight')then S:=S+' and not cdsMain.IsEmpty';
      if(F='btSave')or(F='btCancel')then S:=S+' and (TreeNeedsReload or (cdsMain.ChangeCount > 0))';
      if F='btUp' then S:=S+' and CanUp';
      if F='btDown' then S:=S+' and CanDown';
      if F='btLeft' then S:=S+' and CanLeft';
      if F='btRight' then S:=S+' and CanRight';
      A('  '+F+'.Enabled := '+S+';');
    end;
    A('end;');
    A('procedure WaitEditorError(const MessageText: string);');A('begin');
    A('  errorAlert.TitleText := UGMM.LT(''请修改后重试'');');
    A('  errorAlert.Text := MessageText; errorAlert.Execute;');A('end;');
    A('function ConfirmTree(const MessageText: string): Boolean;');A('begin');
    A('  confirmAlert.TitleText := UGMM.LT(''请确认'');');
    A('  confirmAlert.ConfirmButtonText := UGMM.LT(''确定'');');
    A('  confirmAlert.CancelButtonText := UGMM.LT(''取消'');');
    A('  confirmAlert.Text := UGMM.LT(MessageText);');A('  Result := confirmAlert.Execute;');A('end;');
    A('procedure ShowTreeNotice(const MessageText: string);');A('begin');
    A('  noticeAlert.TitleText := UGMM.LT(''提示'');');
    A('  noticeAlert.ConfirmButtonText := UGMM.LT(''确定'');');A('  noticeAlert.Show(MessageText);');A('end;');
    A('//新增为当前节点的子节点；扫描同级最大序号，避免删除后编号重复');
    A('procedure PrepareTreeAppend;');A('var B: TBookmark; V, Prefix: string; N, MaxN: Integer;');
    A('begin');A('  TreeParent := ''''; if not cdsMain.IsEmpty then TreeParent := cdsMain.FieldByName('+QuotedStr(P.KeyField)+').AsString;');
    if Scoped then A('  CheckTreeSiblingScope(TreeParent);');
    A('  Prefix := TreeParent + ''_''; MaxN := -1; B := cdsMain.GetBookmark;');
    A('  cdsMain.DisableControls;');A('  try');A('    cdsMain.First;');A('    while not cdsMain.Eof do begin');
    A('      if cdsMain.FieldByName('+QuotedStr(P.ParentField)+').AsString = TreeParent then begin');
    A('        V := cdsMain.FieldByName('+QuotedStr(P.OrderField)+').AsString;');
    A('        if Copy(V, 1, Length(Prefix)) <> Prefix then RaiseException(UGMM.LT(''同级排序值不是父键加五位序号，不能自动新增。''));');
    A('        N := StrToIntDef(Copy(V, Length(Prefix) + 1, Length(V)), -1);');
    A('        if N < 0 then RaiseException(UGMM.LT(''同级节点排序值无效。''));');
    A('        if N > MaxN then MaxN := N;');A('      end; cdsMain.Next;');A('    end;');
    A('  finally if cdsMain.BookmarkValid(B) then cdsMain.GotoBookmark(B); cdsMain.FreeBookmark(B); cdsMain.EnableControls; end;');
    A('  Inc(MaxN); if MaxN > 99999 then RaiseException(UGMM.LT(''同级节点数量超过五位排序容量。''));');
    A('  TreeOrder := Prefix + Format(''%.5d'', [MaxN]);');
    A('  if (cdsMain.FieldByName('+QuotedStr(P.OrderField)+').Size > 0) and (Length(TreeOrder) > cdsMain.FieldByName('+QuotedStr(P.OrderField)+').Size) then');
    A('    RaiseException(UGMM.LT(''排序字段长度不足。''));');A('end;');
    AddMultipleValidation(Temp,Required,UniqueFields,Fields,Captions,P.TableName,P.KeyField,False);
    for I:=0 to Temp.Count-1 do Temp[I]:=StringReplace(Temp[I],'ValidateGenericRows','ValidateTreeValues',[rfReplaceAll]);
    Code.AddStrings(Temp);Temp.Clear;
    A('procedure ValidateGenericRows;');A('var B: TBookmark;');A('begin');
    if Scoped then A('  CheckTreeWriteScope;');
    A('  ValidateTreeValues; B := cdsMain.GetBookmark; cdsMain.DisableControls;');
    A('  try ValidateTreeRows; finally');
    A('    if cdsMain.BookmarkValid(B) then cdsMain.GotoBookmark(B); cdsMain.FreeBookmark(B); cdsMain.EnableControls;');A('  end;');A('end;');
    AddMultipleAutoNumber(Code,P.TableName,P.KeyField,'Guid','','','');
    Init.Add('            cdsMain.FieldByName('+QuotedStr(P.ParentField)+').AsString := TreeParent;');
    Init.Add('            cdsMain.FieldByName('+QuotedStr(P.OrderField)+').AsString := TreeOrder;');
    Temp.Clear;
    if not ReadFields(Text(Settings,'隐藏字段-主表'),Temp) then Exit(Fail('隐藏字段必须属于树形根表。'));
    for F in Temp do
      if not SameText(F,P.KeyField)and not SameText(F,P.ParentField)and not SameText(F,P.OrderField)and(EditorInputs.IndexOf(F)<0)then EditorInputs.Add(F);
    AddMultipleRecordEditor(Code,Editable,P.KeyField,P.EditorFrame,Audit,True,True,False,Init,EditorInputs);
    if Temp.Count>0 then for I:=0 to Code.Count-1 do
      if Pos('var F: TUgWebForm;',Code[I])=1 then begin
        Code.Insert(I+1,'  HiddenFrame, HiddenControl: TComponent;');Break;
      end;
    for I:=0 to Code.Count-1 do
      if Pos('F.ModalResult := 0;',Code[I])>0 then begin
        for J:=Temp.Count-1 downto 0 do begin
          Code.Insert(I,'      if HiddenControl is TUniControl then begin TUniControl(HiddenControl).Visible := False; TUniControl(HiddenControl).Enabled := False; end;');
          Code.Insert(I,'      HiddenControl := HiddenFrame.FindComponent('+QuotedStr(P.AliasName+Temp[J])+');');
        end;
        if Temp.Count>0 then Code.Insert(I,'      HiddenFrame := F.RunFrame;');
        Break;
      end;
    if(Buttons.IndexOf('btUp')>=0)or(Buttons.IndexOf('btDown')>=0)or(Buttons.IndexOf('btLeft')>=0)or(Buttons.IndexOf('btRight')>=0)then
      AddTreeMoves(Code,P);
    A('//检查子节点并锁定待删除键；不进行级联删除');
    A('procedure DeleteTreeNode;');A('var K: string; B: TBookmark; HasChild: Boolean;');A('begin');
    A('  if cdsMain.IsEmpty then Exit; K := cdsMain.FieldByName('+QuotedStr(P.KeyField)+').AsString;');
    if Scoped then A('  CheckTreeSiblingScope(K);');
    A('  B := cdsMain.GetBookmark; HasChild := False; cdsMain.DisableControls;');
    A('  try cdsMain.First; while not cdsMain.Eof do begin');
    A('    if cdsMain.FieldByName('+QuotedStr(P.ParentField)+').AsString = K then HasChild := True; cdsMain.Next;');
    A('  end; finally if cdsMain.BookmarkValid(B) then cdsMain.GotoBookmark(B); cdsMain.FreeBookmark(B); cdsMain.EnableControls; end;');
    A('  if HasChild then RaiseException(UGMM.LT(''不能删除有下级节点的记录。''));');
    A('  if not ConfirmTree(''是否删除该节点？'') then Exit;');
    if Scoped then A('  CheckTreeSiblingScope(K);');
    A('  if not cdsMain.Locate('+QuotedStr(P.KeyField)+', K, 0) then RaiseException(UGMM.LT(''待删除节点已变化。''));');
    A('  cdsMain.Delete;');A('end;');
    A('//提交成功立即禁止重复保存；重新读取失败不撤销已提交事务');
    A('procedure SaveTreeChanges;');A('var K: string;');A('begin');
    A('  if TreeNeedsReload or (cdsMain.ChangeCount = 0) then Exit;');
    A('  K := cdsMain.FieldByName('+QuotedStr(P.KeyField)+').AsString;');
    A('  ValidateGenericRows; cdsMain.SubmitUpdates; TreeNeedsReload := True;');
    A('  try LoadTree; TreeNeedsReload := False;');
    A('    if K <> '''' then cdsMain.Locate('+QuotedStr(P.KeyField)+', K, 0);');
    A('  except ShowTreeError(UGMM.LT(''已保存成功，但刷新失败。请点击撤销按钮重新加载，勿重复提交。'') + #13#10 + ExceptionMessage); Exit; end;');
    A('  ShowTreeNotice(UGMM.LT(''数据保存成功。''));');A('end;');
    A('procedure CancelTreeChanges;');A('begin');
    A('  if TreeNeedsReload then begin LoadTree; TreeNeedsReload := False; Exit; end;');
    A('  if cdsMain.ChangeCount = 0 then Exit;');
    A('  if not ConfirmTree(''是否放弃未保存的修改？'') then Exit;');
    A('  cdsMain.CancelUpdates; treeMain.Refresh; treeMain.FullExpand;');A('end;');
    Handler('btAppend','PrepareTreeAppend; EditUnitRecord(True); treeMain.Refresh; treeMain.FullExpand;');
    Handler('btEditor','EditUnitRecord(False); treeMain.Refresh;');Handler('btDelete','DeleteTreeNode; treeMain.Refresh;');
    Handler('btSave','SaveTreeChanges;');Handler('btCancel','CancelTreeChanges;');
    Handler('btUp','MoveTreeNode(0);');Handler('btDown','MoveTreeNode(1);');
    Handler('btLeft','MoveTreeNode(2);');Handler('btRight','MoveTreeNode(3);');
    if Scoped then for I:=0 to Code.Count-1 do begin
      if Pos('TreeSiblings(ParentKey, Keys); I :=',Code[I])>0 then Code[I]:=StringReplace(Code[I],'TreeSiblings(ParentKey, Keys);','CheckTreeSiblingScope(ParentKey); TreeSiblings(ParentKey, Keys);',[]);
      if Pos('TreeSiblings(TargetParent, TargetKeys); TargetKeys.Add',Code[I])>0 then Code[I]:=StringReplace(Code[I],'TreeSiblings(TargetParent, TargetKeys);','CheckTreeSiblingScope(TargetParent); TreeSiblings(TargetParent, TargetKeys);',[]);
    end;
    for I:=0 to Code.Count-1 do
      Code[I]:=TRegEx.Replace(Code[I], 'RaiseException\((''(?:[^'']|'''')*'')\);', 'RaiseException(UGMM.LT($1));');
    Result:=True;
  finally EditorInputs.Free;Temp.Free;Init.Free;UniqueFields.Free;Required.Free;Auto.Free;UniqueRule.Free;end;
end;
end.
