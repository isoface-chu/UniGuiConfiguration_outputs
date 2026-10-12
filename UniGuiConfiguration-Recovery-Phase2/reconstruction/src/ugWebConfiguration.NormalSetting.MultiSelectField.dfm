inherited WebNormalSettingMultiSelectField: TWebNormalSettingMultiSelectField
  ClientHeight = 406
  ClientWidth = 908
  Caption = #22810#36873#23383#27573
  BorderIcons = [biSystemMenu]
  ExplicitWidth = 926
  ExplicitHeight = 453
  PixelsPerInch = 120
  TextHeight = 16
  object gridMultiSelectFields: TUniDBGrid
    AlignWithMargins = True
    Left = 3
    Top = 3
    Width = 902
    Height = 360
    Hint = ''
    DataSource = dsMultiSelectFields
    Options = [dgEditing, dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgRowSelect, dgConfirmDelete, dgAutoRefreshRow]
    WebOptions.Paged = False
    LoadMask.Message = 'Loading data...'
    Align = alClient
    TabOrder = 0
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
  object pButton: TUniContainerPanel
    Left = 0
    Top = 366
    Width = 908
    Height = 40
    Hint = ''
    ParentColor = False
    Align = alBottom
    TabOrder = 1
    object btOk: TUniButton
      AlignWithMargins = True
      Left = 785
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
  object pFilters: TUniHiddenPanel
    Left = 8
    Top = 190
    Width = 160
    Height = 170
    Hint = ''
    Visible = True
  end
  object dsMultiSelectFields: TDataSource
    DataSet = cdsMultiSelectFields
    Left = 216
    Top = 128
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
end
