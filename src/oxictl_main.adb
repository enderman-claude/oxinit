with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Interfaces.C;
with Oxinit.Socket;

--  oxictl: talk to a running oxinit.
--    oxictl status | stop NAME | start NAME
procedure Oxictl_Main is

   use type Interfaces.C.int;
   package US renames Ada.Strings.Unbounded;

   Usage : constant String := "usage: oxictl status | stop NAME | start NAME";

   Cmd : US.Unbounded_String;
   Fd  : Interfaces.C.int;
begin
   if Ada.Command_Line.Argument_Count = 0 then
      Ada.Text_IO.Put_Line (Usage);
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;

   for I in 1 .. Ada.Command_Line.Argument_Count loop
      if I > 1 then
         US.Append (Cmd, " ");
      end if;
      US.Append (Cmd, Ada.Command_Line.Argument (I));
   end loop;

   Fd := Oxinit.Socket.Connect_To (Oxinit.Socket.Path);
   if Fd < 0 then
      Ada.Text_IO.Put_Line ("oxictl: cannot reach oxinit at " & Oxinit.Socket.Path
                            & " (is it running?)");
      Ada.Command_Line.Set_Exit_Status (1);
      return;
   end if;

   Oxinit.Socket.Write_All (Fd, US.To_String (Cmd) & ASCII.LF);
   declare
      Reply : constant String := Oxinit.Socket.Read_All (Fd);
   begin
      Oxinit.Socket.Close (Fd);
      Ada.Text_IO.Put_Line (Reply);
      if Reply'Length >= 6 and then Reply (Reply'First .. Reply'First + 5) = "error:" then
         Ada.Command_Line.Set_Exit_Status (1);
      end if;
   end;
end Oxictl_Main;
