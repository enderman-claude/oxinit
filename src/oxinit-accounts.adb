with Ada.Text_IO;

package body Oxinit.Accounts is

   --  Returns the Col-th colon-separated field of Line (1-based), or "".
   function Nth (Line : String; Col : Positive) return String is
      Count : Positive := 1;
      Start : Positive := Line'First;
   begin
      for I in Line'Range loop
         if Line (I) = ':' then
            if Count = Col then
               return Line (Start .. I - 1);
            end if;
            Count := Count + 1;
            Start := I + 1;
         end if;
      end loop;
      if Count = Col and then Start <= Line'Last then
         return Line (Start .. Line'Last);
      end if;
      return "";
   end Nth;

   procedure Lookup (Path, Name : String; Id : out Natural; Found : out Boolean) is
      F : Ada.Text_IO.File_Type;
   begin
      Id := 0;
      Found := False;
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Path);
      exception
         when Ada.Text_IO.Name_Error =>
            return;
      end;
      while not Ada.Text_IO.End_Of_File (F) and then not Found loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (F);
         begin
            if Line'Length > 0 and then Nth (Line, 1) = Name then
               begin
                  Id := Natural'Value (Nth (Line, 3));
                  Found := True;
               exception
                  when Constraint_Error => null;
               end;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (F);
   end Lookup;

   procedure Find_User (Name : String; Uid : out Natural; Found : out Boolean) is
   begin
      Lookup ("/etc/passwd", Name, Uid, Found);
   end Find_User;

   procedure Find_Group (Name : String; Gid : out Natural; Found : out Boolean) is
   begin
      Lookup ("/etc/group", Name, Gid, Found);
   end Find_Group;

end Oxinit.Accounts;
