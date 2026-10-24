with Interfaces.C;

with Oxinit.Types;

--  Enforces a service's !grace after a stop request. The eviction notice goes out at once;
--  if the process is still the same one when the grace period ends, its process group gets
--  SIGKILL. Used by oxictl stop; global shutdown does its own timing in the main program.
package Oxinit.Grace is

   procedure Arm (Svc : Oxinit.Types.Service; Idx : Positive; Pid : Interfaces.C.int);

end Oxinit.Grace;
