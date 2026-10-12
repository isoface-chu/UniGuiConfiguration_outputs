{
                                  ███████████████████████
                          █████████████████████████████████████
                      █████████████████████████████████████████████
                  █████████████████████████████████████████████████████                        ██████████████████████  ██
                ███████████████████████████████████████████████████████████                  ██████            ██    ██  ██
              ███████████████████████████████████████████████████████████████                ██                ██      ██
            ███████████████████████████████████████████████████████████████████              ██                ██
          ███████████████████████████████████████████████████████████████████████            ██                ██      ██
        ███████████████████████████████████████████████████████████████████████████          ██                ██      ██
      ███████████████████████████████████████████████████████████████████████████████        ████              ██      ██
      ███████████████████████████████████████████████████████████████████████████████          ██              ██      ██
    ███████████████████████████████████████████████████████████████████████████████████        ██              ██      ██
    ███████████████████████████████████████████████████████████████████████████████████        ██              ██      ██
  ███████████████████████████████████████████████████████████████████████████████████████      ██              ██      ██
  ████████████████████████████████████                                 ██████████████████      ██              ██      ██
  ████████████████████████████                                 ████        ██████████████      ██              ██        ██
  ██████████████████████████                ██████████         ██          ████████████████    ██              ██        ██
  ██████████████████████████              ████  ████████                   ████████████████    ██              ██        ██
  ██████████████████████████                                     ████      ████████████████    ██              ██        ██
  ██████████████████████████                █████████            ██          ██████████████    ██              ██        ██
  ████████████████████████████                                               ████████████████  ██              ██        ██
  ████████████████████████████                                               ████████████████  ██          ████████████████
  ████████████████████████████                                               ██████████████    ██        ████████
    ██████████████████████████                     ██              ██          ██████          ██      ████████
    ██████████████████████████                       ████████████                ██            ████    ██████
      ████████████████████                                                       ██          ████████████  ████
                  ████                                   ██████████              ████        ████  ████████████
                    ██                                 ████    ██████            ████        ██████    ██    ██
                    ████                             ██████████  ██
                                  ██        ████████    ████████
                      ████                                                     ████    ██████    ██  ██████████
                      ██████                           ██████                ████  ██████        ██  ████████
                    ████  ██████                           ██████        ████████████          ████████████
                  ████        ██████████                         ████████████████            ███████
                  ████            █████████████████████████████████████    ████            ██████
                ████              ████  ██████       ████████████          ████        ██████
              ██████              ████  ██████             ████████        ████  ████████
            ████  ████████████████████  ██████               ██████        ██████████
            ██
}
unit ugPublicObjectManagement;

interface
uses
  FireDAC.Comp.Client, uniMenuButton,
  System.Classes,  System.JSON, uniGUIApplication,Datasnap.DBClient,
  FireDAC.Stan.Option,  System.TypInfo,
  Contnrs, Winapi.Windows, uniDBGrid,db,
  Vcl.Controls,Vcl.Graphics;
Const
//非可视组件设计器控制尺寸
  cNotViewComponentLength = 26;
