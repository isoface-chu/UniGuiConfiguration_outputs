unit ugWebConfiguration.DataStructure.Setup;


interface

uses
  System.SysUtils, System.Classes, System.Variants,
  Vcl.Controls, Vcl.Forms, Data.DB, Datasnap.DBClient, System.JSON, REST.Json,
  uniGUITypes, uniGUIAbstractClasses, uniGUIBaseClasses, uniGUIClasses,
  uniGUIForm, uniGUIFrame, uniPanel, uniButton, uniSpeedButton, uniLabel,
  uniPageControl, uniEdit, uniComboBox, uniCheckBox, uniMemo, uniSpinEdit,
  uniImageList, uniBasicGrid, uniDBGrid, uniDBTreeGrid, uniURLFrame,
  ugWebCustBaseForm;

type
  TWebDataStructureSetup = class(TWebCustBaseForm)
    pAssociationMethod: TUniContainerPanel;
    edLEpithet: TUniEdit;
    cbAssociationMethod: TUniComboBox;
    pTableName: TUniContainerPanel;
    cbTableName: TUniComboBox;
    edEpithet: TUniEdit;
    capTableComments: TUniLabel;
    pCriteria1: TUniContainerPanel;
    edCriteriaEpithet1: TUniEdit;
    edCriteriaLField1: TUniComboBox;
    edCriteriaEqual1: TUniEdit;
    edCriteriaRField1: TUniComboBox;
    pCriteria2: TUniContainerPanel;
    edCriteriaEpithet2: TUniEdit;
    edCriteriaLField2: TUniComboBox;
    edCriteriaEqual2: TUniEdit;
    edCriteriaRField2: TUniComboBox;
    pCriteria3: TUniContainerPanel;
    edCriteriaEpithet3: TUniEdit;
    edCriteriaLField3: TUniComboBox;
    edCriteriaEqual3: TUniEdit;
    edCriteriaRField3: TUniComboBox;
    btOk: TUniButton;
    procedure cbTableNameChange(Sender: TObject);
    procedure btOkClick(Sender: TObject);
  private
    FNodeName: string;
    FParentGuid: string;
    FEditingGuid: string;
    FOriginalAlias: string;
    FTables: TDataSet;
    procedure LoadColumnNames(const ATableName, AAlias: string;
      AItems: TStrings);
    function BuildCriteria(AIndex: Integer): string;
  public
    procedure PrepareNew(const ANodeName, AAlias, AParentGuid,
      AParentAlias, AParentTableName: string);
    procedure PrepareEdit(const ANodeName, AParentAlias, AParentTableName: string;
      ARow: TDataSet);
    property EditingGuid: string read FEditingGuid;
    property ParentGuid: string read FParentGuid;
    function SelectedTableName: string;
    function SelectedAlias: string;
    function SelectedAssociationMethod: string;
    function SelectedCriteria(AIndex: Integer): string;
  end;

implementation

{$R *.dfm}

procedure TWebDataStructureSetup.LoadColumnNames(const ATableName,
  AAlias: string; AItems: TStrings);
var
  LColumns: TClientDataSet;
begin
  AItems.Clear;
  if (ATableName = '') or not Assigned(UGMM) then
    Exit;
  LColumns := TClientDataSet.Create(nil);
  try
    UGMM.GetNodeDataColumns(FNodeName, ATableName, LColumns);
    LColumns.First;
    while not LColumns.Eof do
    begin
      AItems.Add(AAlias + '.' + LColumns.FieldByName('COLUMN_NAME').AsString);
      LColumns.Next;
    end;
  finally
    LColumns.Free;
  end;
end;

procedure TWebDataStructureSetup.PrepareNew(const ANodeName, AAlias,
  AParentGuid, AParentAlias, AParentTableName: string);
var
  LTables: TClientDataSet;
begin
  FNodeName := ANodeName;
  FParentGuid := AParentGuid;
  edEpithet.Text := AAlias;
  FOriginalAlias := AAlias;
  edLEpithet.Text := AParentAlias;
  cbTableName.Items.Clear;
  LTables := TClientDataSet.Create(nil);
  try
    UGMM.GetNodeDataTables(FNodeName, LTables);
    LTables.First;
    while not LTables.Eof do
    begin
      cbTableName.Items.Add(LTables.FieldByName('TABLE_NAME').AsString);
      LTables.Next;
    end;
  finally
    LTables.Free;
  end;

  // Keep the table dialog layout stable for both root and related tables.
  pAssociationMethod.Visible := True;
  pCriteria1.Visible := True;
  pCriteria2.Visible := True;
  pCriteria3.Visible := True;
  pAssociationMethod.Enabled := AParentGuid <> '';
  pCriteria1.Enabled := AParentGuid <> '';
  pCriteria2.Enabled := AParentGuid <> '';
  pCriteria3.Enabled := AParentGuid <> '';
  if AParentGuid <> '' then
  begin
    cbAssociationMethod.ItemIndex := 0;
    LoadColumnNames(AParentTableName, AParentAlias, edCriteriaLField1.Items);
    edCriteriaLField2.Items.Assign(edCriteriaLField1.Items);
    edCriteriaLField3.Items.Assign(edCriteriaLField1.Items);
  end;
end;

function TWebDataStructureSetup.BuildCriteria(AIndex: Integer): string;
var
  LLeft, LRight: string;
begin
  case AIndex of
    1: begin LLeft := edCriteriaLField1.Text; LRight := edCriteriaRField1.Text; end;
    2: begin LLeft := edCriteriaLField2.Text; LRight := edCriteriaRField2.Text; end;
    3: begin LLeft := edCriteriaLField3.Text; LRight := edCriteriaRField3.Text; end;
  else
    Exit('');
  end;
  if (LLeft = '') or (LRight = '') then
    Exit('');
  Result := LLeft + ' = ' + LRight;
