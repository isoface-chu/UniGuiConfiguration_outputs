unit ugWebConfiguration.QueryCriteria.BatchAppend;


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
  TWebQueryCriteriaBatchAppend = class(TWebCustBaseForm)
    UniDBGrid1: TUniDBGrid;
    btOK: TUniButton;
    btCancel: TUniButton;
    pActions: TUniContainerPanel;
    UniHiddenPanel1: TUniHiddenPanel;
    cbObjectType: TUniComboBox;
    cbComparisonOperator: TUniComboBox;
    cdsColumns: TClientDataSet;
    dsColumns: TDataSource;
    procedure UniDBGrid1ColumnSort(Column: TUniDBGridColumn; Direction: Boolean);
    procedure btOKClick(Sender: TObject);
  public
    procedure Prepare(AColumns: TClientDataSet);
  end;

implementation

{$R *.dfm}

procedure TWebQueryCriteriaBatchAppend.Prepare(AColumns: TClientDataSet);
var
  I: Integer;
  B: TBookmark;
  procedure AddField(const N: string; T: TFieldType; Size: Integer = 0);
  begin
    if cdsColumns.FieldDefs.IndexOf(N) < 0 then cdsColumns.FieldDefs.Add(N, T, Size);
  end;
begin
  Caption := '批量新增查询条件';
  cbObjectType.Items.CommaText :=
    'edit,memo,number,date,time,datetime,check,combobox,lookupedit,lookupeditextra,gridcombobox,gridcomboboxextra';
  cbComparisonOperator.Items.CommaText := '=,<>,>,>=,<,<=,like,in';
  cdsColumns.Close;
  cdsColumns.FieldDefs.Assign(AColumns.FieldDefs);
  AddField('fdComparisonOperator', ftWideString, 10);
  AddField('fdIndePendence', ftBoolean);
  AddField('fdHideCaption', ftBoolean);
  cdsColumns.CreateDataSet;
  B := AColumns.GetBookmark;
  AColumns.DisableControls;
  try
    AColumns.First;
    while not AColumns.Eof do
    begin
      if AColumns.FieldByName('fdSELECT').AsBoolean then
      begin
        cdsColumns.Append;
        for I := 0 to AColumns.FieldCount - 1 do
          if cdsColumns.FindField(AColumns.Fields[I].FieldName) <> nil then
            cdsColumns.FieldByName(AColumns.Fields[I].FieldName).Value := AColumns.Fields[I].Value;
        cdsColumns.FieldByName('fdSELECT').AsBoolean := False;
        if cdsColumns.FieldByName('fdOBJECT_TYPE').AsString = '' then
          cdsColumns.FieldByName('fdOBJECT_TYPE').AsString := 'edit';
        if SameText(cdsColumns.FieldByName('fdOBJECT_TYPE').AsString, 'edit') or
          SameText(cdsColumns.FieldByName('fdOBJECT_TYPE').AsString, 'memo') then
          cdsColumns.FieldByName('fdComparisonOperator').AsString := 'like'
        else cdsColumns.FieldByName('fdComparisonOperator').AsString := '=';
        cdsColumns.FieldByName('fdIndePendence').AsBoolean := False;
        cdsColumns.FieldByName('fdHideCaption').AsBoolean := False;
        cdsColumns.Post;
      end;
      AColumns.Next;
    end;
  finally
    if AColumns.BookmarkValid(B) then AColumns.GotoBookmark(B);
    AColumns.FreeBookmark(B);
    AColumns.EnableControls;
  end;
  cdsColumns.First;
end;

procedure TWebQueryCriteriaBatchAppend.UniDBGrid1ColumnSort(Column: TUniDBGridColumn; Direction: Boolean);
begin
  if (Column = nil) or (cdsColumns.FindField(Column.FieldName) = nil) then Exit;
  if cdsColumns.State in dsEditModes then cdsColumns.Post;
  cdsColumns.IndexName := '';
  cdsColumns.IndexDefs.Update;
  if cdsColumns.IndexDefs.IndexOf('BatchSort') >= 0 then cdsColumns.DeleteIndex('BatchSort');
  if Direction then
    cdsColumns.AddIndex('BatchSort', Column.FieldName, [])
  else cdsColumns.AddIndex('BatchSort', Column.FieldName, [ixDescending]);
  cdsColumns.IndexName := 'BatchSort';
end;

procedure TWebQueryCriteriaBatchAppend.btOKClick(Sender: TObject);
begin
  if cdsColumns.State in dsEditModes then cdsColumns.Post;
  cdsColumns.First;
  while not cdsColumns.Eof do
  begin
    if cdsColumns.FieldByName('fdSELECT').AsBoolean then
    begin
      if cbObjectType.Items.IndexOf(cdsColumns.FieldByName('fdOBJECT_TYPE').AsString) < 0 then
        raise Exception.Create('请选择有效的查询控件类型。');
      if cbComparisonOperator.Items.IndexOf(cdsColumns.FieldByName('fdComparisonOperator').AsString) < 0 then
        raise Exception.Create('请选择有效的比较运算符。');
    end;
    cdsColumns.Next;
  end;
  ModalResult := mrOk;
end;

end.
