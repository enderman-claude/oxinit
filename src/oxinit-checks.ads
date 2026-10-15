with Oxinit.Parser;
with Oxinit.Types;

--  Field-level helpers shared by Validate: value access, errors, and the
--  duration and loadout parsers.
package Oxinit.Checks is

   function Text (Raw : Parser.Raw_Service; F : Types.Field_Id) return String;

   --  Raises Types.Config_Error naming the field and its line.
   procedure Bad (Raw : Parser.Raw_Service; F : Types.Field_Id; Msg : String);

   function Is_Absolute (S : String) return Boolean;

   --  "2s" -> 2. Whole seconds only.
   function Seconds (Raw : Parser.Raw_Service; F : Types.Field_Id) return Natural;

   --  Splits on blanks. Each token must be KEY=VALUE with a non-empty key.
   procedure Parse_Loadout (Raw : Parser.Raw_Service; Env : in out Types.Str_Vectors.Vector);

end Oxinit.Checks;
