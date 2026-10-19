with Ada.Streams;
with Ada.Strings.Unbounded;

--  Support for SHARD service binaries (see the shard repo, docs/spec/format.md).
--  A service whose !summon file starts with the SHARD magic is converted to ELF in
--  memory before it is launched, because execve only runs ELF. Only images with no
--  relocations are accepted for now: the Linux path does not apply relocations yet.
package Oxinit.Shard_Format is

   type Bytes_Access is access Ada.Streams.Stream_Element_Array;

   --  True if the file at Path starts with the SHARD magic "SHRD".
   function Is_Shard (Path : String) return Boolean;

   --  Converts the SHARD file at Path to ELF. On failure Elf is null and Reason says why.
   procedure Convert_To_Elf
     (Path   : String;
      Elf    : out Bytes_Access;
      Reason : out Ada.Strings.Unbounded.Unbounded_String);

end Oxinit.Shard_Format;
