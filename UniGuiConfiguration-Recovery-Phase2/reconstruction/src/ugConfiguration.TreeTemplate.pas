unit ugConfiguration.TreeTemplate;

interface
uses System.SysUtils, System.Classes, System.JSON;
function TryBuildTreeTemplate(Config: TJSONObject; out DFM, Reason: string): Boolean;

implementation
uses ugConfiguration.TreePlan, ugConfiguration.TreeWrite, ugConfiguration.TreeAccess,ugConfiguration.TreePresentation,ugConfiguration.TreeScriptLayout;

function Obj(J:TJSONObject;const K:string):TJSONObject;
var V:TJSONValue;
begin Result:=nil;if J=nil then Exit;V:=J.GetValue(K);if V is TJSONObject then Result:=TJSONObject(V);end;
function Str(J:TJSONObject;const K:string):string;
var V:TJSONValue;
begin Result:='';if J=nil then Exit;V:=J.GetValue(K);if Assigned(V)and not(V is TJSONNull)then Result:=V.Value;end;
function Yes(const S:string):Boolean;
begin Result:=SameText(S,'True')or(S='1')or(S='-1');end;
function Q(const S:string):string;
var C:Char;
begin
  Result:='''';
  for C in S do
    if(Ord(C)<32)or(Ord(C)>126)then Result:=Result+'''#'+IntToStr(Ord(C))+''''
    else if C=''''then Result:=Result+'''''' else Result:=Result+C;
  Result:=Result+'''';
end;
function Ident(const S:string):Boolean;
var C:Char;
begin
  Result:=False;if S=''then Exit;
  if not CharInSet(S[1],['A'..'Z','a'..'z','_'])then Exit;
  for C in S do if not CharInSet(C,['A'..'Z','a'..'z','_','0'..'9'])then Exit;
  Result:=True;
end;

function TryBuildTreeTemplate(Config:TJSONObject;out DFM,Reason:string):Boolean;
var P:TTreePlan;Cols,Settings,Row:TJSONObject;
  Fields,Captions,Selected,Hidden,Buttons,Code,Lines,Editable:TStringList;
  I,X:Integer;F,SQL,Options,Caption,DepartmentField:string;HasQuery,HasClose,WriteTree,Scoped:Boolean;
  function Fail(const S:string):Boolean;
  begin Reason:=S;Result:=False;end;
  procedure A(const S:string);
  begin Code.Add(S);end;
  procedure L(const S:string);
  begin Lines.Add(S);end;
  procedure Button(const Name,Caption:string;X:Integer);
  var IconIndex:Integer;
  begin
    if Name='btPrint' then L('    object '+Name+': TUgMenuButton')
    else L('    object '+Name+': TUgButton');
    L('      Left = '+IntToStr(X));
    L('      AlignWithMargins = True');L('      Align = alLeft');L('      AutoWidth = True');
    L('      Top = 3');
    if Name='btPrint' then L('      Width = 75') else L('      Width = 60');
    L('      Height = 26');
    IconIndex:=0;
    if Name='btAppend' then IconIndex:=1 else if Name='btDelete' then IconIndex:=2
    else if Name='btEditor' then IconIndex:=3 else if Name='btUp' then IconIndex:=4
    else if Name='btDown' then IconIndex:=5 else if Name='btLeft' then IconIndex:=6
    else if Name='btRight' then IconIndex:=7 else if Name='btSave' then IconIndex:=8
    else if Name='btCancel' then IconIndex:=9 else if Name='btPrint' then IconIndex:=10
    else if Name='btAnnex' then IconIndex:=11 else if Name='btClose' then IconIndex:=12;
    L('      Images = Imgs');L('      ImageIndex = '+IntToStr(IconIndex));
    L('      Caption = '+Q(Caption));L('    end');
  end;
