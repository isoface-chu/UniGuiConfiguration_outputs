inherited WebNormalSettingSelectField: TWebNormalSettingSelectField
  ClientHeight = 425
  ClientWidth = 821
  Caption = #36873#25321#23383#27573
  BorderIcons = [biSystemMenu]
  ExplicitWidth = 839
  ExplicitHeight = 472
  PixelsPerInch = 120
  TextHeight = 16
  object gridSelectField: TUniDBGrid
    AlignWithMargins = True
    Left = 3
    Top = 3
    Width = 815
    Height = 379
    Hint = ''
    DataSource = dsSelectField
    Options = [dgEditing, dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgRowSelect, dgConfirmDelete, dgAutoRefreshRow]
    WebOptions.Paged = False
    LoadMask.Message = 'Loading data...'
    Align = alClient
    TabOrder = 0
    OnClearFilters = gridSelectFieldClearFilters
    OnColumnFilter = gridSelectFieldColumnFilter
    Columns = <
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
    Top = 385
    Width = 821
    Height = 40
    Hint = ''
    ParentColor = False
    Align = alBottom
    TabOrder = 1
    object btOk: TUniButton
      AlignWithMargins = True
      Left = 698
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
    Top = 209
    Width = 160
    Height = 170
    Hint = ''
    Visible = True
  end
  object cdsSelectField: TClientDataSet
    Aggregates = <
    >
    FieldDefs = <
    >
    IndexDefs = <
      item
        Name = 'cdsSelectFieldIndex1'
        Fields = 'fdRECNO'
      end
    >
    IndexName = 'cdsSelectFieldIndex1'
    Params = <
    >
    StoreDefs = True
    Left = 264
    Top = 104
  end
  object dsSelectField: TDataSource
    DataSet = cdsSelectField
    Left = 264
    Top = 168
  end
end
