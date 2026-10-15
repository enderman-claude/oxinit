with Ada.Containers.Vectors;
with Oxinit.Types;

--  Loads a .oxi file into Services. Parse and validation errors raise
--  Types.Config_Error. File access errors raise Read_Error.
package Oxinit.Config is

   use type Types.Service;

   package Service_Vectors is new Ada.Containers.Vectors (Positive, Types.Service);

   Read_Error : exception;

   Services : Service_Vectors.Vector;

   procedure Load_File (Path : String);

end Oxinit.Config;
