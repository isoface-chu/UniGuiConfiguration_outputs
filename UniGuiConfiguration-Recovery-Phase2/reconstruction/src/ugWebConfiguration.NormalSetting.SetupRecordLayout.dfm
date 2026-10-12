inherited WebNormalSettingSetupRecordLayout: TWebNormalSettingSetupRecordLayout
  ClientHeight = 452
  ClientWidth = 812
  Caption = #35760#24405#21306#24067#23616
  ExplicitWidth = 828
  ExplicitHeight = 501
  PixelsPerInch = 120
  TextHeight = 16
  object pTop: TUniContainerPanel
    Left = 0
    Top = 0
    Width = 812
    Height = 44
    Hint = ''
    ParentColor = False
    Align = alTop
    TabOrder = 0
    object lbPosition: TUniLabel
      Left = 8
      Top = 15
      Width = 56
      Height = 16
      Hint = ''
      Caption = #20301#32622
      TabOrder = 0
    end
    object cbPosition: TUniComboBox
      Left = 68
      Top = 11
      Width = 90
      Hint = ''
      Text = ''
      TabOrder = 1
    end
    object lbColumns: TUniLabel
      Left = 172
      Top = 15
      Width = 56
      Height = 16
      Hint = ''
      Caption = #21015#25968
      TabOrder = 2
    end
    object seColumns: TUniSpinEdit
      Left = 232
      Top = 11
      Width = 70
      Hint = ''
      MaxValue = 3
      MinValue = 1
      Value = 2
      TabOrder = 3
    end
    object lbFieldWidth: TUniLabel
      Left = 316
      Top = 15
      Width = 80
      Height = 16
      Hint = ''
      Caption = #27599#21015#23485#24230
      TabOrder = 4
    end
    object seFieldWidth: TUniSpinEdit
      Left = 404
      Top = 11
      Width = 90
      Hint = ''
      MaxValue = 800
      MinValue = 80
      Value = 250
      TabOrder = 5
    end
    object cbShowGroups: TUniCheckBox
      Left = 512
      Top = 13
      Width = 130
      Height = 17
      Hint = ''
      Caption = #26174#31034#20998#32452#26631#39064
      TabOrder = 6
    end
    object tbUp: TUniButton
      Left = 656
      Top = 9
      Width = 72
      Height = 28
      Hint = ''
      Caption = #19978#31227
      TabOrder = 7
      OnClick = tbUpClick
    end
    object tbDown: TUniButton
      Left = 732
      Top = 9
      Width = 72
      Height = 28
      Hint = ''
      Caption = #19979#31227
      TabOrder = 8
      OnClick = tbDownClick
    end
  end
  object pButton: TUniContainerPanel
    Left = 0
    Top = 412
    Width = 812
    Height = 40
    Hint = ''
    ParentColor = False
    Align = alBottom
    TabOrder = 2
    object btOk: TUniButton
      AlignWithMargins = True
      Left = 566
      Top = 3
      Width = 120
      Height = 34
      Hint = ''
      Caption = #30830#23450
      Align = alRight
      TabOrder = 0
      OnClick = btOkClick
    end
    object btCancel: TUniButton
      AlignWithMargins = True
      Left = 689
      Top = 3
      Width = 120
      Height = 34
      Hint = ''
      Caption = #21462#28040
      Align = alRight
      ModalResult = 2
      TabOrder = 1
    end
  end
  object gridLayout: TUniDBGrid
    AlignWithMargins = True
    Left = 3
    Top = 47
    Width = 806
    Height = 362
    Hint = ''
    DataSource = dsRecordLayout
    Options = [dgEditing, dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgRowSelect, dgConfirmDelete, dgAutoRefreshRow]
    WebOptions.Paged = False
    LoadMask.Message = 'Loading data...'
    Align = alClient
    TabOrder = 1
    Columns = <
      item
        FieldName = 'fdVISIBLE'
        Title.Caption = #26174#31034
        Width = 50
        CheckBoxField.AutoPost = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdCOLUMN_NAME'
        Title.Caption = #23383#27573
        Width = 150
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdOBJECT_TYPE'
        Title.Caption = #23545#35937#31867#22411
        Width = 90
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdCAPTION'
        Title.Caption = #35760#24405#21306#26631#39064
        Width = 170
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdGROUP'
        Title.Caption = #20998#32452
        Width = 120
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdSPAN'
        Title.Caption = #36328#21015
        Width = 60
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdWIDTH'
        Title.Caption = #23485#24230
        Width = 70
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
    >
  end
  object cdsRecordLayout: TClientDataSet
    Aggregates = <>
    Params = <>
    Left = 24
    Top = 96
  end
  object dsRecordLayout: TDataSource
    DataSet = cdsRecordLayout
    Left = 80
    Top = 96
  end
end
