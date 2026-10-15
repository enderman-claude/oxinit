with Oxinit.Types;

--  All console output goes through here. Service lines are themed by mood.
package Oxinit.Output is
   --  ANSI color is used only when this is True (stdout is a terminal).
   procedure Set_Color (On : Boolean);
   --  Plain oxinit line: no mood, no color.
   procedure Olog (Text : String);
   --  Service line: "<prefix> <name> <text>", plus a meme when Kind is given.
   procedure Svc_Line (Svc : Types.Service; Text : String; Kind : String := "");
   --  Border rule printed once before a service's first line.
   procedure Svc_Rule (Svc : Types.Service);
end Oxinit.Output;
