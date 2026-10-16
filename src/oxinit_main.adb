with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Ada.Exceptions;
with Ada.Real_Time;
with Ada.Text_IO;
with Interfaces.C;
with Oxinit.Config;
with Oxinit.Ctl_Server;
with Oxinit.Launch;
with Oxinit.Moods;
with Oxinit.Output;
with Oxinit.Posix;
with Oxinit.Reaping;  --  elaborating this unit starts the reaper task
with Oxinit.Signals;
with Oxinit.Socket;
with Oxinit.Table;
with Oxinit.Types;
with Oxinit.Worker;

procedure Oxinit_Main is

   use type Interfaces.C.int;
   use Oxinit.Config;

   Default_Config : constant String := "/etc/oxinit/services.oxi";

   type Worker_Ptr is access Oxinit.Worker.Worker;
   Workers : array (1 .. Oxinit.Types.Max_Services) of Worker_Ptr := (others => null);
   Count   : Natural := 0;

   procedure Finish (Code : Interfaces.C.int) is
   begin
      Ada.Text_IO.Flush (Ada.Text_IO.Standard_Output);
      Oxinit.Posix.Exit_Now (Code);
   end Finish;

   function Config_Path (Index : Positive) return String is
   begin
      if Ada.Command_Line.Argument_Count >= Index then
         return Ada.Command_Line.Argument (Index);
      end if;
      return Default_Config;
   end Config_Path;

   function Args_Text (Svc : Oxinit.Types.Service) return String is
      Text   : Ada.Strings.Unbounded.Unbounded_String;
      First  : Boolean := True;
   begin
      Ada.Strings.Unbounded.Append (Text, "[");
      for A of Svc.Args loop
         if not First then
            Ada.Strings.Unbounded.Append (Text, ", ");
         end if;
         First := False;
         Ada.Strings.Unbounded.Append (Text, "'" & Ada.Strings.Unbounded.To_String (A) & "'");
      end loop;
      Ada.Strings.Unbounded.Append (Text, "]");
      return Ada.Strings.Unbounded.To_String (Text);
   end Args_Text;

   procedure Print_Check is
   begin
      for I in 1 .. Natural (Service_Vectors.Length (Services)) loop
         declare
            Svc : constant Oxinit.Types.Service := Service_Vectors.Element (Services, I);
         begin
            Ada.Text_IO.Put_Line
              ("ok: " & Ada.Strings.Unbounded.To_String (Svc.Name)
               & " (mood " & Oxinit.Moods.Name (Svc.Mood)
               & ", program " & Ada.Strings.Unbounded.To_String (Svc.Program)
               & ", args " & Args_Text (Svc)
               & ", lives " & Oxinit.Types.Lives_Name (Svc.Lives)
               & ", furry " & (if Svc.Furry then "true" else "false") & ")");
         end;
      end loop;
      Ada.Text_IO.Put_Line ("ok:" & Natural'Image (Natural (Service_Vectors.Length (Services)))
                            & " service(s) valid");
   end Print_Check;

   procedure Shutdown is
      use type Ada.Real_Time.Time;
      Pid      : Interfaces.C.int;
      Ignored  : Interfaces.C.int;
      Svc      : Oxinit.Types.Service;
      Deadline : Ada.Real_Time.Time;
   begin
      Oxinit.Table.Registry.Begin_Stop;
      Oxinit.Output.Olog_Important ("shutdown requested");

      for I in 1 .. Count loop
         Pid := Oxinit.Table.Registry.Pid_Of (I);
         if Pid > 0 then
            Svc := Service_Vectors.Element (Services, I);
            Oxinit.Output.Svc_Line (Svc, "received eviction notice", "stop", Important => True);
            Ignored := Oxinit.Posix.Kill (Pid, Interfaces.C.int (Svc.Notice));
         end if;
      end loop;

      for I in 1 .. Count loop
         Svc := Service_Vectors.Element (Services, I);
         Deadline := Ada.Real_Time.Clock
           + Ada.Real_Time.To_Time_Span (Duration (Svc.Grace));
         while not Workers (I).all'Terminated and then Ada.Real_Time.Clock < Deadline loop
            delay 0.1;
         end loop;

         if not Workers (I).all'Terminated then
            Pid := Oxinit.Table.Registry.Pid_Of (I);
            if Pid > 0 then
               Oxinit.Output.Svc_Line (Svc, "did not leave, forced removal (SIGKILL)", "kill", Important => True);
               Ignored := Oxinit.Posix.Kill (Pid, Oxinit.Posix.Sigkill);
            end if;
            Deadline := Ada.Real_Time.Clock + Ada.Real_Time.To_Time_Span (5.0);
            while not Workers (I).all'Terminated and then Ada.Real_Time.Clock < Deadline loop
               delay 0.1;
            end loop;
         end if;
      end loop;
   end Shutdown;