begin
  DFM:='';Result:=False;
  if not TryReadTreePlan(Config,P,Reason)then Exit;
  Settings:=Obj(Config,'TWebNormalSetting');
  Scoped:=Yes(Str(Settings,'层级权限'));DepartmentField:='';
  if Trim(Str(Config,'TWebDataNodeName'))=''then Exit(Fail('请选择数据节点。'));
  Fields:=TStringList.Create;Captions:=TStringList.Create;Selected:=TStringList.Create;
  Hidden:=TStringList.Create;Buttons:=TStringList.Create;Code:=TStringList.Create;Lines:=TStringList.Create;
  Editable:=TStringList.Create;
  try
    Buttons.StrictDelimiter:=True;Buttons.Delimiter:=';';Buttons.DelimitedText:=Str(Config,'TWebFunctionButton');
    WriteTree:=False;
    for F in Buttons do if(F<>'')and(F<>'btQuery')and(F<>'btClose')then begin
      if(F='btAppend')or(F='btEditor')or(F='btDelete')or(F='btSave')or(F='btCancel')or
        (F='btUp')or(F='btDown')or(F='btLeft')or(F='btRight')then WriteTree:=True
      else if(F<>'btPrint')and(F<>'btAnnex')then Exit(Fail('mtTree 不支持按钮 '+F));
    end;
    HasQuery:=Buttons.IndexOf('btQuery')>=0;HasClose:=Buttons.IndexOf('btClose')>=0;
    Hidden.StrictDelimiter:=True;Hidden.Delimiter:=';';Hidden.DelimitedText:=Str(Settings,'隐藏字段-主表');
    for I:=0 to Hidden.Count-1 do Hidden[I]:=Trim(Hidden[I]);
    Cols:=Obj(Obj(Obj(Config,'TWebDataStructure'),'cdsColumns'),'Data');
    for I:=0 to Cols.Count-1 do begin
      Row:=Obj(Cols,IntToStr(I));F:=Str(Row,'fdCOLUMN_NAME');
      if not SameText(Copy(F,1,Length(P.AliasName)+1),P.AliasName+'.')then Exit(Fail('树形字段必须属于根表。'));
      F:=Copy(F,Length(P.AliasName)+2,MaxInt);
      if not Ident(F)then Exit(Fail('无效树形字段名：'+F));
      if Fields.IndexOf(F)>=0 then Exit(Fail('树形字段重复：'+F));
      Fields.Add(F);
      if Trim(Str(Row,'fdCAPTION'))=''then Captions.Add(F)
      else Captions.Add(Str(Row,'fdCAPTION'));
      if Yes(Str(Row,'fdSELECT'))and(Hidden.IndexOf(P.AliasName+'.'+F)<0)then Selected.Add(F);
    end;
    if Selected.Count=0 then Exit(Fail('请至少选择一个可见的树形显示字段。'));
    if Scoped then begin
      F:=Str(Settings,'录入部门');
      if not SameText(Copy(F,1,Length(P.AliasName)+1),P.AliasName+'.')then Exit(Fail('层级权限需要设置根表的录入部门字段。'));
      DepartmentField:=Copy(F,Length(P.AliasName)+2,MaxInt);
      if Fields.IndexOf(DepartmentField)<0 then Exit(Fail('录入部门字段不存在。'));
      if SameText(DepartmentField,P.KeyField)or SameText(DepartmentField,P.ParentField)or SameText(DepartmentField,P.OrderField)then Exit(Fail('权限归属字段不能使用节点主键、父键或排序字段。'));
    end;
    for F in Selected do
      if not SameText(F,P.KeyField)and not SameText(F,P.ParentField)and not SameText(F,P.OrderField)then Editable.Add(F);
    SQL:='select ';
    for I:=0 to Fields.Count-1 do begin
      if I>0 then SQL:=SQL+', ';
      SQL:=SQL+P.AliasName+'.'+Fields[I];
    end;
    SQL:=SQL+' from '+P.TableName+' '+P.AliasName;
    if Scoped then SQL:=SQL+' where '+P.AliasName+'.'+DepartmentField+' in '
    else SQL:=SQL+' order by '+P.AliasName+'.'+P.OrderField+', '+P.AliasName+'.'+P.KeyField;
    A('//树形模块：节点关系校验与完整加载；编辑操作暂存后统一保存');
    A('const cDataNodeName = '+QuotedStr(Str(Config,'TWebDataNodeName'))+';');
    if Scoped then AddTreeAccess(Code,P,DepartmentField);
    A('var TreeReady: Boolean = False;');
    A('procedure ShowTreeError(const MessageText: string);');A('begin');
    A('  errorAlert.TitleText := UGMM.LT(''操作未完成'');');
    A('  errorAlert.ConfirmButtonText := UGMM.LT(''确定'');');
    A('  errorAlert.Show(MessageText);');A('end;');
    A('//绑定树之前检查身份、父节点和循环，拒绝损坏关系而不是静默丢弃节点');
    A('function FindTreeKey(Keys: TStringList; const Key: string): Integer;');
    A('var I: Integer;');A('begin');A('  Result := -1;');
    A('  for I := 0 to Keys.Count - 1 do');
    A('    if Keys[I] = Key then begin Result := I; Exit; end;');A('end;');
    A('procedure ValidateTreeRows;');
    A('var Keys, Parents: TStringList; K, ParentKey: string; I, N, Steps: Integer;');
    A('begin');A('  Keys := TStringList.Create; Parents := TStringList.Create;');
    A('  try');A('    cdsMain.First;');
    A('    while not cdsMain.Eof do');A('    begin');
    A('      K := cdsMain.FieldByName('+QuotedStr(P.KeyField)+').AsString;');
    A('      ParentKey := cdsMain.FieldByName('+QuotedStr(P.ParentField)+').AsString;');
    A('      if (K = '''') or (FindTreeKey(Keys, K) >= 0) then');
    A('        RaiseException(UGMM.LT(''节点主键为空或重复：'') + K);');
    A('      Keys.Add(K); Parents.Add(ParentKey); cdsMain.Next;');A('    end;');
    A('    for I := 0 to Keys.Count - 1 do');A('    begin');
    A('      ParentKey := Parents[I]; Steps := 0;');
    A('      while ParentKey <> '''' do');A('      begin');
    A('        N := FindTreeKey(Keys, ParentKey);');
    if Scoped then A('        if N < 0 then Break; //父节点在权限范围外，保留真实父键')
    else A('        if N < 0 then RaiseException(UGMM.LT(''找不到父节点：'') + ParentKey);');
    A('        Inc(Steps);');
    A('        if Steps > Keys.Count then RaiseException(UGMM.LT(''树形节点存在循环关系。''));');
    A('        ParentKey := Parents[N];');A('      end;');A('    end;');
    A('  finally');A('    Parents.Free; Keys.Free; cdsMain.First;');A('  end;');A('end;');
    A('//按排序字段排列每一级节点，避免树控件默认按节点主键排列');
    A('procedure ConfigureTreeSort;');A('begin');
    A('  treeMain.ClientEvents.ExtEvents.Values[''store.load''] :=');
    A('    ''function store.load(sender){sender.remoteSort=false;sender.sort({property:"'' +');
    A('    IntToStr(treeMain.ColumnByName('+QuotedStr(P.OrderField)+').Index) + ''",direction:"ASC"});}'';');
    A('end;');
    A('//完整加载树关系，不按普通表格分页切断父子节点');
    A('procedure LoadTree;');A('var Failure: string;');A('begin');A('  dsMain.DataSet := nil;');
    A('  cdsMain.Close;');
    if Scoped then begin
      A('  LoadedTreeScope := GetTreeScope;');
      A('  cdsMain.CommandText := '+QuotedStr(SQL)+' + LoadedTreeScope');
      A('    + '+QuotedStr(' order by '+P.AliasName+'.'+P.OrderField+', '+P.AliasName+'.'+P.KeyField)+';');
    end else A('  cdsMain.CommandText := '+QuotedStr(SQL)+';');
    A('  cdsMain.Params.Clear;');A('  cdsMain.PageRowCount := -1;');A('  try');
    A('    cdsMain.Open;');A('    cdsMain.IndexFieldNames := '+QuotedStr(P.OrderField+';'+P.KeyField)+';');
    A('    ValidateTreeRows;');A('    ConfigureTreeSort;');A('    dsMain.DataSet := cdsMain;');
    A('    treeMain.FullExpand;');A('  except');A('    Failure := ExceptionMessage;');
    A('    dsMain.DataSet := nil;');A('    try cdsMain.Close; finally RaiseException(Failure); end;');A('  end;');A('end;');
    if WriteTree then
      if not AddTreeWrite(Config,P,Fields,Captions,Editable,Buttons,Code,Reason)then Exit;
    AddTreePresentation(Code,Buttons,Selected,Yes(Str(Settings,'字段移动')),Yes(Str(Settings,'字段宽度')),Yes(Str(Settings,'字段显隐')),WriteTree);
    if WriteTree then begin
      A('procedure treeMainOnSelectionChange(Sender: TObject);');A('begin');
      A('  if TreeReady and not TreeBusy then RefreshTreeState;');A('end;');
    end;
    if HasQuery then begin
      A('procedure btQueryOnClick(Sender: TObject);');A('begin');
      A('  if not TreeReady or not btQuery.Enabled then Exit;');
      if WriteTree then begin
        A('  if TreeBusy then Exit;');
        A('  if not TreeNeedsReload and (cdsMain.ChangeCount > 0) then begin ShowTreeError(UGMM.LT(''请先保存或撤销修改。'')); Exit; end;');
        A('  try LoadTree; TreeNeedsReload := False; except ShowTreeError(ExceptionMessage); end; RefreshTreeState;');
      end else A('  try LoadTree; except ShowTreeError(ExceptionMessage); end;');A('end;');
    end;
    if HasClose then begin
      A('procedure btCloseOnClick(Sender: TObject);');A('begin');
      if WriteTree then begin
        A('  if TreeBusy then Exit;');
        A('  if not TreeNeedsReload and (cdsMain.ChangeCount > 0) then');
        A('    if not ConfirmTree(''尚有未保存的修改，是否关闭并放弃？'') then Exit;');
      end;
      A('  if Self.Parent is TUniForm then TUniForm(Self.Parent).Close;');A('end;');
    end;
    A('//运行脚本后');A('procedure UgWebRunFrameOnAfterRunScript(const sender: tobject);');A('begin');
    A('  TreeReady := False;');A('  try');A('    UGMM.LC(Self);');A('    UGMM.VerifyRunFramePerm(Self);');
    if WriteTree then A('    CaptureTreePermissions;');
    if Buttons.IndexOf('btPrint')>=0 then A('    UGMM.AddReport(btPrint, UGMM.Informations.Values[''AllowLandingType''] <> ''系统用户;'', Self.Guid);');
    A('    cdsMain.DataNodeName := cDataNodeName;');A('    TreeReady := True;');A('    LoadTree;');
    A('    TreeColumnSettings(True);');A('    ConfigureTreeSort;');
    A('  except ShowTreeError(ExceptionMessage); end;');
    if WriteTree then A('  RefreshTreeState;');
    A('end;');A('begin');A('end.');
    FormatTreeScript(Code);
    L('object UgWebRunFrame: TUgWebRunFrame');L('  Width = 1270');L('  Height = 650');
    L('  SyntaxType = ''PascalScript''');L('  Events.Strings = (');
    if HasQuery then L('    ''btQuery|<This>.OnClick:btQueryOnClick''');
    if HasClose then L('    ''btClose|<This>.OnClick:btCloseOnClick''');
    for F in Buttons do if(F<>'')and(F<>'btQuery')and(F<>'btClose')and(F<>'btPrint')then
      L('    '+Q(F+'|<This>.OnClick:'+F+'OnClick'));
    L('    ''treeMain|<This>.OnAjaxEvent:treeMainOnAjaxEvent''');
    if WriteTree then L('    ''treeMain|<This>.OnSelectionChange:treeMainOnSelectionChange''');
    L('    ''Self|<This>.OnAfterRunScript:UgWebRunFrameOnAfterRunScript'')');
    L('  Codes.Strings = (');for F in Code do L('    '+Q(F));L('  )');
    L('  object pButtons: TUgContainerPanel');L('    Align = alTop');L('    Height = 33');
    L('    object topline: TUgContainerPanel');L('      Align = alBottom');L('      Height = 1');
    L('      ParentColor = False');L('      Color = 13093060');L('    end');
    X:=5;
    for F in Buttons do if F<>''then begin
      Caption:=F;
      if F='btQuery'then Caption:='查询';if F='btClose'then Caption:='关闭';
      if F='btAppend'then Caption:='新增';if F='btEditor'then Caption:='修改';
      if F='btDelete'then Caption:='删除';if F='btSave'then Caption:='保存';if F='btCancel'then Caption:='撤销';
      if F='btUp'then Caption:='向上';if F='btDown'then Caption:='向下';if F='btLeft'then Caption:='向左';if F='btRight'then Caption:='向右';
      if F='btPrint'then Caption:='打印';if F='btAnnex'then Caption:='附件';
      if (X>5)and((F='btUp')or(F='btSave')or(F='btPrint')or(F='btAnnex')or(F='btClose'))then begin
        L('    object separator_'+F+': TUgContainerPanel');L('      AlignWithMargins = True');
        L('      Left = '+IntToStr(X));L('      Align = alLeft');L('      Width = 1');
        L('      Margins.Top = 5');L('      Margins.Bottom = 5');
        L('      ParentColor = False');L('      Color = 13093060');L('    end');Inc(X,7);
      end;
      Button(F,Caption,X);Inc(X,75);
    end;
    L('  end');L('  object treeMain: TUgDBTreeGrid');L('    Align = alClient');
    L('    DataSource = dsMain');L('    IdField = '+Q(P.KeyField));L('    IdParentField = '+Q(P.ParentField));
    if Yes(Str(Settings,'表格复制'))then begin
      L('    ClientEvents.UniEvents.Strings = (');
      L('      '+Q('beforeInit=function(sender,config){config.viewConfig=config.viewConfig||{};config.viewConfig.enableTextSelection=true;}')+')');
    end;
    Options:='dgTitles, dgColLines, dgRowLines, dgRowSelect, dgAutoRefreshRow';
    if Yes(Str(Settings,'表格序号'))then Options:=Options+', dgRowNumbers';
    if Yes(Str(Settings,'字段宽度'))then Options:=Options+', dgColumnResize';
    if Yes(Str(Settings,'字段移动'))then Options:=Options+', dgColumnMove';
    L('    Options = ['+Options+']');
    L('    Columns = <');
    for F in Selected do begin L('      item');L('        FieldName = '+Q(F));
      L('        Title.Caption = '+Q(Captions[Fields.IndexOf(F)]));L('        Width = 160');
      if not Yes(Str(Settings,'字段显隐'))then L('        Menu.ColumnHideable = False');
      L('      end');end;
    if Selected.IndexOf(P.OrderField)<0 then begin
      L('      item');L('        FieldName = '+Q(P.OrderField));
      L('        Visible = False');L('        Menu.ColumnHideable = False');L('      end');
    end;
    L('    >');L('  end');
    L('  object Imgs: TUGIconClsList');L('    Left = 20');L('    Top = 550');
    L('    IconText = '+Q('icon iconfont icon-chaxun'#13#10'icon iconfont icon-addEdge'#13#10+
      'icon iconfont icon-shanchu1'#13#10'icon iconfont icon-xiugai1'#13#10+
      'icon iconfont icon-xiangshang'#13#10'icon iconfont icon-xiangxia'#13#10+
      'icon iconfont icon-xiangzuo'#13#10'icon iconfont icon-xiangyou'#13#10+
      'icon iconfont icon-baocun'#13#10'icon iconfont icon-chexiao4'#13#10+
      'icon iconfont icon-dayin4'#13#10'icon iconfont icon-fujian'#13#10'icon iconfont icon-guanbi3'#13#10));L('  end');
    L('  object cdsMain: TUgClientDataSet');
    L('    Left = 100');L('    Top = 550');L('    Active = False');L('    PageRowCount = -1');
    L('    SelectMaxRecCount = 0');L('  end');L('  object dsMain: TUgDataSource');
    L('    Left = 180');L('    Top = 550');L('  end');
    L('  object errorAlert: TUgSweetAlert');L('    Left = 260');L('    Top = 550');
    L('    AlertType = atError');L('    ShowConfirmButton = True');L('  end');
    if WriteTree then begin
      L('  object confirmAlert: TUgSweetAlert');L('    Left = 340');L('    Top = 550');
      L('    AlertType = atQuestion');L('    ShowConfirmButton = True');L('    ShowCancelButton = True');L('  end');
      L('  object noticeAlert: TUgSweetAlert');L('    Left = 420');L('    Top = 550');
      L('    AlertType = atInfo');L('    ShowConfirmButton = True');L('  end');
    end;
    L('end');
    DFM:=Lines.Text;Result:=True;
  finally Editable.Free;Lines.Free;Code.Free;Buttons.Free;Hidden.Free;Selected.Free;Captions.Free;Fields.Free;end;
end;
end.
