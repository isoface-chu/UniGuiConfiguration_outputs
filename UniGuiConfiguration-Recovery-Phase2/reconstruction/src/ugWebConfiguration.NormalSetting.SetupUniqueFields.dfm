inherited WebNormalSettingSetupUniqueFields: TWebNormalSettingSetupUniqueFields
  ClientHeight = 456
  ClientWidth = 909
  Caption = #35774#32622#21807#19968#35268#21017
  ExplicitWidth = 927
  ExplicitHeight = 503
  PixelsPerInch = 120
  TextHeight = 16
  object cbField: TUniComboBox
    AlignWithMargins = True
    Left = 3
    Top = 8
    Width = 456
    Hint = ''
    Margins.Top = 8
    Margins.Right = 450
    Text = ''
    Align = alTop
    TabOrder = 0
    EmptyText = #35831#35774#32622#35760#24405#32534#21495#23383#27573
    FieldLabel = #35760#24405#32534#21495#23383#27573
    IconItems = <
    >
  end
  object pButton: TUniContainerPanel
    Left = 0
    Top = 416
    Width = 909
    Height = 40
    Hint = ''
    ParentColor = False
    Align = alBottom
    TabOrder = 1
    object btOk: TUniButton
      AlignWithMargins = True
      Left = 786
      Top = 3
      Width = 120
      Height = 34
      Hint = ''
      Caption = #30830#23450
      Align = alRight
      TabOrder = 1
      OnClick = btOkClick
    end
  end
  object gridMultiSelectFields: TUniDBGrid
    AlignWithMargins = True
    Left = 3
    Top = 56
    Width = 903
    Height = 357
    Hint = ''
    DataSource = dsMultiSelectFields
    Options = [dgEditing, dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgRowSelect, dgConfirmDelete, dgAutoRefreshRow]
    WebOptions.Paged = False
    LoadMask.Message = 'Loading data...'
    Align = alClient
    TabOrder = 3
    OnClearFilters = gridMultiSelectFieldsClearFilters
    OnColumnFilter = gridMultiSelectFieldsColumnFilter
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
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdObject_Type'
        Title.Caption = ' '#23545#35937#31867#22411
        Width = 110
        ReadOnly = True
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
  object pFilters: TUniHiddenPanel
    Left = 8
    Top = 240
    Width = 160
    Height = 170
    Hint = ''
    Visible = True
  end
  object UniContainerPanel1: TUniContainerPanel
    Left = 0
    Top = 33
    Width = 909
    Height = 1
    Hint = ''
    ParentColor = False
    Color = clSilver
    Align = alTop
    TabOrder = 4
  end
  object UniLabel1: TUniLabel
    AlignWithMargins = True
    Left = 3
    Top = 37
    Width = 84
    Height = 13
    Hint = ''
    Caption = #32452#21512#21807#19968#35760#24405#65306
    Align = alTop
    TabOrder = 5
  end
  object cdsMultiSelectFields: TClientDataSet
    Aggregates = <
    >
    FieldDefs = <
    >
    IndexDefs = <
      item
        Name = 'cdsMultiSelectFieldsIndex1'
        Fields = 'fdRECNO'
      end
    >
    IndexName = 'cdsMultiSelectFieldsIndex1'
    Params = <
    >
    StoreDefs = True
    Left = 216
    Top = 192
  end
  object dsMultiSelectFields: TDataSource
    DataSet = cdsMultiSelectFields
    Left = 216
    Top = 128
  end
end
