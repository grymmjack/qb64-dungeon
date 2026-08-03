import re, os

G = {}
def g(key, **kw): G[key] = kw

g("RIDDLE", title="THE MAGIC MOUTH", file="RIDDLE.bas", side="game",
  what="A carved mouth asks a riddle. Answer it, or it keeps the door shut.\nSits on the magic-mouth chamber events from PLANS.todo.",
  entry="FUNCTION PlayRiddle% (idx AS INTEGER, wis AS INTEGER)",
  entry_note="`idx` picks the riddle; pass -1 for a random unasked one.",
  stat="WIS", stat_buys="extra attempts, and a successful save buys a hint",
  won="answered", lost="out of attempts -- the door stays shut", left="walked away, no penalty",
  tuning=[("MAXRIDDLE","how many riddles the table can hold")],
  structural=[("RID_SOLVED / RID_FAILED / RID_FLED","legacy outcome codes; map to MG_* at the boundary")],
  art=[("mouth.idle","the carved face, closed"),("mouth.speaking","mid-riddle"),("mouth.pleased","answered"),("mouth.angry","failed")],
  sfx=[("riddle.ask","a low stone grind"),("riddle.right","a satisfied hum"),("riddle.wrong","a stone snap"),("riddle.hint","a whisper")],
  music="none -- it is a conversation, not a set piece",
  theme=[("minigame.riddle.prompt","C_TITLE"),("minigame.riddle.answer","C_TEXT"),("minigame.riddle.hint","C_COOL")],
  reads="wis, level (riddle difficulty band)", reports="outcome, note",
  save="which riddles have been asked this run, or the same one repeats",
  data="riddles belong in a data-pack table (`riddles.txt`: prompt | answers | hint), not in code",
  invariants=["answer matching is generous about case, spacing and articles, and strict about being right",
              "every riddle has at least one accepted answer, checked at load",
              "a hint never contains the answer"])

g("MAZE", title="THE SIREN'S MAZE", file="MAZE.bas", side="engine",
  what="Trace a path to the sigil before the fuse burns out. Generic: it knows nothing\nabout the dungeon, which is why it can live in engine/.",
  entry="FUNCTION PlayMaze% (w AS INTEGER, h AS INTEGER, wis AS INTEGER)",
  entry_note="`w`/`h` are odd cell counts; the maze is generated, never authored.",
  stat="WIS", stat_buys="seconds on the fuse",
  won="reached the sigil", lost="fuse expired", left="walked away",
  tuning=[("BRAID_PCT","how many dead ends get opened up -- higher is easier and less maze-like"),
          ("WARD_W / WARD_H","maze size; must stay ODD or the generator has no valid cells")],
  structural=[("MZ_MAX","array bound; raising it costs memory, lowering it truncates"),
              ("W_N / ALLWALLS","wall bitmask; the generator and the renderer share it")],
  art=[("maze.wall","corridor wall"),("maze.floor","corridor"),("maze.sigil","the goal"),("maze.trace","where you have been")],
  sfx=[("maze.step","a footfall"),("maze.wall","bumping a wall"),("maze.sigil","the ward breaking")],
  music="`minigame-tense` cue, ended on every exit path",
  theme=[("minigame.maze.wall","C_DIM"),("minigame.maze.trace","C_COOL"),("minigame.maze.sigil","C_TITLE"),("minigame.maze.fuse","the shared fuse colours")],
  reads="wis", reports="outcome",
  save="nothing -- a maze is per-encounter",
  data="size and braid percentage per dungeon level, so deeper wards are harder",
  invariants=["every generated maze is SOLVABLE, checked on every generation and not sampled",
              "the fuse is long enough for the measured worst-case solve at a human pace",
              "braiding never disconnects the sigil"])

g("DODGE", title="THE ARROW SLITS", file="DODGE.bas", side="game",
  what="Arrows come out of the wall; step PERPENDICULAR to the shot, not away from it.\nThe corridor trap from PLANS.todo.",
  entry="FUNCTION PlayVolley% (n AS INTEGER, dex AS INTEGER, hits AS INTEGER)",
  entry_note="`n` arrows in the volley; `hits` is how many are already on you.",
  stat="DEX", stat_buys="a wider reaction window",
  won="the volley passed", lost="took the arrows", left="backed out of the corridor",
  tuning=[("D_N","arrows per volley")],
  structural=[("DG_CLEAN / DG_HURT / DG_FLED","legacy outcome codes; map to MG_* at the boundary")],
  art=[("arrow.flight","the arrow in the air"),("slit.armed","a loaded slit"),("slit.spent","a fired one"),("dodge.hero","the player token")],
  sfx=[("dodge.release","the string"),("dodge.pass","it goes by"),("dodge.hit","it does not")],
  music="none -- it is over in seconds",
  theme=[("minigame.dodge.arrow","C_WARN"),("minigame.dodge.safe","C_GOOD"),("minigame.dodge.hit","C_BAD")],
  reads="dex, hp", reports="outcome, hp_delta",
  save="nothing",
  data="arrows per volley and window width per level",
  invariants=["the window is never shorter than human reaction time, at any depth",
              "the correct move is always perpendicular -- a slit that can be dodged by standing still is a slit that teaches the wrong lesson"])

