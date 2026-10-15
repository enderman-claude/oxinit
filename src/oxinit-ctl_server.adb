with Interfaces.C;
with Oxinit.Commands;
with Oxinit.Output;
with Oxinit.Socket;

package body Oxinit.Ctl_Server is

   use type Interfaces.C.int;

   task body Server is
      Listener : Interfaces.C.int;
      Client   : Interfaces.C.int;
   begin
      accept Start;

      Listener := Socket.Listen (Socket.Path);
      if Listener < 0 then
         Output.Olog ("cannot listen on " & Socket.Path & ", oxictl is unavailable");
      else
         loop
            Client := Socket.Accept_Client (Listener);
            if Client >= 0 then
               declare
                  Reply : constant String := Commands.Run (Socket.Read_Line (Client));
               begin
                  Socket.Write_All (Client, Reply);
               end;
               Socket.Close (Client);
            else
               delay 0.1;
            end if;
         end loop;
      end if;
   end Server;

end Oxinit.Ctl_Server;
