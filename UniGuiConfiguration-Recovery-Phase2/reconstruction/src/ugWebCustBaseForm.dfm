object WebCustBaseForm: TWebCustBaseForm
  Left = 0
  Top = 0
  ClientHeight = 305
  ClientWidth = 279
  Caption = 'WebCustBaseForm'
  OldCreateOrder = False
  MonitoredKeys.Keys = <>
  ClientEvents.ExtEvents.Strings = (
    
      'window.show=function window.show(sender, eOpts)'#13#10'{'#13#10'    var el =' +
      ' sender.getEl();'#13#10' '#13#10'    el.setOpacity(0);'#13#10'    el.setY(el.getY(' +
      ')+100);'#13#10'    el.fadeIn({'#13#10'        duration: 800,'#13#10'        y: el.' +
      'getY()-100'#13#10'    });'#13#10'}')
  PixelsPerInch = 96
  TextHeight = 13
end