g("GAMBLE", title="KNUCKLEBONES", file="GAMBLE.bas", side="game",
  what="Push-your-luck 2d6 against the house. Any ONE takes the pot.\nThe tavern gamble.",
  entry="FUNCTION PlayGamble% (purse AS LONG, ante AS LONG, wis AS INTEGER)",
  entry_note="the caller owns the purse; the function reports the swing.",
  stat="WIS", stat_buys="the odds shown on screen -- it reads, it does not bend",
  won="banked", lost="busted", left="cashed out",
  tuning=[("HOUSE_PCT","the rake; tuned by Monte Carlo, so changing it changes the proven edge")],
  structural=[("GB_BANKED / GB_BUST / GB_LEFT","legacy outcome codes")],
  art=[("bones.d6","a knucklebone die face"),("bones.pot","the pot"),("bones.table","the felt")],
  sfx=[("bones.throw","the throw"),("bones.settle","they stop"),("bones.bank","banking"),("bones.bust","a one")],
  music="none",
  theme=[("minigame.gamble.pot","C_TITLE"),("minigame.gamble.risk","C_WARN")],
  reads="wis, gold, stake", reports="outcome, gold",
  save="nothing",
  data="the rake, and the ante ladder",
  invariants=["the house edge matches the published figure the rake was tuned to, by Monte Carlo",
              "WIS shows the odds and never changes them"])

g("CRAPS", title="CRAPS", file="CRAPS.bas", side="game",
  what="Come-out roll, then chase the point. The decision is when to walk.",
  entry="FUNCTION PlayCraps% (purse AS LONG, bet AS LONG)",
  entry_note="pass-line only; the caller owns the purse.",
  stat="none -- pure odds, deliberately", stat_buys="nothing; this is the one game where no stat reads for you",
  won="the point made", lost="sevened out", left="walked with the purse",
  tuning=[("(the payout table)","in data, not code")],
  structural=[("CR_COMEOUT / CR_POINT","phase codes; the whole rule set keys off them")],
  art=[("craps.d6","a die face"),("craps.layout","the felt"),("craps.puck","on/off marker")],
  sfx=[("craps.throw",""),("craps.natural",""),("craps.point",""),("craps.sevenout","")],
  music="none",
  theme=[("minigame.craps.point","C_TITLE"),("minigame.craps.loss","C_BAD")],
  reads="gold, stake", reports="outcome, gold",
  save="nothing",
  data="payouts",
  invariants=["the house edge is asserted against the PUBLISHED figure for these exact rules (1.414% pass line), not against a number that felt right",
              "the rules on screen are the rules simulated -- the player asked for a variant once and the maths moved with it"])

g("PLINKO", title="THE FORTUNE SHRINE", file="PLINKO.bas", side="game",
  what="Real physics. Slide a coin along the lip, let go, watch it clatter through a\nrectangular grid of iron studs into a slot.",
  entry="FUNCTION PlayPlinko% (startpurse AS LONG)",
  entry_note="one drop per call is the better integration shape; the prototype loops for convenience.",
  stat="none directly -- PLACEMENT is the skill", stat_buys="nothing; a stat hook here would undercut the one decision the game has",
  won="tripled the stake", lost="ran out", left="walked",
  tuning=[("SHRINE_CUT","the house cut; payouts renormalise around it automatically"),
          ("RISK_LOW / MED / HIGH curves","variance only -- the edge is identical across all three, asserted"),
          ("DROPN","how many placements along the lip")],
  structural=[("PEGROWS / PEGCOLS","the grid MUST reach both walls; anything less leaves a clear channel and a coin falls through untouched"),
              ("GRAV / BOUNCE / WALLBOUNCE / KICK / TOPPLE / RELEASE_JITTER","the physics the payout table is MEASURED from -- change any and the table changes with it"),
              ("DT / SUBSTEP-equivalent","the fixed step the measurement and the animation share")],
  art=[("plinko.case","the cabinet"),("plinko.stud","one iron stud"),("plinko.coin","the coin"),("plinko.slot","a payout slot"),("plinko.lip","the release rail")],
  sfx=[("plinko.clack","stud hit, pitched by impact -- MUST be rate limited"),("plinko.wall","a wall bounce"),("plinko.land","the slot"),("plinko.release","letting go")],
  music="none -- the clatter is the sound design",
  theme=[("minigame.plinko.stud","_RGB32(&H90,&H98,&HA8)"),("minigame.plinko.coin","_RGB32(&HFF,&HD8,&H60)"),("minigame.plinko.case","_RGB32(&H10,&H0E,&H14)"),("minigame.plinko.slot","C_DIM")],
  reads="gold, stake", reports="outcome, gold",
  save="nothing -- but see below",
  data="the cut and the three risk curves. NOT the physics constants: those are structural.",
  invariants=["payouts are MEASURED from the physics at load, never derived -- a bouncing body in a walled field has no closed form",
              "the payout table is rebuilt whenever the board is re-measured, so a table can never outlive its measurement",
              "no placement returns more than the advertised edge; the BEST one hits it exactly, so skill is worth the maximum and still cannot beat the house",
              "every slot is reachable, or the board is advertising a payout it never pays",
              "the measurement runs SILENT -- it drives the real physics ten thousand times at load, and every stud hit asks for a sound"])

