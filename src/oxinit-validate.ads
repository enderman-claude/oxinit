with Oxinit.Parser;
with Oxinit.Types;

--  Turns a raw service into a checked Types.Service. Every rule from the
--  README lives here. Raises Types.Config_Error naming the service and field.
package Oxinit.Validate is
   function Build (Raw : Parser.Raw_Service) return Types.Service;
end Oxinit.Validate;
