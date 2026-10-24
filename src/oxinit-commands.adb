with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Interfaces.C;
with Oxinit.Config;
with Oxinit.Moods;
with Oxinit.Output;
with Oxinit.Grace;
with Oxinit.Posix;
with Oxinit.Table;
with Oxinit.Types;

package body Oxinit.Commands is

   use type Interfaces.C.int;

   package US renames Ada.Strings.Unbounded;

   LF : constant Character := ASCII.LF;

   function Find (Name : String) return Natural is
   begin
      for I in 1 .. Natural (Config.Service_Vectors.Length (Config.Services)) loop
         if US.To_String (Config.Service_Vectors.Element (Config.Services, I).Name) = Name then
            return I;
         end if;
      end loop;
      return 0;
   end Find;

   function Status_Text return String is
      Result : US.Unbounded_String;
      Count  : constant Natural := Natural (Config.Service_Vectors.Length (Config.Services));
   begin
      for I in 1 .. Count loop
         declare
            Svc   : constant Types.Service := Config.Service_Vectors.Element (Config.Services, I);
            Pid   : constant Interfaces.C.int := Table.Registry.Pid_Of (I);
            State : constant Types.Run_State := Table.Registry.State_Of (I);
            Line  : constant String :=
              US.To_String (Svc.Name) & ": " & Types.State_Name (State)
              & (if Pid > 0 then " (pid " & Types.Img (Integer (Pid)) & ")" else "")
              & ", mood " & Moods.Name (Svc.Mood)
              & ", furry " & (if Svc.Furry then "true" else "false");
         begin
            if I > 1 then
               US.Append (Result, LF);
            end if;
            US.Append (Result, Line);
         end;
      end loop;
      return US.To_String (Result);
   end Status_Text;

   function Run (Line : String) return String is
      Text : constant String := Ada.Strings.Fixed.Trim (Line, Ada.Strings.Both);
      Cut  : Natural := 0;
   begin
      if Text = "status" then
         return Status_Text;
      end if;

      for I in Text'Range loop
         if Text (I) = ' ' then
            Cut := I;
            exit;
         end if;
      end loop;

      if Cut = 0 then
         return "error: usage: status | stop NAME | start NAME";
      end if;

      declare
         Verb : constant String := Text (Text'First .. Cut - 1);
         Arg  : constant String := Ada.Strings.Fixed.Trim (Text (Cut + 1 .. Text'Last),
                                                           Ada.Strings.Both);
         Idx  : constant Natural := Find (Arg);
      begin
         if Verb /= "stop" and then Verb /= "start" then
            return "error: unknown command '" & Verb & "'. Try: status | stop NAME | start NAME";
         end if;
         if Idx = 0 then
            return "error: no such service '" & Arg & "'";
         end if;

         declare
            Svc : constant Types.Service := Config.Service_Vectors.Element (Config.Services, Idx);
            Pid : constant Interfaces.C.int := Table.Registry.Pid_Of (Idx);
            Ignored : Interfaces.C.int;
         begin
            if Verb = "stop" then
               Table.Registry.Set_Want (Idx, False);
               Output.Svc_Line (Svc, "stop requested by oxictl", "stop");
               if Pid > 0 then
                  --  Negative pid: the notice reaches the whole process group, descendants included.
                  Ignored := Posix.Kill (-Pid, Interfaces.C.int (Svc.Notice));
                  Grace.Arm (Svc, Idx, Pid);
               end if;
               return "ok: stopping " & Arg;
            else
               Table.Registry.Set_Want (Idx, True);
               Output.Svc_Line (Svc, "start requested by oxictl", "start");
               return "ok: starting " & Arg;
            end if;
         end;
      end;
   end Run;

end Oxinit.Commands;