Type
  TGetSource = (gsData,gsFile);

  TUGModuleType = (mtWeb,mtApp,mtRep);//模块类型
  TUGModuleTypes= Set Of TUGModuleType;
  //删除子项方法
  TDeleteItemMethod = reference to procedure(AObject:TObject);
  //过程方法
  TProcedureMethod = reference to procedure;
  //Ide创建控件事件
  TDesignCreateObjectEvent =  reference to procedure(AObject:TObject);
  //弹窗属性方法
  TDialogPropertyMethod = reference to procedure(AObject:TObject);
{$region 'IUgCustomExcel'}
  IUgCustomExcel = Interface
    ['{FF293639-8736-4570-9F4F-D9149CE51451}']
    Procedure SetCellValue(ASheetName:string;ARow,AColumn:Integer;AValue:Variant);//设置单元格值

    Procedure SetCellFontBold(ASheetName:string;ARow,AColumn:Integer;AIsBold:Boolean);//设置单元格字体加粗
    Procedure SetCellFontSize(ASheetName:string;ARow,AColumn:Integer;ASize:Single);//设置单元格字体大小
    Procedure SetCellFontColor(ASheetName:string;ARow,AColumn:Integer;AColor:TColor);//设置单元格字体颜色

    Procedure SetColumnWidth(ASheetName:string;AColumn:Integer;AWidth:double);//设置列宽[单位字符]
    Procedure SetRowHeight(ASheetName:string;ARow:Integer;AHeight:double);//设置行高[单位磅]
    Procedure SetCellBackgroundColor(ASheetName:string;ARow,AColumn:Integer;AColor:TColor);//设置低色
    Procedure SetRangeMerge(ASheetName:string;Cell1, Cell2:String);//合并单元格
    Procedure SetRangeBorders(ASheetName:string;Cell1, Cell2:String;AIndex:LongWord;ALinestyle:LongWord);//设置单元格线条

    Procedure SetRangeHorizontalAlignment(ASheetName:string;Cell1, Cell2:String;Alignment:LongWord);//设置选中范围文本水平排列方式
    Procedure SetRowHorizontalAlignment(ASheetName:string;ARow:Integer;Alignment:LongWord);//设置行文本水平排列方式
    Procedure SetColumnHorizontalAlignment(ASheetName:string;AColumn:Integer;Alignment:LongWord);//设置列文本水平排列方式
    Procedure SetCellHorizontalAlignment(ASheetName:string;ARow,AColumn:Integer;Alignment:LongWord);//设置单元格文本水平排列方式

    Procedure SetRangeVerticalAlignment(ASheetName:string;Cell1, Cell2:String;Alignment:LongWord);//设置选中范围文本垂直排列方式
    Procedure SetRowVerticalAlignment(ASheetName:string;ARow:Integer;Alignment:LongWord);//设置行文本垂直排列方式
    Procedure SetColumnVerticalAlignment(ASheetName:string;AColumn:Integer;Alignment:LongWord);//设置列文本垂直排列方式
    Procedure SetCellVerticalAlignment(ASheetName:string;ARow,AColumn:Integer;Alignment:LongWord);//设置单元格文本垂直排列方式

    Procedure CreateDetailed(ASheetName:String;AData:TDataSet);//创建明细
  End;
  //导出明细事件
  TDetailsExportEvent_ = procedure(ADataSet:TDataSet;AExcel:IUgCustomExcel) of object;
{$Endregion}
{$region 'IUGMM'}
  IUGMM = Interface
    ['{1084D706-19A3-4599-A565-7B0890D7E1B2}']
    Function  ServerTitle:String;//获取服务端标题
    Function  ApplicationVersion:String;//获取应用版本
    Function  Applicationbit:String;//获取运行平台

    function  HTTPDecode(const AStr: string): string;//连接码转字符串
    function  HTTPEncode(const AStr: string): string;//字符串转连接码

    function  EncodeString(AText:String):string;//字符加密
    function  DecodeString(AText:String):string;//字符解密

    Function  LT(AText:String):string;//获取言语信息
    Procedure LC(AObject:TObject);//界面翻译

    Function  CreateGuid:string;//创建GUID唯一编号

    Function  GetObject(Const ASign:String):TObject; //获取线程管理共享对象
    Procedure AddObject(Const ASign:String;AObject:TObject);//添加线程管理共享对象
    Procedure DelObject(const ASign:String);//释放线程管理共享对象

    Function  GetWebSubForm(ACaption:String;Const AType:String = 'WEB'):TComponent;//获取子窗体
    Procedure DelWebSubForm(ACaption:String);//从内存中释放子窗体
    Function  GetAppSubForm(ACaption:String;Const AFullScreen:Boolean = True):TComponent;//获取子窗体
    Procedure DelAppSubForm(ACaption:String);//从内存中释放子窗体

    Function  GetNodeDataLink(Const ANodeName:String):TFDCustomConnection;//获取二层调用节点库
    Function  GetDriverIDByNodeNames(Const ADriver:String = ''):String;//获取节点库列表
    Function  GetNodeNameByDriver(Const ANodeName:String):String;//获取节点库驱动
    Function  GetNodeNameByCatalogName(Const ANodeName:String):String;//获取节点库目录
    Function  GetNodeNameBySchemaName(Const ANodeName:String):String;//获取节点库架构
    Function  GetNodeDataTableComments(Const ANodeName,ATableName:String):String;//获取表描述
    Procedure GetNodeDataTables(Const ANodeName:String;ACds:TClientdataset);//获取节点库表信息
    Procedure GetNodeDataColumns(Const ANodeName,ATableName:String;ACds:TClientdataset);//获取节点库字段信息
    Procedure GetSequences(Const ANodeName:String;ACds:TClientdataset);//获取序列列表信息

    Function  GetDllComponent(APathName:String;AOwner:TComponent):TComponent;//获取DLL对象
    Function  GetRunFrame(AOwner:TComponent;AKey:String;AGetSoure:TGetSource):TComponent;//获取运行模块

    procedure AddReport(ADllName:string;AButton:TUniMenuButton;AIsEditor:Boolean;Const AForceName:string = ''{可强制指定地址});//添加报表模块
    procedure DelReport(Const AOwner : TComponent);//删除报表功能
    procedure PrintReport(AOwner:TComponent;AReportName:String);//直接打印报表
    Function  ReportDesignPermission(AOwner:TComponent):Boolean;//判断当前登陆用户是否有对应模块的报表设计权限

    function  ImpExcel(ADBGrid:TUniDBGrid;Const ACaption,ARequiredItems:String):Boolean;//导入电子表格
    function  ExpExcel(ADBGrid:TUniDBGrid;Const ACaption,ATitle:String;Const E:TDetailsExportEvent_ = nil):Boolean;//导出电子表格
    Procedure ImportText(AGrid:TUniDBGrid;AColumnCaptions:String);//导入文本

    (*函数GetCdsRecordCount不支持返回过程记录数*)
    Function  GetCdsRecordCount(ANodeName:String;
                                ACds:TClientDataSet) : integer;
    Procedure OpenCds(ANodeName:String;
                      ACds:TClientDataSet;
                      Const SelectMaxRecordCount:Integer = 0;
                      Const RecordCountMode : TFDRecordCountMode = cmTotal;
                      Const PageRowCount :integer = -1;
                      Const PageIndex:Integer = -1);//打开数据集

    Procedure ExecSql(ANodeName,ASqlText:String;Const ALines:TStringList = Nil);//执行SQL脚本
    Procedure ApplyUpdatesCds(ANodeName:String;ACdsList:array of TClientDataSet);
    Procedure ApplyUpdatesCds1(ANodeName:String;ACds:TClientDataSet);//更新一个数据集
    Procedure ApplyUpdatesCds2(ANodeName:String;ACds1,ACds2:TClientDataSet);//同步更新两个数据集
    Procedure ApplyUpdatesCds3(ANodeName:String;ACds1,ACds2,ACds3:TClientDataSet);//同步更新三个数据集
    Procedure ApplyUpdatesCds4(ANodeName:String;ACds1,ACds2,ACds3,ACds4:TClientDataSet);
    Procedure ApplyUpdatesCds5(ANodeName:String;ACds1,ACds2,ACds3,ACds4,ACds5:TClientDataSet);
    Procedure ApplyUpdatesCds6(ANodeName:String;ACds1,ACds2,ACds3,ACds4,ACds5,ACds6:TClientDataSet);
    Procedure ExecuteCds(ANodeName:String;ACds:TClientDataSet);//执行CDS

    Function  AllowExecSql:Boolean;
    Function  ExecSqlSeparator:String;

    Function DataSetToJSON(AData:TDataSet):String;
    Procedure JSONToClientDataSet(AJSON:String;ACds:TClientDataSet;Const LabelName:String = 'TableData');

    Function  CellRestApi(Const AUrl , AParam , AHeaders , ABody : String; Const AType : String = 'Post'):String;//调用接口

    procedure GetAllRunFrameList(ACds:TClientDataSet;Const AType:String);//获取所有模块列表

    Function InputQuery(const ACaption, APrompt: string; var Value: string):Boolean;//输入提示框
    Function GetTickCount:int64; //获取耗时数据

    Function  JsonFormat(AJsonValue: TJSONValue):String; //Json格式化
    Function  JsonTextFormat(AJsonText : String):String; //Json格式化
  End;
{$Endregion}
{$region 'IUniMainModule'}
  IUniMainModule = Interface
    ['{BB121702-75DA-46EF-AB9F-77FEADCAE0A9}']
    Function GetDllMainModule : TObject;
  End;
{$Endregion}
{$region 'IEditorState'}
  IEditorState=Interface{编辑状态接口}
  ['{5DD915CA-3045-4872-9A53-A8DA1BB6982F}']
    Function GetIsEditor:Boolean;
    Procedure SetIsEditor(Value:Boolean);
    Property  IsEditor:Boolean Read GetIsEditor Write SetIsEditor;
  End;
{$Endregion}
//IDE模块接口
{$region 'IUGDesignFrame'}
  IUGDesignFrame = Interface
  ['{024428F3-D9A7-4C69-B1B1-16F496D08761}']
    //添加窗体设计{IUGDesignFrame}
    procedure AddRunFromDesign;
    //消除窗体设计{IUGDesignFrame}
    procedure DelRunFromDesign;
    //刷新设计器脚本代码{IUGDesignFrame}
    Procedure RefDesignScriptCode;
  End;
{$Endregion}
//IDE设计接口
{$region 'IUGDesign'}
  IUGDesign = Interface
    ['{95205F25-6EFF-4161-885C-66E8AEB6EB18}']
    {座标控制}
    Function  GetX:Integer;
    Procedure SetX(Value:Integer);
    Function  GetY:Integer;
    Procedure SetY(Value:Integer);
    {长宽控制}
    Function  GetW:Integer;
    Procedure SetW(Value:Integer);
    Function  GetH:Integer;
    Procedure SetH(Value:Integer);
    {显示控制}
    Function  GetV:Boolean;
    {双击}
    Procedure OnDblClickProc(ADIM:TDeleteItemMethod;AProc:TProcedureMethod);
    {鼠标控制}
    Function  BeforeMouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer):Boolean;//按下鼠标前
    Procedure AfterMouseDown (Button: TMouseButton; Shift: TShiftState; X, Y: Integer);//按下鼠标后

    Property Left:Integer Read GetX Write SetX;
    Property Top :Integer Read GetY Write SetY;
    Property Width:Integer Read GetW Write SetW;
    Property Height:Integer Read GetH Write SetH;
    Property Visible:Boolean Read GetV;
  End;
{$Endregion}
//双击接口
{$region 'IUGAppDblClickProc'}
  IUGAppDblClickProc = Interface
    ['{7EB7300B-F422-4638-90B7-7D5945A19D11}']
    Procedure AppOnDblClickProc(ADIM:TDeleteItemMethod;AProc:TProcedureMethod;Const ADesign:TComponent);
  End;
{$Endregion}
//结构接口
{$region 'IUGStructure'}
  IUGStructure =  Interface
  ['{4A68964E-994A-4EA1-A479-28B785692DA1}']
  //添加节点对象
    Function AddItemObject:TObject;
  //获取当前对象
    Function ActiveObject:TObject;
  //获取记录条数
    function GetCount:Integer;
  //获取对象节点显示文本
    Function GetItemObjectNodeText(AObject:TObject):String;
  //以对象获取索引值
    Function GetIndexByItemObject(AObject:TObject):Integer;
  //设置对象索引值
    procedure SetItemObjectIndex(AObject:TObject;AIndex:Integer);
  //以索引获取对象
    Function GetItemObjectByIndex(AIndex:Integer):TObject;
  //点击节点后动作
    Procedure ClickNodeProc(AObject:TObject;ADesign:TComponent);
  End;
{$Endregion}
//属性接口
{$region 'IUgInspector'}
   IUgInspector =  Interface
   ['{7B92D659-D7DD-4A72-A902-FC2D05E5888E}']
     Function IsEditPropetyRefDesignControl(PropetyName:String):Boolean;
   End;
{$Endregion}
//内存流转存格式流
{$region 'TUgConfigurationStream'}
  TUgConfigurationStream=Class(TPersistent)
  private
    FStream:TMemoryStream;
    FOnChange: TNotifyEvent;
  protected
    procedure DoChange; virtual;
    procedure DefineProperties(Filer: TFiler); override;
    procedure AssignTo(Dest: TPersistent); override;
  Public
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    Property Stream:TMemoryStream Read FStream;
    procedure LoadFromStream(Stream: TStream);
    procedure SaveToStream(Stream: TStream);
    constructor Create;
    destructor Destroy; override;
  End;
{$Endregion}
//控件容器
{$region 'TCuestomObjectItem'}
  TCustomObjectItem=Class(TCollectionItem)
  public
    UGModuleTypes:TUGModuleTypes;
    GroupName:String;      //列组名称
    CustomClass:TClass;    //封装控件
    BmpStream: TMemoryStream;    //控件图标
    DesignCreateObjectEvent : TDesignCreateObjectEvent;
    destructor Destroy; override;
  End;
{$Endregion}
{$region 'TCustomObjectCollection'}
   TCustomObjectCollection = class(TCollection)
   private
     function GetObjectItem(Index: Integer): TCustomObjectItem;{跟据Index获取Item}
   public
     //Items属性
     property  Items[Index:Integer] :TCustomObjectItem Read GetObjectItem; default;
     //跟据TClass来获取Item
     Function  IndexOfClass(AClass:TClass):Integer;
     //注册自定义控件
     procedure RegisterObject(Const AGroup:String;
                              AClass:TClass;
                              ABmpStream:TMemoryStream;
                              AUGModuleTypes:TUGModuleTypes;
                              Const ADesignCreateObjectEvent:TDesignCreateObjectEvent = Nil);
     //注销自定义控件
     procedure Unregister(AClass: TClass);
     //创建
     constructor Create;
   end;
{$Endregion}
//弹窗属性容器
{$region 'TCustomDialogProperty'}
  TCustomDialogProperty  = Class(TCollectionItem)
  public
    PropertyType   : PTypeInfo;
    PropertyClass  : TClass;
    PropertyName   : string;
    PropertyMethod : TDialogPropertyMethod;
    destructor Destroy; override;
  End;
{$Endregion}
{$region 'TCustomDialogPropertys'}
  TCustomDialogPropertys = class(TCollection)
  private
     function GetObjectItem(Index: Integer): TCustomDialogProperty;{跟据Index获取Item}
   public
     //Items属性
     property  Items[Index:Integer] :TCustomDialogProperty Read GetObjectItem; default;
     //跟据TClass来获取Item
     Function  IndexOfClass(APropertyType : PTypeInfo; APropertyClass : TClass; APropertyName  : string):Integer;
     //注册弹窗属性
     procedure RegisterDialogProperty(APropertyType  : PTypeInfo;
                                      APropertyClass : TClass;
                                      APropertyName  : string;
                                      ADialogMethod  : TDialogPropertyMethod);
     //创建
     constructor Create;
  end;
{$Endregion}
//全局变量
{$region 'TGlobalVariable'}
  TGlobalVariable = class
  private
    FCustomObjectCollection : TCustomObjectCollection;
    FCustomDialogPropertys  : TCustomDialogPropertys;

    Function GetCustomClasses:TCustomObjectCollection;
    Function GetCustomDialogPropertys:TCustomDialogPropertys;
  public
    Property CustomClasses:TCustomObjectCollection Read GetCustomClasses;
    Property CustomDialogPropertys:TCustomDialogPropertys Read GetCustomDialogPropertys;
    destructor Destroy; override;
  end;
{$Endregion}
//全局变量
Function GlobalVariable : TGlobalVariable;
//自定义固件容器
Function CustomClasses:TCustomObjectCollection;
//自定义弹窗属性
Function CustomDialogPropertys:TCustomDialogPropertys;
//获取唯一地址
Function CreateGuid:String;
//获取名称
function GetIncName(O:TComponent):String;
{$region 'exe'}
{$IF DEFINED(Exe)}
Type
//这个管理器网上抄的
  TDllManager=Class;
