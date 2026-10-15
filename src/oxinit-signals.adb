with Interfaces.C;
with Oxinit.Posix;
with System;

package body Oxinit.Signals is

   procedure On_Signal (Sig : Interfaces.C.int);
   pragma Convention (C, On_Signal);

   procedure On_Signal (Sig : Interfaces.C.int) is
      pragma Unreferenced (Sig);
   begin
      Stop_Requested := True;
   end On_Signal;

   procedure Install is
      Old : System.Address;
      pragma Unreferenced (Old);
   begin
      Old := Posix.Signal (Posix.Sigterm, On_Signal'Address);
      Old := Posix.Signal (Posix.Sigint, On_Signal'Address);
   end Install;

end Oxinit.Signals;
