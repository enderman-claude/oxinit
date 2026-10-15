with Interfaces.C.Strings;

package body Oxinit.Memes is

   package CS renames Interfaces.C.Strings;

   function Memeunit_Pick (Kind, Seed : CS.chars_ptr) return CS.chars_ptr;
   pragma Import (C, Memeunit_Pick, "memeunit_pick");

   function Pick (Kind, Seed : String) return String is
      K : CS.chars_ptr := CS.New_String (Kind);
      S : CS.chars_ptr := CS.New_String (Seed);
      R : CS.chars_ptr;
   begin
      R := Memeunit_Pick (K, S);
      declare
         Text : constant String := CS.Value (R);
      begin
         CS.Free (K);
         CS.Free (S);
         return Text;
      end;
   end Pick;

end Oxinit.Memes;
