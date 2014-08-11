unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, ActnList, DateUtils, ComObj, MeiserDB, sqldb, lclintf;//, sqldb, ODBCConn;//, ComCtrls;

type

  { TForm1 }

  TForm1 = class(TForm)
    ButtonLunchTable: TButton;
    ButtonLunchTableCurrent: TButton;
    ButtonOrderPaper: TButton;
    ButtonSendOrder: TButton;
    ButtonOrderCancellation: TButton;
    FullUserNameWithEmail: TLabel;
    LabelUser: TLabel;
    OrderHeader: TLabel;
    PayByBank: TRadioButton;
    PayCash: TRadioButton;
    Timer1: TTimer;
    procedure ButtonLunchTableClick(Sender: TObject);
    procedure ButtonLunchTableCurrentClick(Sender: TObject);
    procedure ButtonOrderCancellationClick(Sender: TObject);
    procedure ButtonOrderPaperClick(Sender: TObject);
    procedure ButtonSendOrderClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure AddWeekToogleButtons;
    procedure Timer1Timer(Sender: TObject);
    procedure ToogleMealOfDay(Sender: TObject);
    procedure DisableOrdering;
  private
    { private declarations }
    function GetADInfo: boolean;
  public
    { public declarations }
  end;

  function GetOrderPaperPath: string;
  function GetLunchTablePath(cw:integer): string;

const
  MEISER_PATH = '\\oelnas01\public\Speiseplan\';


var
  Form1: TForm1;
  ExecutionDateProgram: TDateTime;
  StartWeekOfOrder: TDateTime;
  EndWeekOfOrder: TDateTime;
  CurrentCW: Word;
  CWOfOrder: Word;
  FirstName: string;
  LastName: string;
  Email: string;
  Bank: boolean;

  NewOrder: boolean;

  //Database

  //Fconnection  : tODBCConnection;
  //Ftransaction : tSQLTransaction;
  //Fquery       : tSQLQuery;



implementation

{$R *.lfm}

{ TForm1 }


function TForm1.GetADInfo():boolean;
var
  vbs:variant;
  cmd:widestring;
begin
     try
       vbs:=CreateOleObject('ScriptControl');
       vbs.language:='VBScript';
       cmd:= 'Set objADSysInfo = Createobject("ADSystemInfo")'+LineEnding;
       cmd:= cmd + 'Dim objUser : Set objUser = GetObject("LDAP://" & objADSysInfo.UserName)'+LineEnding;

       cmd:= cmd + 'Function MeiserFullName'+LineEnding;
       cmd:= cmd + 'MeiserFullName = objUser.FullName'+LineEnding;
       cmd:= cmd + 'End Function'+LineEnding;

       cmd:= cmd + 'Function MeiserFirstName'+LineEnding;
       cmd:= cmd + 'MeiserFirstName = objUser.FirstName'+LineEnding;
       cmd:= cmd + 'End Function'+LineEnding;

       cmd:= cmd + 'Function MeiserLastName'+LineEnding;
       cmd:= cmd + 'MeiserLastName = objUser.LastName'+LineEnding;
       cmd:= cmd + 'End Function'+LineEnding;

       cmd:= cmd + 'Function MeiserEmail'+LineEnding;
       cmd:= cmd + 'MeiserEmail = objUser.Mail'+LineEnding;
       cmd:= cmd + 'End Function'+LineEnding;
       vbs.AddCode(cmd);

       FirstName:= vbs.Run('MeiserFirstName');
       LastName:= vbs.Run('MeiserLastName');
       Email:= LowerCase(vbs.Run('MeiserEmail'));

       if (Length(Email) = 0) then
          Email:= 'E-Mail nicht vergeben';

       Result:= True;
     except
       On Exception do
       begin
         Result:= False;
       end;
     end;
end;

function IsCorrectOrderTime(): boolean;
var
   my_date: TDateTime;
