unit mainUnit;

interface

uses
  Windows, SysUtils, SvcMgr, Classes, Comm32, IniFiles, ScktComp,
  IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient, IdFTP, DateUtils, ZLibEx,
  ExtCtrls, DataProtocolUnit, Registry;

type
  TWorkThread=class(TThread)
    paused:boolean;
    procedure Execute; override;
  end;

  TTablo_service = class(TService)
    Comm: TComm32;
    Client111: TClientSocket;
    IdFTP1: TIdFTP;
    ClientMonitor: TClientSocket;
    BackupClient: TClientSocket;
    RotationTimer: TTimer;
    UpdateClient: TClientSocket;
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceShutdown(Sender: TService);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure ServicePause(Sender: TService; var Paused: Boolean);
    procedure ServiceContinue(Sender: TService; var Continued: Boolean);
    procedure Client111Connect(Sender: TObject; Socket: TCustomWinSocket);
    procedure Client111Connecting(Sender: TObject; Socket: TCustomWinSocket);
    procedure Client111Disconnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure Client111Error(Sender: TObject; Socket: TCustomWinSocket;
      ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure Client111Lookup(Sender: TObject; Socket: TCustomWinSocket);
    procedure Client111Read(Sender: TObject; Socket: TCustomWinSocket);
    procedure Client111Write(Sender: TObject; Socket: TCustomWinSocket);
    procedure CommReceiveData(Buffer: Pointer; BufferLength: Word);
    procedure ClientMonitorConnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ClientMonitorConnecting(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ClientMonitorDisconnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ClientMonitorError(Sender: TObject; Socket: TCustomWinSocket;
      ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure ClientMonitorLookup(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ClientMonitorRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure ClientMonitorWrite(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure ServiceExecute(Sender: TService);
    procedure BackupClientConnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure BackupClientConnecting(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure BackupClientDisconnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure BackupClientError(Sender: TObject; Socket: TCustomWinSocket;
      ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure BackupClientLookup(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure BackupClientRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure BackupClientWrite(Sender: TObject; Socket: TCustomWinSocket);
    procedure RotationTimerTimer(Sender: TObject);
    procedure UpdateClientConnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure UpdateClientConnecting(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure UpdateClientDisconnect(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure UpdateClientError(Sender: TObject; Socket: TCustomWinSocket;
      ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure UpdateClientLookup(Sender: TObject;
      Socket: TCustomWinSocket);
    procedure UpdateClientRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure UpdateClientWrite(Sender: TObject; Socket: TCustomWinSocket);
  private
    { Private declarations }
  public
    procedure ServiceStopShutdown;
    function GetServiceController: TServiceController; override;
    { Public declarations }
  end; 

  type TProg=array[1..3] of string;

const
  settings_exceptions:array [0..2] of string = ('ComPort','TabloAdress','IMEI');

var
  Tablo_service: TTablo_service;
  WorkThread: TWorkThread;

  DataProtocol:TDataProtocolObject;

  //общие переменные
  LogLevel:integer;
  LogFileName:string;
  IniFile:TINIFile;
  ComPort:string;
  TabloAdress:integer;

  //переменная для евентов
  //event_occured:integer=0;
  //буферы для пришедших пакетов
  info_input:array of array of byte;
  monitor_input:array of array of byte;

  //переменные для работы сокета
  socket_host:string;
  socket_port:integer;
  imei:string;
  before_connect_interval:integer;
  OnConnect_timeout:integer;
  Register_responce_timeout:integer;
  Waiting_for_packet_timeout:integer;

  //переменные для системы мониторинга
  enable_monitor:boolean;
  use_monitor_upload:boolean;
  use_monitor_compression:boolean;
  monitor_socket_host:string;
  monitor_socket_port:integer;
  imei_int:int64;

  update_transfer_in_progress:boolean;
  update_settings_transfer_in_progress:boolean;
  log_backup_transfer_in_progress:boolean;

  //переменные для бекапа файла логов
  enable_backup_log:boolean;
  sended_backup_packet:boolean;
  sended_backup_buffer:boolean;
  backup_log_time:cardinal;
  backup_log_interval:cardinal;
  backup_log_buffer:array of byte;
  backup_log_packet:array of byte;

  //переменные для обновления программы
  enable_update:boolean;
  sended_update_packet:boolean;
  update_time_timeout:cardinal;
  update_time_timeout_interval:cardinal;
  update_time_keep_alive:cardinal;
  update_time_keep_alive_interval:cardinal;
  update_receive_size:integer;
  update_receive_CRC:integer;
  update_receive_version:string;
  update_receive_buf:array of byte;
  update_counter:integer;
  update_receive_temp_buf:array[0..8191] of byte;

  //переменные для обновления настроек
  enable_update_settings:boolean;
  sended_update_settings_packet:boolean;
  update_settings_time_timeout:cardinal;
  update_settings_time_timeout_interval:cardinal;
  update_settings_time_keep_alive:cardinal;
  update_settings_time_keep_alive_interval:cardinal;
  update_settings_receive_size:integer;
  update_settings_receive_CRC:integer;
  update_settings_counter:integer;

  //переменные для протокола обмена
  error_event:boolean=false;
  sended_register:boolean=false;
  receive_time:cardinal;
  register_message:string;
  register_time:cardinal;
  registration:boolean;
  working:boolean;
  temperature_str:string;
  error_index:byte;

  //переменные для вывода прогнозов на табло
  prognozi:array of TProg;
  rotation_interval:integer;

  //переменные для протокола обмена с сервером мониторинга
  error_event_monitor:boolean=false;
  sended_register_monitor:boolean=false;
  echo_time:cardinal;
  echo_interval:cardinal;
  synch_time:cardinal;
  synch_interval:cardinal;
  update_time:cardinal;
  update_interval:cardinal;
  update_settings_time:cardinal;
  update_settings_interval:cardinal;
  registration_monitor:boolean=true;
  registration_monitor_time:cardinal;
  registration_monitor_extra_delay:cardinal;
  register_buf:array of byte;
  echo_buf:array of byte;
  synch_buf:array of byte;
  update_buf:array of byte;
  update_answer_buf:array of byte;
  update_settings_buf:array of byte;
  monitor_socketID:integer;
  TeamViewer_ID:integer;

  //переменные для вывода полей
  col1_start,col1_finish:string;
  col2_start,col2_finish:string;
  col3_start,col3_finish:string;
  date_start,date_finish:string;
  time_start,time_finish:string;
  temp_start,temp_finish:string;
  begush_start,begush_finish:string;
  tablo_type:integer;

  //переменные для работы с FTP
  CurDate:string;  //Текущая дата для отправки логов
  CurFileName:string;  //переменная для сохранения имени файла
  FTPHost:string;
  FTPPort:integer;
  FTPLogin:string;
  FTPPass:string;
  FTPTimeout:integer;

  //переменные для работы с COM
  MSGBeginByte : byte;                         //начало сообщения
  TabAdrByte : array [1..2] of byte;           //адрес табло
  DataBlockLengthByte : array [1..2] of byte;  //длинна блока данных
  DataBlock : array of byte;                  //блок данных
  XORByte : array [1..2] of byte;              //XOR
  MSGEndByte : byte;                           //конец сообщения
  comm_answer:string;


procedure WorkInfo;
procedure WorkMonitor;
function Initialize_tablo(Clear_tablo:boolean):boolean;
procedure Check_update_completion;
procedure Check_update_settings_completion;
function BootReplaceFile(Source,Dest:string):boolean;
function SystemCommit:boolean;
function SysReboot:boolean;
function LogServMess(Mess:string; time:boolean = true):boolean;

implementation

{$R *.DFM}

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  Tablo_service.Controller(CtrlCode);
end;

function TTablo_service.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

//------------------------BEGIN of supply functions--------------------------------

function GetModuleFileNameStr(Instance: THandle): string;
var
  buffer: array [0..MAX_PATH] of Char;
begin
  GetModuleFileName( Instance, buffer, MAX_PATH);
  Result := buffer;
end;

function LogServMess(Mess:string; time:boolean = true):boolean;
var handl:integer;
temp_mess:string;
begin
  result:=false;
  //if LogLevel<0 then exit;
  temp_mess:=Mess+#13+#10;
  if time=true then temp_mess:=FormatDateTime('dd.mm.yyyy hh:nn:ss.zzz',now)+'  '+temp_mess;
  
  if LogFileName<>'' then
  begin
    if FileExists(LogFileName) then
      handl:=FileOpen(LogFileName,fmOpenReadWrite or fmShareDenyNone)
    else
      handl:=FileCreate(LogFileName);

    if handl<0 then exit;
    if FileSeek(handl,0,2)=-1 then exit;
    if FileWrite(handl,temp_mess[1],length(temp_mess))=-1 then exit;
    FileClose(handl);
  end
  else
  begin
    temp_mess:='';
    exit;
  end;

  temp_mess:='';
  result:=true;
end;

function GetErrString(errCode:cardinal):string;
var pch:pchar;
str:string;
t:cardinal;
begin
  pch:=Pointer(0);
  FormatMessage(
    FORMAT_MESSAGE_ALLOCATE_BUFFER or FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_IGNORE_INSERTS,
    nil,
    errCode,
    0,
    @pch,
    max_path-1,
    nil);

  str:=pch;

  t:=LongWord(pch);
  LocalFree(t);

  setlength(str,length(str)-1);
  str:=str+' ('+inttostr(errCode)+')';

  result:=str;
end;

function CreateINIFile(name:string):boolean;
var handl:integer;
contents:string;
begin
  result:=false;
  handl:=FileCreate(Name);
  if handl<0 then exit;
  if FileSeek(handl,0,2)=-1 then exit;

  {contents:='[Main]'+#13+#10+
'LogFile=E:\Evgeniy\Schedule Service\output.log'+#13+#10+
'SettingsFile=E:\Evgeniy\Schedule Service\schedule.ini'+#13+#10+
'URL=http://transport.orgp.spb.ru/Portal/transport/internalapi/forecast/bystop?stopID=1791'+#13+#10+
'Port=COM1'+#13+#10+
'WorkSleep=100'+#13+#10+
'LogLevel=0';                }

  if FileWrite(handl,contents[1],length(contents))=-1 then exit;
  FileClose(handl);
  contents:='';

  result:=true;
end;

function StringToHex(input:string):string;
var str:string;
i:integer;
begin
  str:='';

  for i:=1 to length(input) do
    str:=str+inttohex(ord(input[i]),2)+' ';

  delete(str,length(str),1);
  result:=str;
end;

function SeekLeftStr(ch:char; str:string; index:integer):integer;
var i:integer;
begin
  result:=0;

  if length(str)<index then exit;

  for i:=index downto 1 do
    if str[i]=ch then
    begin
      result:=i;
      exit;
    end;
end;

function FileVersion(AFileName: string): string;
var
  szName: array[0..255] of Char;
  P: Pointer;
  Value: Pointer;
  Len: UINT;
  GetTranslationString: string;
  FFileName: PChar;
  FValid: boolean;
  FSize: DWORD;
  FHandle: DWORD;
  FBuffer: PChar;
begin
  result:='';

  try
    FFileName := StrPCopy(StrAlloc(Length(AFileName) + 1), AFileName);
    FValid := False;
    FSize := GetFileVersionInfoSize(FFileName, FHandle);
    FBuffer:=nil;
    if FSize > 0 then
    try
      GetMem(FBuffer, FSize);
      FValid := GetFileVersionInfo(FFileName, FHandle, FSize, FBuffer);
    except
      FValid := False;
      raise;
    end;
    Result := '';
    if FValid then
      VerQueryValue(FBuffer, '\VarFileInfo\Translation', p, Len)
    else
      p := nil;
    if P <> nil then
      GetTranslationString := IntToHex(MakeLong(HiWord(Longint(P^)),
        LoWord(Longint(P^))), 8);
    if FValid then
    begin
      StrPCopy(szName, '\StringFileInfo\' + GetTranslationString +
        '\FileVersion');
      if VerQueryValue(FBuffer, szName, Value, Len) then
        Result := StrPas(PChar(Value));
    end;
  finally
    try
      if FBuffer <> nil then
        FreeMem(FBuffer, FSize);
    except
    end;
    try
      StrDispose(FFileName);
    except
    end;
  end;
end;

function SendCommData(Com:TComm32; data:PChar):boolean;
begin
  try
    Com.ClearBreak;
    Com.ClearTxBuffer;
    Com.ClearRxBuffer;
    if Com.Active then
      Com.WriteCommData(data, Length(data));
    result:=true;
    if LogLevel>0 then LogServMess('Sended data to a com port',true);
  except
    result:=false;
    if LogLevel>0 then LogServMess('Failed to send data to a com port',true);
  end;
end;

procedure SendComm(input:string);
begin
  if LogLevel>1 then LogServMess('Atempting to send data: '+StringToHex(input),true);
  SendCommData(Tablo_Service.Comm,PChar(input));
end;

procedure SendCommStr(adress:integer; input:string);
var str:string;
i,j:integer;
TmpByte:byte;
begin
  LogServMess('String send to com port with string: '+input,true);

  //адрес табло
  str:=Inttohex(adress,2);
  TabAdrByte[1] := Byte(str[1]);
  TabAdrByte[2] := Byte(str[2]);
  //длинна сообщения
  j:=length(input);
  str:=inttohex(j,2);
  DataBlockLengthByte[1] := Byte(str[1]);
  DataBlockLengthByte[2] := Byte(str[2]);
  //блок данных
  setlength(DataBlock,j);

  for i:=0 to j-1 do
    DataBlock[i] := Byte(input[i+1]);
  //контрольная сумма
  TmpByte := $00;
  TmpByte := TmpByte XOR TabAdrByte[1]; TmpByte := TmpByte XOR TabAdrByte[2];
  TmpByte := TmpByte XOR DataBlockLengthByte[1]; TmpByte := TmpByte XOR DataBlockLengthByte[2];
  for i := 0 to j-1 do
    TmpByte := TmpByte XOR DataBlock[i];
  TmpByte := TmpByte XOR $FF;
  str:=IntTohex(TmpByte,2);

  XORByte[1] := Byte(str[1]);
  XORByte[2] := Byte(str[2]);

  //Формирование строки для отправки
  str:=Chr(MSGBeginByte)+
  chr(TabAdrByte[1])+
  chr(TabAdrByte[2])+
  chr(DataBlockLengthByte[1])+
  chr(DataBlockLengthByte[2]);
  for i:=0 to j-1 do
    str:=str+chr(DataBlock[i]);
  str:=str+
  chr(XORByte[1])+
  chr(XORByte[2])+
  chr(MSGEndByte);

  SendComm(str);
  str:='';
  LogServMess('String send exit',true);
end;

function SendCommWhole(adress:integer; CommSendString:string):boolean;
var str1:string;
i,k,kol:integer;
b:boolean;
begin
  result:=false;
  comm_answer:='';
  kol:=0;

  if CommSendString<>'' then
  begin
    LogServMess('Entering send com whole with message:'+CommSendString,true);
  repeat
    i:=length(CommSendString);
    if i>240 then
    begin
      b:=false;
      k:=240;
      while b=false do
      begin
        k:=SeekLeftStr('%',CommSendString,k);
        if (copy(CommSendString,k+1,2)='04')or(k=0) then b:=true;
        if b=false then dec(k);
      end;

      if k<=0 then
      begin
        LogServMess('Error parsing send string',true);
        exit;
      end;

      str1:=copy(CommSendString,1,k-1);
      delete(CommSendString,1,k-1);

      SendCommStr(adress,str1);
      inc(kol);
      sleep(220);
    end
    else
    begin
      SendCommStr(adress,CommSendString);
      inc(kol);
    end;
  until i<=240;
  end;

  sleep(500);

  str1:='';
  for i:=1 to kol do
    str1:=str1+'0200FD';

  LogServMess('Answer from tablo:'+comm_answer+'    Expected answer:'+str1,false);

  //if pos('0200FD',comm_answer)<>0 then result:=true;
  if str1=comm_answer then result:=true;

  comm_answer:='';
end;

{function TrySocketConnect:boolean;
begin
  LogServMess('TrySocketConnect procedure enter',true);
  result:=false;

  try
    Tablo_service.Client.Open;
  except
    on e:exception do
    begin
      LogServMess('Exception on trying to connect with socket with message:'+e.Message,true);
      exit;
    end;
  end;

  result:=true;
  LogServMess('TrySocketConnect procedure exit',true);
end;    }

function SendMonitorMessage(mess:string; mess_type,mess_level:byte; time:TDateTime):boolean;
var buf:array of byte;
pdouble:^double;
i:integer;
begin
  result:=false;

  setlength(buf,length(mess)+19);
  FillChar(buf[0],length(buf),0);
  buf[0]:=158;  //начальный символ
  //длинна пакета
  i:=length(buf)-5;
  buf[1]:=(i and $FF000000)shr 24;
  buf[2]:=(i and $00FF0000)shr 16;
  buf[3]:=(i and $0000FF00)shr 8;
  buf[4]:=(i and $000000FF);
  buf[6]:=$02;  //тип пакета
  buf[7]:=mess_type;  //тип сообщения
  buf[8]:=mess_level;  //уровень сообщения
  //время сообщения
  pdouble:=@buf[9];
  pdouble^:=time;
  //длинна строки сообщения
  i:=length(mess);
  buf[17]:=(i and $FF00)shr 8;
  buf[18]:=(i and $FF);
  //строка сообщения
  for i:=1 to length(mess) do
    buf[i+18]:=ord(mess[i]);

  //посылка
  if Tablo_service.ClientMonitor.Socket.Connected then Tablo_service.ClientMonitor.Socket.SendBuf(buf[0],length(buf))
  else exit;

  result:=true;
end;

procedure CreateMonitorMessages(imei:int64);
var pint:^int64;
str,str1:string;
i,i1,i2,i3,i4,TVid:integer;
f:integer;
buf:array of byte;
reg:TRegistry;
begin
  //определяем версию
  str:=FileVersion(paramstr(0));
  i1:=0;
  i2:=0;
  i3:=0;
  i4:=0;
  try
    if str<>'' then
    begin
      i:=pos('.',str);  //1.10.100.255
      if i<>0 then
      begin
        str1:=copy(str,1,i-1);
        delete(str,1,i);
        i1:=strtoint(str1);
        i:=pos('.',str);  //10.100.255
        if i<>0 then
        begin
          str1:=copy(str,1,i-1);
          delete(str,1,i);
          i2:=strtoint(str1);
          i:=pos('.',str);  //100.255
          if i<>0 then
          begin
            str1:=copy(str,1,i-1);
            delete(str,1,i);
            i3:=strtoint(str1);
            i:=pos('.',str);  //255
            if i=0 then i4:=strtoint(str);
          end;
        end;
      end;
    end;
  except
    on e:exception do
    begin
      i1:=0;
      i2:=0;
      i3:=0;
      i4:=0;
    end;
  end;

  str:=inttostr(i1)+'.'+inttostr(i2)+'.'+inttostr(i3)+'.'+inttostr(i4);
  LogServMess('Version is '+str,true);

  //определяем TeamViewerID
  TVid:=0;
  reg:=TRegistry.Create(KEY_READ);
  try
    reg.RootKey:=HKEY_LOCAL_MACHINE;
    if reg.KeyExists('\Software\TeamViewer\Version9') then  //проверка на девятую версию
    begin
      reg.OpenKey('\Software\TeamViewer\Version9',false);
      TVid:=reg.ReadInteger('ClientID');
    end
    else if reg.KeyExists('\Software\TeamViewer\Version8') then  //проверка на восьмую версию
    begin
      reg.OpenKey('\Software\TeamViewer\Version8',false);
      TVid:=reg.ReadInteger('ClientID');
    end;
  finally
    reg.Free;
  end;

  TeamViewer_ID:=TVid;

  //пакет регистрации
  setlength(register_buf,27);
  FillChar(register_buf[0],27,0);
  register_buf[0]:=158;  //начальный байт
  register_buf[4]:=$16;  //длинна пакета
  register_buf[6]:=$FF;  //тип пакета
  register_buf[15]:=i1;  //версия
  register_buf[16]:=i2;
  register_buf[17]:=i3;
  register_buf[18]:=i4;
  register_buf[19]:=(echo_interval and $FF000000)shr 24;  //эхо-интервал
  register_buf[20]:=(echo_interval and $00FF0000)shr 16;
  register_buf[21]:=(echo_interval and $0000FF00)shr 8;
  register_buf[22]:=(echo_interval and $000000FF);
  register_buf[23]:=(TVid and $FF000000)shr 24;  //TeamViewerID
  register_buf[24]:=(TVid and $00FF0000)shr 16;
  register_buf[25]:=(TVid and $0000FF00)shr 8;
  register_buf[26]:=(TVid and $000000FF);
  pint:=@register_buf[7];  //IMEI для авторизации
  pint^:=imei;

  //эхо-пакет
  setlength(echo_buf,7);
  FillChar(echo_buf[0],7,0);
  echo_buf[0]:=158;  //начальный байт
  echo_buf[4]:=2;  //длинна пакета
  echo_buf[6]:=1;  //тип пакета

  //пакет синхронизации времени
  setlength(synch_buf,7);
  FillChar(synch_buf[0],7,0);
  synch_buf[0]:=158;  //начальный байт
  synch_buf[4]:=2;  //длинна пакета
  synch_buf[6]:=6;  //тип пакета

  //пакет обновления программы
  setlength(update_buf,15);
  FillChar(update_buf[0],15,0);
  update_buf[0]:=158;  //начальный байт
  update_buf[4]:=10;  //длинна пакета
  update_buf[6]:=9;  //тип пакета
  update_buf[7]:=i1;  //версия сервиса
  update_buf[8]:=i2;
  update_buf[9]:=i3;
  update_buf[10]:=i4;
  //считаем контрольную сумму
  f:=FileOpen(paramstr(0),fmOpenRead or fmShareDenyNone);
  if f>0 then
  begin
    i:=FileSeek(f,0,2);
    if i<>-1 then
    begin
      FileSeek(f,0,0);
      setlength(buf,i);
      FileRead(f,buf[0],length(buf));
    end
    else
      LogServMess('File seek failed');

    FileClose(f);
  end
  else
    LogServMess('File open failed');

  i:=ZCRC32(0,buf[0],length(buf));
  setlength(buf,0);
  //записываем контрольную сумму
  update_buf[11]:=(i and $FF000000)shr 24;  //контрольная сумма
  update_buf[12]:=(i and $00FF0000)shr 16;
  update_buf[13]:=(i and $0000FF00)shr 8;
  update_buf[14]:=(i and $000000FF);

  //пакет ответа для обновления
  setlength(update_answer_buf,12);
  FillChar(update_answer_buf[0],length(update_answer_buf),0);
  update_answer_buf[0]:=158;  //символ начала пакета
  update_answer_buf[4]:=7;  //длинна пакета
  update_answer_buf[6]:=4;  //тип пакета
  //тип ответа заполняется при отправке
  //последние 4 байта должны быть кол-во байт, принятое. Заполняется при отправке.

  LogServMess('CRC32 is '+inttohex(i,8),true);
end;

procedure CreateMessages(imei:string);
var str,str1:string;
sum:cardinal;
i:integer;
begin
  //создаем сообщения для регистрации
  str:=chr(19)+chr(0);  //dlinna
  str:=str+chr($FF);  //priznak registracii
  //imei
  str1:=imei;
  for i:=length(imei) to 15 do
    str1:='0'+str1;
  str:=str+str1;
  str:=str+chr(17)+chr(0);  //versiya i status

  //konstrolnaya summa
  sum:=0;
  for i:=1 to length(str) do
    sum:=(sum+ord(str[i]))and $FFFF;

  str:=str+chr(sum and $FF)+chr((sum and $FF00)shr 8);
  str:=chr($A5)+str+chr($AE);

  register_message:=str;
  LogServMess('Register message created',true);
  str:='';
  str1:='';
end;

procedure CreateUnifiedSettings;
var ini:TINIFile;
sec,params:TStringList;
i,j,k,z,f:integer;
b:boolean;
str,str_name:string;
buf:array of byte;
begin
  //делаем имя нового файла
  str:=ChangeFileExt(GetModuleFileNameStr(0), '.iniuni');
  str_name:=str;
  //проверяем, есть ли он
  if FileExists(str) then
  begin
    //если есть, то удаляем
    LogServMess('Unified file exists, deleting');
    deletefile(str);
  end;

  //LogServMess('Unified filename:'+str_name);

  //создаём переменные
  ini:=TINIFile.Create(str);
  sec:=TStringList.Create;
  params:=TStringList.Create;

  //читаем секции
  INIFile.ReadSections(sec);

  for i:=0 to sec.Count-1 do
  begin
    //LogServMess('  Section '+sec[i],false);
    //читаем параметры в текущей секции
    INIFile.ReadSectionValues(sec[i],params);

    for j:=0 to params.Count-1 do
    begin
      str:=params[j];

      //проверка на коментарий
      k:=pos('//',str);
      if k<>0 then delete(str,k,length(str));
      //проверка на исключения
      b:=false;
      for z:=0 to length(settings_exceptions)-1 do
        if pos(settings_exceptions[z],str)<>0 then
        begin
          b:=true;
          break;
        end;

      if b=true then continue;
      if str='' then continue;

      //LogServMess('   '+params[j]);

      ini.WriteString(sec[i],params.Names[j],params.ValueFromIndex[j]);
    end;
  end;

  ini.Free;
  sec.Free;
  params.Free;

  LogServMess('Sucsessfuly created unified settings file, name='+str_name);

  //создаём пакет обновления настроек
  setlength(update_settings_buf,11);
  FillChar(update_settings_buf[0],11,0);
  update_settings_buf[0]:=158;  //начальный байт
  update_settings_buf[4]:=6;  //длинна пакета
  update_settings_buf[6]:=11;  //тип пакета

  //считаем контрольную сумму
  setlength(buf,0);
  f:=FileOpen(str_name,fmOpenRead or fmShareDenyNone);
  if f>0 then
  begin
    i:=FileSeek(f,0,2);
    if i<>-1 then
    begin
      FileSeek(f,0,0);
      setlength(buf,i);
      FileRead(f,buf[0],length(buf));
    end
    else
      LogServMess('File seek failed');

    FileClose(f);
  end
  else
    LogServMess('File open failed');

  i:=ZCRC32(0,buf[0],length(buf));
  setlength(buf,0);

  //записываем контрольную сумму
  update_settings_buf[7]:=(i and $FF000000)shr 24;  //контрольная сумма
  update_settings_buf[8]:=(i and $00FF0000)shr 16;
  update_settings_buf[9]:=(i and $0000FF00)shr 8;
  update_settings_buf[10]:=(i and $000000FF);

  LogServMess('Settings CRC32 is '+inttohex(i,8),true);
end;

function CreateBackupBuffers:boolean;
var f,fout:file;
i,j:integer;
buf:array of byte;
str_file,str:string;
mem_in,mem_out:TMemoryStream;
compr:TZCompressionStream;
begin
  LogServMess('Create backup buffers enter',true);
  result:=false;

  //очищаем предыдущие буферы
  setlength(backup_log_packet,0);
  setlength(backup_log_buffer,0);
  setlength(buf,0);

  //читаем файл отправки
  AssignFile(f,LogFileName);
  Reset(f,1);
  i:=FileSize(f);
  setlength(backup_log_buffer,i);
  BlockRead(f,backup_log_buffer[0],i,j);
  CloseFile(f);

  if i<>j then
  begin
    LogServMess('Error in reading log file, exiting copy procedure',true);
    exit;
  end;

  LogServMess('Log file read sucsessful',true);

  //логируем буфер
  j:=ZCRC32(0,backup_log_buffer[0],length(backup_log_buffer));
  assignfile(fout,'output_sending.log');
  rewrite(fout,1);
  BlockWrite(fout,backup_log_buffer[0],length(backup_log_buffer));
  CloseFile(fout);
  LogServMess('Uncompressed buffer length='+inttostr(length(backup_log_buffer))+', CRC32='+inttohex(j,8)+', FileName=output_sending.log',true);

  //упаковываем (через потоки, т.к. процедура багнутая), если надо
  //ZCompress(pointer(backup_log_buffer),length(backup_log_buffer),pointer(buf),j,zcMax);

  if use_monitor_compression=true then
  begin
    LogServMess('FTP compression is enabled, begining to compress',true);

    try
      mem_in:=TMemoryStream.Create;
      mem_out:=TMemoryStream.Create;
      compr:=TZCompressionStream.Create(mem_out,zcMax);

      mem_in.WriteBuffer(backup_log_buffer[0],length(backup_log_buffer));
      mem_in.Position:=0;

      compr.CopyFrom(mem_in,mem_in.Size);
      compr.Free;

      mem_out.Position:=0;
      setlength(buf,mem_out.size);
      mem_out.ReadBuffer(buf[0],length(buf));

      mem_out.Free;
      mem_in.Free;
    except
      on e:exception do
      begin
        LogServMess('Exception in compression with message:'+e.Message,true);
        exit;
      end;
    end;

    //логируем сжатый буфер
    j:=ZCRC32(0,buf[0],length(buf));
    assignfile(fout,'output_sending_compressed.log');
    rewrite(fout,1);
    BlockWrite(fout,buf[0],length(buf));
    CloseFile(fout);
    LogServMess('Compressed buffer length='+inttostr(length(buf))+', CRC32='+inttohex(j,8)+', FileName=output_sending_compressed.log',true);
  end;

  //формируем пакет отправки только один раз
  str:=Datetostr(now);
  if str<>CurDate then  //если формируем новый лог за сегодня, то формируем заново имя файла
    CurFileName:=imei+'_'+CurDate+'_'+inttostr(gettickcount)+'.log';
  //str_file:=imei+'_'+CurDate+'_'+inttostr(gettickcount)+'.log';   //название файла на FTP
  str_file:=CurFileName;

  j:=length(str_file)+25;   //длинна пакета
  i:=j-5;   //длинна пакета в заголовке
  setlength(backup_log_packet,j);
  FillChar(backup_log_packet[0],length(backup_log_packet),0);
  backup_log_packet[0]:=158;  //начальный символ
  backup_log_packet[1]:=(i and $FF000000)shr 24;  //длинна
  backup_log_packet[2]:=(i and $00FF0000)shr 16;
  backup_log_packet[3]:=(i and $0000FF00)shr 8;
  backup_log_packet[4]:=(i and $000000FF);
  backup_log_packet[6]:=7;  //тип
  i:=length(backup_log_buffer);
  backup_log_packet[7]:=(i and $FF000000)shr 24;  //длинна распакованного файла
  backup_log_packet[8]:=(i and $00FF0000)shr 16;
  backup_log_packet[9]:=(i and $0000FF00)shr 8;
  backup_log_packet[10]:=(i and $000000FF);
  i:=length(buf);
  backup_log_packet[11]:=(i and $FF000000)shr 24;  //длинна запакованного файла
  backup_log_packet[12]:=(i and $00FF0000)shr 16;
  backup_log_packet[13]:=(i and $0000FF00)shr 8;
  backup_log_packet[14]:=(i and $000000FF);
  if use_monitor_compression=true then
  begin
    backup_log_packet[15]:=1;  //мы используем запаковщик
    i:=ZCRC32(0,buf[0],length(buf));   //считаем контрольную сумму запакованного фрагмента
    //LogServMess('Compressed len='+inttostr(length(buf))+', CRCint='+inttostr(i)+', CRC='+inttohex(i,8),true);
  end
  else
  begin
    backup_log_packet[15]:=0;  //мы не используем запаковщик
    i:=ZCRC32(0,backup_log_buffer[0],length(backup_log_buffer));   //считаем контрольную сумму распакованного фрагмента
  end;
  backup_log_packet[16]:=(i and $FF000000)shr 24;  //crc32
  backup_log_packet[17]:=(i and $00FF0000)shr 16;
  backup_log_packet[18]:=(i and $0000FF00)shr 8;
  backup_log_packet[19]:=(i and $000000FF);
  i:=(backup_log_interval div 3)*2;   //таймаут для сервера на приём данных (2/3 нашего таймаута)
  backup_log_packet[20]:=(i and $FF000000)shr 24;  //timeout
  backup_log_packet[21]:=(i and $00FF0000)shr 16;
  backup_log_packet[22]:=(i and $0000FF00)shr 8;
  backup_log_packet[23]:=(i and $000000FF);
  backup_log_packet[24]:=length(str_file);  //строка с названием файла
  //move(str_file[1],backup_log_packet[25],length(str_file));
  for i:=25 to length(backup_log_packet)-1 do
  begin
    if (i-24)>length(str_file) then break;
    backup_log_packet[i]:=ord(str_file[i-24]);
  end;

  //логируем пакет
  LogServMess('Backup initialization packet:',true);
  for i:=0 to length(backup_log_packet)-1 do
    LogServMess('#'+inttostr(i)+'='+inttostr(backup_log_packet[i]),false);

  //делаем буфер с запакованными данными, если надо
  if use_monitor_compression=true then
  begin
    setlength(backup_log_buffer,length(buf));
    move(buf[0],backup_log_buffer[0],length(buf));
  end;
  setlength(buf,0);

  LogServMess('Compressed and created backup packet',true);
  LogServMess('Create backup buffers exit',true);
  result:=true;
end;

{procedure SendSimpleAnswer(num,errorcode:byte);
var answer:string;
sum:cardinal;
i:integer;
begin
  answer:=chr(2)+chr(0)+  //dlinna
  chr(num)+      //nomer paketa dla otveta
  chr(errorcode);    //otvet

  sum:=0;
  for i:=1 to length(answer) do
    sum:=(sum+ord(answer[i]))and $FFFF;

  answer:=answer+chr(sum and $FF)+chr((sum and $FF00)shr 8);
  answer:=chr($A5)+answer+chr($AE);

  Tablo_service.Client.Socket.SendText(answer);
end;

procedure SendError4Answer(num,errorcode,error_ind:byte);
var answer:string;
sum:cardinal;
i:integer;
begin
  answer:=chr(3)+chr(0)+  //dlinna
  chr(num)+      //nomer paketa dla otveta
  chr(errorcode)+    //otvet
  chr(error_ind);    //index pola gde oshibka

  sum:=0;
  for i:=1 to length(answer) do
    sum:=(sum+ord(answer[i]))and $FFFF;

  answer:=answer+chr(sum and $FF)+chr((sum and $FF00)shr 8);
  answer:=chr($A5)+answer+chr($AE);

  Tablo_service.Client.Socket.SendText(answer);
end;     }

{function CheckEvent(mess:string):boolean;
begin
  result:=false;

  if event_occured>0 then
  begin
    LogServMess('Entering waiting for event ending in '+mess,true);
    result:=true;
  end;
end;  }

function PrognozWork(buf:array of byte):integer;
var flag:byte;
time_out,temp_out,begush_out:boolean;
begush_top:boolean;
begush_str:string;
row_count:byte;
row_mult:byte;
number_style,time_style,end_style:byte;
output_str:string;
index:integer;
i,j,k:integer;
temp_prognoz:array of string;
str,str1:string;
begin
  LogServMess('Prognoz work enter',true);

  result:=-1;

  //читаем свойства
  flag:=buf[4];
  if (flag and $1)<>0 then time_out:=true
  else time_out:=false;
  if (flag and $2)<>0 then temp_out:=true
  else temp_out:=false;
  if (flag and $4)<>0 then begush_out:=true
  else begush_out:=false;
  if (flag and $8)<>0 then begush_top:=true
  else begush_top:=false;

  //читаем бегущую строку если есть
  begush_str:='';
  index:=5;
  if begush_out=true then
  begin
    flag:=buf[5];
    if length(buf)<(6+flag) then
    begin
      result:=1;
      exit;
    end;
    for i:=1 to flag do
      if buf[5+i]<>0 then begush_str:=begush_str+chr(buf[5+i]);
    index:=index+flag+1;
  end;

  //читаем кол-во строк
  row_count:=buf[index];
  inc(index);
  if (row_count<1)or(row_count>6) then row_count:=6;   //количество всегда 6, не использую данную переменную

  //читаем стили шрифта
  number_style:=buf[index];
  inc(index);
  time_style:=buf[index];
  inc(index);
  end_style:=buf[index];
  inc(index);
  if (number_style>3) then number_style:=2;
  if (time_style>3) then time_style:=2;
  if (end_style>3) then end_style:=2;
  if (number_style>1) then dec(number_style,2);
  if (time_style>1) then dec(time_style,2);
  if (end_style>1) then dec(end_style,2);

  //читаем список прогнозов
  flag:=buf[index];
  LogServMess('Prognoz count='+inttostr(flag),true);
  inc(index);
  str:='';
  setlength(temp_prognoz,0);
  for i:=index to length(buf)-4 do
  begin
    if buf[i]=0 then
    begin
      j:=length(temp_prognoz);
      setlength(temp_prognoz,j+1);
      temp_prognoz[j]:=str;
      str:='';
    end
    else
    begin
      str:=str+chr(buf[i]);
    end;
  end;

  LogServMess('Temp_prognoz count='+inttostr(length(temp_prognoz)),true);
  for i:=0 to length(temp_prognoz)-1 do
    LogServMess('Temp_prognoz#'+inttostr(i)+'='+temp_prognoz[i],false);

  if ((length(temp_prognoz) mod 3)<>0)or((length(temp_prognoz) div 3)<>flag) then
  begin
    result:=2;
    exit;
  end;

  //очищаем массив прогнозов
  for i:=0 to length(prognozi)-1 do
  begin
    prognozi[i][1]:='';
    prognozi[i][2]:='';
    prognozi[i][3]:='';
  end;
  setlength(prognozi,0);

  //останавливаем таймер для ротации прогнозов, чтоьбы вывести нормальные прогнозы
  Tablo_Service.RotationTimer.Enabled:=false;

  setlength(prognozi,flag);
  for i:=0 to length(prognozi)-1 do
  begin
    if temp_prognoz[i*3]='' then prognozi[i][1]:=' '
    else prognozi[i][1]:=temp_prognoz[i*3]; //номер маршрута
    if temp_prognoz[i*3+1]='' then prognozi[i][2]:=' '
    else prognozi[i][2]:=temp_prognoz[i*3+1]; //время до прибытия
    if temp_prognoz[i*3+2]='' then prognozi[i][3]:=' '
    else prognozi[i][3]:=temp_prognoz[i*3+2]; //конечная
  end;
  //очищаем
  for i:=0 to length(temp_prognoz)-1 do
    temp_prognoz[i]:='';
  setlength(temp_prognoz,0);




  //=============++++++++++++++ВЫВОД СТРОК НА ТАБЛО+++++++++++===============
  output_str:='';

  case Tablo_type of
  1:begin
      //высчитываем множитель для строк
      row_mult:=8;
      //высчитываем кол-во строк под прогноза и начало строк прогноза
      flag:=1;
      i:=6;
      if (time_out=true)or(temp_out) then
      begin
        dec(i);
        flag:=flag+row_mult;
      end;
      if begush_out=true then dec(i);
      k:=i;
      if length(prognozi)<i then i:=length(prognozi);

      //коррекция вывода для пустого прогноза
      if length(prognozi)=1 then
        if prognozi[0][1]=' ' then i:=0;

      //вывод
      //настройка скорости прокрутки бегущих строк (выставляем стандартную для бегущей строки)
      output_str:=output_str+'%74080301060406040201';
      //дата и время
      if time_out=true then
      begin
        //дата
        output_str:=output_str+'%04'+date_start+date_finish+'001008u%1u$t3$13$u10';
        //время
        output_str:=output_str+'%04'+time_start+time_finish+'001008u%1u$t3$13$u40';
      end;
      //температура
      if (temp_out=true)and(temperature_str<>'') then
      begin
        output_str:=output_str+'%04'+temp_start+temp_finish+'0010084%10$t3$13$60$70'+temperature_str+chr(176)+'C';
      end;
      //бегущая строка
      if begush_out=true then
      begin
        LogServMess('Begushaya stoka dla tablo:'+begush_str,true);
        output_str:=output_str+'%04'+begush_start+begush_finish+'0410484%10$t3$12$60$70'+copy(begush_str,1,150)+'                           ';
      end;
      //настройка скорости прокрутки бегущих строк (выставляем чуть медленнее для строк прогнозов)
      output_str:=output_str+'%74080401060406040201';
      //строки прогноза
      {number_style:=0;
      time_style:=0;
      end_style:=0; }
      begin
        for j:=0 to i-1 do
        begin
          str:=inttostr(j*row_mult+flag);
          str1:=inttostr(j*row_mult+flag+row_mult-1);
          for index:=length(str) to 2 do str:='0'+str;
          for index:=length(str1) to 2 do str1:='0'+str1;

          //маршрут
          output_str:=output_str+'%04'+col1_start+col1_finish+str+str1+'4%10$t3$1'+inttostr(2+number_style)+'$60'+prognozi[j][1];
          //время до прибытия
          output_str:=output_str+'%04'+col3_start+col3_finish+str+str1+'4%10$t3$1'+inttostr(2+time_style)+'$60'+prognozi[j][2];
          //конечная
          output_str:=output_str+'%04'+col2_start+col2_finish+str+str1+'4%10$t3$1'+inttostr(2+end_style)+'$60'+prognozi[j][3];
        end;
        //очистка остальных строк
        for j:=i to k-1 do
        begin
          str:=inttostr(j*row_mult+flag);
          str1:=inttostr(j*row_mult+flag+row_mult-1);
          for index:=length(str) to 2 do str:='0'+str;
          for index:=length(str1) to 2 do str1:='0'+str1;

          //маршрут
          output_str:=output_str+'%04'+col1_start+col1_finish+str+str1+'4%10$t3$12$60$721';
          //время до прибытия
          output_str:=output_str+'%04'+col3_start+col3_finish+str+str1+'4%10$t3$12$60$721';
          //конечная
          if (str='017')and(i=0) then
            output_str:=output_str+'%04'+col2_start+col2_finish+str+str1+'4%10$t2$12$60$70Нет данных'
          else
            output_str:=output_str+'%04'+col2_start+col2_finish+str+str1+'4%10$t3$12$60$721';
        end;
      end;
    end;
  2:begin
      //высчитываем множитель для строк
      row_mult:=19;
      //высчитываем кол-во строк под прогноза и начало строк прогноза
      flag:=1;
      i:=3;
      if (time_out=true) then
      begin
        dec(i);
        //flag:=flag+row_mult;
        flag:=flag+9;
      end;
      //if begush_out=true then dec(i);
      k:=i;
      if length(prognozi)<i then i:=length(prognozi);

      //вывод
      //настройка скорости прокрутки бегущих строк (выставляем стандартную для бегущей строки)
      output_str:=output_str+'%74080301060406040201';
      //дата и время
      if time_out=true then
      begin
        //дата
        output_str:=output_str+'%04'+date_start+date_finish+'001008u%1u$t3$12$u10';
        //время
        output_str:=output_str+'%04'+time_start+time_finish+'001008u%1u$t1$12$u40';
      end;
      //температура
      {if (temp_out=true)and(temperature_str<>'') then
      begin
        output_str:=output_str+'%04'+temp_start+temp_finish+'0010084%10$t3$13$60$70'+temperature_str+chr(176)+'C';
      end;  }
      //бегущая строка
      {if begush_out=true then
      begin
        LogServMess('Begushaya stoka dla tablo:'+begush_str,true);
        output_str:=output_str+'%04'+begush_start+begush_finish+'0410484%10$t3$12$60$70'+copy(begush_str,1,150)+'                           ';
      end;    }
      //настройка скорости прокрутки бегущих строк (выставляем чуть медленнее для строк прогнозов)
      output_str:=output_str+'%74080401060406040201';
      //строки прогноза
      begin
        for j:=0 to i-1 do
        begin
          str:=inttostr(j*row_mult+flag);
          str1:=inttostr(j*row_mult+flag+9-1);
          for index:=length(str) to 2 do str:='0'+str;
          for index:=length(str1) to 2 do str1:='0'+str1;

          //маршрут
          output_str:=output_str+'%04'+col1_start+col1_finish+str+str1+'4%10$t3$1'+inttostr(2+number_style)+'$60'+prognozi[j][1];
          //время до прибытия
          output_str:=output_str+'%04'+col3_start+col3_finish+str+str1+'4%10$t1$1'+inttostr(2+time_style)+'$60'+prognozi[j][2];

          str:=inttostr(j*row_mult+flag+9);
          str1:=inttostr(j*row_mult+flag+10-1+9);
          for index:=length(str) to 2 do str:='0'+str;
          for index:=length(str1) to 2 do str1:='0'+str1;

          //конечная
          output_str:=output_str+'%04'+col2_start+col2_finish+str+str1+'4%10$t3$1'+inttostr(2+end_style)+'$60'+prognozi[j][3];
        end;
        //очистка остальных строк
        for j:=i to k-1 do
        begin
          str:=inttostr(j*row_mult+flag);
          str1:=inttostr(j*row_mult+flag+9-1);
          for index:=length(str) to 2 do str:='0'+str;
          for index:=length(str1) to 2 do str1:='0'+str1;

          //маршрут
          output_str:=output_str+'%04'+col1_start+col1_finish+str+str1+'4%10$t3$12$60$721';
          //время до прибытия
          output_str:=output_str+'%04'+col3_start+col3_finish+str+str1+'4%10$t1$12$60$721';

          str:=inttostr(j*row_mult+flag+9);
          str1:=inttostr(j*row_mult+flag+10-1+9);
          for index:=length(str) to 2 do str:='0'+str;
          for index:=length(str1) to 2 do str1:='0'+str1;

          //конечная
          if (str='017')and(i=0) then
            output_str:=output_str+'%04'+col2_start+col2_finish+str+str1+'4%10$t2$12$60$70Нет данных'
          else
            output_str:=output_str+'%04'+col2_start+col2_finish+str+str1+'4%10$t3$12$60$721';
        end;
      end;
    end;
  end;

  if SendCommWhole(TabloAdress,output_str)=false then
  begin
    result:=3;
    exit;
  end;

  //активируем таймер ротации если надо
  if (length(prognozi)>i)and(i<>0) then Tablo_service.RotationTimer.Enabled:=true;

  result:=0;
end;

function SetDateTimeWork(buf:array of byte):integer;
var b:byte;
output_str:string;
str:string;
begin
  LogServMess('SetDateTime work enter',true);

  result:=-1;

  output_str:='%7c';
  //год
  b:=buf[10];
  if b>99 then
  begin
    result:=1;
    error_index:=6;
    exit;
  end;
  str:=inttostr(b);
  if length(str)=1 then str:='0'+str;
  str:='20'+str;
  output_str:=output_str+str;
  //месяц
  b:=buf[9];
  if (b=0)or(b>12) then
  begin
    result:=1;
    error_index:=5;
    exit;
  end;
  str:=inttostr(b);
  if length(str)=1 then str:='0'+str;
  output_str:=output_str+str;
  //день
  b:=buf[8];
  if (b=0)or(b>31) then
  begin
    result:=1;
    error_index:=4;
    exit;
  end;
  str:=inttostr(b);
  if length(str)=1 then str:='0'+str;
  output_str:=output_str+str;
  //час
  b:=buf[6];
  if b>23 then
  begin
    result:=1;
    error_index:=2;
    exit;
  end;
  str:=inttostr(b);
  if length(str)=1 then str:='0'+str;
  output_str:=output_str+str;
  //минуты
  b:=buf[5];
  if b>59 then
  begin
    result:=1;
    error_index:=1;
    exit;
  end;
  str:=inttostr(b);
  if length(str)=1 then str:='0'+str;
  output_str:=output_str+str;
  //секунды
  b:=buf[4];
  if b>59 then
  begin
    result:=1;
    error_index:=0;
    exit;
  end;
  str:=inttostr(b);
  if length(str)=1 then str:='0'+str;
  output_str:=output_str+str;

  if result<>-1 then exit;

  //посылка
  {if SendCommWhole(TabloAdress,output_str)=false then
  begin
    result:=3;
    exit;
  end;  }
  if Initialize_tablo(false)=false then
  begin
    result:=3;
    exit;
  end;

  result:=0;
end;

function SetTemperatureWork(buf:array of byte):integer;
var str:string;
i:integer;
begin
  result:=-1;

  if length(buf)<>10 then
  begin
    result:=2;
    LogServMess('Error #2 in SetTemperatureWork, packet size='+inttostr(length(buf)),true);
    for i:=0 to length(buf)-1 do
      LogServMess('#'+inttostr(i)+'='+inttostr(buf[i]),false);
    exit;
  end;

  str:='';
  for i:=4 to 6 do
  begin
    if (chr(buf[i])<>'+')and(chr(buf[i])<>'-')and((buf[i]<48)or(buf[i]>57))and(chr(buf[i])<>' ') then
    begin
      result:=1;
      exit;
    end;
    str:=str+chr(buf[i]);
  end;

  temperature_str:=str;

  result:=0;
end;

procedure LogFileCopy;
var str_file,str:string;
f:file;
i,j,z:integer;
buf:array of byte;
handl:integer;
begin
  str:=Datetostr(now);

  if str<>CurDate then
  begin
    LogServMess('========================= Log file copy time =====================',false);

    if (enable_monitor=true)and(use_monitor_upload=true) then
    begin
      LogServMess('Monitor server enabled, backuping using monitor server',true);

      if CreateBackupBuffers=false then  //буфер для отправки и пакет инициализации отправки
      begin
        LogServMess('Failed to create backup, aborting',true);
        CurDate:=str;
        LogServMess('Changed date, backup exiting',true);
        exit;
      end;

      //выставляем флаги
      log_backup_transfer_in_progress:=true;
      enable_backup_log:=true;
      sended_backup_packet:=false;
      sended_backup_buffer:=false;
      //делаем рандомное знечение задержки для разгрузки сервера
      z:=random(600)*1000;
      if gettickcount-backup_log_interval<0 then backup_log_time:=z
      else backup_log_time:=gettickcount-backup_log_interval+z;  //чтобы сразу послать пакет

      LogServMess('Random delay on backup='+inttostr(z));

      CurDate:=str;

      LogServMess('Changed date, backup exiting',true);
    end   //if enable_monitor=true then
    else
    begin
      LogServMess('Monitor server or using monitor server as upoload disabled, backuping using own FTP client',true);

      if FTPHost='' then
      begin
        LogServMess('FTP host is empty, backup exiting',true);
        CurDate:=str;
        exit;
      end;

      LogServMess('Trying to connect to ftp',true);

      try
        Tablo_service.IdFTP1.Connect;
      except
        on e:exception do
        begin
          LogServMess('FTP connection failed with message:'+e.Message,true);
          Tablo_service.IdFTP1.Disconnect;
          Tablo_service.IdFTP1.DisconnectSocket;
          exit;
        end;
      end;

      LogServMess('FTP connection sucsess',true);

      if Tablo_service.IdFTP1.Connected then
      begin
        try
          str_file:=imei+'_'+CurDate+'_'+inttostr(gettickcount)+'_'+extractfilename(LogFileName);
          Tablo_service.IdFTP1.Put(LogFileName,str_file,false);
          Tablo_service.IdFTP1.Disconnect;
          Tablo_service.IdFTP1.DisconnectSocket;
        except
          on e:exception do
          begin
            LogServMess('FTP upload failed with message:'+e.Message,true);
            Tablo_service.IdFTP1.Disconnect;
            Tablo_service.IdFTP1.DisconnectSocket;
            exit;
          end;
        end;

        deletefile(LogFileName);
        handl:=FileCreate(LogFileName);
        CurDate:=str;
        FileClose(handl);

        LogServMess(str,false);
        LogServMess('Old backuped file name='+str_file,false);
      end;

      CurDate:=str;
    end;   //else if enable_monitor=true then
  end;   //if str<>CurDate then
end;

procedure LogFileFinalize;
var f:file;
i,j,k:integer;
buf:array of byte;
str,str1:string;
begin
  LogServMess('Backup finalization enter    ++++++++++++++++++++++++++++++++++++++++++',false);

  //читаем кол-во байт в файле бекапа, которое мы отослали
  i:=(backup_log_packet[7] shl 24)or(backup_log_packet[8] shl 16)or(backup_log_packet[9] shl 8)or(backup_log_packet[10]);
  //читаем название файла
  //setlength(str,backup_log_packet[24]);
  //move(backup_log_packet[25],str[1],length(str));
  str:='';
  for j:=25 to length(backup_log_packet)-1 do
    str:=str+chr(backup_log_packet[j]);

  //открываем файл и читаем остальное для копирования
  AssignFile(f,LogFileName);
  Reset(f,1);
  j:=FileSize(f)-i;
  setlength(buf,j);
  Seek(f,i);
  BlockRead(f,buf[0],length(buf),k);
  CloseFile(f);
  Rewrite(f,1);
  str1:=CurDate+#13+#10+'Old backuped file name='+str+#13+#10;
  BlockWrite(f,str1[1],length(str1));
  BlockWrite(f,buf[0],length(buf));
  CloseFile(f);

  setlength(buf,0);
  setlength(backup_log_buffer,0);
  setlength(backup_log_packet,0);
  str1:='';
  str:='';

  LogServMess('BufferSize='+inttostr(j)+', ActualRead='+inttostr(k),false);

  LogServMess('Backup finalization exit     ++++++++++++++++++++++++++++++++++++++++++',false);
end;

function SysReboot:boolean;
var TP,TPPrev:TTokenPrivileges;
luid:int64;
retLen:cardinal;
token:cardinal;
begin
  result:=false;

  LogServMess('Initiating system reboot',true);

  if LookupPrivilegeValue(nil,pchar('SeShutdownPrivilege'),luid)=false then
  begin
    LogServMess('LookupPrivilegeValue failed with error:'+inttostr(getlasterror),true);
    exit;
  end;
  LogServMess('LookupPrivilegeValue sucsess',true);

  TP.PrivilegeCount:=1;
  TP.Privileges[0].Luid:=luid;
  TP.Privileges[0].Attributes:=SE_PRIVILEGE_ENABLED;

  if OpenProcessToken(GetCurrentProcess,TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY,Token)=false then
  begin
    LogServMess('OpenProcessToken failed with error:'+inttostr(getlasterror),true);
    exit;
  end;
  LogServMess('OpenProcessToken sucsess',true);

  if AdjustTokenPrivileges(token,false,TP,sizeof(TPPrev),TPPrev,retLen)=false then
  begin
    LogServMess('AdjustTokenPrivileges failed with error:'+inttostr(getlasterror),true);
    exit;
  end;
  LogServMess('AdjustTokenPrivileges sucsess',true);

  if GetLastError=ERROR_NOT_ALL_ASSIGNED then
  begin
    LogServMess('Error, not all priviledges assigned',true);
    exit;
  end;

  closehandle(token);

  if ExitWindowsEx(EWX_REBOOT or EWX_FORCE,$00040000 or $00000005)=true then
  begin
    LogServMess('Shutdown sucsessful',true);
  end
  else
    LogServMess('Shutdown failed',true);

  result:=true;
end;

function Initialize_tablo(Clear_tablo:boolean):boolean;
var str,str1:string;
year,day,month,hour,min,sec,msec:word;
begin
  decodedatetime(now,year,month,day,hour,min,sec,msec);
  if Clear_tablo=true then str:='%23%7c'
  else str:='%7c';

  str:=str+inttostr(year);
  str1:=inttostr(month);
  if length(str1)<2 then str1:='0'+str1;
  str:=str+str1;
  str1:=inttostr(day);
  if length(str1)<2 then str1:='0'+str1;
  str:=str+str1;
  str1:=inttostr(hour);
  if length(str1)<2 then str1:='0'+str1;
  str:=str+str1;
  str1:=inttostr(min);
  if length(str1)<2 then str1:='0'+str1;
  str:=str+str1;
  str1:=inttostr(sec);
  if length(str1)<2 then str1:='0'+str1;
  str:=str+str1;

  result:=SendCommWhole(TabloAdress,str);
end;

//------------------------END of supply functions--------------------------------


procedure TTablo_service.ServiceStart(Sender: TService;
  var Started: Boolean);
var fname,str:string;
b:boolean;
i:integer;
begin
  randomize;

  //меняем текущую папку
  SetCurrentDirectory(PChar(ExtractFilePath(GetModuleFileNameStr(0))));

  //начальное задание переменных
  LogLevel:=0;
  LogFileName:='output.log';
  ComPort:='COM1';
  TabloAdress:=1;
  socket_host:='';
  socket_port:=6101;
  sended_register:=false;
  register_message:='';
  register_time:=0;
  comm_answer:='';
  registration:=false;
  working:=false;
  temperature_str:='';
  error_index:=0;
  monitor_socketID:=-1;
  //event_occured:=0;
  CurDate:=Datetostr(now);   //Задаем текущую дату для логов
  enable_backup_log:=false;
  sended_backup_packet:=false;
  sended_backup_buffer:=false;
  update_transfer_in_progress:=false;
  update_settings_transfer_in_progress:=false;
  log_backup_transfer_in_progress:=false;
  backup_log_time:=gettickcount;
  backup_log_interval:=20000;
  TeamViewer_ID:=0;
  registration_monitor_extra_delay:=180000;  //изначально задержка 3 минуты
  setlength(backup_log_buffer,0);
  setlength(backup_log_packet,0);

  //Проверяем, есть ли INI файл
  fname:=ChangeFileExt(GetModuleFileNameStr(0), '.INI');
  if not(FileExists(fname)) then
  begin   //если нет, то создаем
    LogServMess('Missing INI file, creating',true);
    if CreateINIFile(fname) then LogServMess('INI File created',true)
    else
    begin
      LogServMess('Failed to create INI file, shutting down',true);
      started:=false;
      exit;
    end;
  end
  else
    LogServMess('INI file found',true);

  //инициализируем и читаем INI файл
  INIFile:=TINIFile.Create(fname);
  str:=INIFile.ReadString('Main','LogFileName','output.log');
  if expandfilename(str)<>expandfilename(LogFileName) then
  begin
    LogServMess('Log file name is different in INI file ('+str+'), begining to write log to there',false);
    LogFileName:=str;
  end
  else
    LogServMess('Log file is same, continuing',true);
  LogServMess('==================================================================================================',false);
  LogServMess('Starting service...',true);
  LogServMess('Begining to read INI file',true);
  LogLevel:=INIFile.ReadInteger('Main','LogLevel',0);
  LogServMess('Readed LogLevel='+inttostr(LogLevel),true);
  ComPort:=INIFile.ReadString('Main','ComPort','COM1');
  //добавляем специальные символы, чтобы ком-порт работал с портами больше 9
  ComPort:='\\.\'+ComPort;
  LogServMess('Readed ComPort='+ComPort,true);
  TabloAdress:=INIFile.ReadInteger('Main','TabloAdress',126);
  LogServMess('Readed TabloAdress='+inttostr(TabloAdress),true);
  tablo_type:=INIFile.ReadInteger('Main','TabloType',1);
  LogServMess('Readed TabloType='+inttostr(tablo_type),true);
  rotation_interval:=INIFile.ReadInteger('Main','RotationTimerInterval',7000);
  LogServMess('Readed RotationTimerInterval='+inttostr(rotation_interval),true);

  socket_host:=INIFile.ReadString('SocketSettings','Host','');
  LogServMess('Readed SocketHost='+socket_host,true);
  socket_port:=INIFile.ReadInteger('SocketSettings','Port',6101);
  LogServMess('Readed SocketPort='+inttostr(socket_port),true);
  imei:=INIFile.ReadString('SocketSettings','IMEI','');
  LogServMess('Readed IMEI='+imei,true);
  before_connect_interval:=INIFile.ReadInteger('SocketSettings','BeforeConnectInterval',10000);
  LogServMess('Readed BeforeConnectInterval='+inttostr(before_connect_interval));
  OnConnect_timeout:=INIFile.ReadInteger('SocketSettings','OnConnectTimeout',10000);
  LogServMess('Readed OnConnectTimeout='+inttostr(OnConnect_timeout));
  Register_responce_timeout:=INIFile.ReadInteger('SocketSettings','RegisterResponceTimeout',10000);
  LogServMess('Readed RegisterResponceTimeout='+inttostr(Register_responce_timeout));
  Waiting_for_packet_timeout:=INIFile.ReadInteger('SocketSettings','WAitingForPacketTimeout',180000);
  LogServMess('Readed WAitingForPacketTimeout='+inttostr(Waiting_for_packet_timeout));

  col1_start:=INIFile.ReadString('Columns','Col1st','001');
  col1_finish:=INIFile.ReadString('Columns','Col1fin','032');
  col2_start:=INIFile.ReadString('Columns','Col2st','033');
  col2_finish:=INIFile.ReadString('Columns','Col2fin','155');
  col3_start:=INIFile.ReadString('Columns','Col3st','156');
  col3_finish:=INIFile.ReadString('Columns','Col3fin','192');
  date_start:=INIFile.ReadString('Columns','Datest','051');
  date_finish:=INIFile.ReadString('Columns','Datefin','100');
  time_start:=INIFile.ReadString('Columns','Timest','105');
  time_finish:=INIFile.ReadString('Columns','Timefin','150');
  temp_start:=INIFile.ReadString('Columns','Tempst','152');
  temp_finish:=INIFile.ReadString('Columns','Tempfin','192');
  begush_start:=INIFile.ReadString('Columns','Begst','001');
  begush_finish:=INIFile.ReadString('Columns','Begfin','192');

  FTPHost:=INIFile.ReadString('FTP','Host','');
  FTPPort:=INIFile.ReadInteger('FTP','Port',21);
  FTPLogin:=INIFile.ReadString('FTP','Login','root');
  FTPPass:=INIFile.ReadString('FTP','Pass','1');
  FTPTimeout:=INIFile.ReadInteger('FTP','Timeout',20000);

  i:=INIFile.ReadInteger('Monitor','Enable',0);
  if i<>0 then enable_monitor:=true
  else enable_monitor:=false;
  LogServMess('Readed MonitorEnabled='+booltostr(enable_monitor,true),true);
  i:=INIFile.ReadInteger('Monitor','UseAsFTP',0);
  if i<>0 then use_monitor_upload:=true
  else use_monitor_upload:=false;
  LogServMess('Readed UseAsFTP='+booltostr(use_monitor_upload,true),true);
  i:=INIFile.ReadInteger('Monitor','UseFTPCompression',0);
  if i<>0 then use_monitor_compression:=true
  else use_monitor_compression:=false;
  LogServMess('Readed UseFTPCompression='+booltostr(use_monitor_compression,true),true);
  i:=INIFile.ReadInteger('Monitor','EnableUpdate',1);
  if i<>0 then enable_update:=true
  else enable_update:=false;
  LogServMess('Readed EnableUpdate='+booltostr(enable_update,true));
  monitor_socket_host:=INIFile.ReadString('Monitor','Host','vidor.ru');
  LogServMess('Readed MonitorHost='+monitor_socket_host,true);
  monitor_socket_port:=INIFile.ReadInteger('Monitor','Port',750);
  LogServMess('Readed MonitorPort='+inttostr(monitor_socket_port),true);
  echo_interval:=INIFile.ReadInteger('Monitor','EchoInterval',60000);
  LogServMess('Readed EchoInterval='+inttostr(echo_interval),true);
  synch_interval:=INIFile.ReadInteger('Monitor','SynchInterval',3600000);
  LogServMess('Readed SynchInterval='+inttostr(synch_interval),true);
  update_interval:=INIFile.ReadInteger('Monitor','UpdateInterval',3600000);
  LogServMess('Readed UpdateInterval='+inttostr(update_interval),true);
  update_interval:=update_interval+random(3600000);
  LogServMess('  Added random number to UpdateInterval, final result='+inttostr(update_interval),true);
  update_settings_interval:=update_interval div 2;
  LogServMess('  Calculated UpdateSettingsInterval, result='+inttostr(update_settings_interval));
  imei_int:=strtoint64(imei);
  LogServMess('Converted IMEI to int='+inttostr(imei_int),true);
  LogServMess('Reading INI file complete',true);

  //записываем начальное имя файла для бекапа логов
  CurFileName:=imei+'__'+inttostr(gettickcount)+'.log';

  //проверка на правильность параметров сокета
  if (socket_host='')or(imei='') then
  begin
    LogServMess('Empty host adress or imei, exiting',true);
    exit;
  end;

  //инициализируем ком-порт
  MSGBeginByte := $02;                                           //начало сообщения
  TabAdrByte[1] := $00; TabAdrByte[2] := $00;                    //адрес табло
  DataBlockLengthByte[1] := $00; DataBlockLengthByte[2] := $00;  //длинна блока данных
  DataBlock := nil;                                              //блок данных
  XORByte[1] :=$00; XORByte[2] :=$00;                            //XOR
  MSGEndByte := $03;                                             //конец сообщения

  try
    Comm.CommPort:=ComPort;
    b:=Comm.StartComm;
    Comm.OutSignal := SETDTR;
    Comm.OutSignal := SETRTS;
  except
    b:=false;
  end;

  if b=true then
  begin
    LogServMess('Com port opened on '+Comm.CommPort,true);
  end
  else
  begin
    LogServMess('Error. Unable to open com port on '+Comm.CommPort,true);
  end;

  //Изменяем параметры таймера ротации
  RotationTimer.Interval:=rotation_interval;

  //Изменяем параметры ФТП
  IdFTP1.Host:=FTPHost;
  IdFTP1.Port:=FTPPort;
  IdFTP1.Username:=FTPLogin;
  IdFTP1.Password:=FTPPass;
  IdFTP1.Passive:=true;
  IdFTP1.ReadTimeout:=FTPTimeout;

  //записываем параметры сокета в компонент и открываем соединение
  {Client.Host:=socket_host;
  Client.Port:=socket_port;
  Client.ClientType:=ctNonBlocking;   }
  DataProtocol:=TDataProtocolObject.Create(socket_host,socket_port,before_connect_interval,OnConnect_timeout,Register_responce_timeout,Waiting_for_packet_timeout);

  //записываем параметры сокета в компонент и открываем соединение к серверу мониторинга
  ClientMonitor.Host:=monitor_socket_host;
  ClientMonitor.Port:=monitor_socket_port;
  ClientMonitor.ClientType:=ctNonBlocking;
  //открытие соединения в главном потоке

  //записываем параметры сокета в компонент и открываем соединение к серверу бекапа мониторинга
  BackupClient.Host:=monitor_socket_host;
  BackupClient.Port:=2000;
  BackupClient.ClientType:=ctNonBlocking;
  //это соединение открывается по мере надобности
  {if enable_monitor=true then
  begin
    LogServMess('Opening connection to backup server on '+BackupClient.Host+':'+inttostr(BackupClient.Port),true);
    //BackupClient.Open;
  end
  else
    LogServMess('Monitor server connection is disabled, skipping initializing backup connection',true);    }

  //записываем параметры сокета в компонент и открываем соединение к серверу апдейта мониторинга
  UpdateClient.Host:=monitor_socket_host;
  UpdateClient.Port:=2000;
  UpdateClient.ClientType:=ctNonBlocking;

  //создаём пакеты для протокола мониторинга табло
  LogServMess('Calling create packets for monitor server',true);
  try
    CreateMonitorMessages(imei_int);
  except
    on e:exception do
    begin
      LogServMess('WARNING! Exception in CreateMonitorMessages procedure with message:'+e.Message);
      raise;
    end;
  end;

  //создаем пакет регистрации и пакеты для сообщений об ошибках
  LogServMess('Calling create message procedure',true);
  CreateMessages(imei);

  //создаём унифицированный файл настроек и вычисляем его CRC
  LogServMess('Calling create unified settings procedure');
  CreateUnifiedSettings;

  //Запускаем поток для работы
  LogServMess('Creating Thread',true);
  WorkThread:=TWorkThread.Create(true);
  WorkThread.FreeOnTerminate:=false;
  WorkThread.paused:=false;
  WorkThread.Resume;

  Started:=true;
  LogServMess('Start service complete',true);
end;

procedure TTablo_service.ServiceStopShutdown;
var b:boolean;
begin
  LogServMess('Stop/Shutdown procedure began',true);

  if Assigned(WorkThread) then
  begin
    LogServMess('Begin to stop thread',true);
    if WorkThread.Suspended then WorkThread.Resume;
    WorkThread.Terminate;
    WorkThread.WaitFor;
    FreeAndNil(WorkThread);
    LogServMess('Thread stopped sucsessfuly',true);
  end;
  INIFile.Free;
  LogServMess('INI file freed',true);

  try
    Comm.OutSignal := CLRDTR;
    Comm.OutSignal := CLRRTS;
    Comm.StopComm;
    b:=true;
  except
    b:=false;
  end;
  if b=true then LogServMess('Com port stopped',true)
  else LogServMess('Error in stopping com port',true);

  //Client.Close;
  DataProtocol.Free;
  ClientMonitor.Close;
  BackupClient.Close;
  UpdateClient.Close;
  LogServMess('Client socket close done',true);
end;

procedure TTablo_service.ServiceShutdown(Sender: TService);
begin
  LogServMess('Shutdown event enter',true);
  ServiceStopShutdown;

  LogServMess('Shutdown event complete',true);
end;

procedure TTablo_service.ServiceStop(Sender: TService;
  var Stopped: Boolean);
begin
  LogServMess('Stop service event enter',true);
  ServiceStopShutdown;

  LogServMess('Stop service event complete',true);
  Stopped:=true;
end;

procedure TTablo_service.ServicePause(Sender: TService;
  var Paused: Boolean);
begin
  LogServMess('Service pause event started',true);

  WorkThread.paused:=true;

  LogServMess('Service pause event exit',true);
  Paused:=true;
end;

procedure TTablo_service.ServiceContinue(Sender: TService;
  var Continued: Boolean);
begin
  LogServMess('Service continue event started',true);

  WorkThread.paused:=false;

  LogServMess('Service continue event exit',true);
  Continued:=true;
end;

procedure TTablo_service.Client111Connect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('Socket OnConnect event',true);

  sended_register:=false;
end;

procedure TTablo_service.Client111Connecting(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('Socket OnConnecting event',true);
end;

procedure TTablo_service.Client111Disconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('Socket OnDisconnect event',true);
end;

procedure TTablo_service.Client111Error(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
  var ErrorCode: Integer);
begin
  LogServMess('Socket OnError event, ord='+inttostr(ord(ErrorEvent)),true);

  case ErrorEvent of
    eeGeneral:LogServMess('General event error',false);
    eeSend:LogServMess('Send event error',false);
    eeReceive:LogServMess('Receive event error',false);
    eeConnect:LogServMess('Connect event error',false);
    eeDisconnect:LogServMess('Disconnect event error',false);
    eeAccept:LogServMess('Accept event error',false);
    eeLookup:LogServMess('Lookup event error',false);
  end;

  error_event:=true;

  Socket.Disconnect(Socket.SocketHandle);

  ErrorCode:=0;
end;

procedure TTablo_service.Client111Lookup(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('Socket OnLookup event',true);
end;

procedure TTablo_service.Client111Read(Sender: TObject;
  Socket: TCustomWinSocket);
var buf:array of byte;
i,j:integer;
begin
  LogServMess('Socket OnRead event',true);
  //WorkThread.Suspend;
  //inc(event_occured);
  i:=socket.ReceiveLength;
  setlength(buf,i);
  socket.ReceiveBuf(buf[0],i);

  LogServMess('Socket OnRead received bytes:'+inttostr(i),true);

  if i<=7 then
  begin
    LogServMess('Packet is too small, ignoring',true);
  end
  else if i>=2048 then
  begin
    LogServMess('Packet is too big, sending error #1',true);
    //SendSimpleAnswer(buf[3],1);
  end
  else
  begin
    j:=length(info_input);
    setlength(info_input,j+1);
    setlength(info_input[j],i);
    move(buf[0],info_input[j][0],i);

    setlength(buf,0);

    LogServMess('Packet received sucsessfuly, end of OnRead',true);

    {//ищём и делаем замену
    buf2:=copy(buf,0,length(buf));
    setlength(buf,0);

    j:=0;
    while j<=length(buf2)-2 do
    begin
      k:=length(buf);
      setlength(buf,k+1);
      if buf2[j]=$AA then
      begin
        if buf2[j+1]=$05 then buf[k]:=$A5
        else if buf2[j+1]=$0E then buf[k]:=$AE
        else buf[k]:=$AA;
        inc(j);
      end
      else buf[k]:=buf2[j];
      inc(j);
    end;
    k:=length(buf);
    setlength(buf,k+1);
    buf[k]:=buf2[j];
    
    setlength(buf2,0);
    i:=length(buf);

    //проверка на наличие символа начала
    if buf[0]<>$A5 then
    begin
      LogServMess('Wrong starting symbol:'+inttostr(buf[0])+', ignoring',true);
      //WorkThread.Resume;
      //dec(event_occured);
      exit;
    end;
    //проверка длинны пакета
    j:=(buf[1] and $FF)or((buf[2] and $FF)shl 8);
    if j<>(i-6) then
    begin
      LogServMess('Wrong packet length:'+inttostr(j)+', must be:'+inttostr(i-6)+', sending error #3',true);
      SendSimpleAnswer(buf[3],3);
      for i:=0 to length(buf)-1 do
        LogServMess('#'+inttostr(i)+'='+inttostr(buf[i]),false);
      //WorkThread.Resume;
      //dec(event_occured);
      exit;
    end;

    receive_time:=gettickcount;
    if registration=true then
    begin
      registration:=false;
      working:=true;
      error_event:=false;
      //очищаем табло и шлём туда время с компьютера
      //SendCommWhole(TabloAdress,'%23');
      Initialize_tablo;
    end;
    j:=buf[3];

    //SendCommWhole(TabloAdress,'%040011920330404%10$t3$10$60'+'recv='+inttostr(j)+'  '+inttostr(receive_time));
    //SendCommWhole(TabloAdress,'%040010500010084%10$t3$10$60'+'recv='+inttostr(j));

    LogServMess('Received packet type #'+inttostr(j),true);

    case j of
      0:; //перезагрузка табло
      1:begin //загрузка прогнозов
          LogServMess('Prognozi (#1)',true);
          k:=PrognozWork(buf);
          if k=0 then SendSimpleAnswer(1,0)
          else if k=3 then SendSimpleAnswer(1,5);
          LogServMess('Prognoz work returned:'+inttostr(k),true);
        end;
      2:begin //установка параметров табло
          LogServMess('Ustanovka parametrov (#2)',true);
          SendSimpleAnswer(2,0);
        end;
      3:; //запрос параметров табло
      4:; //запрос конфигурации табло
      5:begin //установка времени и даты
          LogServMess('Ustanovka vremeni i dati (#5)',true);
          if length(buf)<11 then
            LogServMess('Wrong packet size, packet is too small for this type (#5), size='+inttostr(length(buf)),true)
          else
          begin
            error_index:=0;
            k:=SetDateTimeWork(buf);
            case k of
              0:SendSimpleAnswer(5,0);
              1:SendError4Answer(5,4,error_index);
              3:SendSimpleAnswer(5,5);
            end;

            LogServMess('SetDateTime work returned:'+inttostr(k),true);
          end;
        end;
      6:; //запрос времени и даты
      7:begin //установка температуры
          LogServMess('Ustanovka temperaturi (#7)',true);
          if length(buf)<6 then
            LogServMess('Wrong packet size, packet is too small for this type (#7), size='+inttostr(length(buf)),true)
          else
          begin
            error_index:=0;
            k:=SetTemperatureWork(buf);
            if k=0 then SendSimpleAnswer(7,0)
            else if k=1 then SendError4Answer(7,4,0)
            else SendSimpleAnswer(7,5);
            LogServMess('SetTemperature work returned:'+inttostr(k),true);
          end;
        end;
      8:; //запрос температуры
      9:; //запуск программы
      10:; //включение, выключение светодиодов табло
      11:begin //запрос статуса
         end
      else
      begin
        LogServMess('Unknown packet type:'+inttostr(j)+', ignoring',true);
      end;
    end;  }
  end;

  //WorkThread.Resume;
  //dec(event_occured);
end;

procedure TTablo_service.Client111Write(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('Socket OnWrite event',true);
end;

//-------------------BEGIN OF THREAD IMPLEMENTATION---------------------------------

procedure TWorkThread.Execute;
var i,exception_count:integer;
time_work:cardinal;
s_reboot:boolean;
msg:TMSG;
begin
  LogServMess('Thread Execution enter',true);

  //инициализация
  i:=0;
  time_work:=gettickcount;
  receive_time:=time_work;
  register_time:=time_work;
  registration:=true;
  working:=false;
  error_event:=false;
  s_reboot:=false;
  exception_count:=0;

  //инициализация переменных для сервера мониторинга
  error_event_monitor:=false;
  sended_register_monitor:=false;
  echo_time:=time_work;
  registration_monitor:=true;
  registration_monitor_time:=time_work;
  synch_time:=time_work;
  update_time:=time_work;
  sended_update_packet:=false;
  update_transfer_in_progress:=false;
  update_settings_transfer_in_progress:=false;
  log_backup_transfer_in_progress:=false;
  update_time_timeout:=time_work;
  update_time_timeout_interval:=15000;
  update_time_keep_alive:=time_work;
  update_time_keep_alive_interval:=5000;
  enable_update_settings:=true;
  sended_update_settings_packet:=false;
  update_settings_time_timeout:=time_work;
  update_settings_time_timeout_interval:=15000;
  update_settings_time_keep_alive:=time_work;
  update_settings_time_keep_alive_interval:=5000;
  update_settings_time:=time_work;

  //ждём инициализации контролера табло
  sleep(5000);

  LogServMess('Dysplaing IMEI',true);
  //вывод IMEI при загрузке
  SendCommWhole(TabloAdress,'%23%040011920090164%10$t2$13$60'+imei);
  LogServMess('Dysplay IMEI complete, waiting',true);
  //ждём чтобы можно было прочитать
  sleep(7000);
  //очищаем дисплей и выводим стандартный текст
  LogServMess('Clearing display',true);
  SendCommWhole(TabloAdress,'%35');
  //ещё ждём перед началом работы
  sleep(2000);

  //ждём рандомное кол-во секунд от 1 до 60 для уменьшения нагрузки на сервер
  randomize;
  i:=random(60000);
  LogServMess('Waiting '+inttostr(i)+' msec before starting',true);
  sleep(i);

  //открытие соединений
  LogServMess('Opening clients',true);
  //LogServMess('Opening connection to '+Tablo_service.Client.Host+':'+inttostr(Tablo_service.Client.Port),true);
  //Tablo_service.Client.Open;


  if enable_monitor=true then
  begin
    LogServMess('Opening connection to monitor server on '+Tablo_service.ClientMonitor.Host+':'+inttostr(Tablo_service.ClientMonitor.Port),true);
    Tablo_service.ClientMonitor.Open;
  end
  else
    LogServMess('Monitor server connection is disabled, skipping initializing connection',true);

  sleep(4000);


  LogServMess('Thread cycle enter',true);
  while not(Terminated) do
  begin
    //проверка на ошибки
    if (exception_count>100)and(s_reboot=false) then
    begin
      LogServMess('Too many errors, rebooting the system',true);
      SysReboot;
      s_reboot:=true;
    end;

    try
    if paused=false then  //основное условие работы - режим паузы
    begin
      {if event_occured>0 then
      begin
        //LogServMess('Entering waiting for event ending',true);
        sleep(200);
        continue;
      end;  }

      if (gettickcount>time_work+100) then  //работа каждые 0.1c
      begin
        inc(i);
        //LogServMess('Thread event #'+inttostr(i),true);
        //SendCommStr(TabloAdress,'%040010300010084%10$t3$10$60'+inttostr(i));

        //обработка полученных пакетов
        WorkInfo;
        WorkMonitor;

        //работа протокола связи с сервером информации
        DataProtocol.Work;

        //режим регистрации
        {if (registration=true) then
        begin
          //LogServMess('Entering registration mode',true);
          if sended_register=false then
          begin
            //if CheckEvent('registration mode') then continue;

            LogServMess('Entering registration mode',true);
            if Tablo_service.Client.Socket.Connected=true then
            begin
              LogServMess('Sending register packet',true);
              Tablo_service.Client.Socket.SendText(register_message);
            end
            else
            begin
              LogServMess('Cant send register packet, socket is closed',true);
            end;
            sended_register:=true;
            register_time:=gettickcount;
            time_work:=register_time;
            //continue;
          end
          else
          begin
            //if CheckEvent('waiting for registration answer') then continue;

            if (gettickcount>register_time+10000) then
            begin
              LogServMess('Entering registration mode',true);
              LogServMess('Too long for registration answer, creating reconnect event',true);
              Tablo_service.Client.Close;
              sleep(1000);
              working:=false;
              registration:=true;
              sended_register:=false;
              Tablo_service.Client.Open;
              time_work:=gettickcount+5000;
              receive_time:=time_work;
              register_time:=time_work;
              //continue;
            end;
          end;
        end;

        //LogServMess('Between register and working----------------------',true);

        //режим нормальной работы
        if (working=true) then
        begin
          //LogServMess('Entering working mode',true);
          //if CheckEvent('working mode') then continue;

          if (Tablo_service.Client.Active=false)or(error_event=true)or(gettickcount>receive_time+180000) then
          begin
            //if CheckEvent('reconnect section') then continue;

            LogServMess('Entered reconnect section, reconnect reason:',true);
            if Tablo_service.Client.Active=false then LogServMess('Client connection is not active',false);
            if error_event=true then LogServMess('Error event occured',false);
            if gettickcount>receive_time+180000 then LogServMess('Client didn''t received command for too long',false);

            Tablo_service.Client.Close;
            sleep(1000);
            working:=false;
            registration:=true;
            sended_register:=false;
            Tablo_service.Client.Open;
            time_work:=gettickcount+10000;
            receive_time:=time_work;
            register_time:=time_work;
            error_event:=false;
            //continue;
          end;
        end;
              }
        //LogServMess('Before monitor register-------------',true);

        if (enable_monitor=true) then
        begin
          //режим регистрации для сервера мониторинга
          if registration_monitor=true then
          begin  //если режим регистрации
            if sended_register_monitor=false then
            begin  //если ещё не посылали регистрацию
              //if CheckEvent('registration mode for monitor server') then continue;

              LogServMess('Entering registration mode for monitor server in execute of thread',true);
              if Tablo_service.ClientMonitor.Socket.Connected=true then
              begin
                LogServMess('Sending register packet for monitor server in execute of thread',true);
                Tablo_service.ClientMonitor.Socket.SendBuf(register_buf[0],length(register_buf));

                //sended_register_monitor:=true;
                //registration_monitor_time:=gettickcount;
              end
              else
                LogServMess('Cant send register packet for monitor server, socket is closed',true);

              sended_register_monitor:=true;
              registration_monitor_time:=gettickcount;
              //continue;
            end
            else
            begin  //если уже посылали регистрацию, проверяем на ответ
              //if CheckEvent('waiting for registration answer for monitor server') then continue;

              if (gettickcount>registration_monitor_time+10000+registration_monitor_extra_delay) then
              begin
                LogServMess('Entering registration mode for monitor server',true);
                LogServMess('Too long for registration answer for monitor server, creating reconnect event',true);
                Tablo_service.ClientMonitor.Close;
                sleep(1000);
                registration_monitor:=true;
                sended_register_monitor:=false;
                registration_monitor_time:=gettickcount;
                time_work:=gettickcount+5000;
                Tablo_service.ClientMonitor.Open;
                //continue;
              end;
            end;
          end
          else
          begin  //режим работы
            //LogServMess('Entering work mode for monitor server',true);
            //if CheckEvent('working mode for registration server') then continue;

            //проверка на ошибки
            if (Tablo_service.ClientMonitor.Active=false)or(error_event_monitor=true) then
            begin
              //if CheckEvent('reconnect section for monitor server') then continue;

              LogServMess('Entered reconnect section for monitor server, reconnect reason:',true);
              if Tablo_service.ClientMonitor.Active=false then LogServMess('Client connection is not active',false);
              if error_event_monitor=true then LogServMess('Error event occured',false);

              Tablo_service.ClientMonitor.Close;
              sleep(1000);
              registration_monitor:=true;
              sended_register_monitor:=false;
              Tablo_service.ClientMonitor.Open;
              time_work:=gettickcount+5000;
              registration_monitor_time:=time_work;
              error_event_monitor:=false;
            end;

            //проверка на посылку эхо-пакета
            if Gettickcount>echo_time+echo_interval then
            begin
              //if CheckEvent('sending echo-packet for monitor server') then continue;

              LogServMess('Sending echo-packet for monitor server',true);
              Tablo_service.ClientMonitor.Socket.SendBuf(echo_buf[0],length(echo_buf));
              echo_time:=time_work;

              //SendMonitorMessage('TestEcho',1,5,IncSecond(now,-15));
            end;

            //проверка на посылку пакета синхронизации
            if Gettickcount>synch_time+synch_interval then
            begin
              //if CheckEvent('sending synchronization packet for monitor server') then continue;

              LogServMess('Sending synchronization packet for monitor server',true);
              Tablo_service.ClientMonitor.Socket.SendBuf(synch_buf[0],length(synch_buf));
              synch_time:=time_work;
            end;

            //проверка на посылку пакета обновления
            if enable_update=true then
            begin
              if Gettickcount>update_time+update_interval then
              begin
                if sended_update_packet=true then
                begin
                  //таймер на отсылку ответов
                  if Gettickcount>update_time_keep_alive+update_time_keep_alive_interval then
                  begin
                    Check_update_completion;
                  end;

                  //таймер на таймаут
                  if gettickcount>update_time_timeout+update_time_timeout_interval then
                  begin
                    //отсылаем пакет ошибки ответа
                    update_answer_buf[7]:=$FF;
                    if Tablo_service.UpdateClient.Socket.Connected then
                      Tablo_service.UpdateClient.Socket.SendBuf(update_answer_buf[0],length(update_answer_buf));

                    update_time:=time_work;
                    sended_update_packet:=false;
                    update_transfer_in_progress:=false;
                  end;
                end  //if sended_update_packet=true then
                else
                begin
                  LogServMess('Sending update packet for monitor server',true);
                  Tablo_service.ClientMonitor.Socket.SendBuf(update_buf[0],length(update_buf));
                  //update_time:=time_work;
                  update_time_keep_alive:=time_work;
                  update_time_timeout:=time_work;
                  sended_update_packet:=true;
                  update_transfer_in_progress:=true;
                  update_receive_size:=1000;
                end;  //else if sended_update_packet=true then
              end;  //if Gettickcount>update_time+update_interval then
            end;  //if enabpe_update=true then

            //проверка на посылку пакета обновления настроек
            if enable_update_settings=true then
            begin
              if Gettickcount>update_settings_time+update_settings_interval then
              begin
                if sended_update_settings_packet=true then
                begin
                  //таймер на отсылку ответов
                  if Gettickcount>update_settings_time_keep_alive+update_settings_time_keep_alive_interval then
                  begin
                    //Check_update_completion;
                    Check_update_settings_completion;
                  end;

                  //таймер на таймаут
                  if gettickcount>update_settings_time_timeout+update_settings_time_timeout_interval then
                  begin
                    //отсылаем пакет ошибки ответа
                    update_answer_buf[7]:=$FF;
                    if Tablo_service.UpdateClient.Socket.Connected then
                      Tablo_service.UpdateClient.Socket.SendBuf(update_answer_buf[0],length(update_answer_buf));

                    update_settings_time:=time_work;
                    sended_update_settings_packet:=false;
                    update_transfer_in_progress:=false;
                    enable_update_settings:=false;
                    LogServMess('Answer timeout for update settings, disabling update');
                  end;
                end  //if sended_update_packet=true then
                else
                begin
                  LogServMess('Sending update settings packet for monitor server',true);
                  Tablo_service.ClientMonitor.Socket.SendBuf(update_settings_buf[0],length(update_settings_buf));
                  //update_time:=time_work;
                  update_settings_time_keep_alive:=time_work;
                  update_settings_time_timeout:=time_work;
                  sended_update_settings_packet:=true;
                  update_settings_transfer_in_progress:=true;
                  update_settings_receive_size:=1000;
                end;  //else if sended_update_packet=true then
              end;  //if Gettickcount>update_time+update_interval then
            end;  //if enabpe_update=true then

            //проверка на посылку лога
            if enable_backup_log=true then
            begin
              if Gettickcount>backup_log_time+backup_log_interval then
              begin   //если время вышло, то проверяем статус
                if sended_backup_packet=true then
                begin
                  //если мы посылали пакет инициализации и не получили ответ вовремя, то пробуем снова
                  LogServMess('Timeout when awaiting for responce on backup initialization packet in monitor server, flagging to send again',true);
                  sended_backup_packet:=false;
                end
                else
                begin  //мы ещё не посылали пакет инициализации бекапа
                  LogServMess('Sending backup initialization packet for monitor server',true);
                  Tablo_service.ClientMonitor.Socket.SendBuf(backup_log_packet[0],length(backup_log_packet));
                  sended_backup_packet:=true;
                  backup_log_time:=time_work;
                end;
              end;  //if Gettickcount>backup_log_time+backup_log_interval then
            end;  //if enable_backup_log=true then   

          end;
        end;

        //if CheckEvent('before FTP copy time') then continue;

        LogFileCopy;

        time_work:=gettickcount;
      end;  //if (gettickcount>time_work+1000) then
    end;  //if paused=false then

    //перехват и передача сообщений для дочерних потоков
    if PeekMessage(Msg, 0, 0, 0, PM_REMOVE) then
    begin
      TranslateMessage(Msg);
      DispatchMessage(Msg);
    end;

    except
      on e:exception do
      begin
        LogServMess('WARNING! Exception occured in main thread, message='+e.Message,true);
        inc(exception_count);
        sleep(1000);
        continue;
      end;
    end;

    {if event_occured<0 then
    begin
      LogServMess('WARNING!WARNING!WARNING!  Event_occured variable='+inttostr(event_occured)+', returning to normal',true);
      event_occured:=0;
    end;  }

    sleep(10);
  end;
  LogServMess('Thread Execution exit',true);
end;

//-------------------END OF THREAD IMPLEMENTATION---------------------------------


procedure TTablo_service.CommReceiveData(Buffer: Pointer;
  BufferLength: Word);
var str:string;
begin
  str:=PChar(Buffer);

  comm_answer:=comm_answer+str;
end;

procedure TTablo_service.ClientMonitorConnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('MonitorSocket OnConnect event',true);
end;

procedure TTablo_service.ClientMonitorConnecting(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('MonitorSocket OnConnecting event',true);
end;

procedure TTablo_service.ClientMonitorDisconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('MonitorSocket OnDisconnect event',true);

  monitor_socketID:=-1;
end;

procedure TTablo_service.ClientMonitorError(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
  var ErrorCode: Integer);
begin
  LogServMess('MonitorSocket OnError event, ord='+inttostr(ord(ErrorEvent)),true);

  case ErrorEvent of
    eeGeneral:LogServMess('General event error',false);
    eeSend:LogServMess('Send event error',false);
    eeReceive:LogServMess('Receive event error',false);
    eeConnect:LogServMess('Connect event error',false);
    eeDisconnect:LogServMess('Disconnect event error',false);
    eeAccept:LogServMess('Accept event error',false);
    eeLookup:LogServMess('Lookup event error',false);
  end;

  error_event_monitor:=true;

  Socket.Disconnect(Socket.SocketHandle);

  ErrorCode:=0;
end;

procedure TTablo_service.ClientMonitorLookup(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('MonitorSocket OnLookup event',true);
end;

procedure TTablo_service.ClientMonitorRead(Sender: TObject;
  Socket: TCustomWinSocket);
var i,j:integer;
//tick:cardinal;
buf:array of byte;
//time,time_now:TDateTime;
//pdouble:^double;
//sys_time:TSYSTEMTIME;
begin
  LogServMess('MonitorSocket OnRead event',true);
  //WorkThread.Suspend;
  //inc(event_occured);
  i:=socket.ReceiveLength;
  setlength(buf,i);
  socket.ReceiveBuf(buf[0],i);

  LogServMess('MonitorSocket OnRead received bytes:'+inttostr(i),true);

  j:=length(monitor_input);
  setlength(monitor_input,j+1);
  setlength(monitor_input[j],i);
  move(buf[0],monitor_input[j][0],i);
  setlength(buf,0);

  LogServMess('Packet received sucsessfuly, end of Monitor OnRead',true);

  (*
  for j:=0 to length(buf)-1 do
    LogServMess('#'+inttostr(j)+'='+inttostr(buf[j]),false);

  //проверяем на правильность пакета======================
  //проверка на минимальную длунну пакета
  if length(buf)<7 then
  begin
    LogServMess('Error in OnRead event: packet is too small',true);
    //WorkThread.Resume;
    //dec(event_occured);
    exit;
  end;

  //проверка на первый символ и длинну пакета в заголовке
  i:=buf[0];
  j:=(buf[1] shl 24)or(buf[2] shl 16)or(buf[3] shl 8)or(buf[4]);
  if (i<>158)or(j<>(length(buf)-5)) then
  begin
    LogServMess('Error in OnRead event: wrong packet format',true);
    //WorkThread.Resume;
    //dec(event_occured);
    exit;
  end;

  //проверяем на ответ от сервера об успешной регистрации, если мы ещё не зарегистрированы
  if registration_monitor=true then
  begin //если всё ещё режим регистрации, то смотрим только на пакет успешной регистрации, остальное игнор
    i:=(buf[5] shl 8)or(buf[6]);
    if i=$0005 then
    begin
      //проверяем правильность пакета
      if j=6 then
      begin
        //читаем ID сокета, который был присвоен данному клиенту
        k:=(buf[7] shl 24)or(buf[8] shl 16)or(buf[9] shl 8)or(buf[10]);
        monitor_socketID:=k;
        //переключаемся на обычный режим работы
        registration_monitor:=false;
        error_event_monitor:=false;
        LogServMess('Reseived conformation registration with SockID='+inttostr(monitor_socketID),true);
        //редактируем время эхо-таймера
        tick:=gettickcount;
        if tick<(echo_interval-5000) then echo_time:=0
        else echo_time:=tick-(echo_interval-5000);
        {if echo_time<echo_interval then echo_time:=0
        else echo_time:=echo_time-echo_interval;  }
        //WorkThread.Resume;
        //dec(event_occured);
        exit;
      end;
    end;
  end
  else
  begin  //если обычный режим работы
    //выделяем тип пакета
    i:=(buf[5] shl 8)or(buf[6]);

    case i of
      6:begin  //пакет синхронизации времени
          //проверяем правильность длинны пакета
          if length(buf)=15 then
          begin
            //читаем время
            pdouble:=@buf[7];
            time:=pdouble^;

            LogServMess('Reseived synchronization packet with TimeDate='+FormatDateTime('dd-mm-yyyy hh:nn:ss.zzz',time),true);

            //проверяем, насколько отличается время
            time_now:=now;
            j:=SecondsBetween(time_now,time);
            if j<600 then
            begin  //если время в пределах 10 минут, то синхронизируемся
              LogServMess('Time is good, synchronizing',true);

              sys_time.wYear:=YearOf(time);
              sys_time.wMonth:=MonthOf(time);
              sys_time.wDay:=DayOf(time);
              sys_time.wHour:=HourOf(time);
              sys_time.wMinute:=MinuteOf(time);
              sys_time.wSecond:=SecondOf(time);
              sys_time.wMilliseconds:=MillisecondOf(time);

              SetLocalTime(sys_time);

              LogServMess('Synchronization complete',true);
            end
            else
              LogServMess('WARNING! Local time is too different from a server time, aborting synchronization',true);
          end;
        end;
    end;
  end;  *)

  //WorkThread.Resume;
  //dec(event_occured);
end;

procedure WorkInfo;
var i,j,k,z:integer;
buf:array of array of byte;
buf2:array of byte;
begin
  //LogServMess('Working on info packets enter',true);

  j:=length(info_input);

  //переписываем из общего буфера в локальный и заодно очищаем общий буфер
  if j>0 then
  begin
    setlength(buf,j);
    for i:=0 to j-1 do
    begin
      setlength(buf[i],length(info_input[i]));
      move(info_input[i][0],buf[i][0],length(info_input[i]));
      setlength(info_input[i],0);
    end;

    setlength(info_input,0);
  end;

  j:=length(buf);

  if j>0 then
  begin
    LogServMess('Working on info packets, packet count='+inttostr(j),true);

    for i:=0 to j-1 do
    begin
      LogServMess('Working on info packets, packet number '+inttostr(i+1),true);

      //ищем и делаем замену
      setlength(buf2,length(buf[i]));
      move(buf[i][0],buf2[0],length(buf[i]));
      setlength(buf[i],0);

      k:=0;
      while k<=length(buf2)-2 do
      begin
        z:=length(buf[i]);
        setlength(buf[i],z+1);
        if buf2[k]=$AA then
        begin
          if buf2[k+1]=$05 then buf[i][z]:=$A5
          else if buf2[k+1]=$0E then buf[i][z]:=$AE
          else buf[i][z]:=$AA;
          inc(k);
        end
        else buf[i][z]:=buf2[k];
        inc(k);
      end;

      z:=length(buf[i]);
      setlength(buf[i],z+1);
      buf[i][z]:=buf2[k];

      setlength(buf2,0);
      k:=length(buf[i]);

      //проверка на наличие символа начала
      if buf[i][0]<>$A5 then
      begin
        LogServMess('Wrong starting symbol:'+inttostr(buf[i][0])+', ignoring',true);
        continue;
      end;
      //проверка длинны пакета
      z:=(buf[i][1] and $FF)or((buf[i][2] and $FF)shl 8);
      if z<>(k-6) then
      begin
        LogServMess('Wrong packet length:'+inttostr(z)+', must be:'+inttostr(k-6)+', sending error #3',true);
        DataProtocol.SendSimpleAnswer(buf[i][3],3);
        for z:=0 to length(buf[i])-1 do
          LogServMess('#'+inttostr(z)+'='+inttostr(buf[i][z]),false);
        continue;
      end;

      {receive_time:=gettickcount;
      if registration=true then
      begin
        registration:=false;
        working:=true;
        error_event:=false;
        //очищаем табло и шлём туда время с компьютера
        //SendCommWhole(TabloAdress,'%23');
        Initialize_tablo(true);
      end;     }
      k:=buf[i][3];

      LogServMess('Received packet type #'+inttostr(k),true);

      case k of
        0:; //перезагрузка табло
        1:begin //загрузка прогнозов
            LogServMess('Prognozi (#1)',true);
            z:=PrognozWork(buf[i]);
            if z=0 then DataProtocol.SendSimpleAnswer(1,0)
            else if z=3 then DataProtocol.SendSimpleAnswer(1,5);
            LogServMess('Prognoz work returned:'+inttostr(z),true);
          end;
        2:begin //установка параметров табло
            LogServMess('Ustanovka parametrov (#2)',true);
            //очищаем табло и шлём туда время с компьютера
            Initialize_tablo(true);

            DataProtocol.SendSimpleAnswer(2,0);
            DataProtocol.FlagRegisterResponce;
          end;
        3:; //запрос параметров табло
        4:; //запрос конфигурации табло
        5:begin //установка времени и даты
            LogServMess('Ustanovka vremeni i dati (#5)',true);
            if length(buf[i])<11 then
              LogServMess('Wrong packet size, packet is too small for this type (#5), size='+inttostr(length(buf[i])),true)
            else
            begin
              error_index:=0;
              z:=SetDateTimeWork(buf[i]);
              case z of
                0:DataProtocol.SendSimpleAnswer(5,0);
                1:DataProtocol.SendError4Answer(5,4,error_index);
                3:DataProtocol.SendSimpleAnswer(5,5);
              end;

              LogServMess('SetDateTime work returned:'+inttostr(z),true);
            end;
          end;
        6:; //запрос времени и даты
        7:begin //установка температуры
            LogServMess('Ustanovka temperaturi (#7)',true);
            if length(buf[i])<6 then
              LogServMess('Wrong packet size, packet is too small for this type (#7), size='+inttostr(length(buf[i])),true)
            else
            begin
              error_index:=0;
              z:=SetTemperatureWork(buf[i]);
              if z=0 then DataProtocol.SendSimpleAnswer(7,0)
              else if z=1 then DataProtocol.SendError4Answer(7,4,0)
              else DataProtocol.SendSimpleAnswer(7,5);
              LogServMess('SetTemperature work returned:'+inttostr(z),true);
            end;
          end;
        8:; //запрос температуры
        9:; //запуск программы
        10:; //включение, выключение светодиодов табло
        11:begin //запрос статуса
           end
        else
        begin
          LogServMess('Unknown packet type:'+inttostr(k)+', ignoring',true);
        end;
      end;  //case
      DataProtocol.FlagPacketResponce;
    end;  //for i:=0 to j-1 do

    for i:=0 to length(buf)-1 do
      setlength(buf[i],0);
    setlength(buf,0);
    setlength(buf2,0);
  end;  //if j>0 then
end;

procedure WorkMonitor;
var buf:array of array of byte;
i,j,k,z,z2,z3,z4,z5:integer;
time,time_now:TDateTime;
pdouble:^double;
sys_time:TSYSTEMTIME;
tick:cardinal;
str:string;
begin
  //LogServMess('Working on monitor packets enter',true);

  j:=length(monitor_input);

  //переписываем из общего буфера в локальный и заодно очищаем общий буфер
  if j>0 then
  begin
    setlength(buf,j);
    for i:=0 to j-1 do
    begin
      setlength(buf[i],length(monitor_input[i]));
      move(monitor_input[i][0],buf[i][0],length(monitor_input[i]));
      setlength(monitor_input[i],0);
    end;

    setlength(monitor_input,0);
  end;

  j:=length(buf);

  if j>0 then
  begin
    LogServMess('Working on monitor packets, packet count='+inttostr(j),true);

    for i:=0 to j-1 do
    begin
      LogServMess('Working on monitor packets, packet number '+inttostr(i+1),true);

      for k:=0 to length(buf[i])-1 do
        LogServMess('#'+inttostr(k)+'='+inttostr(buf[i][k]),false);

      //проверяем на правильность пакета======================
      //проверка на минимальную длунну пакета
      if length(buf[i])<7 then
      begin
        LogServMess('Error in WorkMonitor: packet is too small',true);
        continue;
      end;

      //проверка на первый символ и длинну пакета в заголовке
      k:=buf[i][0];
      z:=(buf[i][1] shl 24)or(buf[i][2] shl 16)or(buf[i][3] shl 8)or(buf[i][4]);
      if (k<>158)or(z<>(length(buf[i])-5)) then
      begin
        LogServMess('Error in WorkMonitor: wrong packet format',true);
        continue;
      end;

      //проверяем на ответ от сервера об успешной регистрации, если мы ещё не зарегистрированы
      if registration_monitor=true then
      begin //если всё ещё режим регистрации, то смотрим только на пакет успешной регистрации, остальное игнор
        k:=(buf[i][5] shl 8)or(buf[i][6]);
        if k=$0005 then
        begin
          //проверяем правильность пакета (длинна пакета)
          if z=6 then
          begin
            //читаем ID сокета, который был присвоен данному клиенту
            k:=(buf[i][7] shl 24)or(buf[i][8] shl 16)or(buf[i][9] shl 8)or(buf[i][10]);
            monitor_socketID:=k;
            //переключаемся на обычный режим работы
            registration_monitor:=false;
            error_event_monitor:=false;
            LogServMess('Reseived conformation registration with SockID='+inttostr(monitor_socketID),true);
            //редактируем время эхо-таймера
            tick:=gettickcount;
            if tick<(echo_interval-5000) then echo_time:=0
            else echo_time:=tick-(echo_interval-5000);
            //редактируем время дополнительной задержки на переподключение
            registration_monitor_extra_delay:=0;
            continue;
          end; //if z=6 then
        end; //if k=$0005 then
      end
      else
      begin  //если обычный режим работы
        //выделяем тип пакета
        k:=(buf[i][5] shl 8)or(buf[i][6]);

        case k of
          4:begin  //пакет ответа
              //проверяем правильность длинны пакета
              if length(buf[i])>=12 then
              begin
                //читаем сокет назначения
                z:=(buf[i][8] shl 24)or(buf[i][9] shl 16)or(buf[i][10] shl 8)or(buf[i][11]);

                LogServMess('Received answer packet with type='+inttostr(buf[i][7])+', SocketID='+inttostr(z),true);

                //if (z=monitor_socketID)and(enable_backup_log=true) then
                if (z=monitor_socketID)and((update_transfer_in_progress=true)or(log_backup_transfer_in_progress=true)or(update_settings_transfer_in_progress=true)) then
                begin
                  LogServMess('SocketID matches in answer pakcet, working',true);

                  case buf[i][7] of
                    $FD:begin  //пакет поддержания связи
                          LogServMess('  KeepAlive answer packet received',true);
                          backup_log_time:=gettickcount;
                        end;
                    $FE:begin  //пакет окончания ответа
                          LogServMess('  End of answer packet received',true);
                          if enable_backup_log=true then
                          begin
                            LogFileFinalize;
                            enable_backup_log:=false;
                            sended_backup_buffer:=false;
                            sended_backup_packet:=false;
                            log_backup_transfer_in_progress:=false;

                          end;
                        end;
                    $FF:begin  //пакет ошибки ответа
                          LogServMess('  Error in answer packet received',true);
                          if enable_backup_log=true then
                          begin
                            sended_backup_buffer:=false;
                            sended_backup_packet:=false;
                            //log_backup_transfer_in_progress:=false;
                            //формируем всё заново
                            CreateBackupBuffers;
                          end;
                        end;
                  end;
                end else LogServMess('WARNING! SocketID mismatch in answer packet, ignoring',true);
              end;
            end;
          6:begin  //пакет синхронизации времени
              //проверяем правильность длинны пакета
              if length(buf[i])=15 then
              begin
                //читаем время
                pdouble:=@buf[i][7];
                time:=pdouble^;

                LogServMess('Reseived synchronization packet with TimeDate='+FormatDateTime('dd-mm-yyyy hh:nn:ss.zzz',time),true);

                //проверяем, насколько отличается время
                time_now:=now;
                z:=MilliSecondsBetween(time_now,time);
                {if z<600 then
                begin  //если время в пределах 10 минут, то синхронизируемся   }
                  LogServMess('Time is good, synchronizing, time difference='+inttostr(z)+' msec.',true);

                  sys_time.wYear:=YearOf(time);
                  sys_time.wMonth:=MonthOf(time);
                  sys_time.wDay:=DayOf(time);
                  sys_time.wHour:=HourOf(time);
                  sys_time.wMinute:=MinuteOf(time);
                  sys_time.wSecond:=SecondOf(time);
                  sys_time.wMilliseconds:=MillisecondOf(time);

                  SetLocalTime(sys_time);

                  LogServMess('Synchronization complete',true);
                {end
                else
                  LogServMess('WARNING! Local time is too different from a server time, aborting synchronization',true);}
              end;
            end;
          7:begin   //пакет ответа на инициализацию бекапа
              //проверяем правильность длинны пакета
              if length(buf[i])=11 then
              begin
                //читаем порт
                z:=(buf[i][7] shl 24)or(buf[i][8] shl 16)or(buf[i][9] shl 8)or(buf[i][10]);

                LogServMess('Reseived backup initialization with port='+inttostr(z),true);

                if enable_backup_log=true then
                begin
                  LogServMess('Opening connection to backup server',true);
                  //открывем соединение по порту и выставляем флаги
                  Tablo_service.BackupClient.Close;
                  Tablo_service.BackupClient.Port:=z;
                  Tablo_service.BackupClient.Open;
                  backup_log_time:=gettickcount;
                end
                else LogServMess('WARNING! Service is not in backup state!',true);
              end;
            end;
          8:begin  //пакет выключения сервера
              //проверяем длинну пакета
              if length(buf[i])=11 then
              begin
                LogServMess('Received server shutdown packet, adding reconnect time delay');

                //редактируем время на переподключение
                registration_monitor_extra_delay:=180000;   
              end
              else
                LogServMess('WARNING! Wrong packet length for packet type=0008h');
            end;
          9:begin  //пакет ответа на пакет обновления
              //проверяем длинну пакета
              if length(buf[i])=28 then
              begin
                //читаем порт
                z:=(buf[i][7] shl 24)or(buf[i][8] shl 16)or(buf[i][9] shl 8)or(buf[i][10]);
                //читаем флаг готовности
                z2:=buf[i][11];
                //читаем версию
                str:=inttostr(buf[i][12])+'.'+inttostr(buf[i][13])+'.'+inttostr(buf[i][14])+'.'+inttostr(buf[i][15]);
                //читаем размер файла
                z3:=(buf[i][16] shl 24)or(buf[i][17] shl 16)or(buf[i][18] shl 8)or(buf[i][19]);
                //читаем контрольную сумму
                z4:=(buf[i][20] shl 24)or(buf[i][21] shl 16)or(buf[i][22] shl 8)or(buf[i][23]);
                //читаем таймаут
                z5:=(buf[i][24] shl 24)or(buf[i][25] shl 16)or(buf[i][26] shl 8)or(buf[i][27]);

                LogServMess('Received update initialization with Port='+inttostr(z)+'  ReadyFlag='+inttostr(z2)+'  Version='+str+'  Size='+inttostr(z3)+'  CRC32='+inttohex(z4,8)+'  Timeout='+inttostr(z5));

                //записываем параметры
                if z2=0 then
                begin  //апдейт не нужен, ждм дальше
                  LogServMess('Update isn''t needed, skiping');
                  update_time:=gettickcount;
                  sended_update_packet:=false;
                  update_transfer_in_progress:=false;
                end
                else
                begin  //апдейт нужен
                  LogServMess('Update needed, saving parameters');
                  //порт
                  if Tablo_service.UpdateClient.Socket.Connected then Tablo_service.UpdateClient.Close;
                  Tablo_service.UpdateClient.Port:=z;
                  //версия
                  update_receive_version:=str;
                  //размер
                  update_receive_size:=z3;
                  //CRC
                  update_receive_crc:=z4;
                  //timeout
                  update_time_timeout_interval:=z5;

                  setlength(update_receive_buf,0);
                  update_counter:=0;

                  LogServMess('Opening connection to '+Tablo_service.UpdateClient.Host+':'+inttostr(Tablo_service.UpdateClient.Port));
                  Tablo_service.UpdateClient.Open;
                end;
              end
              else
                LogServMess('WARNING! Wrong packet length for packet type=0009h');
            end;
          11:begin  //пакет ответа на пакет обновления настроек
               //проверяем длинну пакета
               if length(buf[i])=24 then
               begin
                 //читаем порт
                 z:=(buf[i][7] shl 24)or(buf[i][8] shl 16)or(buf[i][9] shl 8)or(buf[i][10]);
                 //читаем флаг готовности
                 z2:=buf[i][11];
                 //читаем размер файла
                 z3:=(buf[i][12] shl 24)or(buf[i][13] shl 16)or(buf[i][14] shl 8)or(buf[i][15]);
                 //читаем контрольную сумму
                 z4:=(buf[i][16] shl 24)or(buf[i][17] shl 16)or(buf[i][18] shl 8)or(buf[i][19]);
                 //читаем таймаут
                 z5:=(buf[i][20] shl 24)or(buf[i][21] shl 16)or(buf[i][22] shl 8)or(buf[i][23]);

                 LogServMess('Received settings update initialization with Port='+inttostr(z)+'  ReadyFlag='+inttostr(z2)+'  Size='+inttostr(z3)+'  CRC32='+inttohex(z4,8)+'  Timeout='+inttostr(z5));

                 //записываем параметры
                 if z2=0 then
                 begin  //апдейт не нужен, ждм дальше
                   LogServMess('Settings update isn''t needed, skiping and disabling settings update');
                   update_settings_time:=gettickcount;
                   sended_update_settings_packet:=false;
                   update_settings_transfer_in_progress:=false;
                   enable_update_settings:=false;
                 end
                 else
                 begin  //апдейт нужен
                   LogServMess('Settings update needed, saving parameters');
                   //порт
                   if Tablo_service.UpdateClient.Socket.Connected then Tablo_service.UpdateClient.Close;
                   Tablo_service.UpdateClient.Port:=z;
                   //размер
                   update_settings_receive_size:=z3;
                   //CRC
                   update_settings_receive_crc:=z4;
                   //timeout
                   update_settings_time_timeout_interval:=z5;

                   setlength(update_receive_buf,0);
                   update_counter:=0;

                   LogServMess('Opening connection to '+Tablo_service.UpdateClient.Host+':'+inttostr(Tablo_service.UpdateClient.Port));
                   Tablo_service.UpdateClient.Open;
                 end;
               end
               else
                 LogServMess('WARNING! Wrong packet length for packet type=000Bh');
             end;
        end;  //case k of
      end;  //if registration_monitor=true then

    end;  //for i:=0 to j-1 do
  end;  //if j>0 then
end;

procedure TTablo_service.ClientMonitorWrite(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('MonitorSocket OnWrite event',true);

  LogServMess('Entering registration mode for monitor server in OnWrite event',true);
  if Socket.Connected=true then
  begin
    LogServMess('Sending register packet for monitor server in OnWrite event',true);
    Socket.SendBuf(register_buf[0],length(register_buf));

    sended_register_monitor:=true;
    registration_monitor_time:=gettickcount;
  end
  else
    LogServMess('Cant send register packet for monitor server, socket is closed',true);  
end;

procedure TTablo_service.ServiceExecute(Sender: TService);
begin
  ServiceThread.ProcessRequests(true);
end;

procedure TTablo_service.BackupClientConnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('BackupSocket OnConnect event',true);
end;

procedure TTablo_service.BackupClientConnecting(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('BackupSocket OnConnecting event',true);
end;

procedure TTablo_service.BackupClientDisconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('BackupSocket OnDisconnect event',true);
end;

procedure TTablo_service.BackupClientError(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
  var ErrorCode: Integer);
begin
  LogServMess('BackupSocket OnError event, ord='+inttostr(ord(ErrorEvent)),true);

  case ErrorEvent of
    eeGeneral:LogServMess('General event error',false);
    eeSend:LogServMess('Send event error',false);
    eeReceive:LogServMess('Receive event error',false);
    eeConnect:LogServMess('Connect event error',false);
    eeDisconnect:LogServMess('Disconnect event error',false);
    eeAccept:LogServMess('Accept event error',false);
    eeLookup:LogServMess('Lookup event error',false);
  end;

  Socket.Disconnect(Socket.SocketHandle);

  ErrorCode:=0;
end;

procedure TTablo_service.BackupClientLookup(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('BackupSocket OnLookup event',true);
end;

procedure TTablo_service.BackupClientRead(Sender: TObject;
  Socket: TCustomWinSocket);
var i:integer;
str:string;
begin
  i:=socket.ReceiveLength;

  LogServMess('BackupSocket OnRead event, count='+inttostr(i),true);

  str:=socket.ReceiveText;
end;

procedure TTablo_service.BackupClientWrite(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('BackupSocket OnWrite event',true);

  if enable_backup_log=true then
  begin
    if sended_backup_packet=true then
    begin
      LogServMess('Sending backup buffer',true);
      backup_log_time:=gettickcount;
      Socket.SendBuf(backup_log_buffer[0],length(backup_log_buffer));
      sended_backup_buffer:=true;    
    end else LogServMess('Error! Sended backup packet is not set',true);
  end else LogServMess('Error! Enable backup log is not set',true);
end;

procedure TTablo_service.RotationTimerTimer(Sender: TObject);
var output_str,str,str1:string;
i,j,row_mult,index:integer;
temp:TProg;
begin
  LogServMess('Rotation Timer OnTimer event',true);

  //todo: дописать возможно более правильно
  //делаем сразу уикл по всем, т.к. мы знаем что строк много

  //сдвигаем вверх с ротацией
  for i:=0 to length(prognozi)-1 do
  begin
    if (i>0)and(i<(length(prognozi)-1)) then  //обычные записи в середине
    begin
      prognozi[i-1]:=prognozi[i];
    end
    else if i=0 then  //начало списка
    begin
      temp:=prognozi[i];
    end
    else  //конец списка
    begin
      prognozi[i-1]:=prognozi[i];
      prognozi[i]:=temp;
    end;
  end;

  //выводим лог
  //for i:=0 to length(prognozi)-1 do
  //  LogServMess('   #'+inttostr(i+1)+'  №'+prognozi[i][1]+'   '+prognozi[i][2]+'    '+prognozi[i][3],false);

  row_mult:=8;
  //настройка скорости прокрутки бегущих строк (выставляем чуть медленнее для строк прогнозов)
  output_str:=output_str+'%74080401060406040201';
  //строки прогноза
  for j:=0 to 3 do
  begin
    str:=inttostr(j*row_mult+9);
    str1:=inttostr(j*row_mult+9+8-1);
    for index:=length(str) to 2 do str:='0'+str;
    for index:=length(str1) to 2 do str1:='0'+str1;

    //маршрут
    output_str:=output_str+'%04'+col1_start+col1_finish+str+str1+'4%10$t3$1'+inttostr(2+1)+'$60'+prognozi[j][1];
    //время до прибытия
    output_str:=output_str+'%04'+col3_start+col3_finish+str+str1+'4%10$t3$1'+inttostr(2+1)+'$60'+prognozi[j][2];
    //конечная
    output_str:=output_str+'%04'+col2_start+col2_finish+str+str1+'4%10$t3$1'+inttostr(2+1)+'$60'+prognozi[j][3];
  end;

  if SendCommWhole(TabloAdress,output_str)=false then
  begin
    //Tablo_service.RotationTimer.Enabled:=false;
  end;
end;

procedure TTablo_service.UpdateClientConnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('UpdateSocket OnConnect event');
end;

procedure TTablo_service.UpdateClientConnecting(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('UpdateSocket OnConnecting event');
end;

procedure TTablo_service.UpdateClientDisconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('UpdateSocket OnDisconnect event');
end;

procedure TTablo_service.UpdateClientError(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
  var ErrorCode: Integer);
begin
  LogServMess('UpdateSocket OnError event, ErrorEvent='+inttostr(ord(ErrorEvent))+', ErrorCode='+inttostr(ErrorCode));

  socket.Close;

  ErrorCode:=0;
end;

procedure TTablo_service.UpdateClientLookup(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('UpdateSocket OnLookup event');
end;

procedure TTablo_service.UpdateClientRead(Sender: TObject;
  Socket: TCustomWinSocket);
var i,j:integer;
pint:^integer;
begin
  //str:=socket.ReceiveText;
  i:=socket.ReceiveBuf(update_receive_temp_buf[0],8192);

  LogServMess('UpdateSocket OnRead event, size='+inttostr(i));

  update_counter:=update_counter+i;

  //обновляем время
  update_time_timeout:=gettickcount;

  //переписываем буфер
  j:=length(update_receive_buf);
  setlength(update_receive_buf,j+i);
  move(update_receive_temp_buf[0],update_receive_buf[j],i);
end;

procedure TTablo_service.UpdateClientWrite(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  LogServMess('UpdateSocket OnWrite event');
end;

procedure Check_update_completion;
var pint:^integer;
i,j:integer;
f:file;
str,str_curr:string;
begin
  //отправляем ответ
  LogServMess('CheckingUpdateCompletion enter');
  update_time_keep_alive:=gettickcount;

  if Tablo_service.UpdateClient.Socket.Connected=false then
  begin
    LogServMess('  UpdateClient not connected, skipping responce');
    exit;
  end;

  pint:=@update_answer_buf[8];
  pint^:=update_receive_size-update_counter;  //отправляем сколько осталось передать
  if update_counter>update_receive_size then
  begin  //получили больше, отправляем ошибку
    LogServMess('  Sendind error responce');
    update_answer_buf[7]:=$FF;
    if Tablo_service.UpdateClient.Socket.Connected then Tablo_service.UpdateClient.Socket.SendBuf(update_answer_buf[0],length(update_answer_buf));

    update_time:=gettickcount;
    sended_update_packet:=false;
    update_transfer_in_progress:=false;
  end
  else if update_counter<update_receive_size then
  begin  //получили меньше, отправляем нормальный ответ
    LogServMess('  Sendind keep-alive responce');
    update_answer_buf[7]:=$FD;
    if Tablo_service.UpdateClient.Socket.Connected then Tablo_service.UpdateClient.Socket.SendBuf(update_answer_buf[0],length(update_answer_buf));
  end
  else
  begin  //получили ровно, отправляем ответ окончания
    //проверка длинны и контрольной суммы
    i:=length(update_receive_buf);
    j:=ZCRC32(0,update_receive_buf[0],length(update_receive_buf));
    LogServMess('Received size='+inttostr(i)+'  CRC32='+inttohex(j,8));

    //формируем путь к временному файлу
    str_curr:=GetModuleFileNameStr(0);
    str:=ChangeFileExt(str_curr, '.bak');
    LogServMess('Temp file path='+str);

    //создаём файл
    assignfile(f,str);
    rewrite(f,1);
    blockwrite(f,update_receive_buf[0],length(update_receive_buf));
    closefile(f);

    //делаем команду на замену и перезагружаем комп
    if BootReplaceFile(str,str_curr)=true then
    begin
      LogServMess('Replace after reboot complete sucsessfuly, executing commit');

      SystemCommit;

      LogServMess('Executed commit, rebooting');

      SysReboot;
    end;

    update_time:=gettickcount;
    sended_update_packet:=false;
    update_transfer_in_progress:=false;

    LogServMess('  Sendind completion responce');
    update_answer_buf[7]:=$FE;
    if Tablo_service.UpdateClient.Socket.Connected then Tablo_service.UpdateClient.Socket.SendBuf(update_answer_buf[0],length(update_answer_buf));
  end;
end;

procedure Check_update_settings_completion;
type INIRec=record
       section:string;
       parameter:string;
       value:string;
     end;
var pint:^integer;
i,j,k:integer;
str,str_curr:string;
f:file;
ini:TINIFile;
sec,params:TStringList;
saved:array of INIRec;
begin
  //отправляем ответ
  LogServMess('CheckingUpdateSettingsCompletion enter');
  update_settings_time_keep_alive:=gettickcount;

  if Tablo_service.UpdateClient.Socket.Connected=false then
  begin
    LogServMess('  UpdateClient not connected, skipping responce');
    exit;
  end;

  pint:=@update_answer_buf[8];
  pint^:=update_settings_receive_size-update_counter;  //отправляем сколько осталось передать
  if update_counter>update_settings_receive_size then
  begin  //получили больше, отправляем ошибку
    LogServMess('  Sendind error responce');
    update_answer_buf[7]:=$FF;
    if Tablo_service.UpdateClient.Socket.Connected then Tablo_service.UpdateClient.Socket.SendBuf(update_answer_buf[0],length(update_answer_buf));

    update_settings_time:=gettickcount;
    sended_update_settings_packet:=false;
    update_settings_transfer_in_progress:=false;
    enable_update_settings:=false;
    LogServMess('Encountered error in transfer, disabling settings update');
  end
  else if update_counter<update_settings_receive_size then
  begin  //получили меньше, отправляем нормальный ответ
    LogServMess('  Sendind keep-alive responce');
    update_answer_buf[7]:=$FD;
    if Tablo_service.UpdateClient.Socket.Connected then Tablo_service.UpdateClient.Socket.SendBuf(update_answer_buf[0],length(update_answer_buf));
  end
  else
  begin  //получили ровно, отправляем ответ окончания
    //проверка длинны и контрольной суммы
    i:=length(update_receive_buf);
    j:=ZCRC32(0,update_receive_buf[0],length(update_receive_buf));
    LogServMess('Received size='+inttostr(i)+'  CRC32='+inttohex(j,8));

    //формируем путь к временному файлу
    str_curr:=GetModuleFileNameStr(0);
    str:=ChangeFileExt(str_curr, '.inibak');
    LogServMess('Temp file path='+str);

    //создаём файл
    assignfile(f,str);
    rewrite(f,1);
    blockwrite(f,update_receive_buf[0],length(update_receive_buf));
    closefile(f);

    //заменяем настройки и перезагружаем комп
    sec:=TStringList.Create;
    params:=TStringList.Create;
    ini:=TINIFile.Create(str);

    //ищем и сохраняем параметры исключения
    setlength(saved,length(settings_exceptions));
    for i:=0 to length(saved)-1 do
      saved[i].parameter:=settings_exceptions[i];
    INIFile.ReadSections(sec);

    for i:=0 to sec.Count-1 do
    begin
      INIFile.ReadSectionValues(sec[i],params);
      for j:=0 to params.Count-1 do
      begin
        for k:=0 to length(saved)-1 do
          if params.Names[j]=saved[k].parameter then
          begin
            saved[k].section:=sec[i];
            saved[k].value:=params.ValueFromIndex[j];
          end;
      end;
    end;

    LogServMess('Saved parameter exceptions:');
    for i:=0 to length(saved)-1 do
      LogServMess('  Section='+saved[i].section+',  Parameter='+saved[i].parameter+',  Value='+saved[i].value,false);

    //очищаем и переписываем заново все параметры
    LogServMess('Creating new settings file');
    str_curr:=INIFile.FileName;
    INIFile.Free;
    deletefile(str_curr);
    INIFile:=TINIFile.Create(str_curr);

    sec.Clear;
    params.Clear;
    ini.ReadSections(sec);

    for i:=0 to sec.Count-1 do
    begin
      ini.ReadSectionValues(sec[i],params);
      for j:=0 to params.Count-1 do
      begin
        INIFile.WriteString(sec[i],params.Names[j],params.ValueFromIndex[j]);
        LogServMess('  Writed Section='+sec[i]+',  Parameter='+params.Names[j]+',  Value='+params.ValueFromIndex[j],false);
      end;
    end;

    //преписываем параметры исключения
    for i:=0 to length(saved)-1 do
    begin
      INIFile.WriteString(saved[i].section,saved[i].parameter,saved[i].value);
      LogServMess('  Writed Section='+saved[i].section+',  Parameter='+saved[i].parameter+',  Value='+saved[i].value,false);
    end;

    //подчищаем
    ini.Free;
    sec.Free;
    params.Free;
    setlength(saved,0);

    //делаем комит и перезагрузку
    LogServMess('File write complete, executing commit');
    SystemCommit;
    LogServMess('Executed commit, rebooting');
    SysReboot;

    {LogServMess('Searching for new settings');
    b:=false;
    ini:=TINIFile.Create(str);
    sec:=TStringList.Create;
    params:=TStringList.Create;

    ini.ReadSections(sec);

    for i:=0 to sec.Count-1 do
    begin
      ini.ReadSectionValues(sec[i],params);
      for j:=0 to params.Count-1 do
      begin
        //проверяем, есть ли такойже параметр в исходном файле
        if INIFile.ValueExists(sec[i],params.Names[j])=false then
        begin  //если нет, то создаём его
          LogServMess('  Parameter(Section='+sec[i]+'; Parameter='+params.Names[j]+') does not exists, adding parameter with value='+params.ValueFromIndex[j],false);
          INIFile.WriteString(sec[i],params.Names[j],params.ValueFromIndex[j]);
          b:=true;
        end
        else
        begin  //если есть, сравниваем
          str1:=INIFile.ReadString(sec[i],params.Names[j],'qwerty12345');
          if params.ValueFromIndex[j]<>str1 then
          begin
            LogServMess('  Parameter(Section='+sec[i]+'; Parameter='+params.Names[j]+') have different value, old value='+str1+', new value='+params.ValueFromIndex[j],false);
            INIFile.WriteString(sec[i],params.Names[j],params.ValueFromIndex[j]);
            b:=true;
          end;
        end;
      end;
    end;

    if b=false then
    begin  //если ничего не заменили
      LogServMess('WARNING! No values changed');
    end
    else
    begin  //если всё норм
      LogServMess('Updating complete, executing commit');
      SystemCommit;
      LogServMess('Executed commit, rebooting');
      SysReboot;
    end;   }

    update_settings_time:=gettickcount;
    sended_update_settings_packet:=false;
    //update_settings_transfer_in_progress:=false;
    LogServMess('Settings update completed, disabling setting update');
    enable_update_settings:=false;

    LogServMess('  Sendind completion responce');
    update_answer_buf[7]:=$FE;
    if Tablo_service.UpdateClient.Socket.Connected then Tablo_service.UpdateClient.Socket.SendBuf(update_answer_buf[0],length(update_answer_buf));
  end;
end;

function BootReplaceFile(Source,Dest:string):boolean;
var p:PChar;
begin
  result:=false;

  if Win32Platform = VER_PLATFORM_WIN32_NT then
  begin
    if Dest='' then p:=nil
    else p:=PChar(Dest);

    result:=MoveFileEx(PChar(Source),p,MOVEFILE_DELAY_UNTIL_REBOOT or MOVEFILE_REPLACE_EXISTING);
  end;
end;

function SystemCommit:boolean;
var si:TStartupInfo;
pi:TProcessInformation;
b:boolean;
c:cardinal;
begin
  result:=false;

  ZeroMemory(@si,sizeof(si));
  ZeroMemory(@pi,sizeof(pi));
  si.cb:=sizeof(TStartupInfo);

  b:=CreateProcess(nil,  //lpApplicationName
  PChar('ewfmgr c: -commit'),  //lpCommandLine
  nil,  //lpProcessAttributes
  nil,  //lpThreadAttributes
  false,  //bInheritHandles
  0,  //dwCreationFlags
  nil,  //lpEnvironment
  nil,  //lpCurrentDirectory
  si,  //lpStartupInfo
  pi);  //lpProcessInformation

  if b=false then
  begin
    c:=GetLastError;
    LogServMess('Create process failed with error: '+GetErrString(c));
    exit;
  end;

  WaitForSingleObject(pi.hProcess,INFINITE);

  closehandle(pi.hProcess);
  closehandle(pi.hThread);

  result:=true;
end;

end.
