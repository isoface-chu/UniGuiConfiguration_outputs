unit ugConfiguration.DataSetJson;


interface

uses
  System.SysUtils, System.Classes, System.JSON, Data.DB, Datasnap.DBClient;

type
  EConfigurationDataSet = class(Exception);

procedure LoadDataSetFromJSON(ADataSet: TClientDataSet; AJSON: TJSONObject);
function SaveDataSetToJSON(ADataSet: TClientDataSet): TJSONObject;

implementation

uses
  System.TypInfo, System.Generics.Collections;

function RequiredObject(AParent: TJSONObject; const AName: string): TJSONObject;
var
  LValue: TJSONValue;
begin
  if not Assigned(AParent) then
    raise EConfigurationDataSet.Create('JSON 对象不能为空。');
  LValue := AParent.GetValue(AName);
  if not (LValue is TJSONObject) then
    raise EConfigurationDataSet.CreateFmt('缺少 JSON 对象：%s。', [AName]);
  Result := TJSONObject(LValue);
end;

function JSONString(AObject: TJSONObject; const AName: string;
  const ADefault: string = ''): string;
var
  LValue: TJSONValue;
begin
  LValue := AObject.GetValue(AName);
  if not Assigned(LValue) or (LValue is TJSONNull) then
    Exit(ADefault);
  Result := LValue.Value;
end;

function JSONInteger(AObject: TJSONObject; const AName: string;
  ADefault: Integer = 0): Integer;
begin
  Result := StrToIntDef(JSONString(AObject, AName), ADefault);
end;

function FieldTypeFromName(const AName: string): TFieldType;
var
  LValue: Integer;
begin
  LValue := GetEnumValue(TypeInfo(TFieldType), AName);
  if LValue < 0 then
    raise EConfigurationDataSet.CreateFmt('未知字段类型：%s。', [AName]);
  Result := TFieldType(LValue);
end;

function FindNamedObject(AParent: TJSONObject;
  const AName: string): TJSONObject;
var
  I: Integer;
begin
  Result := nil;
  if not Assigned(AParent) then
    Exit;
  { Rio's GetValue treats its argument as a JSON path; a numeric member name
    such as "0" is not reliable through that API. Match the pair name
    directly while leaving Pairs[] order irrelevant. }
  for I := 0 to AParent.Count - 1 do
    if (AParent.Pairs[I].JsonString.Value = AName) and
      (AParent.Pairs[I].JsonValue is TJSONObject) then
      Exit(TJSONObject(AParent.Pairs[I].JsonValue));
end;

procedure CreateFields(ADataSet: TClientDataSet; AStructure: TJSONObject);
var
  I: Integer;
  LDefinition: TJSONObject;
  LFieldDef: TFieldDef;
  LName, LTypeName: string;
begin
  ADataSet.Close;
  ADataSet.FieldDefs.Clear;
  for I := 0 to AStructure.Count - 1 do
  begin
    if not (AStructure.Pairs[I].JsonValue is TJSONObject) then
      Continue;
    LDefinition := TJSONObject(AStructure.Pairs[I].JsonValue);
    LName := JSONString(LDefinition, 'FieldName');
    LTypeName := JSONString(LDefinition, 'FieldType');
    if (LName = '') or (LTypeName = '') then
      raise EConfigurationDataSet.Create('字段定义缺少 FieldName 或 FieldType。');
    LFieldDef := ADataSet.FieldDefs.AddFieldDef;
    LFieldDef.Name := LName;
    LFieldDef.DataType := FieldTypeFromName(LTypeName);
    LFieldDef.Size := JSONInteger(LDefinition, 'FieldSize');
    LFieldDef.Precision := JSONInteger(LDefinition, 'FieldPrecision');
  end;
  ADataSet.CreateDataSet;
end;

procedure LoadRows(ADataSet: TClientDataSet; ARows: TJSONObject);
var
  I, FieldIndex: Integer;
  LRow: TJSONObject;
  LValue: TJSONValue;
  LField: TField;
  LNumericKeys: Boolean;
