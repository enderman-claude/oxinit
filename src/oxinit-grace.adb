
with Oxinit.Output;
with Oxinit.Posix;
with Oxinit.Table;

package body Oxinit.Grace is

   use type Interfaces.C.int;

   type Service_Access is access all Oxinit.Types.Service;

   --  One task per stop request. The grace period is relative to the moment the task starts,
   --  which is the moment the eviction notice goes out. The task exits when it is done.
   --  Discriminants must be discrete or access types, so the service is passed by reference.
   task type Killer (Svc   : Service_Access;
                     Idx   : Positive;
                     Pid   : Interfaces.C.int;
                     Grace : Natural);

   task body Killer is
      Ignored : Interfaces.C.int;
   begin
      delay Duration (Grace);
      --  Only act if the same child is still registered. A child that left, or a slot that
      --  now holds a different pid, is left alone.
      if Oxinit.Table.Registry.Pid_Of (Idx) = Pid then
         Oxinit.Output.Svc_Line (Svc.all,
                                 "did not leave within its grace period, forced removal (SIGKILL)",
                                 "kill", Important => True);
         --  Negative pid: every process in the service's group (setsid made it the leader).
         Ignored := Oxinit.Posix.Kill (-Pid, Oxinit.Posix.Sigkill);
      end if;
   end Killer;

   type Killer_Access is access Killer;

   procedure Arm (Svc : Oxinit.Types.Service; Idx : Positive; Pid : Interfaces.C.int) is
      Svc_Ref  : constant Service_Access := new Oxinit.Types.Service'(Svc);
      --  The task runs on its own; the access value is never needed again.
      Task_Ref : Killer_Access := new Killer (Svc_Ref, Idx, Pid, Svc.Grace);
      pragma Unreferenced (Task_Ref);
   begin
      null;
   end Arm;

end Oxinit.Grace;
