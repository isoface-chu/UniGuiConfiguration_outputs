unit ugWebConfiguration.Moduletype;


interface

uses
  System.SysUtils, System.Classes, System.Variants,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Data.DB, Datasnap.DBClient, System.JSON, REST.Json,
  uniGUITypes, uniGUIAbstractClasses, uniGUIBaseClasses, uniGUIClasses,
  uniGUIForm, uniGUIFrame, uniPanel, uniButton, uniSpeedButton, uniLabel,
  uniPageControl, uniEdit, uniComboBox, uniCheckBox, uniMemo, uniSpinEdit,
  uniImageList, uniBasicGrid, uniDBGrid, uniDBTreeGrid, uniURLFrame,
  ugWebConfigurationBase;

type
  TWebModuletype = class(TWebConfigurationBase)
    pModuletype: TUniURLFrame;
    edModuletype: TUniEdit;
    procedure pModuletypeAjaxEvent(Sender: TComponent; EventName: string; Params: TUniStrings);
    procedure edModuletypeClick(Sender: TObject);
  private
    FModuleTypeSelector: TUniComboBox;
    FSelectButton:TUniButton;
    FDialog:TUniForm;
    procedure DialogClosed(Sender:TObject; var Action:TCloseAction);
    procedure SetModuleType(const AValue: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function CheckConfigure: Boolean; override;
    procedure LoadConfigure(AJSON: TJSONObject); override;
    procedure SaveConfigure(AJSON: TJSONObject); override;
    procedure CurrentAction(APageActionType: TPageActionType); override;
  end;

implementation

{$R *.dfm}

uses uniGUIApplication;

constructor TWebModuletype.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSelectButton:=TUniButton.Create(Self);
  FSelectButton.Parent:=Self;
  FSelectButton.Align:=alTop;
  FSelectButton.Height:=44;
  FSelectButton.Caption:='选择模块类型…';
  FSelectButton.OnClick:=edModuletypeClick;
  edModuletype.Visible := False;
  SetModuleType('');
end;

procedure TWebModuletype.SetModuleType(const AValue: string);
var Description,Title:string;
begin
  edModuletype.Text := AValue;
  Description:='';
  if AValue='mtEditor' then Description:='编辑对话框：配置需要录入的字段，供其他模块调用，确认后返回录入内容。'
  else if AValue='mtMultiple' then Description:='列表式模块：以表格浏览多条记录，可配置查询条件、分页及新增、修改、导入等功能按钮。'
  else if AValue='mtMasterSlave' then Description:='主从单据模块：上方显示主单信息，下方编辑明细。支持单据导航、主从保存、校验及审批规则配置。'
  else if AValue='mtTree' then Description:='树形模块：适合具有父子层级的数据，例如分类或组织结构。需要配置相应的层级关联字段。'
  else if AValue='mtReport' then Description:='报表模块：以数据查询和展示为主要用途，可配置查询条件和输出相关功能。'
  else if AValue='mtDetail' then Description:='明细模块：用于明细数据的浏览与相关业务配置，具体可用功能取决于配置和模板支持范围。'
  else if AValue='mtListEditor' then Description:='列表编辑模块：列表与顶部记录区同窗联动，不依赖查询或编辑子窗体。当前支持单根表浏览，以及数据库自增、Guid或MaxInt（非自增INT最大值+1）主键的新增、修改、保存、撤销和可选删除；写入时须同时启用查询、关闭、新增、修改、保存、撤销，删除按需勾选。主键须为已选字段，可设置为隐藏。查询区域可置顶或靠左，默认收起。暂不支持写入审计字段、层级权限、导入及复杂编辑控件。'
  else Description:='请在选择对话框中选择模块类型。';
  Title:=StringReplace(AValue,'&','&amp;',[rfReplaceAll]);
  Title:=StringReplace(Title,'<','&lt;',[rfReplaceAll]);
  Title:=StringReplace(Title,'>','&gt;',[rfReplaceAll]);
  if AValue = '' then
    FSelectButton.Caption:='选择模块类型…'
  else
    FSelectButton.Caption:='模块类型：'+AValue+'　（点击选择）';
  pModuletype.HTML.Text:='<div style="padding:20px;font:16px/1.8 sans-serif">'+
    '<h2>'+Title+'</h2><hr><p>'+Description+'</p>'+
    '<p>选择后，请依次配置功能按钮、数据结构及常规设置。具体生成能力以完成时的配置检查为准。</p></div>';
end;

destructor TWebModuletype.Destroy;
begin
  if Assigned(FDialog) then
  begin
    FDialog.OnClose:=nil;
    FreeAndNil(FDialog);
  end;
  inherited;
end;

procedure TWebModuletype.DialogClosed(Sender:TObject; var Action:TCloseAction);
begin
  if FDialog.ModalResult=mrOk then SetModuleType(FModuleTypeSelector.Text);
  FModuleTypeSelector:=nil;
  FDialog:=nil;
end;

procedure TWebModuletype.pModuletypeAjaxEvent(Sender: TComponent; EventName: string; Params: TUniStrings);
begin
  { TODO: reconstruct behavior from binary/template evidence. }
end;

procedure TWebModuletype.edModuletypeClick(Sender: TObject);
var B:TUniButton;
begin
  if Assigned(FDialog) then Exit;
  FDialog:=TUniForm.Create(UniApplication);
  try
    FDialog.Caption:='选择模块类型';
    FDialog.Width:=520;FDialog.Height:=210;
    FDialog.Position:=poScreenCenter;
    FDialog.FreeOnClose:=True;
    FModuleTypeSelector:=TUniComboBox.Create(FDialog);
    FModuleTypeSelector.Parent:=FDialog;
    FModuleTypeSelector.SetBounds(20,25,465,36);
    FModuleTypeSelector.Style := csDropDownList;
    // 模块类型呈现顺序与向导一致：编辑器、列表、树、报表、主从、明细
    FModuleTypeSelector.Items.Add('mtEditor');
    FModuleTypeSelector.Items.Add('mtMultiple');
    FModuleTypeSelector.Items.Add('mtTree');
    FModuleTypeSelector.Items.Add('mtReport');
    FModuleTypeSelector.Items.Add('mtMasterSlave');
    FModuleTypeSelector.Items.Add('mtDetail');
    FModuleTypeSelector.Items.Add('mtListEditor');
    FModuleTypeSelector.ItemIndex:=FModuleTypeSelector.Items.IndexOf(edModuletype.Text);
    if FModuleTypeSelector.ItemIndex<0 then FModuleTypeSelector.ItemIndex:=0;
    B:=TUniButton.Create(FDialog);B.Parent:=FDialog;
    B.SetBounds(285,100,90,32);B.Caption:='确定';B.ModalResult:=mrOk;
    B:=TUniButton.Create(FDialog);B.Parent:=FDialog;
    B.SetBounds(395,100,90,32);B.Caption:='取消';B.ModalResult:=mrCancel;
    FDialog.OnClose:=DialogClosed;
    FDialog.ShowModal;
  except
    FreeAndNil(FDialog);FModuleTypeSelector:=nil;raise;
  end;
end;

function TWebModuletype.CheckConfigure: Boolean;
begin
  Result := Trim(edModuletype.Text) <> '';
end;

procedure TWebModuletype.LoadConfigure(AJSON: TJSONObject);
var
  LValue: TJSONValue;
begin
  LValue := AJSON.GetValue('TWebModuletype');
  if Assigned(LValue) and not (LValue is TJSONNull) then
    SetModuleType(LValue.Value)
  else
    SetModuleType('');
end;

procedure TWebModuletype.SaveConfigure(AJSON: TJSONObject);
var
  LPair: TJSONPair;
begin
  LPair := AJSON.RemovePair('TWebModuletype');
  LPair.Free;
  AJSON.AddPair('TWebModuletype', edModuletype.Text);
end;

procedure TWebModuletype.CurrentAction(APageActionType: TPageActionType);
begin
  inherited CurrentAction(APageActionType);
end;

end.
