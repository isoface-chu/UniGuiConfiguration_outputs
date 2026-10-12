inherited WebModuletype: TWebModuletype
  ClientEvents.ExtEvents.Strings = (
    
      'resize=function resize(sender, width, height, oldWidth, oldHeigh' +
      't, eOpts)'#13#10'{'#13#10'  ajaxRequest(sender,'#39'resize'#39',['#39'width='#39' + width,'#39'h' +
      'eight='#39' + height]);'#13#10'}')
  object pModuletype: TUniURLFrame
    Left = 0
    Top = 0
    Width = 1320
    Height = 700
    Hint = ''
    HTML.Strings = (
      '<h1>...</h1>'
      ' <hr width = 100%>'
      ' <ul>'
      ' <li>'#36866#29992#22330#26223#65306#24377#31383#32534#36753#25968#25454'</li>'
      ' <li>'#31934#28789#37197#32622#65306'</li>'
      ' <ol>'
      ' <li>'#21151#33021#25353#38062#65306#26080'</li>'
      ' <li>'#25968#25454#32467#26500#65306#29992#25143#37197#32622'</li>'
      ' <li>'#25968#25454#36879#35270#65306#26080'</li>'
      ' <li>'#26597#35810#26465#20214#65306#26080'</li>'
      ' <li>'#19979#25289#36873#39033#65306#29992#25143#37197#32622'</li>'
      ' <li>'#24120#35268#35774#32622#65306#25991#26412#31867#22411#12289#20462#21098#23383#31526#12289#38750#31354#23383#27573'</li>'
      ' </ol>'
      ' </ul>')
    Align = alClient
    TabOrder = 0
    ParentColor = False
    Color = clBtnFace
    OnAjaxEvent = pModuletypeAjaxEvent
    object edModuletype: TUniEdit
      AlignWithMargins = True
      Left = 0
      Top = 15
      Width = 1320
      Height = 41
      Hint = ''
      Margins.Left = 0
      Margins.Top = 15
      Margins.Right = 0
      BorderStyle = ubsNone
      Text = ''
      ParentFont = False
      Font.Height = -24
      Align = alTop
      TabOrder = 1
      EmptyText = #35831#36873#25321#27169#22359#31867#22411
      ReadOnly = True
      OnClick = edModuletypeClick
    end
  end
end
