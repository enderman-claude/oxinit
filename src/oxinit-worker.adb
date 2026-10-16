with Ada.Real_Time;
with Interfaces.C;
with Oxinit.Config;
with Oxinit.Output;
with Oxinit.Table;
with Oxinit.Types;

package body Oxinit.Worker is

   use type Interfaces.C.int;
   use type Types.Lives_Kind;
   use type Ada.Real_Time.Time;
   use type Ada.Real_Time.Time_Span;

   --  Same meaning as Python's waitstatus_to_exitcode: code, or -signal if killed.
   function Exit_Code (Status : Interfaces.C.int) return Integer is
      S   : constant Integer := Integer (Status);
      Low : constant Integer := S mod 128;
   begin
      if Low = 0 then
         return (S / 256) mod 256;
      else
         return -Low;
      end if;
   end Exit_Code;

   task body Worker is
      Svc     : constant Types.Service :=
        Config.Service_Vectors.Element (Config.Services, Idx);
      Started : Boolean := False;
      Stamps  : array (1 .. Types.Crash_Limit + 1) of Ada.Real_Time.Time;
      Count   : Natural := 0;
      Pid     : Interfaces.C.int;
      Ok      : Boolean;
      Status  : Interfaces.C.int;
      Code    : Integer;
      Now     : Ada.Real_Time.Time;
      Wait    : Natural;
      Counted : Boolean := False;

      --  Reports this service's first start attempt to the boot counter, once.
      procedure Count_First is
      begin
         if not Counted then
            Counted := True;
            Output.First_Attempt_Done;
         end if;
      end Count_First;
   begin
      Main_Loop :
      loop
         exit Main_Loop when Table.Registry.Stopping;

         if not Table.Registry.Want (Idx) then
            --  Down on purpose (oxictl stop, finished, or gave up). Wait for a start.
            Table.Registry.Set_State (Idx, Types.Stopped);
            Count_First;
            Count := 0;
            delay 0.1;
         else
            Table.Registry.Spawn (Idx, Pid, Ok);
            if not Ok then
               Count_First;   --  a failed spawn prints nothing, so count it now
            end if;
            exit Main_Loop when not Ok;

            if not Started then
               Output.Svc_Rule (Svc);
               Started := True;
            end if;
            Table.Registry.Set_State (Idx, Types.Running);
            Output.Svc_Line (Svc, "started (pid " & Types.Img (Integer (Pid)) & ")", "start");
            Count_First;   --  count only after the start line is out, so it reaches the console

            Table.Boxes (Idx).Get (Status);
            Code := Exit_Code (Status);
            Output.Svc_Line (Svc, "exited with code " & Types.Img (Code), "exit");

            if Table.Registry.Stopping then
               Output.Svc_Line (Svc, "left during shutdown", "stop");
               exit Main_Loop;

            elsif not Table.Registry.Want (Idx) then
               Table.Registry.Set_State (Idx, Types.Stopped);
               Output.Svc_Line (Svc, "stopped on request", "stop");
               Count := 0;

            elsif Svc.Lives = Types.Never
              or else (Svc.Lives = Types.On_Failure and then Code = 0)
            then
               Table.Registry.Set_Want (Idx, False);
               Table.Registry.Set_State (Idx, Types.Finished);
               Output.Svc_Line (Svc, "will not be restarted (lives: "
                                & Types.Lives_Name (Svc.Lives) & ")", "oneshot");

            else
               --  Keep only crashes inside the window, then record this one.
               Now := Ada.Real_Time.Clock;
               declare
                  Kept : Natural := 0;
               begin
                  for I in 1 .. Count loop
                     if Ada.Real_Time.To_Duration (Now - Stamps (I)) < Types.Crash_Window then
                        Kept := Kept + 1;
                        Stamps (Kept) := Stamps (I);
                     end if;
                  end loop;
                  Count := Kept;
               end;
               Count := Count + 1;
               Stamps (Count) := Now;

               if Count > Types.Crash_Limit then
                  Table.Registry.Set_Want (Idx, False);
                  Table.Registry.Set_State (Idx, Types.Given_Up);
                  Output.Svc_Line (Svc, "crashed " & Types.Img (Types.Crash_Limit)
                                   & " times in 60s, giving up", "giveup");
               else
                  --  Cooldown doubles with each crash, capped at Max_Backoff.
                  Wait := Svc.Cooldown;
                  for K in 2 .. Count loop
                     exit when Wait >= Types.Max_Backoff;
                     Wait := Wait * 2;
                  end loop;
                  if Wait > Types.Max_Backoff then
                     Wait := Types.Max_Backoff;
                  end if;

                  Table.Registry.Set_State (Idx, Types.Cooling);
                  Output.Svc_Line (Svc, "restarting in " & Types.Img (Wait) & "s", "restart");

                  declare
                     Resume : constant Ada.Real_Time.Time :=
                       Ada.Real_Time.Clock + Ada.Real_Time.To_Time_Span (Duration (Wait));
                  begin
                     while Ada.Real_Time.Clock < Resume
                       and then Table.Registry.Want (Idx)
                       and then not Table.Registry.Stopping
                     loop
                        delay 0.1;
                     end loop;
                  end;
               end if;
            end if;
         end if;
      end loop Main_Loop;
   end Worker;

end Oxinit.Worker;
