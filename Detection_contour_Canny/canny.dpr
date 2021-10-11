program canny;

uses
  Forms,
  UMain in 'UMain.pas' {FrmDemoMain},
  UCanny in 'UCanny.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TFrmDemoMain, FrmDemoMain);
  Application.Run;
end.
