unit ugWebConfiguration.NormalSetting.SetupAutoNumber;


interface

uses
  System.SysUtils, System.Classes, System.Variants,
  Vcl.Controls, Vcl.StdCtrls, Data.DB, Datasnap.DBClient, System.JSON, REST.Json,
  uniGUITypes, uniGUIAbstractClasses, uniGUIBaseClasses, uniGUIClasses,
  uniGUIForm, uniGUIFrame, uniPanel, uniButton, uniSpeedButton, uniLabel,
  uniPageControl, uniEdit, uniComboBox, uniCheckBox, uniMemo, uniSpinEdit,
  uniImageList, uniBasicGrid, uniDBGrid, uniDBTreeGrid, uniURLFrame,
  ugWebCustBaseForm;

type
  TWebNormalSettingSetupAutoNumber = class(TWebCustBaseForm)
    pButton: TUniContainerPanel;
    btOk: TUniButton;
    cbAutoNumberType: TUniComboBox;
    cbField: TUniComboBox;
    seDigitCapacity: TUniSpinEdit;
    edPrefix: TUniEdit;
    cbSeqUence: TUniComboBox;
    edSuffix: TUniEdit;
    procedure btOkClick(Sender: TObject);
    procedure cbAutoNumberTypeChange(Sender: TObject);
  private
    FConfiguredValue: string;
    FSequencesLoaded: Boolean;
    FAllowMaxInt: Boolean;
    procedure LoadSequences;
    procedure UpdateControlVisibility;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Prepare(AColumns: TClientDataSet; const AValue: string;
      const AModuleType: string = '');
    property ConfiguredValue: string read FConfiguredValue;
  end;

implementation

{$R *.dfm}

const CMaxIntCaption = 'MaxInt（最大整数+1）';

function CanonicalNumberType(const Value:string):string;
begin
  Result:=Trim(Value);
  if SameText(Result,CMaxIntCaption) then Result:='MaxInt';
end;

function AutoNumberJSONValue(AJSON: TJSONObject; const AName: string): string;
var
  LValue: TJSONValue;
begin
  Result := '';
  if not Assigned(AJSON) then
    Exit;
  LValue := AJSON.GetValue(AName);
  if Assigned(LValue) then
    Result := LValue.Value;
end;

constructor TWebNormalSettingSetupAutoNumber.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  cbField.Style := csDropDownList;
  cbSeqUence.Style := csDropDownList;
  seDigitCapacity.MinValue := 1;
  seDigitCapacity.MaxValue := 30;
  seDigitCapacity.Value := 10;
  UpdateControlVisibility;
end;

procedure TWebNormalSettingSetupAutoNumber.Prepare(AColumns: TClientDataSet;
  const AValue: string; const AModuleType: string);
var
  LBookmark: TBookmark;
  LJSONValue: TJSONValue;
  LJSON: TJSONObject;
  LName: string;
begin
  FAllowMaxInt:=SameText(AModuleType,'mtListEditor');
  if FAllowMaxInt then begin
    if cbAutoNumberType.Items.IndexOf(CMaxIntCaption)<0 then
      cbAutoNumberType.Items.Add(CMaxIntCaption);
  end else if cbAutoNumberType.Items.IndexOf(CMaxIntCaption)>=0 then
    cbAutoNumberType.Items.Delete(cbAutoNumberType.Items.IndexOf(CMaxIntCaption));
  FConfiguredValue := AValue;
  cbField.Items.Clear;
  if Assigned(AColumns) and AColumns.Active and not AColumns.IsEmpty then
  begin
    LBookmark := AColumns.GetBookmark;
    AColumns.DisableControls;
    try
      AColumns.First;
      while not AColumns.Eof do
      begin
        if AColumns.FieldByName('fdSELECT').AsBoolean then
        begin
          LName := AColumns.FieldByName('fdCOLUMN_NAME').AsString;
          if cbField.Items.IndexOf(LName) < 0 then
            cbField.Items.Add(LName);
        end;
        AColumns.Next;
      end;
    finally
      if AColumns.BookmarkValid(LBookmark) then
        AColumns.GotoBookmark(LBookmark);
      AColumns.FreeBookmark(LBookmark);
      AColumns.EnableControls;
    end;
  end;

  LJSON := nil;
  LJSONValue := nil;
  if Trim(AValue) <> '' then
    LJSONValue := TJSONObject.ParseJSONValue(AValue);
  try
    if LJSONValue is TJSONObject then
      LJSON := TJSONObject(LJSONValue);
    cbField.Text := AutoNumberJSONValue(LJSON, 'cbField');
    cbAutoNumberType.Text := AutoNumberJSONValue(LJSON, 'cbAutoNumberType');
    if SameText(cbAutoNumberType.Text,'MaxInt') then cbAutoNumberType.Text:=CMaxIntCaption;
    cbSeqUence.Text := AutoNumberJSONValue(LJSON, 'cbSeqUence');
    edPrefix.Text := AutoNumberJSONValue(LJSON, 'edPrefix');
    seDigitCapacity.Value := StrToIntDef(
      AutoNumberJSONValue(LJSON, 'seDigitCapacity'), 10);
    edSuffix.Text := AutoNumberJSONValue(LJSON, 'edSuffix');
  finally
    LJSONValue.Free;
  end;
  if SameText(cbAutoNumberType.Text, 'SeqUence') then
    LoadSequences;
  UpdateControlVisibility;
