inherited WebFunctionButton: TWebFunctionButton
  object Tree: TUniDBTreeGrid
    Left = 0
    Top = 0
    Width = 1320
    Height = 700
    Hint = ''
    DataSource = ds
    ClientEvents.ExtEvents.Strings = (
      'beforeitemcollapse=function(){return false;}'
      'afterrender=function(sender){sender.expandAll();}')
    Align = alClient
    TabOrder = 0
    LoadMask.Message = 'Loading data...'
    Options = [dgEditing, dgTitles, dgColumnResize, dgColLines, dgRowLines, dgConfirmDelete, dgAutoRefreshRow]
    IdParentField = 'fdParent'
    IdField = 'fdName'
    OnDrawColumnCell = TreeDrawColumnCell
    OnAjaxEvent = TreeAjaxEvent
    Columns = <
      item
        FieldName = 'fdDisplayName'
        Title.Caption = #21517#31216
        Width = 200
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdCaption'
        Title.Caption = #26631#39064
        Width = 120
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdSelect'
        Title.Caption = #36873#25321
        Width = 80
        CheckBoxField.AutoPost = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdShortcutkeys'
        Title.Caption = #24555#25463#38190
        Width = 120
        Visible = False
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdSupportmodule'
        Title.Caption = #25903#25345#27169#22359#31867#22411
        Width = 180
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdExplain'
        Title.Caption = #35828#26126
        Width = 280
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdOperationassociation'
        Title.Caption = #25805#20316#20851#32852
        Width = 80
        ReadOnly = True
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end
      item
        FieldName = 'fdRowID'
        Title.Caption = #25490#24207#23383#27573
        Width = 64
        Menu.MenuEnabled = False
        Menu.ColumnHideable = False
      end>
  end
  object cds: TClientDataSet
    Aggregates = <>
    FieldDefs = <>
    IndexDefs = <
      item
        Name = 'cdsIndex1'
        Fields = 'fdSort'
      end>
    IndexName = 'cdsIndex1'
    Params = <>
    StoreDefs = True
    BeforePost = cdsBeforePost
    AfterPost = cdsAfterPost
    Left = 184
    Top = 128
  end
  object ds: TDataSource
    DataSet = cds
    Left = 184
    Top = 184
  end
end
