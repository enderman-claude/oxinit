--  Builds the C-side data for each service before any fork, so the child
--  does nothing but set up and exec.
package Oxinit.Launch is
   procedure Prepare;
   --  Runs in the forked child. Never returns.
   procedure Exec_Child (Idx : Positive);
end Oxinit.Launch;
