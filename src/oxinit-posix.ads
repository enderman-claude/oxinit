with Interfaces.C;
with Interfaces.C.Strings;
with System;

--  Thin imports of the POSIX calls oxinit needs. No C source, just bindings.
package Oxinit.Posix is

   subtype C_Int is Interfaces.C.int;

   Sigint  : constant C_Int := 2;
   Sigkill : constant C_Int := 9;
   Sigterm : constant C_Int := 15;

   O_Wronly : constant C_Int := 1;
   O_Creat  : constant C_Int := 64;
   O_Append : constant C_Int := 1024;

   function Fork return C_Int;
   pragma Import (C, Fork, "fork");

   function Waitpid (Pid : C_Int; Status : System.Address; Options : C_Int) return C_Int;
   pragma Import (C, Waitpid, "waitpid");

   function Kill (Pid : C_Int; Sig : C_Int) return C_Int;
   pragma Import (C, Kill, "kill");

   function Getpid return C_Int;
   pragma Import (C, Getpid, "getpid");

   function Isatty (Fd : C_Int) return C_Int;
   pragma Import (C, Isatty, "isatty");

   function Setsid return C_Int;
   pragma Import (C, Setsid, "setsid");

   function Setuid (Uid : C_Int) return C_Int;
   pragma Import (C, Setuid, "setuid");

   function Setgid (Gid : C_Int) return C_Int;
   pragma Import (C, Setgid, "setgid");

   function Chdir (Path : Interfaces.C.Strings.chars_ptr) return C_Int;
   pragma Import (C, Chdir, "chdir");

   function Open (Path : Interfaces.C.Strings.chars_ptr; Flags : C_Int; Mode : C_Int)
      return C_Int;
   pragma Import (C, Open, "open");

   function Dup2 (Old_Fd, New_Fd : C_Int) return C_Int;
   pragma Import (C, Dup2, "dup2");

   function Close (Fd : C_Int) return C_Int;
   pragma Import (C, Close, "close");

   function Execve (Path : Interfaces.C.Strings.chars_ptr; Argv, Envp : System.Address)
      return C_Int;
   pragma Import (C, Execve, "execve");

   procedure Exit_Now (Code : C_Int);
   pragma Import (C, Exit_Now, "_exit");
   pragma No_Return (Exit_Now);

   function Signal (Sig : C_Int; Handler : System.Address) return System.Address;
   pragma Import (C, Signal, "signal");

   procedure Sync;
   pragma Import (C, Sync, "sync");

   --  Linux reboot(2) via glibc. Cmd 16#4321FEDC# powers off.
   function Reboot (Cmd : C_Int) return C_Int;
   pragma Import (C, Reboot, "reboot");

   Reboot_Power_Off : constant C_Int := 16#4321FEDC#;

end Oxinit.Posix;
