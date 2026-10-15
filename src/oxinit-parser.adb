with Ada.Strings.Fixed;

package body Oxinit.Parser is

   Blank : constant Raw_Service :=
     (Name   => US.Null_Unbounded_String,
      Header => 0,
      Seen   => (others => False),
      Values => (others => US.Null_Unbounded_String),
      Lines  => (others => 0));

   function Trim (S : String) return String is
     (Ada.Strings.Fixed.Trim (S, Ada.Strings.Both));

   function Has_Blank (S : String) return Boolean is
   begin
      for C of S loop
         if C = ' ' or else C = ASCII.HT then
            return True;
         end if;
      end loop;
      return False;
   end Has_Blank;

   function Read (Text : String) return Raw_Vectors.Vector is
      Result     : Raw_Vectors.Vector;
      Current    : Raw_Service := Blank;
      In_Service : Boolean := False;
      Pos        : Natural := Text'First;
      Line_No    : Positive := 1;

      procedure Fail (Line : Positive; Msg : String) is
      begin
         raise Types.Config_Error with "line " & Types.Img (Line) & ": " & Msg;
      end Fail;
   begin
      while Pos <= Text'Last loop
         declare
            Stop : Natural := Pos;
         begin
            while Stop <= Text'Last and then Text (Stop) /= ASCII.LF loop
               Stop := Stop + 1;
            end loop;

            declare
               Line : constant String := Trim (Text (Pos .. Stop - 1));
            begin
               if Line'Length = 0 or else Line (Line'First) = '#' then
                  null;

               elsif Line (Line'First) = '@' then
                  if In_Service then
                     Result.Append (Current);
                  end if;
                  declare
                     Name : constant String := Trim (Line (Line'First + 1 .. Line'Last));
                  begin
                     if Name'Length = 0 or else Has_Blank (Name) then
                        Fail (Line_No, "service name must be non-empty with no spaces");
                     end if;
                     for R of Result loop
                        if US.To_String (R.Name) = Name then
                           Fail (Line_No, "duplicate service name '" & Name & "'");
                        end if;
                     end loop;
                     Current := Blank;
                     Current.Name := US.To_Unbounded_String (Name);
                     Current.Header := Line_No;
                     In_Service := True;
                  end;

               elsif Line (Line'First) = '!' then
                  if not In_Service then
                     Fail (Line_No, "field before any @service");
                  end if;
                  declare
                     Body_Text : constant String := Line (Line'First + 1 .. Line'Last);
                     Cut       : Natural := 0;
                  begin
                     for I in Body_Text'Range loop
                        if Body_Text (I) = ' ' or else Body_Text (I) = ASCII.HT then
                           Cut := I;
                           exit;
                        end if;
                     end loop;
                     declare
                        FName : constant String :=
                          (if Cut = 0 then Body_Text else Body_Text (Body_Text'First .. Cut - 1));
                        Value : constant String :=
                          (if Cut = 0 then "" else Trim (Body_Text (Cut + 1 .. Body_Text'Last)));
                        Found : Boolean := False;
                        Id    : Types.Field_Id := Types.Field_Id'First;
                     begin
                        for F in Types.Field_Id loop
                           if Types.Field_Name (F) = FName then
                              Id := F;
                              Found := True;
                              exit;
                           end if;
                        end loop;
                        if not Found then
                           Fail (Line_No, "unknown field '!" & FName & "'");
                        end if;
                        if Current.Seen (Id) then
                           Fail (Line_No, "duplicate field '!" & FName
                                 & "' in service '" & US.To_String (Current.Name) & "'");
                        end if;
                        if Value'Length = 0 then
                           Fail (Line_No, "!" & FName & " has no value");
                        end if;
                        Current.Seen (Id) := True;
                        Current.Values (Id) := US.To_Unbounded_String (Value);
                        Current.Lines (Id) := Line_No;
                     end;
                  end;

               else
                  Fail (Line_No, "lines must start with @ (service) or ! (field)");
               end if;
            end;

            Pos := Stop + 1;
            Line_No := Line_No + 1;
         end;
      end loop;

      if In_Service then
         Result.Append (Current);
      end if;
      if Result.Is_Empty then
         raise Types.Config_Error with "no services declared";
      end if;
      return Result;
   end Read;

end Oxinit.Parser;