//Dll子项目
  TDllItem=Class(TObject)
  private
    FOwner  :TDllManager;
    FHandle :HMODULE;
    FDllName:String;
    Procedure SetDllName(Const Value:String);
  public
    Property DllFileName:String  Read FDllName Write SetDllName;
    Property Handle :THandle Read FHandle  Write FHandle;
    constructor Create; virtual;
    destructor Destroy; override;
  End;

  TDllManager=Class(TList)
  private
    FLock: {TCriticalSection;}TRTLCriticalSection;
    procedure Lock;
    procedure UnLock;
    Function GetDllByName(const DllFileName: String):TDllItem;
  public
    procedure Clear;overload;
    function Add(const DllFileName: String): Integer; overload;
    function IndexOf(const DllFileName: String): Integer; overload;
    function Remove(const DllFileName: String): Integer; overload;
    property DllsByName[const DllFileName: String]: TDllItem read GetDllByName;
    constructor Create;
    destructor Destroy; override;
  End;

  Procedure AddDllControl;
  Procedure DelDllControl;
  Function  GetDllManager:TDllManager;
  Function  GetDllComponent(ADllName,AComponentName:String;AOwner:TComponent):TComponent;
  Procedure ProcFinalization;
{$IFEND}
{$Endregion}

{$region 'dll'}
{$IF DEFINED(DLL)}
Type
  TClientdatasetHelperObject = Class
  Public
    HelperClientdataset    : TClientdataset;

    DataNodeName           : String;
    //RecordCountMode     : TFDRecordCountMode;
    PageRowCount           : Integer; //每页行数默认-1不分页
    PageIndex              : Integer; //当前页数默认-1不分页，1为第一页,0无意义
    PageCount              : Integer; //总页数-1不分页
    TotalRecordCount       : Integer; //总行数，如果不分页则RecordCount
    ErrorCommandTextOffset : Integer;
    FilterParams           : TStringList;
    destructor Destroy; override;
  end;
  {增加支持分页，支持三层提交及执行}
  TClientdatasetHelper = class helper for TClientdataset
  private
    Function GetClientdatasetHelperObjectFlag : String;
    Function GetClientdatasetHelperObject : TClientdatasetHelperObject;
  protected
    Function GetDataNodeName:String;
    Procedure SetDataNodeName(Value:String);

    Function GetPageRowCount:Integer;
    Procedure SetPageRowCount(Value:Integer);

    Function GetPageIndex:Integer;
    Procedure SetPageIndex(Value:Integer);

    Function GetPageCount:Integer;

    Function GetTotalRecordCount:Integer;
    Function GetErrorCommandTextOffset : Integer;

    Function GetFilterParams:TStringList;
  Public
    Property DataNodeName           : String  Read GetDataNodeName Write SetDataNodeName;
    Property PageRowCount           : Integer Read GetPageRowCount Write SetPageRowCount;
    Property PageIndex              : Integer Read GetPageIndex    Write SetPageIndex;
    Property PageCount              : Integer Read GetPageCount;
    Property TotalRecordCount       : Integer Read GetTotalRecordCount;
    Property ErrorCommandTextOffset : Integer Read GetErrorCommandTextOffset;

    property FilterParams:TStringList read GetFilterParams;

    Procedure ReFilter;//重新过滤

    Procedure Open;//打开
    Procedure Close;//关闭
    Procedure SubmitUpdates;//提交更新
    Procedure Execute;   //执行
    Procedure FreeHelperObject;//释放补助对象
    procedure Free;//释放
  end;
