with Ada.Strings.Unbounded;
with Interfaces.C;
with Interfaces.C.Strings;
with Oxinit.Config;
with Oxinit.Posix;
with Oxinit.Types;
with System;

package body Oxinit.Launch is

   package US renames Ada.Strings.Unbounded;
   package CS renames Interfaces.C.Strings;

   use type Posix.C_Int;

   type Ptr_Array is access CS.chars_ptr_array;

   type Prepared_Rec is record
      Program     : CS.chars_ptr := CS.Null_Ptr;
      Cwd         : CS.chars_ptr := CS.Null_Ptr;
      Log         : CS.chars_ptr := CS.Null_Ptr;
      Log_To_File : Boolean := False;
      Argv        : Ptr_Array := null;
      Envp        : Ptr_Array := null;
      Uid         : Posix.C_Int := 0;
      Gid         : Posix.C_Int := 0;
   end record;

   Prepared : array (1 .. Types.Max_Services) of Prepared_Rec;

   --  NULL-terminated array of C strings built from a vector of text.
   function Make (Items : Types.Str_Vectors.Vector) return Ptr_Array is
      Count  : constant Natural := Natural (Items.Length);
      Result : constant Ptr_Array := new CS.chars_ptr_array (0 .. Interfaces.C.size_t (Count));
   begin
      for I in 1 .. Count loop
         Result (Interfaces.C.size_t (I - 1)) := CS.New_String (US.To_String (Items.Element (I)));
      end loop;
      Result (Interfaces.C.size_t (Count)) := CS.Null_Ptr;
      return Result;
   end Make;

   procedure Prepare is
      Count : constant Natural := Natural (Config.Service_Vectors.Length (Config.Services));
   begin
      for I in 1 .. Count loop
         declare
            Svc  : constant Types.Service := Config.Service_Vectors.Element (Config.Services, I);
            Argv : Types.Str_Vectors.Vector := Svc.Args;
         begin
            Argv.Prepend (Svc.Program);
            Prepared (I).Program := CS.New_String (US.To_String (Svc.Program));
            Prepared (I).Cwd := CS.New_String (US.To_String (Svc.Cwd));
            Prepared (I).Log := CS.New_String (US.To_String (Svc.Scoreboard));
            Prepared (I).Log_To_File := US.To_String (Svc.Scoreboard) /= "-";
            Prepared (I).Uid := Posix.C_Int (Svc.Uid);
            Prepared (I).Gid := Posix.C_Int (Svc.Gid);
            Prepared (I).Argv := Make (Argv);
            Prepared (I).Envp := Make (Svc.Env);
         end;
      end loop;
   end Prepare;

   procedure Exec_Child (Idx : Positive) is
      P   : Prepared_Rec renames Prepared (Idx);
      Fd  : Posix.C_Int;
      Old : System.Address;
      pragma Unreferenced (Old);
   begin
      --  Put default signal handling back so the service can be stopped normally.
      Old := Posix.Signal (Posix.Sigterm, System.Null_Address);
      Old := Posix.Signal (Posix.Sigint, System.Null_Address);

      if Posix.Setsid < 0 then
         null;
      end if;

      if P.Log_To_File then
         Fd := Posix.Open (P.Log, Posix.O_Wronly + Posix.O_Creat + Posix.O_Append, 8#644#);
         if Fd < 0 then
            Posix.Exit_Now (126);
         end if;
         if Posix.Dup2 (Fd, 1) < 0 or else Posix.Dup2 (Fd, 2) < 0 then
            Posix.Exit_Now (126);
         end if;
         if Posix.Close (Fd) < 0 then
            null;
         end if;
      end if;

      if Posix.Chdir (P.Cwd) /= 0 then
         Posix.Exit_Now (126);
      end if;
      --  The service runs with exactly its !party group. Supplementary groups
      --  inherited from oxinit are cleared before the primary group changes.
      if Posix.Setgroups (0, System.Null_Address) /= 0 then
         Posix.Exit_Now (126);
      end if;
      if Posix.Setgid (P.Gid) /= 0 then
         Posix.Exit_Now (126);
      end if;
      if Posix.Setuid (P.Uid) /= 0 then
         Posix.Exit_Now (126);
      end if;

      --  Execve only returns on failure.
      if Posix.Execve (P.Program, P.Argv.all (0)'Address, P.Envp.all (0)'Address) < 0 then
         null;
      end if;
      Posix.Exit_Now (127);
   end Exec_Child;

end Oxinit.Launch;
