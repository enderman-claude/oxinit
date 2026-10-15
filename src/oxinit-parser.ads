with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Oxinit.Types;

--  Reads the .oxi text into raw services: one @block per service, one
--  !field line per field. Field values are checked later, in Validate.
package Oxinit.Parser is

   package US renames Ada.Strings.Unbounded;

   type Presence is array (Types.Field_Id) of Boolean;
   type Texts    is array (Types.Field_Id) of US.Unbounded_String;
   type Line_Nums is array (Types.Field_Id) of Natural;

   type Raw_Service is record
      Name   : US.Unbounded_String;
      Header : Natural;
      Seen   : Presence;
      Values : Texts;
      Lines  : Line_Nums;
   end record;

   use type Raw_Service;

   package Raw_Vectors is new Ada.Containers.Vectors (Positive, Raw_Service);

   --  Raises Types.Config_Error with a line number on any syntax problem.
   function Read (Text : String) return Raw_Vectors.Vector;

end Oxinit.Parser;
