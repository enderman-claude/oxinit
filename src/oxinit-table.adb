with Oxinit.Launch;
with Oxinit.Posix;

package body Oxinit.Table is

   use type Interfaces.C.int;

   protected body Mailbox is
      procedure Put (V : Interfaces.C.int) is
      begin
         Value := V;
         Full := True;
      end Put;

      entry Get (V : out Interfaces.C.int) when Full is
      begin
         V := Value;
         Full := False;
      end Get;
   end Mailbox;

   protected body Registry is

      procedure Spawn (Idx : Positive; Pid : out Interfaces.C.int; Ok : out Boolean) is
         Child : Interfaces.C.int;
      begin
         Pid := 0;
         Ok := False;
         if Stop_Flag then
            return;
         end if;
         Child := Posix.Fork;
         if Child = 0 then
            Launch.Exec_Child (Idx);   --  child: never returns
         elsif Child > 0 then
            Slot (Idx) := Child;
            Pid := Child;
            Ok := True;
         end if;
      end Spawn;

      procedure Take (Pid : Interfaces.C.int; Idx : out Natural) is
      begin
         Idx := 0;
         for I in Slot'Range loop
            if Slot (I) = Pid then
               Idx := I;
               Slot (I) := 0;
               return;
            end if;
         end loop;
      end Take;

      function Pid_Of (Idx : Positive) return Interfaces.C.int is
        (Slot (Idx));

      procedure Begin_Stop is
      begin
         Stop_Flag := True;
      end Begin_Stop;

      function Stopping return Boolean is
        (Stop_Flag);

   end Registry;

end Oxinit.Table;
