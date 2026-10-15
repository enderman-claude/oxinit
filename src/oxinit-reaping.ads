--  The only task that calls waitpid. Hands each exit status to the worker
--  that owns the pid. Unknown pids are orphans and get logged.
package Oxinit.Reaping is
   task Reaper;
end Oxinit.Reaping;