end;

procedure TWebNormalSettingSetupAutoNumber.LoadSequences;
var
  LSequences: TClientDataSet;
begin
  if FSequencesLoaded then
    Exit;
  FSequencesLoaded := True;
  cbSeqUence.Items.Clear;
  LSequences := TClientDataSet.Create(nil);
  try
    UGMM.GetSequences(DataNodeName, LSequences);
    if LSequences.Active and
      Assigned(LSequences.FindField('SEQUENCE_NAME')) then
    begin
      LSequences.First;
      while not LSequences.Eof do
      begin
        cbSeqUence.Items.Add(
          LSequences.FieldByName('SEQUENCE_NAME').AsString);
        LSequences.Next;
      end;
    end;
  finally
    LSequences.Free;
  end;
end;

procedure TWebNormalSettingSetupAutoNumber.UpdateControlVisibility;
var
  LType: string;
  LUsesRule: Boolean;
begin
  LType := CanonicalNumberType(cbAutoNumberType.Text);
  LUsesRule := SameText(LType, 'SeqUence') or
    SameText(LType, 'MaxCode') or SameText(LType, 'DateTimeRandom');
  cbSeqUence.Visible := SameText(LType, 'SeqUence');
  edPrefix.Visible := LUsesRule;
  seDigitCapacity.Visible := LUsesRule;
  edSuffix.Visible := LUsesRule;
end;

procedure TWebNormalSettingSetupAutoNumber.btOkClick(Sender: TObject);
var
  LJSON: TJSONObject;
  LType: string;
begin
  if Trim(cbField.Text) = '' then
    raise Exception.Create('请选择编号字段。');
  LType := CanonicalNumberType(cbAutoNumberType.Text);
  if LType = '' then
    raise Exception.Create('请选择编号方式。');
  if SameText(LType,'MaxInt') and not FAllowMaxInt then
    raise Exception.Create('MaxInt目前仅接入mtListEditor模板。');
  if SameText(LType, 'SeqUence') and (Trim(cbSeqUence.Text) = '') then
    raise Exception.Create('请选择取数序列。');

  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('cbField', cbField.Text);
    LJSON.AddPair('cbAutoNumberType', LType);
    if SameText(LType, 'SeqUence') then
      LJSON.AddPair('cbSeqUence', cbSeqUence.Text);
    if SameText(LType, 'SeqUence') or SameText(LType, 'MaxCode') or
      SameText(LType, 'DateTimeRandom') then
    begin
      LJSON.AddPair('edPrefix', edPrefix.Text);
      LJSON.AddPair('seDigitCapacity', IntToStr(Trunc(seDigitCapacity.Value)));
      LJSON.AddPair('edSuffix', edSuffix.Text);
    end;
    FConfiguredValue := LJSON.Format(2);
  finally
    LJSON.Free;
  end;
  ModalResult := mrOk;
end;

procedure TWebNormalSettingSetupAutoNumber.cbAutoNumberTypeChange(Sender: TObject);
begin
  if SameText(cbAutoNumberType.Text, 'SeqUence') then
    LoadSequences;
  UpdateControlVisibility;
end;

end.
