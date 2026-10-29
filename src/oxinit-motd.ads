--  Writes /etc/motd before a special-name service (login, graphical, shell,
--  booted) boots, with fleet counts: furries, non-furries, crashes, and spies
--  (issue #15). The path is $OXINIT_MOTD, or /etc/motd when that is unset.
package Oxinit.Motd is

   --  Called by a worker each time its service exits with a nonzero code or a
   --  signal while oxinit still wants it running. Counts as one crash.
   procedure Mark_Crashed (Idx : Positive);

   --  Writes the motd once, on the first call. Later calls do nothing.
   procedure Write_Once;

end Oxinit.Motd;
