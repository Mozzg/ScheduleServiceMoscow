unit threadUnit;

interface

uses Classes;

type
  TWorkThread=class(TThread)
  public
    procedure Execute; override;
  end;

implementation

procedure TWorkThread.Execute;
begin
  
end;

end.
