with Ada.Characters.Handling;
with Ada.Strings.Unbounded;

package body Oxinit.Moods is

   package US renames Ada.Strings.Unbounded;
   use type Types.Mood_Kind;

   type Look is record
      Style, Border, Prefix : US.Unbounded_String;
   end record;

   function L (S, B, P : String) return Look is
     (Style  => US.To_Unbounded_String (S),
      Border => US.To_Unbounded_String (B),
      Prefix => US.To_Unbounded_String (P));

   Looks : constant array (Types.Mood_Kind) of Look :=
     [Types.Chill   => L ("36", "-", "~"),
      Types.Hyper   => L ("1;93", "*", "!!"),
      Types.Grumpy  => L ("31", "#", ">:("),
      Types.Sleepy  => L ("2;34", ".", "zz"),
      Types.Feral   => L ("35", "/\", ">>"),
      Types.Owo     => L ("95", "~", "owo"),
      Types.Sus     => L ("32", "?", "sus"),
      Types.Blessed => L ("97;43", "=", "(*)"),
      Types.Doomed  => L ("30;41", "x", "RIP")];

   function Name (M : Types.Mood_Kind) return String is
   begin
      return Ada.Characters.Handling.To_Lower (Types.Mood_Kind'Image (M));
   end Name;

   function All_Names return String is
      Result : US.Unbounded_String;
   begin
      for M in Types.Mood_Kind loop
         if M /= Types.Mood_Kind'First then
            US.Append (Result, ", ");
         end if;
         US.Append (Result, Name (M));
      end loop;
      return US.To_String (Result);
   end All_Names;

   function Parse (Text : String; M : out Types.Mood_Kind) return Boolean is
   begin
      for K in Types.Mood_Kind loop
         if Name (K) = Text then
            M := K;
            return True;
         end if;
      end loop;
      return False;
   end Parse;

   function Style (M : Types.Mood_Kind) return String is
     (US.To_String (Looks (M).Style));

   function Border (M : Types.Mood_Kind) return String is
     (US.To_String (Looks (M).Border));

   function Prefix (M : Types.Mood_Kind) return String is
     (US.To_String (Looks (M).Prefix));

end Oxinit.Moods;