Function GetUGMM:IUGMM;
{$IFEND}
{$Endregion}
implementation
uses
  {$IF DEFINED(Exe)}
  ugBasics,ugConst,
  {$IFEND}
  {$IF DEFINED(DLL)}
  ugCallModular,
  ugRegDllControl,
  uniGUIMainModule,
  FireDAC.Stan.Error,
  {$IFEND}
  {Winapi.ActiveX,}System.SysUtils,Vcl.Forms;
//配置流对象
{$region 'TUgConfigurationStream'}
procedure TUgConfigurationStream.DoChange;
Begin
  if Assigned(FOnChange) then
    FOnChange(Self);
End;

procedure TUgConfigurationStream.DefineProperties(Filer: TFiler);
Begin
  inherited;
  Filer.DefineBinaryProperty('Stream', LoadFromStream, SaveToStream, FStream.Size > 0);
End;
procedure TUgConfigurationStream.AssignTo(Dest: TPersistent);
Begin
  if Dest is TUgConfigurationStream then
  Begin
    FStream.Clear;
    FStream.CopyFrom(TUgConfigurationStream(Dest).FStream,TUgConfigurationStream(Dest).FStream.Size);
    DoChange;
  End Else
  inherited;
End;

procedure TUgConfigurationStream.LoadFromStream(Stream: TStream);
Begin
  Stream.Position:=0;
  FStream.LoadFromStream(Stream);
  DoChange;
