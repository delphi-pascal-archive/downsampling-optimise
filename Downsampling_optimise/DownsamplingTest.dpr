program DownsamplingTest;

uses
  Forms,
  Main in 'Main.pas' {MainForm},
  Downsampling in 'Downsampling.pas';

{$R *.res}
{$R WinThemes.res}

begin
  Application.Initialize;
  Application.Title := 'Downsampling optimisé';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
