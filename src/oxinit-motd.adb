with Ada.Characters.Handling;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Streams.Stream_IO;
with Oxinit.Config;
with Oxinit.Output;
with Oxinit.Types;

package body Oxinit.Motd is

   package US renames Ada.Strings.Unbounded;

   type Flag_Array is array (1 .. Types.Max_Services) of Boolean;

   protected Crashes is
      procedure Set (Idx : Positive);
      function Get (Idx : Positive) return Boolean;
   private
      Flags : Flag_Array := (others => False);
   end Crashes;

   protected body Crashes is
      procedure Set (Idx : Positive) is
      begin
         Flags (Idx) := True;
      end Set;

      function Get (Idx : Positive) return Boolean is
      begin
         return Flags (Idx);
      end Get;
   end Crashes;

   protected Gate is
      --  True only for the first caller.
      procedure Claim (First : out Boolean);
   private
      Taken : Boolean := False;
   end Gate;

   protected body Gate is
      procedure Claim (First : out Boolean) is
      begin
         First := not Taken;
         Taken := True;
      end Claim;
   end Gate;

   procedure Mark_Crashed (Idx : Positive) is
   begin
      Crashes.Set (Idx);
   end Mark_Crashed;

   function Img (N : Natural) return String is
      S : constant String := Ada.Strings.Fixed.Trim (Natural'Image (N), Ada.Strings.Left);
   begin
      return S;
   end Img;

   function GCD (A, B : Natural) return Natural is
   begin
      if B = 0 then
         return A;
      end if;
      return GCD (B, A mod B);
   end GCD;

   --  Reduced to lowest terms. 0:0 stays 0:0.
   function Ratio (First, Second : Natural) return String is
      G : constant Natural := GCD (First, Second);
   begin
      if G = 0 then
         return "0:0";
      end if;
      return Img (First / G) & ":" & Img (Second / G);
   end Ratio;

   function Is_Spy (Svc : Types.Service) return Boolean is
     (Ada.Strings.Fixed.Index
        (Ada.Characters.Handling.To_Lower (US.To_String (Svc.Fursona.Species)), "spy") > 0);

   function Motd_Path return String is
     (if Ada.Environment_Variables.Exists ("OXINIT_MOTD")
      then Ada.Environment_Variables.Value ("OXINIT_MOTD")
      else "/etc/motd");

   --  Label padded to one column, then the value. One line, ending in LF.
   Label_Width : constant := 21;

   function Row (Label, Value : String) return String is
     (Ada.Strings.Fixed.Head (Label, Label_Width) & Value & ASCII.LF);

   function Text return String is
      Furries, Plain, Furry_Crashed, Plain_Crashed, Spies : Natural := 0;
      Total : constant Natural := Natural (Config.Service_Vectors.Length (Config.Services));
   begin
      for I in 1 .. Total loop
         declare
            Svc     : constant Types.Service := Config.Service_Vectors.Element (Config.Services, I);
            Crashed : constant Boolean := Crashes.Get (I);
         begin
            if Svc.Furry then
               Furries := Furries + 1;
               if Crashed then
                  Furry_Crashed := Furry_Crashed + 1;
               end if;
               if Is_Spy (Svc) then
                  Spies := Spies + 1;
               end if;
            else
               Plain := Plain + 1;
               if Crashed then
                  Plain_Crashed := Plain_Crashed + 1;
               end if;
            end if;
         end;
      end loop;

      return
        Row ("furries:", Img (Furries))
        & Row ("non furries:", Img (Plain))
        & Row ("furry ratio:", Ratio (Furries, Plain))
        & Row ("furries crashed:", Img (Furry_Crashed))
        & Row ("non furries crashed:", Img (Plain_Crashed))
        & Row ("crash ratio:", Ratio (Furry_Crashed, Plain_Crashed))
        & Row ("total crashed:", Img (Furry_Crashed + Plain_Crashed))
        & (if Spies > 0 then Row ("suspicious furries:", Img (Spies)) else "");
   end Text;

   procedure Write_Once is
      First : Boolean;
      F     : Ada.Streams.Stream_IO.File_Type;
      Path  : constant String := Motd_Path;
   begin
      Gate.Claim (First);
      if not First then
         return;
      end if;

      begin
         --  Raw bytes, so the file holds exactly the text built above.
         Ada.Streams.Stream_IO.Create (F, Ada.Streams.Stream_IO.Out_File, Path);
         String'Write (Ada.Streams.Stream_IO.Stream (F), Text);
         Ada.Streams.Stream_IO.Close (F);
      exception
         when others =>
            Oxinit.Output.Olog_Important ("cannot write " & Path & ", continuing without a motd");
      end;
   end Write_Once;

end Oxinit.Motd;