End;
procedure TUgConfigurationStream.SaveToStream(Stream: TStream);
Begin
  FStream.SaveToStream(Stream);
  Stream.Position:=0;
End;

constructor TUgConfigurationStream.Create;
Begin
  inherited Create;
  FStream:=TMemoryStream.Create;
End;
destructor TUgConfigurationStream.Destroy;
Begin
  FStream.Free;
  inherited Destroy;
End;
{$Endregion}
{$region 'TCuestomObjectItem'}
destructor TCustomObjectItem.Destroy;
begin
    BmpStream.Free;
  inherited Destroy;
end;
{$Endregion}
{$region 'TCuestomObjectCollection'}
function TCustomObjectCollection.GetObjectItem(Index: Integer): TCustomObjectItem;
Begin
  Result := TCustomObjectItem(inherited Items[Index]);
End;

Function  TCustomObjectCollection.IndexOfClass(AClass:TClass):Integer;
Var
  Index:Integer;
Begin
  for Index := 0 to Self.Count - 1 do
    if Self.GetObjectItem(Index).CustomClass=AClass then
      Exit(Index);
  Exit(-1);
End;

procedure TCustomObjectCollection.RegisterObject(Const AGroup:String;
                                                  AClass:TClass;
                                                  ABmpStream:TMemoryStream;
                                                  AUGModuleTypes:TUGModuleTypes;
                                                  Const ADesignCreateObjectEvent:TDesignCreateObjectEvent = Nil);
var
  i: Integer;
  iObjItem: TCustomObjectItem;
begin
  for i := 0 to Self.Count - 1 do
  begin
    iObjItem := Self.Items[i];
    if AClass=iObjItem.CustomClass then
    Exit;
  end;
  iObjItem:=TCustomObjectItem(Self.Add);
  iObjItem.UGModuleTypes := AUGModuleTypes;
  iObjItem.GroupName:=AGroup;
  iObjItem.CustomClass:=AClass;
  iObjItem.BmpStream:=ABmpStream;
  iObjItem.DesignCreateObjectEvent:=ADesignCreateObjectEvent;
End;

procedure TCustomObjectCollection.Unregister(AClass: TClass);
var
  i: Integer;
begin
  i := 0;
  while i < Self.Count do
  begin
    if Items[i].CustomClass = AClass then
    Begin
      Items[i].Free;
      Exit;
    end;
    Inc(i);
  end;
End;
constructor TCustomObjectCollection.Create;
Begin
  inherited Create(TCustomObjectItem);
End;
{$Endregion}
{$region 'TCustomDialogProperty'}
destructor TCustomDialogProperty.Destroy;
begin
  inherited Destroy;
end;
{$Endregion}
{$region 'TCustomDialogPropertys'}
function TCustomDialogPropertys.GetObjectItem(Index: Integer): TCustomDialogProperty;
Begin
  Result := TCustomDialogProperty(inherited Items[Index]);
End;

Function  TCustomDialogPropertys.IndexOfClass(APropertyType : PTypeInfo; APropertyClass : TClass; APropertyName  : string):Integer;
Var
  Index:Integer;
Begin
  for Index := 0 to Self.Count - 1 do
  if (GetObjectItem(Index).PropertyType^.name  = APropertyType^.Name)
  and(GetObjectItem(Index).PropertyClass = APropertyClass)
  and(GetObjectItem(Index).PropertyName  = APropertyName) then
    Exit(Index);
  Exit(-1);
End;

//注册弹窗属性
procedure TCustomDialogPropertys.RegisterDialogProperty(APropertyType  : PTypeInfo;
                                                        APropertyClass : TClass;
                                                        APropertyName  : string;
                                                        ADialogMethod  : TDialogPropertyMethod);
var
  Index: Integer;
  iCDP: TCustomDialogProperty;
begin
  for Index := 0 to Count - 1 do
  if (GetObjectItem(Index).PropertyType  = APropertyType)
  and(GetObjectItem(Index).PropertyClass = APropertyClass)
  and(GetObjectItem(Index).PropertyName  = APropertyName) then
  Exit;

  iCDP := TCustomDialogProperty(Add);
  iCDP.PropertyType   := APropertyType;
  iCDP.PropertyClass  := APropertyClass;
  iCDP.PropertyName   := APropertyName;
  iCDP.PropertyMethod := ADialogMethod;
end;
//创建
constructor TCustomDialogPropertys.Create;
begin
  inherited Create(TCustomDialogProperty);