begin
   my_date := Now;
   if (DayOfTheWeek(my_date) = DayFriday) and (HourOf(my_date) >= 14)  then
    begin
     showmessage('Es ist Freitag nach 14 Uhr und die Bestellung kann nicht mehr angenommen werden!');
     Exit(FALSE);
    end;
   Exit(TRUE);
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  dom:integer;
begin

     //Datum Start des Programms
     ExecutionDateProgram:=Now;
     dom:= DayOfTheWeek(ExecutionDateProgram);

     // Essenbestellung
     if not (dom in [DayMonday ..DayFriday]) then
                 ExecutionDateProgram:=IncDay(EndOfTheWeek(ExecutionDateProgram),1);

     //Ermittlung Active Directory Info

     if self.GetADInfo then
        begin
          CurrentCW:= WeekOf(ExecutionDateProgram);

          //showmessage(DateToStr(ExecutionDateProgram));

          //Arbeitswoche Montag bis Freitag
          StartWeekOfOrder:= IncDay(EndOfTheWeek(ExecutionDateProgram),1);
          EndWeekOfOrder:= IncDay(EndOfTheWeek(StartWeekOfOrder),-2);
          Timer1.Enabled:=True;
          CWOfOrder:= WeekOf(StartWeekOfOrder);
          ButtonLunchTable.Caption:= 'Speiseplan KW '+IntToStr(CWOfOrder);
          ButtonLunchTableCurrent.Caption:= 'Speiseplan Aktuelle KW '+IntToStr(CurrentCW);
          OrderHeader.Caption:= ' Essenbestellung für KW '+
          IntToStr(CWOfOrder)+ ' ('+ DateToStr(StartWeekOfOrder) + ' bis '+
          DateToStr(EndWeekOfOrder)+')';

          self.Caption:= ' Essenbestellung für KW '+ IntToStr(CWOfOrder);
          FullUserNameWithEmail.Caption:= Firstname + ' '+ LastName+' ('+ Email+ ')';

          if not IsCorrectOrderTime() then
             Application.terminate;
        end
     else
        begin
          showmessage('Fehler');
          Application.terminate;
        end;

     try
      CreateFConnection;
     except
       On Exception do
         begin
         showmessage('Es konnte keine Verbindung zur Datenbank hergestellt werden. Versuchen  Sie es später nocheinmal oder kontaktieren Sie ihren Administrator.');
         Application.Terminate;
       end
     end;

     CreateFTransaction;
     Fquery := TSQLQuery.create(nil);

     with Fquery do
      begin
       database := Fconnection;
       transaction := Ftransaction;
      end;

     NewOrder:= True;
     with Fquery do
      begin
       ReadOnly := True;
       SQL.Clear;
       SQL.Add('select COUNT(*) AS present from lunch_orders where year = '+IntToStr(YearOf(StartWeekOfOrder))+ ' and calendar_week ='+IntToStr(CWOfOrder)+' and mail='''+Email+''''+' and LastName='''+LastName+''''+' and FirstName='''+FirstName+'''');
       //SQL.Add('select COUNT(*) AS present from lunch_orders where calendar_week ='+IntToStr(CWOfOrder)+' and mail='''+Email+'''');
       Open;
       while not eof do
        begin
         if fieldbyname('present').AsLongint > 0 then
          begin
               NewOrder:= False;
               ButtonOrderCancellation.Visible:=True;
               OrderHeader.Caption:= 'Aktualisierung '+ OrderHeader.Caption;
          end;
         next;
        end;
       Close;
      end;

     Fquery.Free;

     Ftransaction.Free;
     Fconnection.Free;


     if not FileExists(GetLunchTablePath(CurrentCW)) then
        ButtonLunchTableCurrent.Enabled:=False;
     //check for new lunch table
     if FileExists(GetLunchTablePath(CWOfOrder)) then
        begin
            // Creation ToggleButtons for each weekday
            self.AddWeekToogleButtons;
        end
     else
         begin
              ButtonLunchTable.Enabled:=False;
              ButtonSendOrder.Enabled:=False;
         end;
end;

procedure TForm1.ButtonSendOrderClick(Sender: TObject);

var
   tb : TToggleBox;
   i : integer;
   correct: boolean;
   order: string;
   saveMessage: string;

begin
     order:='';
     correct:= False;
     for i := 0 to self.ComponentCount - 1 do
     begin

          if self.Components[i] is TToggleBox then
          begin
               tb := (self.Components[i] as TToggleBox);
               if tb.Checked = true then
                begin
                    correct:= True;
                    order:=order+'1,';
                end
               else
                begin
                    order:=order+'0,';
                end
          end;
     end;

     if correct = True then
        begin

             if not IsCorrectOrderTime() then
                Application.terminate;

             CreateFConnection;
             CreateFTransaction;
             Fquery := TSQLQuery.create(nil);

             with Fquery do
             begin
              database := Fconnection;
              transaction := Ftransaction;
             end;

             with Fquery do
             begin
              SQL.Clear;
              if NewOrder = True then
               begin
                saveMessage:= 'Die Bestellung wurde im System registriert';


               end
              else
               begin
                saveMessage:= 'Die Bestellung wurde aktualisiert.';
                SQL.Add('Delete from lunch_orders where year ='+IntToStr(YearOf(StartWeekOfOrder))+' and calendar_week ='+IntToStr(CWOfOrder)+' and mail='''+Email+''''+' and LastName='''+LastName+''''+' and FirstName='''+FirstName+'''');

               end;

              SQL.Add('insert into lunch_orders (firstname, lastname, mail , year,'+
              'calendar_week, guest_order, guest_description,'+
              'monday_red, monday_green, tuesday_red, tuesday_green,'+
              'wednesday_red, wednesday_green, thursday_red, thursday_green,'+
              'friday_red, friday_green, saturday_red, saturday_green,'+
              'sunday_red, sunday_green, created_at, updated_at, bank) '+

              'VALUES ('''+UTF8ToANSI(FirstName) +''','''+ UTF8ToANSI(LastName)+''','''+Email+''','+ IntToStr(YearOf(StartWeekOfOrder))+
              ','+IntToStr(CWOfOrder)+',0,'''','+
              order+'0,0,0,0,'+
              ''''+ DateTimeToStr(Now)+''','''+ DateTimeToStr(Now)+''','+ BoolToStr(PayByBank.Checked) +
              ')');
              ExecSql;


             end;

             Ftransaction.CommitRetaining;

             Fquery.Free;

             Ftransaction.Free;
             Fconnection.Free;
             NewOrder:= False;
             showmessage(saveMessage);
             Application.Terminate;
        end
     else
         Begin
              showmessage(FirstName+ ', du hast noch keine einzige Mahlzeit ausgewählt. Die Bestellung kann ich mir sparen ;-D');
         end;
