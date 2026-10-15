with Ada.Strings.Unbounded;
with Ada.Text_IO;
with Oxinit.Parser;
with Oxinit.Validate;

package body Oxinit.Config is

   package US renames Ada.Strings.Unbounded;

   procedure Load_File (Path : String) is
      F   : Ada.Text_IO.File_Type;
      Buf : US.Unbounded_String;
   begin
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Path);
      exception
         when Ada.Text_IO.Name_Error | Ada.Text_IO.Use_Error =>
            raise Read_Error with "cannot read " & Path;
      end;

      while not Ada.Text_IO.End_Of_File (F) loop
         US.Append (Buf, Ada.Text_IO.Get_Line (F));
         US.Append (Buf, ASCII.LF);
      end loop;
      Ada.Text_IO.Close (F);

      declare
         Raws : constant Parser.Raw_Vectors.Vector := Parser.Read (US.To_String (Buf));
      begin
         if Natural (Raws.Length) > Types.Max_Services then
            raise Types.Config_Error with
              "too many services, the limit is" & Types.Img (Types.Max_Services);
         end if;
         Services.Clear;
         for R of Raws loop
            Services.Append (Validate.Build (R));
         end loop;
      end;
   end Load_File;

end Oxinit.Config;