end;

procedure TWebDataStructureSetup.PrepareEdit(const ANodeName, AParentAlias,
  AParentTableName: string; ARow: TDataSet);
var
  I, P: Integer;
  V: string;
  LLeft, LRight: array[1..3] of TUniComboBox;
begin
  PrepareNew(ANodeName, ARow.FieldByName('fdEpithet').AsString,
    ARow.FieldByName('fdParent').AsString, AParentAlias, AParentTableName);
  FEditingGuid := ARow.FieldByName('fdGuid').AsString;
  cbTableName.Text := ARow.FieldByName('fdTableName').AsString;
  cbTableNameChange(nil);
  cbTableName.Enabled := False;
  FTables := ARow;
  edEpithet.Enabled := FParentGuid <> '';
  edEpithet.ReadOnly := FParentGuid = '';
  cbAssociationMethod.Text := ARow.FieldByName('fdAssociationMethod').AsString;
  LLeft[1] := edCriteriaLField1; LLeft[2] := edCriteriaLField2; LLeft[3] := edCriteriaLField3;
  LRight[1] := edCriteriaRField1; LRight[2] := edCriteriaRField2; LRight[3] := edCriteriaRField3;
  for I := 1 to 3 do
  begin
    V := Trim(ARow.FieldByName('fdCriteria'+IntToStr(I)).AsString);
    if V = '' then Continue;
    P := Pos(' = ', V);
    if (P = 0) or (Pos('=', Copy(V, P+3, MaxInt)) > 0) then
      raise Exception.Create('当前修改界面仅支持字段等值关联，原配置未更改。');
    LLeft[I].Text := Trim(Copy(V, 1, P-1));
    LRight[I].Text := Trim(Copy(V, P+3, MaxInt));
    if (LLeft[I].Items.IndexOf(LLeft[I].Text) < 0) or
      (LRight[I].Items.IndexOf(LRight[I].Text) < 0) then
      raise Exception.Create('关联条件不是当前父表和关联表的有效字段，原配置未更改。');
  end;
end;

function TWebDataStructureSetup.SelectedTableName: string;
begin
  Result := cbTableName.Text;
end;

function TWebDataStructureSetup.SelectedAlias: string;
begin
  Result := edEpithet.Text;
end;

function TWebDataStructureSetup.SelectedAssociationMethod: string;
begin
  Result := cbAssociationMethod.Text;
end;

function TWebDataStructureSetup.SelectedCriteria(AIndex: Integer): string;
begin
  Result := BuildCriteria(AIndex);
  if not SameText(FOriginalAlias, SelectedAlias) then
    Result := StringReplace(Result, ' = '+FOriginalAlias+'.',
      ' = '+SelectedAlias+'.', [rfIgnoreCase]);
end;

procedure TWebDataStructureSetup.cbTableNameChange(Sender: TObject);
begin
  if Assigned(UGMM) and (cbTableName.Text <> '') then
  begin
    capTableComments.Caption :=
      UGMM.GetNodeDataTableComments(FNodeName, cbTableName.Text);
    LoadColumnNames(cbTableName.Text, edEpithet.Text, edCriteriaRField1.Items);
    edCriteriaRField2.Items.Assign(edCriteriaRField1.Items);
    edCriteriaRField3.Items.Assign(edCriteriaRField1.Items);
  end;
end;

procedure TWebDataStructureSetup.btOkClick(Sender: TObject);
var
  I: Integer;
  AliasName: string;
  B: TBookmark;
begin
  if Trim(cbTableName.Text) = '' then
    raise Exception.Create('请选择数据表。');
  AliasName := Trim(edEpithet.Text);
  if (Length(AliasName)<1) or (Length(AliasName)>2) then
    raise Exception.Create('表别名须为1至2个英文字母。');
  for I:=1 to Length(AliasName) do
    if not CharInSet(AliasName[I], ['a'..'z','A'..'Z']) then
      raise Exception.Create('表别名须为1至2个英文字母。');
  if Assigned(FTables) then
  begin
    B:=FTables.GetBookmark;
    FTables.DisableControls;
    try
      FTables.First;
      while not FTables.Eof do
      begin
        if (FTables.FieldByName('fdGuid').AsString<>FEditingGuid) and
          SameText(FTables.FieldByName('fdEpithet').AsString,AliasName) then
          raise Exception.Create('表别名已被其他数据表使用，请重新填写。');
        FTables.Next;
      end;
    finally
      FTables.GotoBookmark(B);FTables.FreeBookmark(B);FTables.EnableControls;
    end;
  end;
  edEpithet.Text:=AliasName;
  if (FEditingGuid <> '') and (FParentGuid <> '') and
    (SelectedCriteria(1) = '') then
    raise Exception.Create('关联表至少需要填写第一组关联条件。');
  if FEditingGuid <> '' then
    for I := 1 to 3 do
    begin
      case I of
        1: if (Trim(edCriteriaLField1.Text) = '') xor (Trim(edCriteriaRField1.Text) = '') then raise Exception.Create('关联条件左右字段必须同时填写。');
        2: if (Trim(edCriteriaLField2.Text) = '') xor (Trim(edCriteriaRField2.Text) = '') then raise Exception.Create('关联条件左右字段必须同时填写。');
        3: if (Trim(edCriteriaLField3.Text) = '') xor (Trim(edCriteriaRField3.Text) = '') then raise Exception.Create('关联条件左右字段必须同时填写。');
      end;
    end;
  ModalResult := mrOk;
end;

end.