g("GUESS", title="THE BOUND SPIRIT", file="GUESS.bas", side="game",
  what="It thinks of a number. You have a budget of guesses and it says higher or lower.",
  entry="FUNCTION PlayGuess% (intel AS INTEGER)",
  entry_note="",
  stat="INT", stat_buys="extra guesses on top of the solvable minimum",
  won="named it", lost="out of guesses", left="walked",
  tuning=[("GRANGE","the range; the budget derives from it automatically")],
  structural=[("(the budget formula)","must never drop below the true worst case, computed by halving")],
  art=[("spirit.bound","the spirit"),("spirit.higher","gesture up"),("spirit.lower","gesture down")],
  sfx=[("guess.higher",""),("guess.lower",""),("guess.right",""),("guess.spent","the last guess")],
  music="none",
  theme=[("minigame.guess.number","C_TITLE"),("minigame.guess.budget","C_WARN")],
  reads="intel", reports="outcome",
  save="nothing",
  data="the range per level",
  invariants=["the budget NEVER drops below ceil(log2(range)), computed by halving rather than by a logarithm",
              "perfect play beats every secret in range, checked exhaustively over all of them"])

g("RPS", title="THE GOBLIN'S GAME", file="RPS.bas", side="game",
  what="Best of five. The goblin is not random: it has a habit, and WIS decides\nwhether you can read it.",
  entry="FUNCTION PlayRps% (wis AS INTEGER)",
  entry_note="",
  stat="WIS", stat_buys="seeing the goblin's tell spelled out",
  won="three throws", lost="three throws against", left="walked",
  tuning=[("PREDICT_PCT","how often the goblin obeys its habit -- the dial between 'no read possible' and 'a read wins outright'")],
  structural=[("TELLS","how many habits exist; each needs a counter-play in CounterPlay%")],
  art=[("rps.rock","hand"),("rps.paper","hand"),("rps.scissors","hand"),("goblin.throwing","the opponent")],
  sfx=[("rps.throw",""),("rps.win",""),("rps.lose",""),("rps.draw","")],
  music="none",
  theme=[("minigame.rps.win","C_GOOD"),("minigame.rps.lose","C_BAD"),("minigame.rps.tell","C_COOL")],
  reads="wis", reports="outcome",
  save="nothing",
  data="the tells and their obey rate",
  invariants=["counter-play beats every tell well above chance, measured over DECIDED throws (draws excluded -- a draw is nobody being right)",
              "...and never approaches certainty, or a spotted tell ends the game",
              "blind play sits at even"])

g("RUNEMEMORY", title="THE RUNE SLAB", file="RUNEMEMORY.bas", side="game",
  what="Concentration on a W x H slab. Some pairs are PAIN runes and cost 1 HP every\ntime they are revealed -- which is what makes memory a mechanic and not a theme.",
  entry="FUNCTION PlaySlab% (cols AS INTEGER, rows AS INTEGER, painpairs AS INTEGER, hpmax AS INTEGER, intel AS INTEGER)",
  entry_note="an odd cell count silently drops one stone rather than dealing an unmatchable one.",
  stat="INT", stat_buys="turns on the budget",
  won="slab cleared", lost="out of turns, or out of HP", left="walked away KEEPING what was matched",
  tuning=[("cols / rows","slab size, per level"),("painpairs","how many cursed pairs"),("hpmax","the HP the slab may spend")],
  structural=[("MAXTILES","array bound"),("RUNE_N","how many distinct runes exist; must be >= pairs")],
  art=[("rune.back","a face-down stone"),("rune.seen","one you have turned before"),("rune.<name>","one per rune"),("rune.pain","the cursed marking")],
  sfx=[("rune.turn",""),("rune.match",""),("rune.bite","a pain rune -- distinct and nasty")],
  music="none",
  theme=[("minigame.rune.back","C_DIM"),("minigame.rune.seen","C_WARN"),("minigame.rune.face","C_GOOD"),("minigame.rune.pain","C_BAD")],
  reads="intel, hp, hpmax", reports="outcome, hp_delta, gold (spoils for pairs matched)",
  save="nothing -- a slab is per-encounter",
  data="size, pain-pair count and HP allowance per level",
  invariants=["perfect play clears EVERY deal inside the turn budget -- the first budget I derived sat one turn under the measured worst case",
              "the budget is not padded either: the worst case sits just under it",
              "damage is charged per REVEAL, not per stone -- that is the entire design, and it is what makes the three simulated memory tiers bleed 6.3 / 8.8 / 48.6 HP",
              "perfect play never dies on the default slab"])

