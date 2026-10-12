unit ugConfiguration.Document;


interface

uses
  System.SysUtils, System.Classes, System.JSON;

type
  EUniGuiConfiguration = class(Exception);

  { Owns a complete wizard JSON document while preserving unknown fields. }
  TUniGuiConfigurationDocument = class
  private
    FRoot: TJSONObject;
    function GetString(AIndex: Integer): string;
    procedure SetString(AIndex: Integer; const AValue: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure LoadFromText(const AText: string);
    procedure LoadFromFile(const AFileName: string);
    function SaveToText: string;
    procedure SaveToFile(const AFileName: string);
    function Validate(AErrors: TStrings): Boolean;
    function Section(const AName: string; ACreate: Boolean = False): TJSONObject;
    function CloneRoot: TJSONObject;
    property Root: TJSONObject read FRoot;
    property DataNodeName: string index 0 read GetString write SetString;
    property ModuleType: string index 1 read GetString write SetString;
    property FunctionButtons: string index 2 read GetString write SetString;
  end;

implementation

const
  CPropertyNames: array[0..2] of string = (
    'TWebDataNodeName', 'TWebModuletype', 'TWebFunctionButton');

  CRequiredSections: array[0..4] of string = (
    'TWebDataStructure', 'TWebDetailedStructure', 'TWebDataPerspective',
    'TWebQueryCriteria', 'TWebNormalSetting');

  CModuleTypes: array[0..6] of string = (
    'mtEditor', 'mtMultiple', 'mtTree', 'mtReport', 'mtMasterSlave', 'mtDetail', 'mtListEditor');

constructor TUniGuiConfigurationDocument.Create;
begin
  inherited Create;
  FRoot := TJSONObject.Create;
end;

destructor TUniGuiConfigurationDocument.Destroy;
begin
  FRoot.Free;
  inherited Destroy;
end;

procedure TUniGuiConfigurationDocument.Clear;
begin
  FreeAndNil(FRoot);
  FRoot := TJSONObject.Create;
end;

function TUniGuiConfigurationDocument.GetString(AIndex: Integer): string;
var
  LName: string;
  LValue: TJSONValue;
begin
  LName := CPropertyNames[AIndex];
  LValue := FRoot.GetValue(LName);
  if Assigned(LValue) and not (LValue is TJSONNull) then
    Exit(LValue.Value);
  Result := '';
end;

procedure TUniGuiConfigurationDocument.SetString(AIndex: Integer;
  const AValue: string);
var
  LName: string;
  LPair: TJSONPair;
begin
  LName := CPropertyNames[AIndex];
  LPair := FRoot.RemovePair(LName);
  LPair.Free;
  FRoot.AddPair(LName, AValue);
end;

procedure TUniGuiConfigurationDocument.LoadFromText(const AText: string);
var
  LValue: TJSONValue;
begin
  LValue := TJSONObject.ParseJSONValue(AText);
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    raise EUniGuiConfiguration.Create('配置内容不是有效的 JSON 对象。');
  end;
  FRoot.Free;
  FRoot := TJSONObject(LValue);
end;

procedure TUniGuiConfigurationDocument.LoadFromFile(const AFileName: string);
var
  LText: TStringList;
begin
  LText := TStringList.Create;
  try
    LText.LoadFromFile(AFileName, TEncoding.UTF8);
    LoadFromText(LText.Text);
  finally
    LText.Free;
  end;
end;

function TUniGuiConfigurationDocument.SaveToText: string;
begin
  Result := FRoot.Format(2);
end;

procedure TUniGuiConfigurationDocument.SaveToFile(const AFileName: string);
var
  LText: TStringList;
begin
  LText := TStringList.Create;
  try
    LText.Text := SaveToText;
    LText.SaveToFile(AFileName, TEncoding.UTF8);
  finally
    LText.Free;
  end;
end;

function TUniGuiConfigurationDocument.Section(const AName: string;
  ACreate: Boolean): TJSONObject;
var
  LValue: TJSONValue;
begin
  LValue := FRoot.GetValue(AName);
  if LValue is TJSONObject then
    Exit(TJSONObject(LValue));
  if Assigned(LValue) then
    raise EUniGuiConfiguration.CreateFmt('配置项 %s 应为 JSON 对象。', [AName]);
  if not ACreate then
    Exit(nil);
  Result := TJSONObject.Create;
  FRoot.AddPair(AName, Result);
end;

function TUniGuiConfigurationDocument.CloneRoot: TJSONObject;
begin
  Result := TJSONObject.ParseJSONValue(FRoot.ToJSON) as TJSONObject;
end;

function TUniGuiConfigurationDocument.Validate(AErrors: TStrings): Boolean;
var
  I: Integer;
  LModuleType: string;
  LKnown: Boolean;
begin
  if not Assigned(AErrors) then
    raise EArgumentNilException.Create('AErrors');
  AErrors.Clear;

  if Trim(DataNodeName) = '' then
    AErrors.Add('缺少 TWebDataNodeName。');
  LModuleType := ModuleType.Trim;
  if LModuleType = '' then
    AErrors.Add('缺少 TWebModuletype。')
  else
  begin
    LKnown := False;
    for I := Low(CModuleTypes) to High(CModuleTypes) do
      LKnown := LKnown or SameText(LModuleType, CModuleTypes[I]);
    if not LKnown then
      AErrors.Add('不支持的模块类型：' + LModuleType);
  end;

  for I := Low(CRequiredSections) to High(CRequiredSections) do
    if not (FRoot.GetValue(CRequiredSections[I]) is TJSONObject) then
      AErrors.Add('缺少或无效的配置区块：' + CRequiredSections[I]);

  Result := AErrors.Count = 0;
end;

end.
