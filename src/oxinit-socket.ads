with Interfaces.C;

--  Unix stream socket helpers, used by the init (server side) and oxictl (client side).
package Oxinit.Socket is

   --  OXINIT_SOCKET if set, otherwise /run/oxinit.sock.
   function Path return String;

   --  Server: removes any stale socket file, binds, listens. -1 on failure.
   function Listen (P : String) return Interfaces.C.int;
   function Accept_Client (Listener : Interfaces.C.int) return Interfaces.C.int;

   --  Client: connects. -1 on failure.
   function Connect_To (P : String) return Interfaces.C.int;

   --  Reads up to the first newline (server) or to end of stream (client).
   function Read_Line (Fd : Interfaces.C.int) return String;
   function Read_All (Fd : Interfaces.C.int) return String;

   procedure Write_All (Fd : Interfaces.C.int; Text : String);
   procedure Close (Fd : Interfaces.C.int);
   procedure Remove (P : String);

end Oxinit.Socket;
