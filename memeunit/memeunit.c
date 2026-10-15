/* memeunit: compiled-in meme table for oxinit.
 *
 * Output is deterministic. The seed (service name, mood, species) is hashed,
 * so a given service always gets the same line for a given event. A recognised
 * species picks from its own short list instead of the generic pool.
 * Build with `make` in this directory to produce libmemeunit.so.
 */
#include <stddef.h>
#include <stdint.h>

#define N_KINDS 8
#define N_GENERIC 6
#define N_SPECIES_LINES 2

struct meme_set {
    const char *key;
    const char *lines[N_GENERIC];
};

/* Order here sets the kind index. species_table uses the same order. */
static const struct meme_set table[N_KINDS] = {
    { "start", {
        "MEDIC! The squad is up. Fight the good fight.",
        "uwu the process has awoken and is ready to notice ur crashes.",
        "Ubercharge ready. Process spawned, the pyro is still on fire.",
        "Hello, I'm the spy, I'm here to help. Your service is in the back row.",
        "Process is up. Fursona spawned. Tail is wagging.",
        "Engineer: nice dispenser. Service is now deployed and happy.",
    }},
    { "exit", {
        "Exited with a nonzero code. It's a sentry-level failure, not a critical one.",
        "Oh no the process went boom. Owo. Fell over like a Heavy at lunch.",
        "Process died, the medic is not in the area. Reviving soon.",
        "This is fine. (It is not fine.) Flaming dog in a coffee shop energy.",
        "Scout-level reflexes: it crashed before we could blink.",
        "The fursuit tripped on the cable. Happens to the best of us, uwu.",
    }},
    { "restart", {
        "Have you tried turning it off and on again? Engie would approve.",
        "Restarting with backoff. Soldiers do not give up. Soldiers rocket-jump back.",
        "Waiting before respawn, like a classic TF2 respawn timer.",
        "Respawning in a bit. Keep your fursona on standby, uwu.",
        "Backoff engaged. The Heavy says patience is a virtue, and also a sandvich.",
        "Restarting. Please hold while the medic finishes his spiel.",
    }},
    { "oneshot", {
        "One-shot service retired. Respect. Like the Sniper's last headshot.",
        "Ran once, did the thing, left. Quiet exit, very spy.",
        "Single-run process completed. Fursuit off, sweaty and happy.",
        "Ran once and stays dead. Meet the Team, we already have 9 of these.",
        "One-hit wonder with a signature move. Mann Co. approves.",
        "It did one job. The engineer would be proud of its efficiency.",
    }},
    { "giveup", {
        "Crashed too many times. Touch grass. Mann Co. has no more respawns for you.",
        "Gave up on it after the crash limit. Get some sleep, uwu. Okay, bye.",
        "Crash loop detected. Medic, we need a revive that works.",
        "Too many deaths. Go take a break, the Sentry is also tired.",
        "Respawn denied. Heavy is sad. Heavy will eat a sandvich about it.",
        "Five strikes and out. Baseball, but make it a service.",
    }},
    { "stop", {
        "Asking politely for a shutdown. Please leave the pool, sir.",
        "Requesting a graceful exit. Nicely, like a Scout with a bat.",
        "Stopping with SIGTERM. Like an engineer packing up the dispenser.",
        "Politely knocking on the door. Furry etiquette is important.",
        "Sending the 'please leave' signal. It will go quietly, probably.",
        "Shutdown requested. Medic says: stop running and get over here.",
    }},
    { "kill", {
        "Ignored the polite request. Escalating to SIGKILL. Not personal.",
        "Uncooperative process. Pyro-level chaos. Escalating.",
        "Didn't leave the pool. Heavy sees this and is not impressed.",
        "Not leaving voluntarily, so SIGKILL it is. Spy: sorry about your back.",
        "It refused to leave. The Soldier is going full rocket-jump on it.",
        "Escalating. Like a meme in a comment section, it is now dead.",
    }},
    { "config", {
        "Your config is cooked. Read the error, not the vibes.",
        "Parse error. Heavy looked at your config and ate a sandvich instead.",
        "Config rejected. Even the Spy can't get past a missing field.",
        "Syntax says no. Sentry will not fire until you fix it.",
        "Something's wrong with the stack, uwu. Please fix and retry.",
        "No defaults here, sweetie. Every field has to be spelled out.",
    }},
};

/* Species lines. Matched case-insensitively as a substring of the species
 * the service declares, so "Protogen", "protogen-ish" and "proto" all match.
 * "spy" is the Spy: a spy pretending to be a furry.
 * lines[kind][n] lines up with table[kind] above. */
struct species_set {
    const char *match;
    const char *lines[N_KINDS][N_SPECIES_LINES];
};

