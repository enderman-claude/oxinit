with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

--  Shared types and constants used across oxinit.
package Oxinit.Types is

   package US renames Ada.Strings.Unbounded;

   Max_Services : constant := 64;
   Crash_Window : constant Duration := 60.0;
   Crash_Limit  : constant := 5;
   Max_Backoff  : constant := 30;

   Config_Error : exception;

   type Mood_Kind is (Chill, Hyper, Grumpy, Sleepy, Feral, Owo, Sus, Blessed, Doomed);
   type Lives_Kind is (Always, Never, On_Failure);

   --  What a service is doing right now, as reported by oxictl status.
   type Run_State is (Starting, Running, Cooling, Stopped, Finished, Given_Up);

   type Field_Id is
     (Mood, Summon, Incant, Arena, Role, Party, Loadout, Lives, Cooldown,
      Eviction_Notice, Grace, Scoreboard, Amiafurry,
      Fursona_Name, Fursona_Description, Fursona_Species);

   use type US.Unbounded_String;

   package Str_Vectors is new Ada.Containers.Vectors (Positive, US.Unbounded_String);

   type Fursona_Rec is record
      Name, Description, Species : US.Unbounded_String;
   end record;

   type Service is record
      Name       : US.Unbounded_String;
      Mood       : Mood_Kind;
      Program    : US.Unbounded_String;
      Args       : Str_Vectors.Vector;
      Cwd        : US.Unbounded_String;
      User       : US.Unbounded_String;
      Uid        : Natural;
      Group      : US.Unbounded_String;
      Gid        : Natural;
      Env        : Str_Vectors.Vector;
      Lives      : Lives_Kind;
      Cooldown   : Natural;
      Notice     : Natural;
      Grace      : Natural;
      Scoreboard : US.Unbounded_String;
      Furry      : Boolean;
      Fursona    : Fursona_Rec;
   end record;

   --  Config field name as written in files, e.g. Eviction_Notice -> "eviction-notice".
   function Field_Name (F : Field_Id) return String;
   function Lives_Name (L : Lives_Kind) return String;
   function State_Name (S : Run_State) return String;
   --  Signal number for a name without SIG; 0 if unsupported.
   function Signal_Number (Name : String) return Natural;
   function Img (N : Integer) return String;

end Oxinit.Types;
