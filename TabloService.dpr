program TabloService;

uses
  SvcMgr,
  mainUnit in 'mainUnit.pas' {Tablo_service: TService},
  DataProtocolUnit in 'DataProtocolUnit.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TTablo_service, Tablo_service);
  Application.Run;
end.
