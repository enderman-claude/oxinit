with Oxinit.Types;

--  Splits !incant the way a POSIX shell does, and rejects the shell features
--  oxinit does not run: pipes, redirects, separators, and $ or backtick expansion.
package Oxinit.Shell is
   --  Raw is the field value. A bare "-" means no arguments.
   --  Line is used in error messages. Raises Types.Config_Error.
   function Split (Raw : String; Line : Positive) return Types.Str_Vectors.Vector;
end Oxinit.Shell;