g("MONKEYSEE", title="MONKEY SEE, MONKEY DO", file="MONKEYSEE.bas", side="engine",
  what="Simon. Four glyph-stones light in a sequence; repeat it. Every round adds ONE.\nGeneric enough for engine/.",
  entry="FUNCTION PlayMonkey% (wis AS INTEGER)",
  entry_note="",
  stat="WIS", stat_buys="[R]ecall charges -- another LOOK at the same sequence, capped",
  won="cleared the last round", lost="a wrong stone", left="walked",
  tuning=[("WINROUND","how deep it goes"),("FLASH_MIN","the readable floor -- lowering it is the one change that can make the game unfair")],
  structural=[("MAXSEQ","array bound; must exceed WINROUND"),("PADS","four; the tone table and the key map are sized to it")],
  art=[("pad.sun","stone 1"),("pad.moon","stone 2"),("pad.stag","stone 3"),("pad.wyrm","stone 4"),("pad.lit","the lit overlay")],
  sfx=[("pad.sun","330Hz"),("pad.moon","415Hz"),("pad.stag","494Hz"),("pad.wyrm","622Hz"),("monkey.fail","")],
  music="none -- the pads ARE the music",
  theme=[("minigame.monkey.pad1..4","one per stone"),("minigame.monkey.lit","the lit state")],
  reads="wis", reports="outcome",
  save="nothing",
  data="round count and flash timing per level",
  invariants=["the sequence is FIXED up front; each round reveals a longer PREFIX. Regenerating per round is indistinguishable for exactly one round and then feels broken forever",
              "no stone lights three times running -- a triple reads as one long flash, i.e. as the game's fault when you lose to it",
              "the flash never drops below FLASH_MIN at any depth: past a point faster is not harder, it is unreadable",
              "a recall re-shows the SAME sequence -- it does not re-deal"])

g("LOCKPICK", title="THE PICK AND THE PINS", file="LOCKPICK.bas", side="engine",
  what="Feel for the notch that sets each pin on a 24-notch dial. A SEARCH, not a\nquick-time event -- the catalogue rejected the QTE version explicitly.",
  entry="FUNCTION PlayLock% (dex AS INTEGER)",
  entry_note="",
  stat="DEX", stat_buys="seconds on the fuse, and nothing else",
  won="every pin set", lost="the fuse ran out", left="gave up",
  tuning=[("PINS","how many pins"),("(the fuse base in LockFuse!)","seconds")],
  structural=[("NOTCHES","dial size; the band table and the coarse JUMP are derived from it"),
              ("JUMP","the coarse step; must divide NOTCHES or the sweep misses positions"),
              ("T_FINE / T_JUMP / T_SET / T_MISS","move costs -- the fuse budget is DERIVED from these"),
              ("THINK_PER_MOVE","the human allowance the fuse is proved against")],
  art=[("lock.dial","the dial"),("lock.marker","the pick position"),("lock.pin.set","a set pin"),("lock.pin.open","an unset one")],
  sfx=[("lock.turn","one notch"),("lock.jump","a coarse jump"),("lock.set","a pin giving"),("lock.slip","a wrong set"),("lock.snap","the fuse")],
  music="`minigame-tense`",
  theme=[("minigame.lock.dial","C_DIM"),("minigame.lock.marker","C_COOL"),("minigame.lock.set","C_GOOD")],
  reads="dex", reports="outcome",
  save="nothing",
  data="pin count and fuse per level",
  invariants=["the fuse drains in BOTH real time and move cost -- with only the latter, standing still was free and the fuse was a move budget wearing a bar",
              "an efficient search fits, proved EXHAUSTIVELY over all 576 (start, target) pairs, not sampled",
              "brute force does NOT fit, on move cost alone, so a key-masher cannot beat it -- this is the assertion that broke when the fuse grew and forced T_FINE up",
              "the direction hint is only offered inside CLOSE range and always points the SHORT way round"])

