--  SIGTERM and SIGINT set Stop_Requested. The main loop does the shutdown.
package Oxinit.Signals is
   Stop_Requested : Boolean := False with Atomic;
   procedure Install;
end Oxinit.Signals;
