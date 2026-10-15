--  Accepts oxictl connections on the control socket, one request per connection.
--  Call Server.Start once the services are loaded.
package Oxinit.Ctl_Server is
   task Server is
      entry Start;
   end Server;
end Oxinit.Ctl_Server;