end;
{$Endregion}
{$region 'TGlobalVariable'}
Function TGlobalVariable.GetCustomClasses:TCustomObjectCollection;
begin
  if Not Assigned(FCustomObjectCollection) then
    FCustomObjectCollection := TCustomObjectCollection.Create;
  Exit(FCustomObjectCollection);
end;

Function TGlobalVariable.GetCustomDialogPropertys:TCustomDialogPropertys;
begin
  if Not Assigned(FCustomDialogPropertys) then
    FCustomDialogPropertys := TCustomDialogPropertys.Create;
  Exit(FCustomDialogPropertys);
end;

destructor TGlobalVariable.Destroy;
begin
  if FCustomObjectCollection <> nil then
  FreeAndNil(FCustomObjectCollection);

  if FCustomDialogPropertys <> nil then
  FreeAndNil(FCustomDialogPropertys);
  inherited Destroy;
end;
var
  FGV : TGlobalVariable = nil;
Function GlobalVariable : TGlobalVariable;
begin
  if Not Assigned(FGV) then
    FGV := TGlobalVariable.Create;
  Exit(FGV);
end;
{$Endregion}
{$region 'Function  CreateGuid:String;'}
Function CustomClasses:TCustomObjectCollection;//自定义固件容器
begin
  Exit(GlobalVariable.CustomClasses);
end;
Function CustomDialogPropertys:TCustomDialogPropertys;//自定义弹窗属性
begin
  Exit(GlobalVariable.CustomDialogPropertys);
end;
Function  CreateGuid:String;
var
  Guid: TGUID;
Begin
  System.SysUtils.CreateGUID(Guid);
  Result := GuidToString(Guid);
  Result := COPY(Result,2,Length(Result)-2);
End;
{$ENDREGION}
{$region 'function GetIncName(O:TComponent):String;'}
function GetIncName(O:TComponent):String;
Var
  i : Integer;
  b : Boolean;
  s : string;
begin
  i := 0;
  b := True;
  while b do
  begin
    s := Copy(O.ClassName,2,Length(o.ClassName)) + Format('%.2d', [i + 1]);
    i := i + 1;
    if not Assigned(O.Owner.FindComponent(s)) then
    b:=False;
  end;
  Exit(s);
end;
{$ENDREGION}

{$region 'dll'}
{$IF DEFINED(DLL)}
//添加控件
Procedure AddDllControl(Const AGV:TGlobalVariable);stdcall;
Begin
  FGV := AGV;
  ugRegDllControl.AddDllControl;
End;
//删除控件
Procedure DelDllControl(Const AGV:TGlobalVariable);stdcall;
Begin
  ugRegDllControl.DelDllControl;
End;

Function GetDllComponent(AName:String;AOwner:TComponent):TComponent;stdcall;
Begin
  Exit(ugCallModular.CallModular(AName,AOwner));
End;

destructor TClientdatasetHelperObject.Destroy;
begin
  if FilterParams <> nil then
  FilterParams.Free;
  inherited Destroy;
end;

Function TClientdatasetHelper.GetClientdatasetHelperObjectFlag : String;
var
  n : String;
begin
  n := IntToStr(NativeInt(Self)) + TClientdatasetHelperObject.ClassName;
  Exit(n);
end;

Function TClientdatasetHelper.GetClientdatasetHelperObject : TClientdatasetHelperObject;
Var
  o:TClientdatasetHelperObject;
  n:String;
begin
  n := GetClientdatasetHelperObjectFlag;
  o := TClientdatasetHelperObject(GETUGMM.GetObject(n));
  if o = nil then
  begin
    o := TClientdatasetHelperObject.Create;
    o.HelperClientdataset := Self;
    o.PageRowCount        := -1;
    o.PageIndex           := -1;
    o.PageCount           := -1;
    o.ErrorCommandTextOffset := -1;
    o.FilterParams := nil;
    GetUGMM.AddObject(n,o);
  end;
  exit(o);
end;

Function TClientdatasetHelper.GetDataNodeName:String;
begin
  Exit(GetClientdatasetHelperObject.DataNodeName);
end;

Procedure TClientdatasetHelper.SetDataNodeName(Value:String);
begin
  GetClientdatasetHelperObject.DataNodeName := Value;
end;

Function TClientdatasetHelper.GetPageRowCount:Integer;
begin
 Exit(GetClientdatasetHelperObject.PageRowCount);
end;

Procedure TClientdatasetHelper.SetPageRowCount(Value:Integer);
begin
  if GetClientdatasetHelperObject.PageRowCount <> Value then
  GetClientdatasetHelperObject.PageCount := -1;

  GetClientdatasetHelperObject.PageRowCount := Value;
end;

Function TClientdatasetHelper.GetPageIndex:Integer;
begin
  Exit(GetClientdatasetHelperObject.PageIndex);
end;

Procedure TClientdatasetHelper.SetPageIndex(Value:Integer);
begin
  GetClientdatasetHelperObject.PageIndex := Value;
end;

Function TClientdatasetHelper.GetPageCount:Integer;
begin
  Exit(GetClientdatasetHelperObject.PageCount);
end;

Function TClientdatasetHelper.GetTotalRecordCount:Integer;
begin
  Exit(GetClientdatasetHelperObject.TotalRecordCount);
end;

Function TClientdatasetHelper.GetErrorCommandTextOffset : Integer;
begin
  Exit(GetClientdatasetHelperObject.ErrorCommandTextOffset);
end;

Function TClientdatasetHelper.GetFilterParams:TStringList;
begin
  if GetClientdatasetHelperObject.FilterParams = nil then
  GetClientdatasetHelperObject.FilterParams := TStringList.Create;

  Exit(GetClientdatasetHelperObject.FilterParams);
end;

Procedure TClientdatasetHelper.ReFilter;//重新过滤
var
  k:Integer;
