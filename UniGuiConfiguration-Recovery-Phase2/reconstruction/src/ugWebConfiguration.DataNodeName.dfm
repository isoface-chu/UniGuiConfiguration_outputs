inherited WebDataNodeName: TWebDataNodeName
  OnAjaxEvent = UniFrameAjaxEvent
  ClientEvents.ExtEvents.Strings = (
    
      'resize=function resize(sender, width, height, oldWidth, oldHeigh' +
      't, eOpts)'#13#10'{'#13#10'  ajaxRequest(sender,'#39'resize'#39',['#39'width='#39' + width,'#39'h' +
      'eight='#39' + height]);'#13#10'}')
  object pDataNode: TUniContainerPanel
    Left = 216
    Top = 200
    Width = 241
    Height = 105
    Hint = ''
    ParentColor = False
    TabOrder = 0
    object cbDataNodeNames: TUniComboBox
      AlignWithMargins = True
      Left = 3
      Top = 3
      Width = 235
      Height = 48
      Hint = ''
      Style = csDropDownList
      Text = ''
      Align = alTop
      TabOrder = 1
      FieldLabel = #35831#36873#25321#33410#28857#24211
      FieldLabelAlign = laTop
      IconItems = <>
    end
    object cbAddCatalogName: TUniCheckBox
      AlignWithMargins = True
      Left = 3
      Top = 57
      Width = 235
      Height = 17
      Hint = ''
      Enabled = False
      BodyRTL = False
      Caption = 'Add Catalog Name'
      Align = alTop
      TabOrder = 2
    end
    object cbAddSchemaName: TUniCheckBox
      AlignWithMargins = True
      Left = 3
      Top = 80
      Width = 235
      Height = 17
      Hint = ''
      Enabled = False
      Caption = 'Add Schema Name'
      Align = alTop
      TabOrder = 3
    end
  end
end
