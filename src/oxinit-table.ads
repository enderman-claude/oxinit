with Interfaces.C;
with Oxinit.Types;

--  Shared process state. Registry guards the pid table and the fork step, so the
--  reaper can never see a child before it is registered. Boxes hand each exit
--  status from the reaper to the worker that owns the service.
package Oxinit.Table is

   protected type Mailbox is
      procedure Put (V : Interfaces.C.int);
      entry Get (V : out Interfaces.C.int);
   private
      Full  : Boolean := False;
      Value : Interfaces.C.int := 0;
   end Mailbox;

   Boxes : array (1 .. Types.Max_Services) of Mailbox;

   type Slot_Array is array (1 .. Types.Max_Services) of Interfaces.C.int;

   protected Registry is
      --  Forks and registers the child. Ok is False if stopping.
      procedure Spawn (Idx : Positive; Pid : out Interfaces.C.int; Ok : out Boolean);
      --  Finds and removes the service that owns Pid. Idx = 0 if none.
      procedure Take (Pid : Interfaces.C.int; Idx : out Natural);
      function Pid_Of (Idx : Positive) return Interfaces.C.int;
      --  After this, Spawn refuses. Called once, at shutdown.
      procedure Begin_Stop;
      function Stopping return Boolean;
   private
      Stop_Flag : Boolean := False;
      Slot      : Slot_Array := [others => 0];
   end Registry;

end Oxinit.Table;