begin
   if Ada.Command_Line.Argument_Count >= 1
     and then Ada.Command_Line.Argument (1) = "--check"
   then
      Load_File (Config_Path (2));
      Print_Check;
      Finish (0);
   end if;

   Oxinit.Output.Set_Color (Oxinit.Posix.Isatty (1) = 1);
   Oxinit.Signals.Install;

   if Oxinit.Posix.Getpid /= 1 then
      Oxinit.Output.Olog ("not running as PID 1, dev mode");
   end if;

   Load_File (Config_Path (1));
   Oxinit.Launch.Prepare;

   Count := Natural (Service_Vectors.Length (Services));
   Oxinit.Output.Expect_Boot (Count);   --  before any worker can report
   for I in 1 .. Count loop
      Workers (I) := new Oxinit.Worker.Worker (I);
   end loop;

   Oxinit.Ctl_Server.Server.Start;
   Oxinit.Output.Olog ("loaded" & Natural'Image (Count) & " service(s) from " & Config_Path (1));
   --  Wait for #hadmycoffee: every service has made its first start attempt.
   --  Give up after 10 seconds and go quiet anyway, so a stuck service cannot
   --  keep the console noisy forever.
   declare
      Waited : Natural := 0;
   begin
      while not Oxinit.Output.Boot_Done and then Waited < 100 loop
         delay 0.1;
         Waited := Waited + 1;
      end loop;
      if not Oxinit.Output.Boot_Done then
         Oxinit.Output.Olog_Important ("#hadmycoffee timed out, going quiet");
         Oxinit.Output.Force_Boot_Done;
      end if;
   end;
   Oxinit.Output.Olog_Important ("#hadmycoffee reached, routine lines go to the log");

   while not Oxinit.Signals.Stop_Requested loop
      delay 0.2;
   end loop;

   Shutdown;
   Oxinit.Socket.Remove (Oxinit.Socket.Path);
   Oxinit.Output.Olog_Important ("exiting");

   if Oxinit.Posix.Getpid = 1 then
      --  As PID 1, returning would panic the kernel ("Attempted to kill init").
      --  Flush the disks and power off instead.
      Oxinit.Output.Olog_Important ("powering off");
      Oxinit.Posix.Sync;
      if Oxinit.Posix.Reboot (Oxinit.Posix.Reboot_Power_Off) < 0 then
         Oxinit.Output.Olog_Important ("power off failed, halting here");
         loop
            delay 3600.0;
         end loop;
      end if;
   end if;
   Finish (0);

exception
   when E : Oxinit.Types.Config_Error =>
      Oxinit.Output.Olog_Important ("config error: " & Ada.Exceptions.Exception_Message (E));
      Finish (1);
   when E : Oxinit.Config.Read_Error =>
      Oxinit.Output.Olog_Important (Ada.Exceptions.Exception_Message (E));
      Finish (1);
end Oxinit_Main;
