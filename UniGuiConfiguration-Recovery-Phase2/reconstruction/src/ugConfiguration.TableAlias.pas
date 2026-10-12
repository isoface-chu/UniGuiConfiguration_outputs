unit ugConfiguration.TableAlias;

interface

uses Datasnap.DBClient;

procedure RenameTableColumns(Columns:TClientDataSet;
  const TableGuid,TableName,NewAlias:string);

implementation

uses System.SysUtils;

procedure RenameTableColumns(Columns:TClientDataSet;
  const TableGuid,TableName,NewAlias:string);
var
  OldIndex,OldFields,V:string;
  WasFiltered:Boolean;
begin
  OldIndex:=Columns.IndexName;
  OldFields:=Columns.IndexFieldNames;
  WasFiltered:=Columns.Filtered;
  Columns.DisableControls;
  try
    // Editing an indexed alias/table/field name moves the current record.
    // Traverse the physical rows to avoid skipping records after Post.
    Columns.IndexName:='';
    Columns.IndexFieldNames:='';
    Columns.Filtered:=False;
    Columns.First;
    while not Columns.Eof do
    begin
      if Columns.FieldByName('fdTABLE_GUID').AsString=TableGuid then
      begin
        V:=Columns.FieldByName('fdCOLUMN_NAME').AsString;
        if Pos('.',V)=0 then raise Exception.Create('字段限定名无效，未完成别名更新。');
        Columns.Edit;
        Columns.FieldByName('fdEpithet').AsString:=NewAlias;
        Columns.FieldByName('fdCOLUMN_NAME').AsString:=NewAlias+Copy(V,Pos('.',V),MaxInt);
        Columns.FieldByName('fdTABLE_NAME').AsString:=TableName+'('+NewAlias+')';
        Columns.Post; // Invokes existing GUID-based typesetting synchronization.
      end;
      Columns.Next;
    end;
  finally
    Columns.Filtered:=WasFiltered;
    if OldIndex<>'' then Columns.IndexName:=OldIndex
    else Columns.IndexFieldNames:=OldFields;
    Columns.EnableControls;
  end;
end;

end.