g("TRAPDISARM", title="FIVE WIRES AND A SET OF NOTES", file="TRAPDISARM.bas", side="game",
  what="Deduce the one legal cut order from notes scratched on the plate.",
  entry="FUNCTION PlayTrap% (intel AS INTEGER)",
  entry_note="",
  stat="INT", stat_buys="extra TRUE notes about the same unchanged order",
  won="disarmed", lost="two strikes", left="backed away",
  tuning=[("(strike count)","how many wrong cuts before it fires")],
  structural=[("WIRES","5; PERMS must equal WIRES! and BuildPerms is written for it"),
              ("PERMS","120 -- the uniqueness scan is a full enumeration"),
              ("MAXCLUE","note-table bound"),("CL_BEFORE / CL_ADJ / CL_NOTAT / CL_AT","note kinds; each needs a case in Holds% AND in NoteText$")],
  art=[("wire.copper","..."),("wire.sinew","..."),("wire.bone","..."),("wire.iron","..."),("wire.silver","..."),("trap.plate","the notes"),("wire.cut","a cut wire")],
  sfx=[("trap.cut",""),("trap.snap","a wrong cut"),("trap.disarm",""),("trap.fire","")],
  music="`minigame-tense`",
  theme=[("minigame.trap.wire.*","one per wire colour"),("minigame.trap.note","C_TEXT"),("minigame.trap.cut","C_DIM")],
  reads="intel", reports="outcome, hp_delta",
  save="nothing",
  data="wire names and colours; the note KINDS are structural",
  invariants=["EVERY generated puzzle has exactly one solution, brute-forced over all 120 orderings on every generation",
              "...and that solution is the order the player is graded against -- unique-but-different would be the cruellest possible bug",
              "every note is load-bearing: switch any one off and the answer goes ambiguous",
              "INT's extra notes are TRUE of the same unchanged order, and the answer stays unique with them on"])

g("CUPSHUFFLE", title="THE COIN AND THE CUPS", file="CUPSHUFFLE.bas", side="game",
  what="Follow the coin through a shuffle. The game does not palm it.",
  entry="FUNCTION PlayCups% (cups AS INTEGER, swaps AS INTEGER, wis AS INTEGER)",
  entry_note="",
  stat="WIS", stat_buys="a dealer FUMBLE -- one cup lifted mid-shuffle. Information, not odds.",
  won="named the right cup", lost="named a wrong one", left="walked",
  tuning=[("cups","2..5"),("swaps","how many")],
  structural=[("SLIDE_MIN","the animation floor -- below it the cups teleport and the game silently becomes a 1-in-N guess"),
              ("MAXCUPS / MAXSWAP","array bounds")],
  art=[("cup.closed","a cup"),("cup.lifted","one being lifted"),("cup.coin","the gold piece"),("cup.table","the surface")],
  sfx=[("cup.slide","one swap"),("cup.lift",""),("cup.win",""),("cup.lose","")],
  music="none",
  theme=[("minigame.cup.body","_RGB32(&H70,&H50,&H30)"),("minigame.cup.coin","C_TITLE")],
  reads="wis", reports="outcome, gold",
  save="nothing",
  data="cup and swap counts per level",
  invariants=["the coin is never moved except by a swap the player was SHOWN -- proved by replaying the swap list over a separately tracked index and demanding it agree",
              "no swap is ever a no-op, and the slide has a hard floor: both read as a dropped frame, and a player who cannot follow correctly concludes tracking is pointless",
              "the coin finishes under each cup about equally often",
              "a WIS fumble only LIFTS a cup -- it never nudges the coin"])

g("WHACKAGOBLIN", title="WHACK-A-GOBLIN", file="WHACKAGOBLIN.bas", side="game",
  what="Nine holes in a cellar floor. About a third of what comes up must NOT be hit --\na go/no-go task rather than a reflex test.",
  entry="FUNCTION PlayWhack% (dex AS INTEGER)",
  entry_note="",
  stat="DEX", stat_buys="longer visibility per target -- time to decide, never an auto-hit",
  won="reached the target score", lost="did not", left="walked",
  tuning=[("TARGET","the score needed -- DERIVED from the sloppy-player simulation, not chosen"),
          ("HIT_GOOD / HIT_BAD","scoring")],
  structural=[("N_FOES / N_DECOYS","the mix is EXACTLY these counts, shuffled; rolling it per target spread the count 12-26 and broke all three fairness claims at once"),
              ("UP_FLOOR","the visibility floor, set well clear of REACTION"),
              ("REACTION","the human budget the floor is measured against"),("HOLES / MAXPOP","bounds")],
  art=[("hole.empty","a hole"),("mob.goblin","hit this"),("mob.pup","asleep, do not"),("mob.mimic","hits back"),("mob.mule","yours"),("whack.shovel","the cursor")],
  sfx=[("whack.hit","a goblin"),("whack.wrong","a decoy"),("whack.miss","the floor"),("whack.rise","something coming up")],
  music="`minigame-frantic`",
  theme=[("minigame.whack.goblin","C_GOOD"),("minigame.whack.decoy.*","one per decoy kind"),("minigame.whack.hole","C_DIM")],
  reads="dex", reports="outcome, gold, hp_delta",
  save="nothing",
  data="the decoy roster and the mix",
  invariants=["a player who swings at EVERYTHING must lose, or the discrimination is decorative",
              "perfect discrimination must WIN, on every round",
              "a good-but-human player wins too -- at TARGET 14 an attentive player failed a third of all rounds, which is not challenging, it is a game that hates attentive players. It is 12.",
              "no hole ever holds two things at once -- that is unresolvable, not hard",
              "every target is up longer than human reaction time at any depth"])

