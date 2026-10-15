with Oxinit.Types;

--  All oxinit output goes through here, in two channels, the way pintinit does it.
--  Before boot finishes, everything goes to the console. After that, routine
--  lines (service starts, restarts, crashes, oxictl requests) go to the log file
--  instead, so the console stays readable. Lines marked Important (shutdown,
--  fatal errors) always go to the console as well.
--
--  The log file is $OXINIT_LOG, or /var/log/oxinit.log when that is unset. If the
--  log cannot be opened, routine lines fall back to the console so nothing is lost.
package Oxinit.Output is

   --  ANSI color is used only when this is True (stdout is a terminal).
   --  Colors never go into the log file.
   procedure Set_Color (On : Boolean);

   --  Call once boot is complete. From then on, routine lines go to the log.
   procedure Set_Booted;

   --  Plain oxinit line: no mood, no color.
   procedure Olog (Text : String);

   --  Plain oxinit line that stays on the console after boot too.
   procedure Olog_Important (Text : String);

   --  Service line: "<prefix> <name> <text>", plus a meme when Kind is given.
   --  Important forces the line onto the console even after boot.
   procedure Svc_Line (Svc       : Types.Service;
                       Text      : String;
                       Kind      : String := "";
                       Important : Boolean := False);

   --  Border rule printed once before a service's first line.
   procedure Svc_Rule (Svc : Types.Service);

end Oxinit.Output;
