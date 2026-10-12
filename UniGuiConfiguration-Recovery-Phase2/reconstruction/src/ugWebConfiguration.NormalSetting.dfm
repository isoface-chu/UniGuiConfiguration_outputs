inherited WebNormalSetting: TWebNormalSetting
  object gridNormalSetting: TUniDBGrid
    Left = 0
    Top = 0
    Width = 1320
    Height = 700
    Hint = ''
    DataSource = dsNormalSetting
    Options = [dgEditing, dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgRowSelect, dgConfirmDelete, dgAutoRefreshRow, dgRowNumbers]
    WebOptions.Paged = False
    Grouping.FieldName = 'fdGroup'
    Grouping.FieldCaption = 'Group'
    Grouping.Enabled = True
    Grouping.ShowCaption = False
    LoadMask.Message = 'Loading data...'
    Align = alClient
    TabOrder = 0
    OnKeyDown = gridNormalSettingKeyDown
    OnSelectionChange = gridNormalSettingSelectionChange
    OnCellClick = gridNormalSettingCellClick
    OnColumnSort = gridNormalSettingColumnSort
    OnDrawColumnCell = gridNormalSettingDrawColumnCell
    Columns = <
      item
        FieldName = 'fdCaption'
        Title.Caption = #21517#31216
        Width = 137
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdSetupType'
        Title.Caption = #31867#22411
        Width = 148
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdValue'
        Title.Caption = #35774#32622#21464#37327
        Width = 150
        Editor = edValue
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdSupportmodule'
        Title.Caption = #25903#25345#27169#22359
        Width = 180
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdDefault'
        Title.Caption = #40664#35748#20540
        Width = 100
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdAllowNull'
        Title.Caption = #20801#35768#31354#20540
        Width = 81
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdExplain'
        Title.Caption = #22791#27880#35828#26126
        Width = 400
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdComeIntoEffect'
        CheckBoxField.AutoPost = True
        Title.Caption = #29983#25928
        Width = 50
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end>
  end
  object pHiddenPanel: TUniHiddenPanel
    Left = 3
    Top = 444
    Width = 310
    Height = 256
    Hint = ''
    Visible = True
    object edValue: TUniComboBox
      Left = 24
      Top = 12
      Width = 145
      Hint = ''
      Text = ''
      TabOrder = 1
      Triggers = <
        item
          ImageIndex = 11
          ButtonId = 0
        end>
      Images = WebConfigurationModule.UniNativeImageList1
      IconItems = <>
      OnKeyDown = edValueKeyDown
      OnClick = edValueClick
      OnTriggerEvent = edValueTriggerEvent
    end
  end
  object cdsNormalSetting: TClientDataSet
    Aggregates = <>
    FieldDefs = <>
    IndexDefs = <
      item
        Name = 'cdsNormalSettingIndex1'
        Fields = 'fdSort'
      end>
    IndexName = 'cdsNormalSettingIndex1'
    Params = <>
    StoreDefs = True
    Left = 216
    Top = 160
  end
  object dsNormalSetting: TDataSource
    DataSet = cdsNormalSetting
    Left = 216
    Top = 104
  end
end
