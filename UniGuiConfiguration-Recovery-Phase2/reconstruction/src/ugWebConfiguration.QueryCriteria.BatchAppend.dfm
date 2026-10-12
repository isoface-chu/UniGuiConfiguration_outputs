inherited WebQueryCriteriaBatchAppend: TWebQueryCriteriaBatchAppend
  ClientHeight = 530
  ClientWidth = 1182
  Caption = 'WebQueryCriteriaBatchAppend'
  BorderIcons = [biSystemMenu]
  ExplicitWidth = 1200
  ExplicitHeight = 577
  PixelsPerInch = 120
  TextHeight = 16
  object UniDBGrid1: TUniDBGrid
    AlignWithMargins = True
    Left = 3
    Top = 3
    Width = 1176
    Height = 486
    Hint = ''
    DataSource = dsColumns
    Options = [dgEditing, dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgRowSelect, dgConfirmDelete, dgAutoRefreshRow]
    WebOptions.Paged = False
    Grouping.FieldName = 'fdTABLE_NAME'
    Grouping.FieldCaption = 'TableName'
    Grouping.Enabled = True
    LoadMask.Message = 'Loading data...'
    Align = alClient
    TabOrder = 0
    OnColumnSort = UniDBGrid1ColumnSort
    Columns = <
      item
        FieldName = 'fdSELECT'
        Title.Caption = ' '#36873#25321
        Width = 80
        CheckBoxField.AutoPost = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdCOLUMN_NAME'
        Title.Caption = #23383#27573#21517#31216
        Width = 110
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdCAPTION'
        Title.Caption = ' '#23383#27573#26631#39064
        Width = 110
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdComparisonOperator'
        Title.Caption = #27604#36739#36816#31639#31526
        Width = 110
        Editor = cbComparisonOperator
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdObject_Type'
        Title.Caption = ' '#23545#35937#31867#22411
        Width = 110
        Editor = cbObjectType
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdIndePendence'
        Title.Caption = #29420#31435#26465#20214
        Width = 80
        CheckBoxField.AutoPost = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdHideCaption'
        Title.Caption = #38544#34255#26631#39064
        Width = 80
        CheckBoxField.AutoPost = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdCOLUMN_TYPENAME'
        Title.Caption = #23383#27573#31867#22411
        Width = 110
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdCOLUMN_PRECISION'
        Title.Caption = #25968#20540#38271#24230
        Width = 110
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdCOLUMN_SCAL'
        Title.Caption = #25968#20540#20301#25968
        Width = 110
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdCOLUMN_LENGTH'
        Title.Caption = ' '#23383#31526#38271#24230
        Width = 110
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
    >
  end
  object pActions: TUniContainerPanel
    Align = alBottom
    Height = 42
    object btOK: TUniButton
      AlignWithMargins = True
      Align = alRight
      Left = 950
      Width = 100
      Caption = #30830#23450
      OnClick = btOKClick
    end
    object btCancel: TUniButton
      AlignWithMargins = True
      Align = alRight
      Left = 1060
      Width = 100
      Caption = #21462#28040
      ModalResult = 2
    end
  end
  object UniHiddenPanel1: TUniHiddenPanel
    Left = 3
    Top = 346
    Width = 160
    Height = 143
    Hint = ''
    Visible = True
    object cbObjectType: TUniComboBox
      Left = 3
      Top = 16
      Width = 145
      Hint = ''
      Style = csDropDownList
      Text = ''
      TabOrder = 1
      AnyMatch = True
      MatchFieldWidth = False
      IconItems = <
      >
    end
    object cbComparisonOperator: TUniComboBox
      Left = 3
      Top = 44
      Width = 145
      Hint = ''
      Style = csDropDownList
      Text = ''
      TabOrder = 2
      IconItems = <
      >
    end
  end
  object cdsColumns: TClientDataSet
    Aggregates = <
    >
    FieldDefs = <
    >
    IndexDefs = <
      item
        Name = 'cdsColumnsIndex1'
        Fields = 'fdEpithet;fdRECNO'
      end
    >
    IndexName = 'cdsColumnsIndex1'
    Params = <
    >
    StoreDefs = True
    Left = 304
    Top = 168
  end
  object dsColumns: TDataSource
    DataSet = cdsColumns
    Left = 408
    Top = 168
  end
end
