unit DataProtocolUnit;

interface

uses ScktComp;

type
  TDataProtocolStatus=(dpsCreating,dpsWaitingBeforeConnect,dpsConnecting,dpsWaitingForConnect,dpsConnected,
    dpsSendingRegisterPacket,dpsWaitingForRegisterResponce,dpsReceivedRegisterResponce,dpsWaitingForPacket,
    dpsReceivedPacket,dpsDisconnect,dpsError,dpsTimeout,dpsDestroing);

  TDataProtocolObject=class(TObject)
  private
    Client:TClientSocket;  //сокет для соединения с сервером мосгортранса
    FClientHost:string;  //адрес сервера
    FClientPort:integer;  //порт сервера
    FStatus:TDataProtocolStatus;  //текущий статус и положение в диаграмме обмена данными
    FLastAction:cardinal;  //время последнего изменения

    FBeforeConnectInterval:integer;  //интервал ожидания перед конектом
    FOnConnectTimeout:integer;  //таймаут на конект
    FRegisterResponceTimeout:integer;  //таймаут на ожидание ответа на пакет регистрации
    FWaitingForPacketTimeout:integer;  //таймаут на ожидание пакетов в обычном режиме работы

    FClientConnected:boolean;  //флаг на конект клиента
    FClientError:boolean;  //флаг на ошибку сокета
    FClientOnDisconnect:boolean;  //флаг на дисконект клиента
    FClientOnRegisterResponce:boolean;  //флаг ответа на пакет регистрации
    FClientOnPacketReceive:boolean;  //флаг на получение правильного пакета

    //события для компонента клиента
    procedure ClientConnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure ClientConnecting(Sender: TObject; Socket: TCustomWinSocket);
    procedure ClientDisconnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure ClientError(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure ClientLookup(Sender: TObject; Socket: TCustomWinSocket);
    procedure ClientRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure ClientWrite(Sender: TObject; Socket: TCustomWinSocket);
  public
    constructor Create(host:string; port:integer; BeforeConn_interval, OnConn_timeout, RegisterResp_timeout, WaitingPacket_timeout:integer);  //конструктор объекта
    destructor Destroy; override;  //деструктор объекта

    procedure FlagRegisterResponce;  //процедура для выставления флага ответа на регистрацию
    procedure FlagPacketResponce;  //процедура для выставления флага получения правильного пакета

    procedure SetStatus(stat:TDataProtocolStatus);  //процедура для изменения статуса и логирования изменений
    procedure Work;  //основная процедура, которая будет вызываться в основном цикле программы

    //отправка ответа по сокету
    procedure SendSimpleAnswer(num,errorcode:byte);
    procedure SendError4Answer(num,errorcode,error_ind:byte);

    procedure Log(mess:string);  //процедура для логирования
  end;

implementation

uses mainUnit, TypInfo, Windows, SysUtils;

//-------------------TDataProtocolObject-----------------------------
constructor TDataProtocolObject.Create(host:string; port:integer; BeforeConn_interval, OnConn_timeout, RegisterResp_timeout, WaitingPacket_timeout:integer);
begin
  Log('DataProtocolObject create enter');

  FStatus:=dpsCreating;

  //инициализация переменных
  FClientConnected:=false;
  FClientError:=false;
  FClientOnDisconnect:=false;
  FClientOnRegisterResponce:=false;
  FClientOnPacketReceive:=false;
  FClientHost:=host;
  FClientPort:=port;
  FBeforeConnectInterval:=BeforeConn_interval;
  FOnConnectTimeout:=OnConn_timeout;
  FRegisterResponceTimeout:=RegisterResp_timeout;
  FWaitingForPacketTimeout:=WaitingPacket_timeout;

  Log('Creating client socket');
  Client:=TClientSocket.Create(nil);
  Client.ClientType:=ctNonBlocking;
  Client.Host:=FClientHost;
  Client.Port:=FClientPort;
  Client.OnConnect:=ClientConnect;
  Client.OnConnecting:=ClientConnecting;
  Client.OnDisconnect:=ClientDisconnect;
  Client.OnError:=ClientError;
  Client.OnLookup:=ClientLookup;
  Client.OnRead:=ClientRead;
  Client.OnWrite:=ClientWrite;

  SetStatus(dpsWaitingBeforeConnect);
  FLastAction:=gettickcount;

  Log('DataProtocolObject create exit');
end;

destructor TDataProtocolObject.Destroy;
begin
  Log('DataProtocolObject destroy enter');

  Log('Closing Data connection');
  Client.Close;

  SetStatus(dpsDestroing);

  Client.Free;

  Log('DataProtocolObject destroy exit');
end;

procedure TDataProtocolObject.ClientConnect(Sender: TObject; Socket: TCustomWinSocket);
begin
  Log('InfoDataObject socket OnConnect');

  FClientConnected:=true;
end;

procedure TDataProtocolObject.ClientConnecting(Sender: TObject; Socket: TCustomWinSocket);
begin
  Log('InfoDataObject socket OnConnecting');
end;

procedure TDataProtocolObject.ClientDisconnect(Sender: TObject; Socket: TCustomWinSocket);
begin
  Log('InfoDataObject socket OnDisconnect');

  FClientOnDisconnect:=true;
end;

procedure TDataProtocolObject.ClientError(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
begin
  Log('InfoDataObject socket OnError, ErrorEvent='+inttostr(ord(ErrorEvent))+', ErrorCode='+inttostr(ErrorCode));

  FClientError:=true;
  ErrorCode:=0;
end;

procedure TDataProtocolObject.ClientLookup(Sender: TObject; Socket: TCustomWinSocket);
begin
  Log('InfoDataObject socket OnLookup');
end;

procedure TDataProtocolObject.ClientRead(Sender: TObject; Socket: TCustomWinSocket);
var buf:array of byte;
i,j:integer;
begin
  i:=socket.ReceiveLength;
  setlength(buf,i);
  socket.ReceiveBuf(buf[0],i);

  Log('InfoDataObject socket OnRead, received '+inttostr(i)+' bytes');

  if i<=7 then
  begin
    Log('Packet is too small, ignoring');
  end
  else if i>=2048 then
  begin
    Log('Packet is too big, sending error #1');
    SendSimpleAnswer(buf[3],1);
  end
  else
  begin
    j:=length(info_input);
    setlength(info_input,j+1);
    setlength(info_input[j],i);
    move(buf[0],info_input[j][0],i);

    setlength(buf,0);

    Log('Packet received sucsessfuly, end of OnRead');
  end;
end;

procedure TDataProtocolObject.ClientWrite(Sender: TObject; Socket: TCustomWinSocket);
begin
  Log('InfoDataObject socket OnWrite');
end;

procedure TDataProtocolObject.FlagRegisterResponce;
begin
  FClientOnRegisterResponce:=true;
end;

procedure TDataProtocolObject.FlagPacketResponce;
begin
  FClientOnPacketReceive:=true;
end;

procedure TDataProtocolObject.SetStatus(stat:TDataProtocolStatus);
begin
  Log('Status changing from '+GetEnumName(TypeInfo(TDataProtocolStatus),ord(FStatus))+' to '+GetEnumName(TypeInfo(TDataProtocolStatus),ord(stat)));

  FStatus:=stat;
end;

procedure TDataProtocolObject.Work;
var t:cardinal;
begin
  t:=gettickcount;

  case FStatus of
    dpsCreating:  //-----------------
    begin
      //сюда мы попадаем только если что-то нето случилось, так что принимаем меры
      Log('WARNING! Wrong section on DataProtocolObject work, rebooting computer');

      mainUnit.SysReboot;

      //вызываем смену статуса, чтобы мы сюда больше не попадали
      SetStatus(dpsDestroing);
      FLastAction:=0;
    end;
    dpsWaitingBeforeConnect:  //-----------------
    begin
      //ждём FBeforeConnectInterval мсекунд
      if t>(FLastAction+FBeforeConnectInterval) then
      begin
        Log('Entered WaitingBeforeConnect section in DataProtocolObject');

        //проверяем на активный таймер ротации
        if Tablo_service.RotationTimer.Enabled then
        begin
          Log('WARNING! Rotation timer is enabled in WaitingBeforeConnect section, disabling timer');
          Tablo_service.RotationTimer.Enabled:=false;
        end;

        //обновляем статус и последнее действие
        SetStatus(dpsConnecting);
        FLastAction:=t;
      end;
    end;
    dpsConnecting:  //-----------------
    begin
      //ждём ещё 1 секунду перед созданием коннекта
      if t>(FLastAction+1000) then
      begin
        Log('Entered Connecting section in DataProtocolObject, opening connection to '+Client.Host+':'+inttostr(Client.Port));

        //открываем соединение и сбрасываем флаги
        FClientConnected:=false;
        FClientError:=false;
        FClientOnDisconnect:=false;
        FClientOnRegisterResponce:=false;
        FClientOnPacketReceive:=false;
        Client.Open;
        //обновляем статус и время
        SetStatus(dpsWaitingForConnect);
        FLastAction:=t;
      end;
    end;
    dpsWaitingForConnect:  //-----------------
    begin
      //проверяем на дисконект, ошибки и сам коннект
      if FClientConnected=true then  //конект
      begin
        //меняем статус и время и выходим, в лог ничего не выводим, т.к. это нормальное действие
        SetStatus(dpsConnected);
        FLastAction:=t;
        exit;
      end;

      if FClientError=true then  //ошибка
      begin
        Log('Entered WaitingForConnect section and encountered error in DataProtocolObject, reseting');
        //изменяем статус и время
        SetStatus(dpsError);
        FLastAction:=t;
        exit;
      end;

      if FClientOnDisconnect=true then  //отсоединение
      begin
        Log('Entered WaitingForConnect section and encountered disconnect in DataProtocolObject, reseting');
        //изменяем статус и время
        SetStatus(dpsDisconnect);
        FLastAction:=t;
        exit;
      end;

      //проверяем на таймаут FOnConnectTimeout мсекунд
      if t>(FLastAction+FOnConnectTimeout) then
      begin
        Log('Entered WaitingForConnect section and encountered timeout in DataProtocolObject, reseting');
        //изменяем статус и время
        SetStatus(dpsTimeout);
        FLastAction:=t;
      end;
    end;
    dpsConnected:  //-----------------
    begin
      Log('Entered Connected section in DataProtocolObject, checking connection');
      //проверяем на активное подключение
      if Client.Socket.Connected=true then
      begin
        Log('Connection good, changing status');
        //обновляем статус и время
        SetStatus(dpsSendingRegisterPacket);
        FLastAction:=t;
      end
      else
      begin
        Log('WARNING! Connection is not active, raising error and reseting');
        //обновляем статус и время
        SetStatus(dpsError);
        FLastAction:=t;
      end;
    end;
    dpsSendingRegisterPacket:  //-----------------
    begin
      //ждём 1 секунду и отправляем пакет
      if t>(FLastAction+1000) then
      begin
        try
          Log('Entered SendingRegisterPacket section in DataProtocolObject, sending registration packet');
          Client.Socket.SendText(mainUnit.register_message);

          Log('Packet sent, waiting for answer');
          //обновляем статус и время
          SetStatus(dpsWaitingForRegisterResponce);
          FLastAction:=t;
        except
          on e:exception do
          begin
            Log('WARNING! Exception on sending register packet with message:'+e.Message);
            SetStatus(dpsError);
            FLastAction:=t;
            exit;
          end;
        end;
      end;
    end;
    dpsWaitingForRegisterResponce:  //-----------------
    begin
      //проверяем на дисконект, ошибки и ответ
      if FClientonRegisterResponce=true then  //ответ
      begin
        //изменяем статус и время
        SetStatus(dpsReceivedRegisterResponce);
        FLastAction:=t;
        exit;
      end;

      if FClientError=true then  //ошибка
      begin
        Log('Entered WaitingForRegisterResponce section and encountered error in DataProtocolObject, reseting');
        //изменяем статус и время
        SetStatus(dpsError);
        FLastAction:=t;
        exit;
      end;

      if FClientOnDisconnect=true then  //отсоединение
      begin
        Log('Entered WaitingForRegisterResponce section and encountered disconnect in DataProtocolObject, reseting');
        //изменяем статус и время
        SetStatus(dpsDisconnect);
        FLastAction:=t;
        exit;
      end;

      //проверяем на таймаут FRegisterResponceTimeout мсекунд
      if t>(FLastAction+FRegisterResponceTimeout) then
      begin
        Log('Entered WaitingForRegisterResponce section and encountered timeout in DataProtocolObject, reseting');
        //изменяем статус и время
        SetStatus(dpsTimeout);
        FLastAction:=t;
      end;
    end;
    dpsReceivedRegisterResponce:  //-----------------
    begin
      Log('Entered ReceivedRegisterResponce section in DataProtocolObject, waiting for packets');
      //изменяем статус и время
      FClientOnPacketReceive:=false;
      SetStatus(dpsWaitingForPacket);
      FLastAction:=t;
    end;
    dpsWaitingForPacket:  //-----------------
    begin
      //основная работа
      //нужно проверить на ошибки, дисконект и таймаут
      if FClientError=true then  //ошибка
      begin
        Log('Entered WaitingForPacket section and encountered error in DataProtocolObject, reseting');
        //изменяем статус и время
        SetStatus(dpsError);
        FLastAction:=t;
        exit;
      end;

      if FClientOnDisconnect=true then  //отсоединение
      begin
        Log('Entered WaitingForPacket section and encountered disconnect in DataProtocolObject, reseting');
        //изменяем статус и время
        SetStatus(dpsDisconnect);
        FLastAction:=t;
        exit;
      end;

      //проверяем на таймаут FWaitingForPacketTimeout мсекунд
      if t>(FLastAction+FWaitingForPacketTimeout) then
      begin
        Log('Entered WaitingForPacket section and encountered timeout in DataProtocolObject, reseting');
        //изменяем статус и время
        SetStatus(dpsTimeout);
        FLastAction:=t;
      end;

      //проверяем на получение пакета
      if FClientOnPacketReceive=true then
      begin
        //меняем статус
        SetStatus(dpsReceivedPacket);
      end;
    end;
    dpsReceivedPacket:  //-----------------
    begin
      Log('Entered ReceivedPacket section in DataProtocolObject, changing time');

      FClientOnPacketReceive:=false;

      //обновляем время и меняем статус обратно
      SetStatus(dpsWaitingForPacket);
      FLastAction:=t;
    end;
    dpsDisconnect:  //-----------------
    begin
      Log('WARNING! Entered Disconnect section in DataProtocolObject, reseting');

      Client.Close;
      SetStatus(dpsWaitingBeforeConnect);
      FLastAction:=t;

      FClientConnected:=false;
      FClientError:=false;
      FClientOnDisconnect:=false;
      FClientOnRegisterResponce:=false;
      FClientOnPacketReceive:=false;
    end;
    dpsError:  //-----------------
    begin
      Log('WARNING! Entered Error section in DataProtocolObject, reseting');

      Client.Close;
      SetStatus(dpsWaitingBeforeConnect);
      FLastAction:=t;

      FClientConnected:=false;
      FClientError:=false;
      FClientOnDisconnect:=false;
      FClientOnRegisterResponce:=false;
      FClientOnPacketReceive:=false;
    end;
    dpsTimeout:  //-----------------
    begin
      Log('WARNING! Entered Timeout section in DataProtocolObject, reseting');

      Client.Close;
      SetStatus(dpsWaitingBeforeConnect);
      FLastAction:=t;

      FClientConnected:=false;
      FClientError:=false;
      FClientOnDisconnect:=false;
      FClientOnRegisterResponce:=false;
      FClientOnPacketReceive:=false;
    end;
    dpsDestroing:  //-----------------
    begin
      //секция для уничтожения, заходим каждые 2 секунды
      if t>(FLastAction+2000) then
      begin
        Log('WARNING! DataProtocolObject entered Destroing section, waiting');

        FLastAction:=t;
      end;
    end;
  end;
end;

procedure TDataProtocolObject.SendSimpleAnswer(num,errorcode:byte);
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

  Client.Socket.SendText(answer);
end;

procedure TDataProtocolObject.SendError4Answer(num,errorcode,error_ind:byte);
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

  Client.Socket.SendText(answer);
end;

procedure TDataProtocolObject.Log(mess:string);
begin
  mainUnit.LogServMess(mess,true);
end;
//===================TDataProtocolObject=============================

end.
