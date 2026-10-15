with Interfaces.C;
with Oxinit.Output;
with Oxinit.Posix;
with Oxinit.Table;
with Oxinit.Types;

package body Oxinit.Reaping is

   use type Interfaces.C.int;

   task body Reaper is
      Status : aliased Interfaces.C.int;
      Pid    : Interfaces.C.int;
      Idx    : Natural;
   begin
      loop
         Pid := Posix.Waitpid (-1, Status'Address, 0);
         if Pid < 0 then
            --  No children right now (ECHILD). Not an error for an init.
            delay 0.1;
         else
            Table.Registry.Take (Pid, Idx);
            if Idx > 0 then
               Table.Boxes (Idx).Put (Status);
            else
               Output.Olog ("reaped orphan pid " & Types.Img (Integer (Pid)));
            end if;
         end if;
      end loop;
   end Reaper;

end Oxinit.Reaping;