begin
  if FilterParams.Count = 0 then
  begin
    Filter := '';
    Filtered := False;
  end else begin
    Filter := '';
    Filtered := False;
    for k := 0 to FilterParams.Count - 1 do
    if Assigned(FindField(FilterParams.Names[k])) then
    Begin
      if Filter <> '' then
      Filter := Filter + ' And ';
      if self.FieldByName(FilterParams.Names[k]).DataType in [ftSmallint, ftInteger,
                                                              ftWord,ftBoolean, ftFloat,
                                                              ftCurrency, ftBCD, ftDate,
                                                              ftTime, ftDateTime,ftLargeint,
                                                              ftTimeStamp, ftFMTBcd, ftLongWord,
                                                              ftShortint, ftByte, ftExtended,ftSingle] then
      Filter := Filter + FilterParams.Names[k] + ' = ' + FilterParams.Values[FilterParams.Names[k]].Replace('%','')
      else
      Filter := Filter + FilterParams.Names[k] + ' LIKE ' + QuotedStr(FilterParams.Values[FilterParams.Names[k]]);
    End;
    if Filter <> '' then
    Filtered := True;
  end;
end;

Procedure TClientdatasetHelper.Open;
begin
  //初始错误命令文本偏移
  GetClientdatasetHelperObject.ErrorCommandTextOffset := -1;
  //获取总记录数和总页数
  if (PageRowCount > 0)
  and(PageCount = -1) then
  Try
    GetClientdatasetHelperObject.PageCount := GetUGMM.GetCdsRecordCount(DataNodeName,Self);
    GetClientdatasetHelperObject.PageCount := TotalRecordCount div PageRowCount;
    if TotalRecordCount mod PageRowCount > 0 then
    GetClientdatasetHelperObject.PageCount := PageCount + 1;
  except
    on e:exception do
    begin
      if (e is EFDDBEngineException)
      and(EFDDBEngineException(e).ErrorCount > 0) then
        GetClientdatasetHelperObject.ErrorCommandTextOffset := EFDDBEngineException(e).Errors[0].CommandTextOffset;
      raise Exception.Create(e.Message);
    end;
  End;
  {Try
    c := TClientdataset.Create(nil);
    c.CommandText := ' select'
                   + '   count(1) as TotalRecordCount'
                   + ' from('
                   + CommandText
                   + ' ) a';

    c.Params.Clear;
    if Params.Count > 0 then
    for i := 0 to Params.Count - 1 do
    begin
      c.Params.CreateParam(Params[i].DataType,Params[i].Name,Params[i].ParamType);
      c.ParamByName(Params[i].Name).Value := ParamByName(Params[i].Name).Value;
    end;

    GetUGMM.OpenCds(DataNodeName,c,0,cmVisible);
    GetClientdatasetHelperObject.TotalRecordCount := c.FieldByName('TotalRecordCount').AsInteger;
    GetClientdatasetHelperObject.PageCount := TotalRecordCount div PageRowCount;
    if TotalRecordCount mod PageRowCount > 0 then
    GetClientdatasetHelperObject.PageCount := PageCount + 1;
  Finally
    c.Free;
  End;  }

  if PageIndex = -1 then
  PageIndex := 1;
  Try
    GetUGMM.OpenCds(DataNodeName,Self,0,cmVisible,PageRowCount,PageIndex);
  except
    on e:exception do
    begin
      if (e is EFDDBEngineException)
      and(EFDDBEngineException(e).ErrorCount > 0) then
        GetClientdatasetHelperObject.ErrorCommandTextOffset := EFDDBEngineException(e).Errors[0].CommandTextOffset;
      raise Exception.Create(e.Message);
    end;
  End;
  if PageRowCount <= 0 then
  GetClientdatasetHelperObject.TotalRecordCount := RecordCount;
end;

Procedure TClientdatasetHelper.Close;//关闭
begin
  GetClientdatasetHelperObject.PageIndex        := -1; //当前页数默认-1不分页，1为第一页,0无意义
  GetClientdatasetHelperObject.PageCount        := -1; //总页数-1不分页
  Active := False;
End;

Procedure TClientdatasetHelper.SubmitUpdates;
begin
  GetUGMM.ApplyUpdatesCds1(DataNodeName,Self);
end;

Procedure TClientdatasetHelper.Execute;
begin
  GetUGMM.ExecuteCds(DataNodeName,Self);
end;

Procedure TClientdatasetHelper.FreeHelperObject;
Var
  n:String;
begin
  n := GetClientdatasetHelperObjectFlag;
  GetUGMM.DelObject(n);
end;

procedure TClientdatasetHelper.Free;
begin
  FreeHelperObject;
  inherited;
end;

Function GetUGMM:IUGMM;
var
  vUMM  : IUniMainModule;
  vUGMM : IUGMM;
begin
  if UniApplication.UniMainModule.GetInterface(IUniMainModule,vUMM) then
  if vUMM.GetDllMainModule.GetInterface(IUGMM,vUGMM) then
  exit(vUGMM);

  exit(nil);
End;

exports
AddDllControl,
DelDllControl,
GetDllComponent;
{$IFEND}
{$Endregion}

{$region 'exe'}
{$IF DEFINED(exe)}
{TDllItem}
Procedure TDllItem.SetDllName(Const Value:String);
Begin
  if FHandle = 0 then
  Begin
    FHandle := LoadLibrary(PWideChar(ExtractFilePath(Application.Exename) + Value + '.Dll'));
    if FHandle <> 0 then
      FDllName:=Value
    Else
    raise Exception.Create('加载DLL"'+Value+'"失败.');
  End;
end;
constructor TDllItem.Create;
Begin
  FOwner:=Nil;
  FHandle:=0;
  FDllName:='';
End;

destructor TDllItem.Destroy;
var
  M: TDllManager;
begin
  //删除列表中的项
  if FOwner <> nil then
  begin
    M := FOwner;
    FOwner := nil;
    M.Remove(Self);
  end;
  //当已装截库时，释放库
  //if FHandle<>0 then
  //freeLibrary(FHandle);
  inherited Destroy;
