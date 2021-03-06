unit meiserdb;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Dialogs, sqldb, ODBCConn;


var

   Fconnection  : tODBCConnection;
   Ftransaction : tSQLTransaction;
   Fquery       : tSQLQuery;


procedure ExitWithError(s : string);
procedure CreateFConnection;
procedure CreateFTransaction;
procedure CreateFQuery;

implementation

procedure ExitWithError(s : string);

begin
  showmessage('Execution aborted: '+s);
  halt;
end;

procedure CreateFConnection;

begin
  Fconnection:= tODBCConnection.Create(nil);

  if not assigned(Fconnection) then ExitWithError('Invalid database-type, check if a valid database-type was provided in the file ''database.ini''');

  with Fconnection do
  begin
          //DatabaseName:= 'lunch_orders';
          //Params.add('Trusted Connection=SSPI');
          Driver:=  'SQL Server';
          //Params.add('Trusted Connection=Yes');
          //Params.add('Server=oelsql11');
          //Params.add('Database=esab_sa');
          Params.add('UID=Speiseplan');
          Params.add('PWD=Speiseplan123');
          Params.add('Server=oelsql11');
          Params.add('Database=Speiseplan');
          open;
  end
end;

procedure CreateFTransaction;

begin
  Ftransaction := tsqltransaction.create(nil);
  with Ftransaction do
    begin
    database := Fconnection;
    StartTransaction;
    end;
end;

procedure CreateFQuery;

begin
  Fquery := TSQLQuery.create(nil);
  with Fquery do
    begin
    database := Fconnection;
    transaction := Ftransaction;
    end;
end;



end.

