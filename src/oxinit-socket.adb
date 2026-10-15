with Ada.Environment_Variables;
with Ada.Strings.Unbounded;
with Interfaces;
with Interfaces.C.Strings;
with System;

package body Oxinit.Socket is

   use type Interfaces.C.int;
   use type Interfaces.C.long;

   package CS renames Interfaces.C.Strings;
   package US renames Ada.Strings.Unbounded;

   AF_UNIX     : constant Interfaces.C.int := 1;
   SOCK_STREAM : constant Interfaces.C.int := 1;
   LF          : constant Character := ASCII.LF;

   function C_Socket (Domain, Kind, Proto : Interfaces.C.int) return Interfaces.C.int;
   pragma Import (C, C_Socket, "socket");

   function C_Bind (Fd : Interfaces.C.int; Addr : System.Address; Len : Interfaces.C.int)
      return Interfaces.C.int;
   pragma Import (C, C_Bind, "bind");

   function C_Connect (Fd : Interfaces.C.int; Addr : System.Address; Len : Interfaces.C.int)
      return Interfaces.C.int;
   pragma Import (C, C_Connect, "connect");

   function C_Listen (Fd : Interfaces.C.int; Backlog : Interfaces.C.int) return Interfaces.C.int;
   pragma Import (C, C_Listen, "listen");

   function C_Accept (Fd : Interfaces.C.int; Addr, Len : System.Address) return Interfaces.C.int;
   pragma Import (C, C_Accept, "accept");

   function C_Read (Fd : Interfaces.C.int; Buf : System.Address; Count : Interfaces.C.size_t)
      return Interfaces.C.long;
   pragma Import (C, C_Read, "read");

   function C_Write (Fd : Interfaces.C.int; Buf : System.Address; Count : Interfaces.C.size_t)
      return Interfaces.C.long;
   pragma Import (C, C_Write, "write");

   function C_Close (Fd : Interfaces.C.int) return Interfaces.C.int;
   pragma Import (C, C_Close, "close");

   function C_Unlink (Path : CS.chars_ptr) return Interfaces.C.int;
   pragma Import (C, C_Unlink, "unlink");

   function C_Chmod (Path : CS.chars_ptr; Mode : Interfaces.C.int) return Interfaces.C.int;
   pragma Import (C, C_Chmod, "chmod");

   --  struct sockaddr_un: 2-byte family, then up to 108 bytes of path.
   type Addr_Buf is array (1 .. 110) of Interfaces.Unsigned_8;

   function Make_Addr (P : String; Buf : out Addr_Buf) return Interfaces.C.int is
   begin
      Buf := [others => 0];
      Buf (1) := 1;  --  AF_UNIX, little-endian low byte
      for I in P'Range loop
         Buf (2 + (I - P'First) + 1) := Interfaces.Unsigned_8 (Character'Pos (P (I)));
      end loop;
      return Interfaces.C.int (2 + P'Length + 1);
   end Make_Addr;

   function Path return String is
   begin
      if Ada.Environment_Variables.Exists ("OXINIT_SOCKET") then
         return Ada.Environment_Variables.Value ("OXINIT_SOCKET");
      end if;
      return "/run/oxinit.sock";
   end Path;

   procedure Remove (P : String) is
      C : CS.chars_ptr := CS.New_String (P);
      R : Interfaces.C.int;
      pragma Unreferenced (R);
   begin
      R := C_Unlink (C);
      CS.Free (C);
   end Remove;

   function Listen (P : String) return Interfaces.C.int is
      Buf : Addr_Buf;
      Len : constant Interfaces.C.int := Make_Addr (P, Buf);
      Fd  : Interfaces.C.int;
      C   : CS.chars_ptr := CS.New_String (P);
      R   : Interfaces.C.int;
   begin
      Remove (P);
      Fd := C_Socket (AF_UNIX, SOCK_STREAM, 0);
      if Fd < 0 then
         CS.Free (C);
         return -1;
      end if;
      if C_Bind (Fd, Buf'Address, Len) < 0 then
         R := C_Close (Fd);
         CS.Free (C);
         return -1;
      end if;
      R := C_Chmod (C, 8#600#);   --  only root (the init) talks to the socket
      CS.Free (C);
      if C_Listen (Fd, 8) < 0 then
         R := C_Close (Fd);
         return -1;
      end if;
      return Fd;
   end Listen;

   function Accept_Client (Listener : Interfaces.C.int) return Interfaces.C.int is
   begin
      return C_Accept (Listener, System.Null_Address, System.Null_Address);
   end Accept_Client;

   function Connect_To (P : String) return Interfaces.C.int is
      Buf : Addr_Buf;
      Len : constant Interfaces.C.int := Make_Addr (P, Buf);
      Fd  : constant Interfaces.C.int := C_Socket (AF_UNIX, SOCK_STREAM, 0);
      R   : Interfaces.C.int;
   begin
      if Fd < 0 then
         return -1;
      end if;
      if C_Connect (Fd, Buf'Address, Len) < 0 then
         R := C_Close (Fd);
         return -1;
      end if;
      return Fd;
   end Connect_To;

   function Read_Impl (Fd : Interfaces.C.int; Stop_On_Lf : Boolean) return String is
      Buf    : String (1 .. 512);
      Result : US.Unbounded_String;
      N      : Interfaces.C.long;
   begin
      loop
         N := C_Read (Fd, Buf'Address, 512);
         exit when N <= 0;
         for I in 1 .. Integer (N) loop
            if Stop_On_Lf and then Buf (I) = LF then
               return US.To_String (Result);
            end if;
            US.Append (Result, Buf (I));
         end loop;
      end loop;
      return US.To_String (Result);
   end Read_Impl;

   function Read_Line (Fd : Interfaces.C.int) return String is
     (Read_Impl (Fd, True));

   function Read_All (Fd : Interfaces.C.int) return String is
     (Read_Impl (Fd, False));

   procedure Write_All (Fd : Interfaces.C.int; Text : String) is
      Pos : Natural := Text'First;
      N   : Interfaces.C.long;
   begin
      while Pos <= Text'Last loop
         N := C_Write (Fd, Text (Pos)'Address,
                       Interfaces.C.size_t (Text'Last - Pos + 1));
         exit when N <= 0;
         Pos := Pos + Integer (N);
      end loop;
   end Write_All;

   procedure Close (Fd : Interfaces.C.int) is
      R : Interfaces.C.int;
      pragma Unreferenced (R);
   begin
      R := C_Close (Fd);
   end Close;

end Oxinit.Socket;
