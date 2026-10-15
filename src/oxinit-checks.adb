with Ada.Strings.Unbounded;

package body Oxinit.Checks is

   package US renames Ada.Strings.Unbounded;

   function Text (Raw : Parser.Raw_Service; F : Types.Field_Id) return String is
     (US.To_String (Raw.Values (F)));

   procedure Bad (Raw : Parser.Raw_Service; F : Types.Field_Id; Msg : String) is
   begin
      raise Types.Config_Error with
        "line " & Types.Img (Raw.Lines (F)) & ": !" & Types.Field_Name (F) & ": " & Msg;
   end Bad;

   function Is_Absolute (S : String) return Boolean is
     (S'Length > 0 and then S (S'First) = '/');

   --  "2s" -> 2. Whole seconds only.
   function Seconds (Raw : Parser.Raw_Service; F : Types.Field_Id) return Natural is
      V     : constant String := Text (Raw, F);
      Total : Natural := 0;
   begin
      if V'Length < 2 or else V (V'Last) /= 's' then
         Bad (Raw, F, "must be whole seconds like 2s, got '" & V & "'");
      end if;
      for C of V (V'First .. V'Last - 1) loop
         if C not in '0' .. '9' then
            Bad (Raw, F, "must be whole seconds like 2s, got '" & V & "'");
         end if;
         if Total > 99_999_999 then
            Bad (Raw, F, "too large");
         end if;
         Total := Total * 10 + (Character'Pos (C) - Character'Pos ('0'));
      end loop;
      return Total;
   end Seconds;

   --  Splits on blanks. Each token must be KEY=VALUE with a non-empty key.
   procedure Parse_Loadout (Raw : Parser.Raw_Service; Env : in out Types.Str_Vectors.Vector) is
      V : constant String := Text (Raw, Types.Loadout);
      I : Natural;
   begin
      if V = "-" then
         return;
      end if;
      I := V'First;
      while I <= V'Last loop
         if V (I) = ' ' or else V (I) = ASCII.HT then
            I := I + 1;
         else
            declare
               J   : Natural := I;
               Eq  : Natural := 0;
            begin
               while J <= V'Last and then V (J) /= ' ' and then V (J) /= ASCII.HT loop
                  J := J + 1;
               end loop;
               declare
                  Tok : constant String := V (I .. J - 1);
               begin
                  for K in Tok'Range loop
                     if Tok (K) = '=' then
                        Eq := K;
                        exit;
                     end if;
                  end loop;
                  if Eq <= Tok'First then
                     Bad (Raw, Types.Loadout, "'" & Tok & "' is not KEY=VALUE");
                  end if;
                  Env.Append (US.To_Unbounded_String (Tok));
               end;
               I := J;
            end;
         end if;
      end loop;
   end Parse_Loadout;

end Oxinit.Checks;
