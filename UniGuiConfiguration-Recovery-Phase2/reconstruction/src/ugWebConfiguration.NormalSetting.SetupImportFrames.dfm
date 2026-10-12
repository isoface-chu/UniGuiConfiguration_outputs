inherited WebNormalSettingSetupImportFrames: TWebNormalSettingSetupImportFrames
  ClientHeight = 452
  ClientWidth = 812
  Caption = #23548#20837#31383#20307
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
    object lbCaption: TUniLabel
      Left = 8
      Top = 15
      Width = 64
      Height = 16
      Hint = ''
      Caption = #33756#21333#26631#39064
      TabOrder = 0
    end
    object edCaption: TUniEdit
      Left = 80
      Top = 10
      Width = 320
      Hint = ''
      Text = ''
      TabOrder = 1
      OnExit = edCaptionExit
    end
    object tbAdd: TUniButton
      Left = 412
      Top = 9
      Width = 72
      Height = 28
      Hint = ''
      Caption = #28155#21152
      TabOrder = 2
      OnClick = tbAddClick
    end
    object tbDelete: TUniButton
      Left = 490
      Top = 9
      Width = 72
      Height = 28
      Hint = ''
      Caption = #21024#38500
      TabOrder = 3
      OnClick = tbDeleteClick
    end
    object tbUp: TUniButton
      Left = 568
      Top = 9
      Width = 72
      Height = 28
      Hint = ''
      Caption = #19978#31227
      TabOrder = 4
      OnClick = tbUpClick
    end
    object tbDown: TUniButton
      Left = 646
      Top = 9
      Width = 72
      Height = 28
      Hint = ''
      Caption = #19979#31227
      TabOrder = 5
      OnClick = tbDownClick
    end
    object tbPick: TUniButton
      Left = 724
      Top = 9
      Width = 76
      Height = 28
      Hint = ''
      Caption = #36873#31383#20307
      TabOrder = 6
      OnClick = tbPickClick
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
      TabOrder = 1
      OnClick = btCancelClick
    end
  end
  object gridItems: TUniDBGrid
    AlignWithMargins = True
    Left = 3
    Top = 47
    Width = 806
    Height = 362
    Hint = ''
    DataSource = dsItems
    Options = [dgEditing, dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgRowSelect, dgConfirmDelete, dgAutoRefreshRow]
    WebOptions.Paged = False
    LoadMask.Message = 'Loading data...'
    Align = alClient
    TabOrder = 1
    Columns = <
      item
        FieldName = 'fdSort'
        Title.Caption = #24207#21495
        Width = 60
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdCaption'
        Title.Caption = #33756#21333#26631#39064
        Width = 240
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdFrame'
        Title.Caption = #26597#35810#31383#20307
        Width = 320
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdMultiSelect'
        Title.Caption = ' '#22810#36873
        Width = 90
        CheckBoxField.AutoPost = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
    >
  end
  object cdsItems: TClientDataSet
    Aggregates = <>
    Params = <>
    Left = 24
    Top = 96
  end
  object dsItems: TDataSource
    DataSet = cdsItems
    Left = 80
    Top = 96
  end
end
