unit ugWebConfiguration.DataPerspective.Setup;


interface

uses
  System.SysUtils, System.Classes, System.Variants,
  Vcl.Controls, Vcl.Forms, Data.DB, Datasnap.DBClient, System.JSON, REST.Json,
  uniGUITypes, uniGUIAbstractClasses, uniGUIBaseClasses, uniGUIClasses,
  uniGUIForm, uniGUIFrame, uniPanel, uniButton, uniSpeedButton, uniLabel,
  uniPageControl, uniEdit, uniComboBox, uniCheckBox, uniMemo, uniSpinEdit,
  uniImageList, uniBasicGrid, uniDBGrid, uniDBTreeGrid, uniURLFrame,
  ugWebCustBaseForm, uniMultiItem;

type
  TWebDataPerspectiveSetup = class(TWebCustBaseForm)
    cbFieldAs: TUniComboBox;
    edCaption: TUniEdit;
    edGroup: TUniEdit;
    cbType: TUniComboBox;
    ckDBlClickGoToDtails: TUniCheckBox;
    edField: TUniEdit;
    btOK: TUniButton;
    procedure cbFieldAsChange(Sender: TObject);
    procedure cbTypeChange(Sender: TObject);
    procedure btOKClick(Sender: TObject);
  private
    FFieldCaptions: TStringList;
    function GetSelectedField: string;
    function GetSelectedFieldAs: string;
    function GetSelectedCaption: string;
    function GetSelectedGroup: string;
    function GetSelectedType: Integer;
    function GetGoToDetails: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Prepare(AFields: TStrings; const AField, AFieldAs, ACaption,
      AGroup: string; AType: Integer; AGoToDetails: Boolean);
    property SelectedField: string read GetSelectedField;
    property SelectedFieldAs: string read GetSelectedFieldAs;
    property SelectedCaption: string read GetSelectedCaption;
    property SelectedGroup: string read GetSelectedGroup;
    property SelectedType: Integer read GetSelectedType;
    property GoToDetails: Boolean read GetGoToDetails;
  end;

implementation

{$R *.dfm}

constructor TWebDataPerspectiveSetup.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FFieldCaptions := TStringList.Create;
end;

destructor TWebDataPerspectiveSetup.Destroy;
begin
  FFieldCaptions.Free;
  inherited Destroy;
end;

procedure TWebDataPerspectiveSetup.Prepare(AFields: TStrings;
  const AField, AFieldAs, ACaption, AGroup: string; AType: Integer;
  AGoToDetails: Boolean);
var
  I: Integer;
begin
  FFieldCaptions.Assign(AFields);
  cbFieldAs.Items.BeginUpdate;
  try
    cbFieldAs.Items.Clear;
    for I := 0 to FFieldCaptions.Count - 1 do
      cbFieldAs.Items.Add(FFieldCaptions.Names[I]);
  finally
    cbFieldAs.Items.EndUpdate;
  end;
  cbFieldAs.ItemIndex := cbFieldAs.Items.IndexOf(AFieldAs);
  if (cbFieldAs.ItemIndex < 0) and (cbFieldAs.Items.Count > 0) then
    cbFieldAs.ItemIndex := 0;
  edField.Text := AField;
  edCaption.Text := ACaption;
  edGroup.Text := AGroup;
  if (AType < 0) or (AType > 1) then
    cbType.ItemIndex := 0
  else
    cbType.ItemIndex := AType;
  ckDBlClickGoToDtails.Checked := AGoToDetails;
  cbTypeChange(cbType);
  if (AField = '') and (cbFieldAs.ItemIndex >= 0) then
    cbFieldAsChange(cbFieldAs);
end;

procedure TWebDataPerspectiveSetup.cbFieldAsChange(Sender: TObject);
var
  LField, LCaption: string;
begin
  LField := cbFieldAs.Text;
  if LField = '' then
    Exit;
  edField.Text := LField;
  LCaption := FFieldCaptions.Values[LField];
  if LCaption = '' then
    LCaption := LField.Substring(LField.LastIndexOf('.') + 1);
  edCaption.Text := LCaption;
end;

procedure TWebDataPerspectiveSetup.cbTypeChange(Sender: TObject);
begin
  ckDBlClickGoToDtails.Enabled := cbType.ItemIndex = 1;
  if not ckDBlClickGoToDtails.Enabled then
    ckDBlClickGoToDtails.Checked := False;
end;

procedure TWebDataPerspectiveSetup.btOKClick(Sender: TObject);
begin
  if Trim(cbFieldAs.Text) = '' then
    raise Exception.Create('请选择字段别名。');
  if Trim(edField.Text) = '' then
    raise Exception.Create('字段表达式不能为空。');
  if Trim(edCaption.Text) = '' then
    edCaption.Text := cbFieldAs.Text;
  ModalResult := mrOk;
end;

function TWebDataPerspectiveSetup.GetSelectedField: string;
begin
  Result := Trim(edField.Text);
end;

function TWebDataPerspectiveSetup.GetSelectedFieldAs: string;
begin
  Result := Trim(cbFieldAs.Text);
end;

function TWebDataPerspectiveSetup.GetSelectedCaption: string;
begin
  Result := Trim(edCaption.Text);
end;

function TWebDataPerspectiveSetup.GetSelectedGroup: string;
begin
  Result := Trim(edGroup.Text);
end;

function TWebDataPerspectiveSetup.GetSelectedType: Integer;
begin
  Result := cbType.ItemIndex;
  if Result < 0 then
    Result := 0;
end;

function TWebDataPerspectiveSetup.GetGoToDetails: Boolean;
begin
  Result := ckDBlClickGoToDtails.Checked;
end;

end.