end;

procedure TForm1.ButtonOrderCancellationClick(Sender: TObject);
begin

     CreateFConnection;
     CreateFTransaction;
     Fquery := TSQLQuery.create(nil);

     with Fquery do
      begin
       database := Fconnection;
       transaction := Ftransaction;
       SQL.Add('Delete from lunch_orders where calendar_week ='+IntToStr(CWOfOrder)+' and mail='''+Email+''''+' and LastName='''+LastName+''''+' and FirstName='''+FirstName+'''');
       ExecSql;
      end;

     Ftransaction.CommitRetaining;
     Fquery.Free;

     Ftransaction.Free;
     Fconnection.Free;

     showmessage('Die komplette Bestellung für KW '+IntToStr(CWOfOrder)+' wurde storniert.');
     Application.Terminate;
end;

procedure TForm1.ButtonOrderPaperClick(Sender: TObject);
begin
     OpenDocument(GetOrderPaperPath);
end;

procedure TForm1.ButtonLunchTableClick(Sender: TObject);
begin
     OpenDocument(GetLunchTablePath(CWOfOrder));
end;

procedure TForm1.ButtonLunchTableCurrentClick(Sender: TObject);
begin
     OpenDocument(GetLunchTablePath(CurrentCW));
end;

procedure TForm1.ToogleMealOfDay(Sender: TObject);
var
   clickedComp: string;
   tb: TToggleBox;
begin
     clickedComp:= TControl(Sender).Name;

     case clickedComp[Length(clickedComp)] of
     '1':
         clickedComp[Length(clickedComp)]:='2';

     '2':
         clickedComp[Length(clickedComp)]:='1';
     end;

     //comp:= self.FindComponent(clickedComp);
     tb:= TToggleBox(self.FindComponent(clickedComp));
     //disable event fireing and change status
     tb.OnClick := nil;
     tb.Checked:=False;
     //reasign old onClickEvent
     tb.onClick:= @ToogleMealOfDay;

end;

procedure TForm1.AddWeekToogleButtons();

var
   i,o : integer;
   tbRed,tbGreen : TToggleBox;
   weekDayLabel: TLabel;
   OldOrder: Array[0..9] of Boolean;
begin


       if NewOrder= False then
        begin
            CreateFConnection;
            CreateFTransaction;
            Fquery := TSQLQuery.create(nil);



            with Fquery do
            begin
             database := Fconnection;
             transaction := Ftransaction;
             ReadOnly := True;
             SQL.Clear;
             SQL.Add('select monday_red, monday_green, tuesday_red, tuesday_green,'+
              'wednesday_red, wednesday_green, thursday_red, thursday_green,'+
              'friday_red, friday_green, saturday_red, saturday_green,'+
              'sunday_red, sunday_green, bank from lunch_orders where calendar_week ='+IntToStr(CWOfOrder)+' and mail='''+Email+''''+' and LastName='''+LastName+''''+' and FirstName='''+FirstName+'''');
             Open;
             while not eof do
             begin
              OldOrder[0]:= (fieldbyname('monday_red').AsBoolean);
              OldOrder[1]:= (fieldbyname('monday_green').AsBoolean);
              OldOrder[2]:= (fieldbyname('tuesday_red').AsBoolean);
              OldOrder[3]:= (fieldbyname('tuesday_green').AsBoolean);
              OldOrder[4]:= (fieldbyname('wednesday_red').AsBoolean);
              OldOrder[5]:= (fieldbyname('wednesday_green').AsBoolean);
              OldOrder[6]:= (fieldbyname('thursday_red').AsBoolean);
              OldOrder[7]:= (fieldbyname('thursday_green').AsBoolean);
              OldOrder[8]:= (fieldbyname('friday_red').AsBoolean);
              OldOrder[9]:= (fieldbyname('friday_green').AsBoolean);

              if (fieldbyname('bank').Asboolean = True) then PayByBank.Checked:=True;

              next;
             end;
             Close;
            end;

            Ftransaction.CommitRetaining;
            Fquery.Free;

            Ftransaction.Free;
            Fconnection.Free;

        end;


       o:=0;
       for i:=Low(FormatSettings.LongDayNames)+1 to High(TFormatSettings.LongDayNames)-1 do
        begin
         //Label Weekday
         weekDayLabel:= TLabel.Create(self);
         weekDayLabel.Name:='WeekdayLabel'+FormatSettings.ShortDayNames[i];
         weekDayLabel.Caption:=FormatSettings.LongDayNames[i];
         weekDayLabel.Top:= FullUserNameWithEmail.Top+80;
         weekDayLabel.Width:= 80;
         weekDayLabel.Alignment:=taCenter;
         weekDayLabel.Left:= weekDayLabel.Width*(i-1);
         weekDayLabel.Parent:= self;
         weekDayLabel.Enabled:=True;
         weekDayLabel.Visible:=True;
         weekDayLabel.show;

         //Rote Buttons
         tbRed:= TToggleBox.Create(self);
         tbRed.Name:='ToggleBox'+FormatSettings.ShortDayNames[i]+'1';
         tbRed.Caption:='Rot';
         tbRed.Top:=  weekDayLabel.Top+20;
         tbRed.Width:= 80;
         tbRed.Height:= 80;
         tbRed.Left:= tbRed.Width*(i-1);
         tbRed.Parent:=self;
         tbRed.Visible:=True;
         tbRed.Enabled:=True;
         if not NewOrder then tbRed.Checked:=OldOrder[2*o];

         //Grüne Buttons
         tbGreen:= TToggleBox.Create(self);
         tbGreen.Name:='ToggleBox'+FormatSettings.ShortDayNames[i]+'2';
         tbGreen.Caption:='Grün';
         tbGreen.Top:= weekDayLabel.Top+20+ tbRed.Height;
         tbGreen.Width:= 80;
         tbGreen.Height:= 80;
         tbGreen.Left:= tbGreen.Width*(i-1);
         tbGreen.Parent:=self;
         tbGreen.Enabled:=True;
         tbGreen.Visible:=True;
         if not NewOrder then tbGreen.Checked:=OldOrder[2*o+1];

         tbRed.OnClick:=@ToogleMealOfDay;
         tbGreen.OnClick:=@ToogleMealOfDay;

         o:= o+1;
        end;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
//var
   //dom:integer;
begin
     //dom:= DayOfTheWeek(Now);



     if (DateOf(Now) > DateOf(EndWeekOfOrder)) and (HourOf(Now) > 14) then
      begin
          Timer1.Enabled:=False;
          showmessage('Das hat zu lange gedauert. Es kann für diese KW nun keine Bestellung mehr aufgenommen werden.');
          Application.Terminate;
      end;
     //if (not (dom in [DayMonday ..DayFriday])) or(false) then Application.Terminate;
end;

procedure TForm1.DisableOrdering();
var
   i: integer;

begin
      ButtonSendOrder.Enabled:= False;
      ButtonOrderCancellation.Enabled:=False;
      for i := 0 to self.ComponentCount - 1 do
      begin

          if self.Components[i] is TToggleBox then
          begin
               (self.Components[i] as TToggleBox).Enabled:=False;
          end;
      end;

end;

function GetOrderPaperPath: string;
begin
   GetOrderPaperPath:= MEISER_PATH+'VordruckEssenbestellungKantineParkhotel.pdf';
end;

function GetLunchTablePath(cw:integer): string;

var
   doc_path: string;
   pdf_path: string;
begin
   //showmessage(DateTimeToStr(StartWeekOfOrder));
   pdf_path:= MEISER_PATH+IntToStr(YearOf(StartWeekOfOrder))+'\kw'+IntToStr(cw)+'.pdf';
   //pdf_path:= MEISER_PATH+IntToStr(YearOf(StartWeekOfOrder))+'\kw31.pdf';
   doc_path:= MEISER_PATH+IntToStr(YearOf(StartWeekOfOrder))+'\kw'+IntToStr(cw)+'.doc';
   //doc_path:= MEISER_PATH+IntToStr(YearOf(StartWeekOfOrder))+'\kw31.doc';
   if FileExists(pdf_path) then
           Exit(pdf_path);

   if FileExists(doc_path) then
      begin
          Exit(doc_path);
      end
   else
      begin
           Exit('');

      end;
end;


end.
