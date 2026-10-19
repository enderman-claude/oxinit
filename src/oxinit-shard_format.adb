with Ada.Streams.Stream_IO;
with Ada.Unchecked_Deallocation;
with Interfaces.C;
with System;

package body Oxinit.Shard_Format is

   use Interfaces;
   use type Ada.Streams.Stream_Element_Offset;
   use type Ada.Streams.Stream_Element_Array;
   use type C.int;
   use type C.size_t;
   package US renames Ada.Strings.Unbounded;
   package SIO renames Ada.Streams.Stream_IO;
   subtype Stream_Bytes is Ada.Streams.Stream_Element_Array;

   --  Mirrors struct shard_image in shard/include/shard/shard_open.h, field for field.
   type Shard_Image is record
      Data       : System.Address := System.Null_Address;
      Len        : C.size_t := 0;
      Flags      : Unsigned_32 := 0;
      Entry_Pt   : Unsigned_64 := 0;
      Image_Size : Unsigned_64 := 0;
      Sec_Count  : Unsigned_32 := 0;
      Sec_Off    : Unsigned_32 := 0;
      Rel_Count  : Unsigned_32 := 0;
      Rel_Off    : Unsigned_32 := 0;
   end record with Convention => C;

   function Shard_Open
     (Data : System.Address; Len : C.size_t; Img : not null access Shard_Image) return C.int;
   pragma Import (C, Shard_Open, "shard_open");

   function Shard_To_Elf_Size
     (Img : not null access Shard_Image; Size : not null access C.size_t) return C.int;
   pragma Import (C, Shard_To_Elf_Size, "shard_to_elf_size");

   function Shard_To_Elf
     (Img     : not null access Shard_Image;
      Buf     : System.Address;
      Cap     : C.size_t;
      Written : not null access C.size_t) return C.int;
   pragma Import (C, Shard_To_Elf, "shard_to_elf");

   Magic : constant Stream_Bytes :=
     (Ada.Streams.Stream_Element (Character'Pos ('S')),
      Ada.Streams.Stream_Element (Character'Pos ('H')),
      Ada.Streams.Stream_Element (Character'Pos ('R')),
      Ada.Streams.Stream_Element (Character'Pos ('D')));

   function Is_Shard (Path : String) return Boolean is
      F    : SIO.File_Type;
      Buf  : Stream_Bytes (1 .. 4);
      Last : Ada.Streams.Stream_Element_Offset;
   begin
      SIO.Open (F, SIO.In_File, Path);
      SIO.Read (F, Buf, Last);
      SIO.Close (F);
      return Last = 4 and then Buf = Magic;
   exception
      when others =>
         if SIO.Is_Open (F) then
            SIO.Close (F);
         end if;
         return False;
   end Is_Shard;

   procedure Convert_To_Elf
     (Path   : String;
      Elf    : out Bytes_Access;
      Reason : out US.Unbounded_String)
   is
      F    : SIO.File_Type;
      Data : Bytes_Access;
   begin
      Elf := null;
      Reason := US.Null_Unbounded_String;

      --  Read the whole file.
      SIO.Open (F, SIO.In_File, Path);
      declare
         Size : constant Natural := Natural (SIO.Size (F));
      begin
         Data := new Stream_Bytes (1 .. Ada.Streams.Stream_Element_Offset (Size));
         if Size > 0 then
            declare
               Last : Ada.Streams.Stream_Element_Offset;
            begin
               SIO.Read (F, Data.all, Last);
               if Last /= Data'Last then
                  raise Program_Error with "short read";
               end if;
            end;
         end if;
      end;
      SIO.Close (F);

      declare
         Img    : aliased Shard_Image;
         Status : C.int;
         Sz     : aliased C.size_t := 0;
         Wrote  : aliased C.size_t := 0;
      begin
         if Data'Length = 0 then
            Reason := US.To_Unbounded_String ("empty file");
            return;
         end if;

         Status := Shard_Open (Data.all'Address, C.size_t (Data'Length), Img'Access);
         if Status /= 0 then
            Reason := US.To_Unbounded_String
              ("invalid SHARD image (status" & C.int'Image (Status) & ")");
            return;
         end if;

         if Img.Rel_Count /= 0 then
            Reason := US.To_Unbounded_String
              ("SHARD image has relocations, which the Linux path does not apply yet");
            return;
         end if;

         if Shard_To_Elf_Size (Img'Access, Sz'Access) /= 0 then
            Reason := US.To_Unbounded_String ("cannot size ELF output");
            return;
         end if;

         Elf := new Stream_Bytes (1 .. Ada.Streams.Stream_Element_Offset (Sz));
         if Shard_To_Elf (Img'Access, Elf.all'Address, Sz, Wrote'Access) /= 0
           or else Wrote /= Sz
         then
            Free_Elf :
            declare
               procedure Free is new Ada.Unchecked_Deallocation (Stream_Bytes, Bytes_Access);
            begin
               Free (Elf);
            end Free_Elf;
            Reason := US.To_Unbounded_String ("ELF conversion failed");
         end if;
      end;
   exception
      when others =>
         Elf := null;
         Reason := US.To_Unbounded_String ("cannot read " & Path);
   end Convert_To_Elf;

end Oxinit.Shard_Format;
