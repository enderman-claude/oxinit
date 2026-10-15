/* memeunit: compiled-in meme table for oxinit.
 *
 * Output is deterministic: the same event key always picks the same line.
 * Build with `make` in this directory to produce libmemeunit.so.
 */
#include <stddef.h>
#include <stdint.h>

#define N_KINDS 8

struct meme_set {
    const char *key;
    const char *lines[6];
};

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
};

const char *memeunit_pick(const char *kind, const char *seed) {
    uint32_t h = 2166136261u;  /* FNV-1a over seed, so the same seed always picks the same line */
    const char *p = seed ? seed : "";
    while (*p) { h ^= (unsigned char)*p++; h *= 16777619u; }
    for (int i = 0; i < N_KINDS; i++) {
        const char *k = table[i].key;
        const char *q = kind;
        int same = 1;
        while (*k || *q) {
            if (*k != *q) { same = 0; break; }
            k++; q++;
        }
        if (same) return table[i].lines[h % 6];
    }
    return "";
}
