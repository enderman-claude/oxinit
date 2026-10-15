with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Oxinit.Memes;
with Oxinit.Moods;

package body Oxinit.Output is

   package US renames Ada.Strings.Unbounded;

   Esc      : constant Character := Character'Val (27);
   Color_On : Boolean := False;

   --  Serialises writes so lines from different tasks never interleave.
   protected Console is
      procedure Emit (Line : String);
   end Console;

   protected body Console is
      procedure Emit (Line : String) is
      begin
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Output, Line);
         Ada.Text_IO.Flush (Ada.Text_IO.Standard_Output);
      end Emit;
   end Console;

   function Styled (Text, Style : String) return String is
   begin
      if Color_On and then Style'Length > 0 then
         return Esc & "[" & Style & "m" & Text & Esc & "[0m";
      end if;
      return Text;
   end Styled;

   procedure Set_Color (On : Boolean) is
   begin
      Color_On := On;
   end Set_Color;

   procedure Olog (Text : String) is
   begin
      Console.Emit ("oxinit: " & Text);
   end Olog;

   procedure Svc_Line (Svc : Types.Service; Text : String; Kind : String := "") is
      Name : constant String := US.To_String (Svc.Name);
      M    : constant Types.Mood_Kind := Svc.Mood;
      Line : constant String := Moods.Prefix (M) & " " & Name & " " & Text;
      --  Seed: name, mood and species, so each service gets a stable line.
      --  Species is only used for furry services; everyone else gets the generic pool.
      Species : constant String :=
        (if Svc.Furry then US.To_String (Svc.Fursona.Species) else "");
      Seed    : constant String := Name & "|" & Types.Mood_Kind'Image (M);
   begin
      if Kind = "" then
         Console.Emit (Styled (Line, Moods.Style (M)));
      else
         Console.Emit (Styled (Line & " | " & Memes.Pick (Kind, Seed, Species), Moods.Style (M)));
      end if;
   end Svc_Line;

   procedure Svc_Rule (Svc : Types.Service) is
      M : constant Types.Mood_Kind := Svc.Mood;
      B : constant String := Moods.Border (M);
      Rule : constant String := B & B & B & B;
   begin
      Console.Emit (Styled (Rule, Moods.Style (M)));
   end Svc_Rule;

end Oxinit.Output;
