with Ada.Strings.Unbounded;

package body Oxinit.Shell is

   package US renames Ada.Strings.Unbounded;

   Nul : constant Character := Character'Val (0);

   function Split (Raw : String; Line : Positive) return Types.Str_Vectors.Vector is
      Result  : Types.Str_Vectors.Vector;
      Word    : US.Unbounded_String;
      In_Word : Boolean := False;
      Quote   : Character := Nul;
      I       : Natural := Raw'First;

      procedure Fail (Msg : String) is
      begin
         raise Types.Config_Error with
           "line " & Types.Img (Line) & ": !incant: " & Msg;
      end Fail;

      procedure Push_Char (C : Character) is
      begin
         US.Append (Word, C);
         In_Word := True;
      end Push_Char;

      procedure End_Word is
      begin
         if In_Word then
            Result.Append (Word);
            Word := US.Null_Unbounded_String;
            In_Word := False;
         end if;
      end End_Word;
   begin
      if Raw = "-" then
         return Result;
      end if;

      while I <= Raw'Last loop
         declare
            C : constant Character := Raw (I);
         begin
            if Quote = Nul then
               if C = ' ' or else C = ASCII.HT then
                  End_Word;
               elsif C = ''' or else C = '"' then
                  Quote := C;
                  In_Word := True;
               elsif C = '\' then
                  if I = Raw'Last then
                     Fail ("trailing backslash");
                  end if;
                  I := I + 1;
                  Push_Char (Raw (I));
               elsif C in '|' | '&' | ';' | '<' | '>' | '(' | ')' then
                  Fail ("unquoted '" & C & "' is not supported (no pipes, redirects, "
                        & "or command separators)");
               elsif C = '$' or else C = '`' then
                  Fail ("'" & C & "' expansion is not supported");
               else
                  Push_Char (C);
               end if;

            elsif Quote = ''' then
               if C = ''' then
                  Quote := Nul;
               else
                  Push_Char (C);
               end if;

            else  --  inside double quotes
               if C = '"' then
                  Quote := Nul;
               elsif C = '\' then
                  if I = Raw'Last then
                     Fail ("trailing backslash");
                  end if;
                  I := I + 1;
                  Push_Char (Raw (I));
               elsif C = '$' or else C = '`' then
                  Fail ("'" & C & "' expansion is not supported");
               else
                  Push_Char (C);
               end if;
            end if;
         end;
         I := I + 1;
      end loop;

      if Quote /= Nul then
         Fail ("unterminated quote");
      end if;
      End_Word;
      return Result;
   end Split;

end Oxinit.Shell;