g("BLACKJACK", title="TWENTY-ONE", file="BLACKJACK.bas", side="game",
  what="One deck, dealer stands on all 17s, natural pays 3:2, double on the first two,\nno splits, no hole-card peek. The only game here whose skill is a TABLE.",
  entry="FUNCTION PlayJack% (purse AS INTEGER)",
  entry_note="",
  stat="none", stat_buys="nothing -- basic strategy is the skill and it is learnable",
  won="doubled the purse", lost="broke", left="cashed out",
  tuning=[("BJ_PAY","the natural payout -- changing it changes the measured edge"),("RESHUFFLE","penetration")],
  structural=[("DECKN","52; ShoeWellFormed% asserts four of each rank"),("MAXHAND","bound"),
              ("(the strategy table)","it IS the game's advice; a wrong table is worse than none")],
  art=[("card.<rank>","thirteen faces"),("card.back","the hole card"),("jack.felt","the table")],
  sfx=[("card.deal",""),("card.hit",""),("jack.win",""),("jack.bust",""),("jack.natural","")],
  music="none",
  theme=[("minigame.jack.felt","dark green"),("minigame.jack.win","C_GOOD"),("minigame.jack.bust","C_BAD")],
  reads="gold, stake", reports="outcome, gold",
  save="nothing",
  data="the rules variant and the payout; the strategy table follows the rules and must be re-measured if they change",
  invariants=["basic strategy loses slowly (-0.25 per 100 staked), mimic-the-dealer loses several times faster (-5.09), never-bust worse still (-15.75). If those three do not come out in that order the table is wrong -- and a wrong table teaches a habit that costs money while calling it advice",
              "the shoe deals WITHOUT replacement, or the measured edge is fiction",
              "soft-hand arithmetic is right on three-card hands, which is where the classic ace bug lives"])

g("SPINWHEEL", title="THE WHEEL OF MYSTERY", file="SPINWHEEL.bas", side="game",
  what="A heavy iron wheel. Crank it up/down to build momentum, let go, and whatever it\nstops on happens. A spin that fails to complete a full turn has BALKED.",
  entry="FUNCTION PlayWheel% ()",
  entry_note="takes nothing today; integration should pass MG_CTX for the level, since the wedge table should vary by depth.",
  stat="none", stat_buys="nothing -- the crank is the only input and it deliberately cannot aim",
  won="always -- the outcome is the wedge, reported in res", lost="n/a", left="did not pull the handle",
  tuning=[("the wedge table","names, tells, WIDTHS -- the widths ARE the odds and belong in data"),
          ("MAXTRAVEL","how far a full crank goes"),("FRICTION","how long it coasts")],
  structural=[("TRAVEL_SLOP","the anti-aim term; MUST exceed 360 or crank settings become aimable"),
              ("BALK_AT","one full turn"),("MIN_RELEASE","below this the handle does not move at all"),
              ("SUBSTEP / MAX_STEP","the animation's fixed step; a per-frame step made every spin look identical"),
              ("(the square travel curve)","linear made a weak crank spin nearly as far as a hard one")],
  art=[("wheel.rim","the painted rim"),("wheel.hub",""),("wheel.spoke","the tracking mark -- without it fast and slow both read as a shimmer"),("wheel.pointer",""),("wheel.handle","")],
  sfx=[("wheel.crank","one stroke, pitched by charge"),("wheel.tick","a wedge passing, pitched by speed"),("wheel.settle",""),("wheel.balk","the punishment")],
  music="`minigame-fate`, ended when the wedge resolves",
  theme=[("minigame.wheel.<wedge>","one per wedge -- but see below"),("minigame.wheel.spoke","near-white"),("minigame.wheel.pointer","C_TITLE")],
  reads="level (which wedge table)", reports="outcome, gold, hp_delta, item -- the WEDGE is the result",
  save="nothing",
  data="the whole wedge table, including widths",
  invariants=["the outcome is READ off the angle it stopped at, never picked and animated toward",
              "the wedge announced is the wedge DRAWN under the pointer. These are checked SEPARATELY, because the first version passed 60000 spins of the first claim while announcing a wedge two positions from the one on screen -- the test replayed the same sign convention the bug lived in",
              "NO crank setting aims the wheel, checked at EVERY setting rather than on average: one exploitable charge value is all it takes",
              "a balked wheel finishes the spin ITSELF, so nudging selects nothing",
              "the crank is workable by a human hand -- reaching full charge at a human stroke rate, and surviving the moment it takes to reach for SPACE"])

