--  Resolves user and group names from /etc/passwd and /etc/group.
--  No defaults: a name that does not exist is simply not found.
package Oxinit.Accounts is
   procedure Find_User (Name : String; Uid : out Natural; Found : out Boolean);
   procedure Find_Group (Name : String; Gid : out Natural; Found : out Boolean);
end Oxinit.Accounts;
