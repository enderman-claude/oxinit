--  Bindings to the compiled-in memeunit (memeunit/libmemeunit.a).
package Oxinit.Memes is
   --  Kind is an event key such as "start"; Seed is the service name.
   --  The same pair always returns the same line.
   function Pick (Kind, Seed : String) return String;
end Oxinit.Memes;
