--  Bindings to the compiled-in memeunit (memeunit/libmemeunit.a).
--  Seed is hashed to pick the line; Species, when non-empty and recognised,
--  selects that species' own lines instead of the generic pool.
package Oxinit.Memes is
   function Pick (Kind, Seed, Species : String) return String;
end Oxinit.Memes;
