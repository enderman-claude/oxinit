--  Runs one oxictl request and returns the reply text (no trailing newline).
--  Commands: status | stop NAME | start NAME
package Oxinit.Commands is
   function Run (Line : String) return String;
end Oxinit.Commands;
