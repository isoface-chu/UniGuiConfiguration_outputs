unit ugConfiguration.DialogLayout;

interface

uses uniGUIForm;

procedure ConfigureWizardDialogLayout(Form: TUniForm);

implementation

uses System.SysUtils;

procedure ConfigureWizardDialogLayout(Form: TUniForm);
var JS: string;
begin
  //仅供两个已确认内容区高度塌缩的配置窗口使用，不改动全局 Ext 布局。
  JS := 'function(sender){' +
    'sender.ugDialogLayoutVersion=2;' +
    'if(!sender.ugRestoreContent){' +
      'sender.ugInitialWidth=sender.getWidth();' +
      'sender.ugInitialHeight=sender.getHeight();' +
      'sender.ugRestoreContent=function(){' +
        'if(sender.destroyed||sender.destroying||sender.hidden||sender.ugRestoringContent)return;' +
        'var f=sender.items&&sender.items.items&&sender.items.items[0],b=sender.body;' +
        'if(!f||f.destroyed||!f.rendered||!f.el||!f.el.dom||!b||!b.dom)return;' +
        'var w=b.dom.clientWidth,h=b.dom.clientHeight;' +
        'var fallbackW=Math.max(1,%d+sender.getWidth()-sender.ugInitialWidth);' +
        'var fallbackH=Math.max(1,%d+sender.getHeight()-sender.ugInitialHeight);' +
        'sender.ugRestoringContent=true;' +
        'try{' +
          'if(w<=2){w=fallbackW;b.setWidth(w)}' +
          'if(h<=2){h=fallbackH;b.setHeight(h)}' +
          'if(Math.abs(f.getWidth()-w)>1||Math.abs(f.getHeight()-h)>1){' +
            'f.setSize(w,h);' +
            //配置尺寸相同但 DOM 样式丢失时，setSize 不一定重新写入尺寸。
            'if(Math.abs(f.el.getWidth()-w)>1||Math.abs(f.el.getHeight()-h)>1){' +
              'f.el.setSize(w,h);' +
            '}' +
            'f.updateLayout();' +
          '}' +
          //内部 form 没有标题和停靠栏；只恢复已塌缩的内容区，不改动子控件。
          'if(f.body&&f.body.dom&&f.el.dom.clientHeight>2&&f.body.getHeight()<=2){' +
            'f.body.setSize(f.el.dom.clientWidth,f.el.dom.clientHeight);' +
            'f.updateLayout();' +
          '}' +
        '}finally{sender.ugRestoringContent=false;}' +
      '};' +
      'sender.on("resize",sender.ugRestoreContent);' +
      'sender.on("afterlayout",sender.ugRestoreContent);' +
    '}' +
    'sender.ugRestoreContent();' +
    'Ext.defer(function(){if(!sender.destroyed&&!sender.destroying)sender.ugRestoreContent();},1);' +
  '}';
  //替换这两个窗体继承的 show 动画，避免在同一阶段继续移动内容区。
  Form.ClientEvents.ExtEvents.Values['window.show'] :=
    Format(JS,[Form.ClientWidth,Form.ClientHeight]);
end;

end.
