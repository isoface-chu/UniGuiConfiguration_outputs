inherited WebNormalSettingSelectRunFrame: TWebNormalSettingSelectRunFrame
  ClientHeight = 579
  ClientWidth = 630
  Caption = #35831#36873#25321#23376#31383#20307
  BorderIcons = [biSystemMenu]
  ExplicitWidth = 646
  ExplicitHeight = 618
  PixelsPerInch = 96
  TextHeight = 13
  object pButton: TUniContainerPanel
    Left = 0
    Top = 539
    Width = 630
    Height = 40
    Hint = ''
    ParentColor = False
    Align = alBottom
    TabOrder = 0
    ExplicitWidth = 889
    object btOk: TUniButton
      AlignWithMargins = True
      Left = 507
      Top = 3
      Width = 120
      Height = 34
      Hint = ''
      Caption = #30830#23450
      Align = alRight
      TabOrder = 1
      OnClick = btOkClick
      ExplicitLeft = 766
    end
  end
  object gridFrames: TUniDBGrid
    Left = 0
    Top = 0
    Width = 630
    Height = 539
    Hint = ''
    Options = [dgEditing, dgTitles, dgIndicator, dgColumnResize, dgColLines, dgRowLines, dgRowSelect, dgConfirmDelete, dgFilterClearButton, dgAutoRefreshRow, dgRowNumbers]
    LoadMask.Message = 'Loading data...'
    Align = alClient
    TabOrder = 1
    OnColumnSort = gridFramesColumnSort
    OnDblClick = gridFramesOnDblClick
    OnClearFilters = gridFramesClearFilters
    OnColumnFilter = gridFramesColumnFilter
  end
  object pFilters: TUniHiddenPanel
    Left = 8
    Top = 368
    Width = 160
    Height = 170
    Hint = ''
    Visible = True
  end
  object cdsRunFrames: TClientDataSet
    Aggregates = <>
    FieldDefs = <>
    IndexDefs = <
      item
        Name = 'cdsRunFramesIndex1'
        Fields = 'FrameGroup;Caption'
      end>
    IndexName = 'cdsRunFramesIndex1'
    Params = <>
    StoreDefs = True
    Left = 224
    Top = 280
  end
  object dsRunFrame: TDataSource
    DataSet = cdsRunFrames
    Left = 224
    Top = 352
  end
end
