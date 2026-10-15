--  One task per service: spawn, wait for exit, apply lives and cooldown.
package Oxinit.Worker is
   task type Worker (Idx : Positive);
end Oxinit.Worker;
