unit ugWebConfiguration.QueryCriteria.Setup;


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
  TWebQueryCriteriaSetup = class(TWebCustBaseForm)
    cbField: TUniComboBox;
    edCaption: TUniEdit;
    cbObjectType: TUniComboBox;
    cbComparisonOperator: TUniComboBox;
    ckIndePendence: TUniCheckBox;
    ckHideCaption: TUniCheckBox;
    btOK: TUniButton;
    procedure cbFieldChange(Sender: TObject);
    procedure btOKClick(Sender: TObject);
  private
    FFields: TStringList;
    function GetFieldName: string;
    function GetCaption: string;
    function GetObjectType: string;
    function GetComparisonOperator: string;
    function GetIndependence: Boolean;
    function GetHideCaption: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Prepare(AFields: TStrings; const AFieldName, ACaption,
      AObjectType, AComparisonOperator: string; AIndependence,
      AHideCaption: Boolean);
    property FieldName: string read GetFieldName;
    property CaptionText: string read GetCaption;
    property ObjectType: string read GetObjectType;
    property ComparisonOperator: string read GetComparisonOperator;
    property Independence: Boolean read GetIndependence;
    property HideCaption: Boolean read GetHideCaption;
  end;

implementation

{$R *.dfm}

function MetadataPart(const AValue: string; AIndex: Integer): string;
var
  LParts: TStringList;
begin
  LParts := TStringList.Create;
  try
    LParts.StrictDelimiter := True;
    LParts.Delimiter := '|';
    LParts.DelimitedText := AValue;
    if (AIndex >= 0) and (AIndex < LParts.Count) then
      Result := LParts[AIndex]
    else
      Result := '';
  finally
    LParts.Free;
  end;
end;

constructor TWebQueryCriteriaSetup.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FFields := TStringList.Create;
  cbComparisonOperator.Items.Text :=
    '=' + sLineBreak + '<>' + sLineBreak + '>' + sLineBreak + '>=' +
    sLineBreak + '<' + sLineBreak + '<=' + sLineBreak + 'like' +
    sLineBreak + 'in';
  cbObjectType.Items.Text :=
    'edit' + sLineBreak + 'memo' + sLineBreak + 'number' + sLineBreak +
    'date' + sLineBreak + 'time' + sLineBreak + 'datetime' + sLineBreak + 'check' + sLineBreak +
    'combobox' + sLineBreak + 'lookupedit' + sLineBreak +
    'lookupeditextra' + sLineBreak + 'gridcombobox' + sLineBreak +
    'gridcomboboxextra';
end;

destructor TWebQueryCriteriaSetup.Destroy;
begin
  FFields.Free;
  inherited Destroy;
end;

procedure TWebQueryCriteriaSetup.Prepare(AFields: TStrings;
  const AFieldName, ACaption, AObjectType, AComparisonOperator: string;
  AIndependence, AHideCaption: Boolean);
var
  I: Integer;
begin
  FFields.Assign(AFields);
  cbField.Items.Clear;
  for I := 0 to FFields.Count - 1 do
    cbField.Items.Add(FFields.Names[I]);
  cbField.ItemIndex := cbField.Items.IndexOf(AFieldName);
  if (cbField.ItemIndex < 0) and (cbField.Items.Count > 0) then
    cbField.ItemIndex := 0;
  cbFieldChange(cbField);
  if ACaption <> '' then
    edCaption.Text := ACaption;
  if AObjectType <> '' then
    cbObjectType.ItemIndex := cbObjectType.Items.IndexOf(AObjectType);
  if AComparisonOperator <> '' then
    cbComparisonOperator.ItemIndex :=
      cbComparisonOperator.Items.IndexOf(AComparisonOperator);
  ckIndePendence.Checked := AIndependence;
  ckHideCaption.Checked := AHideCaption;
end;

procedure TWebQueryCriteriaSetup.cbFieldChange(Sender: TObject);
var
  LMetadata, LObjectType: string;
begin
  LMetadata := FFields.Values[cbField.Text];
  edCaption.Text := MetadataPart(LMetadata, 0);
  LObjectType := MetadataPart(LMetadata, 1);
  cbObjectType.ItemIndex := cbObjectType.Items.IndexOf(LObjectType);
  if cbObjectType.ItemIndex < 0 then
    cbObjectType.ItemIndex := cbObjectType.Items.IndexOf('edit');
  if (LObjectType = 'edit') or (LObjectType = 'memo') then
    cbComparisonOperator.ItemIndex :=
      cbComparisonOperator.Items.IndexOf('like')
  else
    cbComparisonOperator.ItemIndex :=
      cbComparisonOperator.Items.IndexOf('=');
end;

procedure TWebQueryCriteriaSetup.btOKClick(Sender: TObject);
begin
  if Trim(cbField.Text) = '' then
    raise Exception.Create('请选择字段名称。');
  if Trim(edCaption.Text) = '' then
    edCaption.Text := cbField.Text;
  if cbComparisonOperator.ItemIndex < 0 then
    raise Exception.Create('请选择比较运算符。');
  if cbObjectType.ItemIndex < 0 then
    raise Exception.Create('请选择对象类型。');
  ModalResult := mrOk;
end;

function TWebQueryCriteriaSetup.GetFieldName: string;
begin
  Result := Trim(cbField.Text);
end;

function TWebQueryCriteriaSetup.GetCaption: string;
begin
  Result := Trim(edCaption.Text);
end;

function TWebQueryCriteriaSetup.GetObjectType: string;
begin
  Result := Trim(cbObjectType.Text);
end;

function TWebQueryCriteriaSetup.GetComparisonOperator: string;
begin
  Result := Trim(cbComparisonOperator.Text);
end;

function TWebQueryCriteriaSetup.GetIndependence: Boolean;
begin
  Result := ckIndePendence.Checked;
end;

function TWebQueryCriteriaSetup.GetHideCaption: Boolean;
begin
  Result := ckHideCaption.Checked;
end;

end.
