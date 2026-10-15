with Oxinit.Types;

--  Fixed visual themes. Same mood, same look, every time.
package Oxinit.Moods is
   function Name (M : Types.Mood_Kind) return String;
   function All_Names return String;
   --  Returns False if Text is not a known mood.
   function Parse (Text : String; M : out Types.Mood_Kind) return Boolean;
   function Style (M : Types.Mood_Kind) return String;
   function Border (M : Types.Mood_Kind) return String;
   function Prefix (M : Types.Mood_Kind) return String;
end Oxinit.Moods;
