with Ada.Characters.Handling;

package body Oxinit.Types is

   function Field_Name (F : Field_Id) return String is
      R : String := Ada.Characters.Handling.To_Lower (Field_Id'Image (F));
   begin
      for I in R'Range loop
         if R (I) = '_' then
            R (I) := '-';
         end if;
      end loop;
      return R;
   end Field_Name;

   function Lives_Name (L : Lives_Kind) return String is
   begin
      case L is
         when Always     => return "always";
         when Never      => return "never";
         when On_Failure => return "on-failure";
      end case;
   end Lives_Name;

   function State_Name (S : Run_State) return String is
   begin
      case S is
         when Starting => return "starting";
         when Running  => return "running";
         when Cooling  => return "cooling down";
         when Stopped  => return "stopped";
         when Finished => return "finished";
         when Given_Up => return "given up";
      end case;
   end State_Name;

   function Signal_Number (Name : String) return Natural is
   begin
      if Name = "HUP" then
         return 1;
      elsif Name = "INT" then
         return 2;
      elsif Name = "QUIT" then
         return 3;
      elsif Name = "USR1" then
         return 10;
      elsif Name = "USR2" then
         return 12;
      elsif Name = "TERM" then
         return 15;
      else
         return 0;
      end if;
   end Signal_Number;

   function Img (N : Integer) return String is
      S : constant String := Integer'Image (N);
   begin
      if N < 0 then
         return S;
      else
         return S (S'First + 1 .. S'Last);
      end if;
   end Img;

   function Quiet_Marker (Name : String) return Boolean is
   begin
      return Name = "login" or else Name = "graphical"
        or else Name = "shell" or else Name = "booted";
   end Quiet_Marker;

end Oxinit.Types;