begin
  ADataSet.DisableControls;
  try
    ADataSet.EmptyDataSet;
    { The original configuration writer omits Data for an empty data set.
      Its seven recovered golden configurations use this form extensively. }
    if not Assigned(ARows) then
      Exit;
    { System.JSON does not promise that Pairs[] follows the textual order of
      object members. The legacy format encodes row order explicitly as
      contiguous keys "0", "1", ...; honor those keys so field/layout order
      survives a load/save round trip. }
    LNumericKeys := True;
    for I := 0 to ARows.Count - 1 do
      if not Assigned(FindNamedObject(ARows, IntToStr(I))) then
      begin
        LNumericKeys := False;
        Break;
      end;
    for I := 0 to ARows.Count - 1 do
    begin
      if LNumericKeys then
        LRow := FindNamedObject(ARows, IntToStr(I))
      else
      begin
        if not (ARows.Pairs[I].JsonValue is TJSONObject) then
          Continue;
        LRow := TJSONObject(ARows.Pairs[I].JsonValue);
      end;
      ADataSet.Append;
      for FieldIndex := 0 to ADataSet.FieldCount - 1 do
      begin
        LField := ADataSet.Fields[FieldIndex];
        LValue := LRow.GetValue(LField.FieldName);
        if not Assigned(LValue) or (LValue is TJSONNull) then
          LField.Clear
        else
          LField.AsString := LValue.Value;
      end;
      ADataSet.Post;
    end;
    ADataSet.First;
  finally
    ADataSet.EnableControls;
  end;
end;

procedure LoadDataSetFromJSON(ADataSet: TClientDataSet; AJSON: TJSONObject);
var
  LRowsValue: TJSONValue;
begin
  if not Assigned(ADataSet) then
    raise EArgumentNilException.Create('ADataSet');
  CreateFields(ADataSet, RequiredObject(AJSON, 'TableStructure'));
  LRowsValue := AJSON.GetValue('Data');
  if not Assigned(LRowsValue) or (LRowsValue is TJSONNull) then
    LoadRows(ADataSet, nil)
  else if LRowsValue is TJSONObject then
    LoadRows(ADataSet, TJSONObject(LRowsValue))
  else
    raise EConfigurationDataSet.Create('JSON 对象 Data 的格式无效。');
end;

function SaveDataSetToJSON(ADataSet: TClientDataSet): TJSONObject;
var
  LStructure, LRows, LDefinition, LRow: TJSONObject;
  LBookmark: TBookmark;
  I, RowIndex: Integer;
  LField: TField;
  LIndexName, LIndexFieldNames: string;
begin
  if not Assigned(ADataSet) then
    raise EArgumentNilException.Create('ADataSet');
  Result := TJSONObject.Create;
  try
    LStructure := TJSONObject.Create;
    Result.AddPair('TableStructure', LStructure);
    for I := 0 to ADataSet.FieldDefs.Count - 1 do
    begin
      LDefinition := TJSONObject.Create;
      LStructure.AddPair(IntToStr(I), LDefinition);
      LDefinition.AddPair('FieldName', ADataSet.FieldDefs[I].Name);
      LDefinition.AddPair('FieldType', GetEnumName(TypeInfo(TFieldType), Ord(ADataSet.FieldDefs[I].DataType)));
      LDefinition.AddPair('FieldSize', TJSONNumber.Create(ADataSet.FieldDefs[I].Size));
      LDefinition.AddPair('FieldPrecision', TJSONNumber.Create(ADataSet.FieldDefs[I].Precision));
    end;

    LRows := TJSONObject.Create;
    Result.AddPair('Data', LRows);
    if not ADataSet.Active then
      Exit;
    LBookmark := ADataSet.GetBookmark;
    LIndexName := ADataSet.IndexName;
    LIndexFieldNames := ADataSet.IndexFieldNames;
    ADataSet.DisableControls;
    try
      { Grid header sorting installs an active index. It is a view concern and
        must not rewrite the configuration's row/layout order. Serialize the
        physical record order, then restore the user's current grid view. }
      ADataSet.IndexName := '';
      ADataSet.IndexFieldNames := '';
      RowIndex := 0;
      ADataSet.First;
      while not ADataSet.Eof do
      begin
        LRow := TJSONObject.Create;
        // Transfer ownership before field conversion can raise an exception.
        LRows.AddPair(IntToStr(RowIndex), LRow);
        for I := 0 to ADataSet.FieldCount - 1 do
        begin
          LField := ADataSet.Fields[I];
          if LField.IsNull then
            LRow.AddPair(LField.FieldName, TJSONNull.Create)
          else
            LRow.AddPair(LField.FieldName, LField.AsString);
        end;
        Inc(RowIndex);
        ADataSet.Next;
      end;
    finally
      if LIndexName <> '' then
        ADataSet.IndexName := LIndexName
      else if LIndexFieldNames <> '' then
        ADataSet.IndexFieldNames := LIndexFieldNames;
      if ADataSet.BookmarkValid(LBookmark) then
        ADataSet.GotoBookmark(LBookmark);
      ADataSet.FreeBookmark(LBookmark);
      ADataSet.EnableControls;
    end;
  except
    Result.Free;
    raise;
  end;
end;

end.