g("TRUENAME", title="SPEAK ITS NAME", file="TRUENAME.bas", side="game",
  what="A warded door names a thing by description; you type what it is. The roster is\non screen, so it is RECALL, not a vocabulary exam.",
  entry="FUNCTION PlayName% (wis AS INTEGER)",
  entry_note="",
  stat="WIS", stat_buys="the first letter",
  won="named enough in a row", lost="out of lives", left="backed away",
  tuning=[("WINSTREAK","how many"),("READ_TIME","seconds to read the clue before typing")],
  structural=[("SLOW_CPS","the typing pace the fuse is DERIVED from -- lowering it to make the game harder is changing an estimate to fit, not tuning"),
              ("ROSTER","how many entries")],
  art=[("name.door","the ward"),("name.roster","the list frame")],
  sfx=[("name.key","a keystroke"),("name.right",""),("name.wrong",""),("name.timeout","")],
  music="none",
  theme=[("minigame.name.clue","C_TITLE"),("minigame.name.typed","C_TEXT"),("minigame.name.hint","C_COOL")],
  reads="wis", reports="outcome",
  save="nothing",
  data="the roster -- and it should come from the BESTIARY, so it stays in step with the monsters that actually exist",
  invariants=["the fuse is derived from the LONGEST name at a one-finger pace, with reading time ON TOP. Nobody may lose this for typing slowly; they lose it for not knowing",
              "matching ignores case, spacing and punctuation, and still rejects near misses",
              "no two names normalise to the same key, or one of them becomes unanswerable"])

g("SCRAMBLE", title="THE SCATTERED WORD", file="SCRAMBLE.bas", side="game",
  what="Letters carved out of order. Put them back.",
  entry="FUNCTION PlayScr% (intel AS INTEGER)",
  entry_note="",
  stat="INT", stat_buys="revealing the next letter in place",
  won="enough words", lost="out of lives", left="left",
  tuning=[("WINSTREAK",""),("THINK_TIME","seconds to solve before typing time starts")],
  structural=[("SLOW_CPS","as TRUENAME"),("WORDN","list size")],
  art=[("scramble.door","the carved door"),("scramble.tile","one letter")],
  sfx=[("scramble.key",""),("scramble.right",""),("scramble.wrong",""),("scramble.reveal","")],
  music="none",
  theme=[("minigame.scramble.letters","C_TITLE"),("minigame.scramble.reveal","C_COOL")],
  reads="intel", reports="outcome",
  save="nothing",
  data="the word list -- and the anagram check MUST run against whatever a pack supplies",
  invariants=["NO TWO WORDS IN THE LIST MAY BE ANAGRAMS. The player unscrambles correctly, types a real answer, and is told they are wrong -- unrecoverable as a player, invisible as an author, because the fault is in the PAIR. The first run of this check found SCEPTRE and SPECTRE eight entries apart in a list I had just written",
              "a scramble uses every letter and no others",
              "it never comes out as the word itself, and never spells a DIFFERENT word from the list"])

g("OPENTHECHEST", title="THE THREE CLASPS", file="OPENTHECHEST.bas", side="game",
  what="Three colour-coded clasps, opened in one order. Every clasp is re-dealt after\neach pick, so the answer is a colour and never a position.",
  entry="FUNCTION PlayChest% (lv AS INTEGER)",
  entry_note="THE INTEGRATION POINT: it must take the run's code table, not own one. See below.",
  stat="none -- the LEVEL MEMORY is the mechanic", stat_buys="nothing; a stat hook would undercut the code being worth learning",
  won="opened", lost="the fuse ran out", left="backed away",
  tuning=[("FUSE_SECS","seconds once armed -- see the invariant, this is NOT free to change"),
          ("HUMAN_PICK","the modelled cost of a deliberate pick; the fuse is proved against it")],
  structural=[("CLASPS / HUES","three of each; a code is a permutation of the hues"),
              ("LEVELS","9 -- one code per dungeon level"),("ARTN","the art key table size")],
  art=[("chest.closed",""),("chest.open",""),("chest.blown",""),("clasp.closed",""),("clasp.open",""),("lid",""),("box","the hoard beneath"),("cursor","")],
  sfx=[("chest.pick","moving the cursor"),("chest.correct",""),("chest.wrong",""),("chest.shuffle","the clasps tumbling"),("chest.open",""),("chest.trap","")],
  music="`minigame-tense` once the fuse is armed, and only then",
  theme=[("minigame.chest.clasp.a/b/c","the three clasp colours -- CONTENT, a pack may want different ones"),("minigame.chest.wood",""),("minigame.chest.fuse","the shared fuse colours")],
  reads="level -- and the run's code table", reports="outcome, gold, `learned` (this level's code is now known)",
  save="THE CODES AND WHICH ARE KNOWN. A reload that re-charges a player for a code they already bought is the worst kind of bug, because it looks like the game working. Format: nine `<code><K|->` groups on one save line.",
  data="clasp colours and count; the fuse and the pick estimate",
  invariants=["a player who KNOWS the code wins EVERY time. If the re-deal can ever put a needed colour out of reach, the level memory is worthless and the first chest was robbery",
              "the re-deal is UNIFORM. Forcing it to always change means excluding the identity permutation, which biases where the answer lands (measured 40/20/40 against 33/33/33). Visible movement is a presentation problem and is solved by the tumble animation",
              "the fuse NEVER stops. Nothing blocks; messages carry an expiry and the shuffle is a frame counter. The first version paused and then discounted those seconds back, which is a fuse you can watch stop AND a rule someone must remember at every future pause",
              "a wrong clasp never touches the fuse -- which makes the fuse LENGTH the only thing between a patient guesser and a free chest. At 6.5s a simulated guesser opened 100% of chests by elimination. The length is derived: one more pick must fit, two must not",
              "one code per LEVEL, shared by every chest on it, learned once, and two levels may share a code by chance -- forcing them distinct is itself information"])