End;
{TDllManager}
procedure TDllManager.Lock;
Begin
  EnterCriticalSection(FLock);
End;
procedure TDllManager.UnLock;
Begin
  LeaveCriticalSection(FLock);
End;
Function TDllManager.GetDllByName(const DllFileName: String):TDllItem;
var
  i: Integer;
begin
  Lock;
  try
    i := IndexOf(DllFileName);
    if i = -1 then
    Exit(Nil);
    Exit(Self[i]);
  finally
    UnLock;
  end;
End;
procedure TDllManager.Clear;
Var
  Dll:TDllItem;
Begin
//清空列表并释放表中的对象
  while Count > 0 do
  Begin
    Dll:=TDllItem(Self[0]);
    Dll.Free;
  End;
End;
function TDllManager.Add(const DllFileName: String): Integer;
var
  Dll: TDllItem;
begin
  Lock;
  try
    if DllsByName[DllFileName] = nil then
    begin
      Dll := TDllItem.Create;
      Try
      //设置DLL文件路径并加载库不带扩展名
        Dll.DllFileName := DllFileName;
        Dll.FOwner:=Self;
      //当加载成功后，添加到管理列表并输出
        Exit(Add(Dll));
      except
        on E: Exception do
        Begin
        //加载失败后释放对象
          FreeAndNil(Dll);
        //重新抛出异常
          raise Exception.Create(e.Message);
        End;
      End;
    end else
      raise Exception.Create('重复加载DLL"'+DllFileName+'".');
  finally
    UnLock;
  end;
End;
function TDllManager.IndexOf(const DllFileName: String): Integer;
var
  I: Integer;
begin
  result := -1;
  Lock;
  try
    for I := 0 to Count - 1 do
      if CompareText(DllFileName, TDllItem(Self[I]).DllFileName) = 0 then
      Exit(i);
  finally
    UnLock;
  end;
End;
function TDllManager.Remove(const DllFileName: String): Integer;
var
  I: Integer;
  dll:TDllItem;
begin
  Lock;
  try
    I := IndexOf(DllFileName);
    if I >= 0 then
    Begin
      dll:=TDllItem(Self[I]);
      dll.FOwner:=Nil;
      Dll.Free;
      Exit(Remove(Self[I]));
    End;
    Exit(-1);
  finally
    UnLock;
  end;

End;
constructor TDllManager.Create;
Begin
//初始临界区
  InitializeCriticalSection(FLock);
End;
destructor TDllManager.Destroy;
Var
  Dll:TDllItem;
Begin
//清空列表并释放表中的对象
  while Count > 0 do
  Begin
    Dll:=TDllItem(Self[0]);
    Dll.Free;
  End;
//删除临界区
  DeleteCriticalSection(FLock);
  inherited;
End;
//const
//  cDllName = 'UniGuiExtend';
Var
  FDM:TDllManager = Nil;
  FInitialLoadingDlls:TStringList = Nil;
Function InitialLoadingDlls:TStringList;
Var
  s:String;
Begin
  if Not Assigned(FInitialLoadingDlls) then
  Begin
    FInitialLoadingDlls:=TStringList.Create;
    s := ReadIni(UGini , 'Frame','InitialLoadingDll','UniGuiExtend');
    FInitialLoadingDlls.Text := s.Replace(',',#$d#$a);
  End;
  Exit(FInitialLoadingDlls);
End;
Function GetDllManager:TDllManager;
Begin
  if Not Assigned(FDM) then
  FDM := TDllManager.Create;
  Exit(FDM);
End;

Procedure AddDllControl;
Type
  TAddDllControl = Procedure (Const AGV:TGlobalVariable);stdcall;
Var
  p:TAddDllControl;
  i:Integer;
  n:String;
Begin
  Try
    for i := 0 to InitialLoadingDlls.Count - 1 do
    Begin
      n:=InitialLoadingDlls[i];
      if FileExists(ExtractFilePath(Application.Exename) + n + '.dll') then
      Begin
        if GetDllManager.IndexOf(n) = -1 then
        GetDllManager.Add(n);
        if GetDllManager.IndexOf(n) = -1 then
        Exit;
        @p := Winapi.Windows.GetProcAddress(GetDllManager.DllsByName[n].Handle, LPCWSTR('AddDllControl'));
        if Assigned(p) then
        begin
          p(GlobalVariable);
        end;
      End;
    End;
  except
    on e:exception do
    begin

    end;
  end;
End;
Procedure DelDllControl;
Type
  TDelDllControl = Procedure (Const AGV:TGlobalVariable);stdcall;
Var
  p:TDelDllControl;
  i:Integer;
  n:String;
Begin
  Try
    for i := 0 to InitialLoadingDlls.Count - 1 do
    Begin
      n := InitialLoadingDlls[i];

      if GetDllManager.IndexOf(n) = -1 then
      Exit;

      @p := Winapi.Windows.GetProcAddress(GetDllManager.DllsByName[n].Handle, LPCWSTR('DelDllControl'));
      if Assigned(p) then
      p(GlobalVariable);
    end;
  Except

  end;
End;

Function  GetDllComponent(ADllName,AComponentName:String;AOwner:TComponent):TComponent;
Type
  TGetDllComponent = Function (AName:String;AOwner:TComponent):TComponent;stdcall;
Var
  g:TGetDllComponent;
Begin
  if GetDllManager.IndexOf(ADllName) = -1 then
  GetDllManager.Add(ADllName);

  @g := Winapi.Windows.GetProcAddress(GetDllManager.DllsByName[ADllName].Handle, LPCWSTR('GetDllComponent'));
  if Assigned(g) then
  Exit(g(AComponentName,AOwner));
End;

Procedure ProcFinalization;
Begin
  if FGV <> nil then
    FreeAndNil(FGV);

  if Assigned(FDM) then
    FreeAndNil(FDM);
  if Assigned(FInitialLoadingDlls) then
    FreeAndNil(FInitialLoadingDlls)
End;
{$IFEND}
{$Endregion}

end.
