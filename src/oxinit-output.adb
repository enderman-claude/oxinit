with Ada.Environment_Variables;
with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Oxinit.Memes;
with Oxinit.Moods;

package body Oxinit.Output is

   package US renames Ada.Strings.Unbounded;

   Esc      : constant Character := Character'Val (27);
   Color_On : Boolean := False;
   Booted   : Boolean := False;

   --  Serialises console writes so lines from different tasks never interleave.
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

   Log_File  : Ada.Text_IO.File_Type;
   Log_Ready : Boolean := False;   --  only touched inside protected Log
   Log_Tried : Boolean := False;   --  the log is opened once, on first write

   --  Opens the log once, on first use. Appends to an existing file.
   procedure Open_Log is
      Path : constant String :=
        (if Ada.Environment_Variables.Exists ("OXINIT_LOG")
         then Ada.Environment_Variables.Value ("OXINIT_LOG")
         else "/var/log/oxinit.log");
   begin
      begin
         Ada.Text_IO.Open (Log_File, Ada.Text_IO.Append_File, Path);
      exception
         when others =>
            begin
               Ada.Text_IO.Create (Log_File, Ada.Text_IO.Out_File, Path);
            exception
               when others => null;
            end;
      end;
      Log_Ready := Ada.Text_IO.Is_Open (Log_File);
   end Open_Log;

   protected Log is
      procedure Write (Line : String; Written : out Boolean);
   end Log;

   protected body Log is
      procedure Write (Line : String; Written : out Boolean) is
      begin
         if not Log_Tried then
            Log_Tried := True;
            Open_Log;
         end if;
         if Log_Ready then
            Ada.Text_IO.Put_Line (Log_File, Line);
            Ada.Text_IO.Flush (Log_File);
            Written := True;
         else
            Written := False;
         end if;
      end Write;
   end Log;

   function Styled (Text, Style : String) return String is
   begin
      if Color_On and then Style'Length > 0 then
         return Esc & "[" & Style & "m" & Text & Esc & "[0m";
      end if;
      return Text;
   end Styled;

   --  Sends one line to the right channel.
   --  Plain is the text for the log file, Shown is the text for the console.
   procedure Route (Plain, Shown : String; Important : Boolean) is
      Written : Boolean;
   begin
      if not Booted then
         Console.Emit (Shown);
         return;
      end if;

      Log.Write (Plain, Written);
      if Important or else not Written then
         Console.Emit (Shown);
      end if;
   end Route;

   procedure Set_Color (On : Boolean) is
   begin
      Color_On := On;
   end Set_Color;

   procedure Set_Booted is
   begin
      Booted := True;
   end Set_Booted;

   procedure Olog (Text : String) is
      Line : constant String := "oxinit: " & Text;
   begin
      Route (Line, Line, Important => False);
   end Olog;

   procedure Olog_Important (Text : String) is
      Line : constant String := "oxinit: " & Text;
   begin
      Route (Line, Line, Important => True);
   end Olog_Important;

   procedure Svc_Line (Svc       : Types.Service;
                       Text      : String;
                       Kind      : String := "";
                       Important : Boolean := False)
   is
      Name : constant String := US.To_String (Svc.Name);
      M    : constant Types.Mood_Kind := Svc.Mood;
      Line : constant String := Moods.Prefix (M) & " " & Name & " " & Text;
      --  Seed: name, mood and species, so each service gets a stable line.
      --  Species is only used for furry services; everyone else gets the generic pool.
      Species : constant String :=
        (if Svc.Furry then US.To_String (Svc.Fursona.Species) else "");
      Seed    : constant String := Name & "|" & Types.Mood_Kind'Image (M);
      Plain   : constant String :=
        (if Kind = "" then Line else Line & " | " & Memes.Pick (Kind, Seed, Species));
   begin
      Route (Plain, Styled (Plain, Moods.Style (M)), Important);
   end Svc_Line;

   procedure Svc_Rule (Svc : Types.Service) is
      M    : constant Types.Mood_Kind := Svc.Mood;
      B    : constant String := Moods.Border (M);
      Rule : constant String := B & B & B & B;
   begin
      Route (Rule, Styled (Rule, Moods.Style (M)), Important => False);
   end Svc_Rule;

end Oxinit.Output;