TMPL = """# {name} — API

**{title}** · `{file}` · lands in **`{side}/`**

Read [MINIGAME-API.md](MINIGAME-API.md) first — this file only covers what is
specific to this game.

## What it is

{what}

## Entry point

```basic
{entry}
```

{entry_note}
Integration signature should become the standard one:

```basic
FUNCTION Play{camel}% (ctx AS MG_CTX, res AS MG_RESULT)
```

| outcome | means |
|---|---|
| `MG_WON` | {won} |
| `MG_LOST` | {lost} |
| `MG_LEFT` | {left} |

## Configuration

**Tuning** — a data pack may set these and the game still works:

{tuning}

**Structural** — changing these breaks an invariant or invalidates a measured
number. They are code, not content:

{structural}

## Art keys

{art}

Missing means the built-in placeholder, never a failure. A placeholder must stay
detectable as one so `imagemanifest audit` keeps listing it.

## Sound keys

{sfx}

Every one needs a hand-tuned `Tone` fallback so a pack shipping none still sounds
like something. Raw `SOUND` is forbidden.

## Music

{music}

## Theme keys

{theme}

Each call passes its own fallback, so a pack may restyle one colour and stay
silent about the rest.

## Run state

- **reads from `MG_CTX`:** {reads}
- **reports in `MG_RESULT`:** {reports}
- **must survive a save:** {save}

## Content that belongs in a data pack

{data}

## Stat hook

**{stat}** — {stat_buys}

## Invariants the integration must not break

{invariants}

Each of these is an assertion in `{file}`'s selftest. If integration changes the
numbers, re-run it — the assertions are written to fail loudly rather than to
pass quietly.
"""

def bullets(rows):
    if not rows: return "_none_\n"
    out = []
    for a, b in rows:
        out.append("- `%s`%s" % (a, (" — " + b) if b else ""))
    return "\n".join(out) + "\n"

def numbered(items):
    return "\n".join("%d. %s" % (i + 1, t) for i, t in enumerate(items)) + "\n"

CAMEL = {"RIDDLE":"Riddle","MAZE":"Maze","DODGE":"Volley","GAMBLE":"Gamble","CRAPS":"Craps",
         "PLINKO":"Plinko","GUESS":"Guess","RPS":"Rps","RUNEMEMORY":"Slab","MONKEYSEE":"Monkey",
         "LOCKPICK":"Lock","TRAPDISARM":"Trap","CUPSHUFFLE":"Cups","WHACKAGOBLIN":"Whack",
         "BLACKJACK":"Jack","SPINWHEEL":"Wheel","TRUENAME":"Name","SCRAMBLE":"Scr","OPENTHECHEST":"Chest"}

for name, d in G.items():
    src = open(d["file"]).read()
    # keep the docs honest: every named constant must actually exist
    missing = []
    for a, _ in d["tuning"] + d["structural"]:
        tok = a.split()[0].strip("()")
        if tok and tok[0].isupper() and "/" not in tok and not re.search(r"^CONST %s\b" % re.escape(tok), src, re.M):
            missing.append(tok)
    body = TMPL.format(
        name=name, title=d["title"], file=d["file"], side=d["side"], what=d["what"],
        entry=d["entry"], entry_note=(d["entry_note"] + "\n" if d["entry_note"] else ""),
        camel=CAMEL[name], won=d["won"], lost=d["lost"], left=d["left"],
        tuning=bullets(d["tuning"]), structural=bullets(d["structural"]),
        art=bullets(d["art"]), sfx=bullets(d["sfx"]), music=d["music"],
        theme=bullets(d["theme"]), reads=d["reads"], reports=d["reports"], save=d["save"],
        data=d["data"], stat=d["stat"], stat_buys=d["stat_buys"],
        invariants=numbered(d["invariants"]))
    open("%s-API.md" % name, "w").write(body)
    if missing:
        print("  %-14s constants named in the doc but NOT in the source: %s" % (name, ", ".join(missing)))

print("wrote %d API docs" % len(G))
