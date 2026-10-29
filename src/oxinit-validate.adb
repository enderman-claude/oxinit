with Ada.Strings.Unbounded;
with Oxinit.Accounts;
with Oxinit.Checks;
with Oxinit.Moods;
with Oxinit.Shell;

package body Oxinit.Validate is

   package US renames Ada.Strings.Unbounded;

   use Oxinit.Checks;

   function Starts_With (S, Prefix : String) return Boolean is
   begin
      return S'Length >= Prefix'Length
        and then S (S'First .. S'First + Prefix'Length - 1) = Prefix;
   end Starts_With;

   function Build (Raw : Parser.Raw_Service) return Types.Service is
      Svc     : Types.Service;
      Missing : US.Unbounded_String;
      Found   : Boolean;
      Uid     : Natural := 0;
      Gid     : Natural := 0;
      Furry   : Boolean;
      Dashed  : constant String := "-";
   begin
      --  Every field is required. Report all missing ones at once.
      for F in Types.Field_Id loop
         if not Raw.Seen (F) then
            if US.Length (Missing) > 0 then
               US.Append (Missing, ", ");
            end if;
            US.Append (Missing, "!" & Types.Field_Name (F));
         end if;
      end loop;
      if US.Length (Missing) > 0 then
         raise Types.Config_Error with
           "line " & Types.Img (Raw.Header) & ": service '"
           & US.To_String (Raw.Name) & "' is missing " & US.To_String (Missing);
      end if;

      --  "-" is only allowed where the README says so.
      for F in Types.Field_Id loop
         if Text (Raw, F) = Dashed and then F in
           Types.Mood | Types.Summon | Types.Arena | Types.Role | Types.Party
           | Types.Lives | Types.Cooldown | Types.Eviction_Notice | Types.Grace
           | Types.Amiafurry
         then
            Bad (Raw, F, "'-' is not allowed here, give a real value");
         end if;
      end loop;

      Svc.Name := Raw.Name;

      if not Moods.Parse (Text (Raw, Types.Mood), Svc.Mood) then
         Bad (Raw, Types.Mood, "unknown mood '" & Text (Raw, Types.Mood)
              & "'. Choose one of: " & Moods.All_Names);
      end if;

      declare
         V : constant String := Text (Raw, Types.Summon);
      begin
         if not Is_Absolute (V) then
            Bad (Raw, Types.Summon, "must be an absolute path. No PATH lookup here.");
         end if;
         Svc.Program := US.To_Unbounded_String (V);
      end;

      Svc.Args := Shell.Split (Text (Raw, Types.Incant), Raw.Lines (Types.Incant));

      declare
         V : constant String := Text (Raw, Types.Arena);
      begin
         if not Is_Absolute (V) then
            Bad (Raw, Types.Arena, "must be an absolute path");
         end if;
         Svc.Cwd := US.To_Unbounded_String (V);
      end;

      Accounts.Find_User (Text (Raw, Types.Role), Uid, Found);
      if not Found then
         Bad (Raw, Types.Role, "no such user '" & Text (Raw, Types.Role) & "'");
      end if;
      Svc.User := Raw.Values (Types.Role);
      Svc.Uid := Uid;

      Accounts.Find_Group (Text (Raw, Types.Party), Gid, Found);
      if not Found then
         Bad (Raw, Types.Party, "no such group '" & Text (Raw, Types.Party) & "'");
      end if;
      Svc.Group := Raw.Values (Types.Party);
      Svc.Gid := Gid;

      Parse_Loadout (Raw, Svc.Env);

      declare
         V : constant String := Text (Raw, Types.Lives);
      begin
         if V = "always" then
            Svc.Lives := Types.Always;
         elsif V = "never" then
            Svc.Lives := Types.Never;
         elsif V = "on-failure" then
            Svc.Lives := Types.On_Failure;
         else
            Bad (Raw, Types.Lives, "must be always, never, or on-failure");
         end if;
      end;

      Svc.Cooldown := Seconds (Raw, Types.Cooldown);

      declare
         V : constant String := Text (Raw, Types.Eviction_Notice);
      begin
         if V'Length >= 3 and then V (V'First .. V'First + 2) = "SIG" then
            Bad (Raw, Types.Eviction_Notice, "write the name without SIG, like 'TERM'");
         end if;
         Svc.Notice := Types.Signal_Number (V);
         if Svc.Notice = 0 then
            Bad (Raw, Types.Eviction_Notice, "unknown signal '" & V
                 & "'. Supported: HUP INT QUIT USR1 USR2 TERM");
         end if;
      end;

      Svc.Grace := Seconds (Raw, Types.Grace);

      declare
         V : constant String := Text (Raw, Types.Scoreboard);
      begin
         if V /= "-" and then not Is_Absolute (V) then
            Bad (Raw, Types.Scoreboard, "must be an absolute path, or - for no output");
         end if;
         if Starts_With (V, "/dev/tty") or else Starts_With (V, "/dev/pts/")
           or else Starts_With (V, "/dev/console")
         then
            Bad (Raw, Types.Scoreboard,
                 "is a terminal; services never write to a terminal, use - for no output");
         end if;
         Svc.Scoreboard := US.To_Unbounded_String (V);
      end;

      declare
         V : constant String := Text (Raw, Types.Amiafurry);
      begin
         if V = "true" then
            Furry := True;
         elsif V = "false" then
            Furry := False;
         else
            Bad (Raw, Types.Amiafurry, "must be true or false");
         end if;
         Svc.Furry := Furry;
      end;

      --  Fursona fields: real values when furry, "-" when not.
      declare
         V : constant String := Text (Raw, Types.Fursona_Name);
         D : constant String := Text (Raw, Types.Fursona_Description);
         S : constant String := Text (Raw, Types.Fursona_Species);
         procedure Check (F : Types.Field_Id; Value : String) is
         begin
            if Furry and then Value = "-" then
               Bad (Raw, F, "required when !amiafurry is true, give a real value");
            end if;
            if not Furry and then Value /= "-" then
               Bad (Raw, F, "must be - when !amiafurry is false");
            end if;
         end Check;
      begin
         Check (Types.Fursona_Name, V);
         Check (Types.Fursona_Description, D);
         Check (Types.Fursona_Species, S);
         if Furry then
            Svc.Fursona := (Name        => US.To_Unbounded_String (V),
                            Description => US.To_Unbounded_String (D),
                            Species     => US.To_Unbounded_String (S));
         else
            Svc.Fursona := (Name => US.Null_Unbounded_String,
                            Description => US.Null_Unbounded_String,
                            Species => US.Null_Unbounded_String);
         end if;
      end;

      return Svc;
   end Build;

end Oxinit.Validate;