#define N_SPECIES 5
static const struct species_set species_table[N_SPECIES] = {
    { "proto", {
        { "Visor on, boop. Protogen systems online, process is up.",
          "Fins up, visor bright. The protogen has started its service." },
        { "Visor flickered and the process dropped. Recalibrating.",
          "Protogen fell over. Fins are bent, visor is fine." },
        { "Visor back on, restarting. Fins up.",
          "Boop. Respawning on a fresh boot, visor awake." },
        { "Visor dims after one run. Clean shutdown, boop.",
          "One run, visor off. Fins down, job done." },
        { "Too many visor crashes. The protogen is taking the day off.",
          "Crash limit hit. Fins down, visor dark, no more respawns." },
        { "Visor asks the process to leave politely. Boop.",
          "The protogen gently taps the shutdown button." },
        { "It would not leave, so the visor says goodbye. SIGKILL.",
          "Fins up, visor angry, process being removed." },
        { "Visor is showing a config error. Please fix the fields, boop.",
          "The protogen cannot parse this config. Check the fields." },
    }},
    { "wolf", {
        { "Wolf ears up, the process is awake and on watch.",
          "Howl! The service is up and guarding its territory." },
        { "The wolf yelped and the process stopped. Check the code.",
          "The wolf tripped over its own tail and the process exited." },
        { "The wolf shakes it off and runs again after a short wait.",
          "Pack instinct says get back up. Restarting." },
        { "One howl, one task, and the wolf sleeps. Clean finish.",
          "The wolf finished its patrol and lay down for good." },
        { "The wolf is done for the day after too many crashes.",
          "Too many falls. The pack leader has called it off." },
        { "The wolf sits, and the process is asked to stand down.",
          "The wolf calls the process back to the den." },
        { "The wolf stopped waiting and went in for the removal.",
          "Pack leader is out of patience. SIGKILL." },
        { "The wolf sniffs the config and does not like it. Fix it.",
          "Bad config. The wolf refuses to run it until it is fixed." },
    }},
    { "fox", {
        { "Fox trots in, service is running and sneaky.",
          "The fox is awake and the process has begun." },
        { "The fox pounced and missed. The process exited with a failure.",
          "Something spooked the fox and the process ended." },
        { "The fox dusts off and runs back in.",
          "Circling back for another try, fox style." },
        { "The fox grabbed its prey in one go and left.",
          "One quick job, then the fox vanished into the trees." },
        { "The fox has had enough and is retreating for good.",
          "Too many bad hunts. The fox is going home." },
        { "The fox politely asks the process to leave the den.",
          "The fox sits quietly, waiting for the process to leave." },
        { "The fox would not wait any longer, so it moved in.",
          "Stubborn process. The fox is removing it now." },
        { "The fox refuses to hunt with that config. Check the fields.",
          "Something in the config smells wrong. Fix it, then retry." },
    }},
    { "dragon", {
        { "The dragon wakes up and the service takes flight.",
          "The dragon stretches. The process is awake and breathing fire." },
        { "The dragon coughed a smoke ring and the process fell out of the sky.",
          "Crash in the cave. The dragon is angry at the process." },
        { "The dragon takes off again, slower this time.",
          "Wing beats again, restarting with a longer wait." },
        { "One breath of fire and the dragon sleeps. Job done.",
          "The dragon finished its hoard and went back to sleep." },
        { "The dragon has had enough crashes and goes back to its mountain.",
          "Too many falls. The dragon is grounded for good." },
        { "The dragon lowers its head and asks the process to leave.",
          "Asking politely, the dragon nudges the process out." },
        { "The dragon will not wait, so the process gets the flame.",
          "Refused to leave the cave. SIGKILL breath." },
        { "The dragon sniffs the config and roars. Fix the fields.",
          "The hoard is safe, the config is not. Please fix it." },
    }},
    { "spy", {
        { "Spy here, fursuit on, tail taped on. Process is up. Nobody looks closer.",
          "Ears on, disguise on. Service running. I am definitely a furry, do not check." },
        { "Fursuit caught on the cable and the process went down. Blending in is hard.",
          "Disguise slipped mid-run, service exited. Cover blown, sort of." },
        { "Quick costume change, back in. Totally a regular furry, honest.",
          "Re-disguising and restarting. Nobody saw the tail fall off." },
        { "In, out, one job, disguise folded up. Never was here.",
          "Single mission complete. The fursuit went back in the bag." },
        { "Too many slips. Cover is blown, pack up the suit and go.",
          "Compromised. Abort, abort, the fursona was fake anyway." },
        { "Asking nicely to stand down. Please do not look at the tail.",
          "Requesting extraction. The suit is getting hot." },
        { "Refused to leave, so the disguise comes off. SIGKILL. Sorry about the paws.",
          "Uncooperative target. Going in hard. Ears off." },
        { "Config has the wrong fields, the disguise will not hold. Fix it.",
          "Bad config. Even a spy cannot pass as a furry with missing fields." },
    }},
};

static char lower(char c) {
    return (c >= 'A' && c <= 'Z') ? (char)(c + ('a' - 'A')) : c;
}

/* Case-insensitive substring test. */
static int has_ci(const char *hay, const char *needle) {
    for (const char *s = hay; *s; s++) {
        const char *h = s, *n = needle;
        while (*n && *h && lower(*h) == lower(*n)) { h++; n++; }
        if (!*n) return 1;
    }
    return 0;
}

static int kind_index(const char *kind) {
    for (int i = 0; i < N_KINDS; i++) {
        const char *k = table[i].key;
        const char *q = kind;
        int same = 1;
        while (*k || *q) {
            if (*k != *q) { same = 0; break; }
            k++; q++;
        }
        if (same) return i;
    }
    return -1;
}

static const struct species_set *find_species(const char *species) {
    if (!species || !*species) return NULL;
    for (int i = 0; i < N_SPECIES; i++) {
        if (has_ci(species, species_table[i].match)) return &species_table[i];
    }
    return NULL;
}

/* seed: service name, mood and species, joined by the caller.
 * species: the declared fursona species, or "" for non-furry services. */
const char *memeunit_pick(const char *kind, const char *seed, const char *species) {
    uint32_t h = 2166136261u;  /* FNV-1a over the seed */
    const char *p = seed ? seed : "";
    while (*p) { h ^= (unsigned char)*p++; h *= 16777619u; }

    int k = kind_index(kind);
    if (k < 0) return "";

    const struct species_set *sp = find_species(species);
    if (sp) return sp->lines[k][h % N_SPECIES_LINES];
    return table[k].lines[h % N_GENERIC];
}
