' ============================================================================
'  GAME.BI -- DUNGEON!-specific globals / TYPEs / CONSTs (the swappable layer)
'  Split out of the old include/DUNGEON.BI. Included AFTER engine/ENGINE.BI.
'
'  A different game replaces THIS header (+ game/*) and reuses engine/* + the
'  engine header unchanged. Everything here encodes TSR Dungeon! content or
'  rules: the board sectors/rooms, monster/treasure/spell tables, class win
'  totals, inventory, chambers, solo modes, the per-run chronicle, and flavor.
' ============================================================================

' (START_CX/START_CY moved to ENGINE.BI -- "where the cursor starts on the board" is
'  engine state. The GAME still reads it freely: that this is also the win-return point
'  and the heal spot is a DUNGEON! rule, but the coordinate itself is not.)
' --- gameplay tuning (potions, encounters, XP) ---
DIM SHARED POTION_SMALL_DIE AS INTEGER  ' Small Healing Potion heals 1d4
DIM SHARED POTION_LARGE_DIE AS INTEGER  ' Large Healing Potion heals 1d8...
DIM SHARED POTION_LARGE_BONUS AS INTEGER  ' ...+1  (Large potion heals 1d8+1)
DIM SHARED TREASURE_POTION_PCT AS INTEGER  ' % chance a slain hoard also yields a potion -- kept lean
DIM SHARED TREASURE_LARGE_PCT AS INTEGER  ' when a hoard potion drops, % chance it's the LARGE (1d8+1) kind
DIM SHARED LEVELCLEAR_LARGE_PCT AS INTEGER  ' % chance clearing a level also yields a Large potion
DIM SHARED IDLE_ENCOUNTER_PCT AS INTEGER  ' % chance a wanderer appears once the loiter meter is full
DIM SHARED LOITER_THRESHOLD AS INTEGER  ' loiter ticks (searches / idle beats) before a wander check
DIM SHARED WANDER_GOLD_DIV AS INTEGER  ' wandering-monster gold = level treasure / this (lean -- no farming)
DIM SHARED XP_PER_KILL_LVL AS INTEGER  ' XP per slain monster = its dungeon level * this (+ boss bonus)
DIM SHARED CHEST_PCT AS INTEGER  ' % chance a curio turns up after a room fight

' What KIND of thing is being spawned -- the only input MonsterStats needs besides the depth.
CONST MK_ROOM = 0        ' an ordinary lair monster
CONST MK_BOSS = 1        ' the one boss lair on a deep level
CONST MK_LORD = 2        ' the LORD of a chamber (chamber-events.txt `lord`)
CONST MK_WANDER = 3      ' a wandering ambush drawn by loitering
CONST MK_MIMIC = 4       ' a curio chest that turns out to have teeth

' --- MONSTER SCALING (D&D mode) -- see MonsterStats / MonsterToHit% in game/SECTOR.bas ---
' These formulas used to be copy-pasted at five spawn sites (room, boss, wanderer, chamber
' guardian, chamber LORD, mimic) as bare literals, so "the level-8 lord hits too hard" meant
' editing code in three files and there was no way to measure or tune it. One funnel, one
' table, and `dungeon.run econdump` can reason about it.
DIM SHARED MON_HP_PER_LVL AS INTEGER    ' flat HP per dungeon level
DIM SHARED MON_HP_DIE_BASE AS INTEGER   ' HP die sides at level 0...
DIM SHARED MON_HP_DIE_STEP AS INTEGER   ' ...growing by this per level (L1 d6 .. L9 d22 at 4/2)
DIM SHARED MON_AC_BASE AS INTEGER       ' armour class = this + level
DIM SHARED MON_AC_MAX AS INTEGER        ' hard cap: AC can never outrun a hero's best to-hit
DIM SHARED MON_TOHIT_MAX AS INTEGER     ' hard cap on the monster's d20 bonus
DIM SHARED BOSS_HP_BASE AS INTEGER      ' the one boss lair: flat HP...
DIM SHARED BOSS_HP_PER_LVL AS INTEGER   ' ...+ this per level, + 1d10
DIM SHARED BOSS_AC AS INTEGER
DIM SHARED BOSS_TOHIT_BONUS AS INTEGER  ' + to the monster's d20 attack
DIM SHARED LORD_HP_PCT AS INTEGER       ' chamber LORD: % of an ordinary guardian's HP
DIM SHARED LORD_AC_BONUS AS INTEGER
DIM SHARED LORD_TOHIT_BONUS AS INTEGER
DIM SHARED WANDER_AC_BONUS AS INTEGER   ' wanderers travel light -- softer than a lair monster
DIM SHARED MIMIC_HP_PER_LVL AS INTEGER
DIM SHARED MIMIC_AC_BASE AS INTEGER
DIM SHARED CHEST_TRAP_PCT AS INTEGER  ' % chance a curio CHEST is trapped
DIM SHARED CURIO_PATH_PCT AS INTEGER  ' % chance per explored corridor step that a curio turns up
DIM SHARED CURIO_COOLDOWN AS INTEGER  ' minimum steps between path curios (anti-spam)
TYPE CURIO_T
    kind AS STRING * 12           ' the mechanic (dispatched in code)
    nm AS STRING * 24             ' display name
    weight AS INTEGER             ' relative spawn frequency
    prompt AS STRING * 96         ' the discovery line
END TYPE
DIM SHARED CURIOS(1 TO 40) AS CURIO_T
DIM SHARED NCURIO AS INTEGER
DIM SHARED curio_cool AS INTEGER  ' steps since the last path curio (counts down)
DIM SHARED SIREN_ENCOUNTER_BOOST AS INTEGER  ' + to the wandering-encounter % while a magic siren wails
DIM SHARED SIREN_MOVE_PCT AS INTEGER  ' % chance each step (while a siren wails) to draw an encounter
DIM SHARED FLEE_FAIL_BASE AS INTEGER  ' % chance a flee attempt fails (monster drags you back) on level 1
DIM SHARED FLEE_FAIL_STEP AS INTEGER  ' + this % per dungeon level deeper (level 9 = 15 + 8*5 = 55%)

TYPE SECTOR
    start_x AS INTEGER
    start_y AS INTEGER
    end_x   AS INTEGER
    end_y   AS INTEGER
    kolor   AS _UNSIGNED LONG
    label   AS STRING
    monster AS STRING
    mnum    AS INTEGER       ' 2d6 total needed to defeat (baked for the roller's class)
    mslot   AS INTEGER       ' which of the level's 3 monsters (for per-player kill numbers)
    mgold   AS INTEGER       ' treasure guarded (sits under the monster)
    malive  AS INTEGER
    is_boss AS INTEGER       ' room flag: tougher guardian
    treasure AS INTEGER      ' gold value of the treasure the monster guards
    treasure_name AS STRING  ' name of that treasure (Dungeon!-style)
    trapped AS INTEGER       ' the treasure is trapped
    looted  AS INTEGER       ' treasure already taken
    secret_here AS INTEGER   ' (unused) legacy flag
    secret_found AS INTEGER  ' (unused) legacy flag
    treasure_item AS INTEGER ' special-item code for this room's treasure (see TRE_ITEM)
    monster_fought AS INTEGER ' room flag: combat has happened here
    player_died AS INTEGER    ' room flag: the player was slain/downed here
    mhp     AS INTEGER       ' D&D mode: monster max hit points
    mhp_now AS INTEGER       ' D&D mode: monster current hit points (mid-fight)
    mac     AS INTEGER       ' D&D mode: monster armor class (d20+tohit must meet/beat)
END TYPE

' An individual room block (a colored rectangle within a sector). EVERY reachable
' room holds a monster guarding a treasure -- detected by flood-fill (DetectRooms).
TYPE ROOM
    sec     AS INTEGER        ' which sector/level this block belongs to
    cells   AS INTEGER        ' size of the block (tiny blocks = labels, no encounter)
    ' How many of those cells are PLAIN room floor -- not a doorway, not one of the art's
    ' decorative half-block lips, not a cell with a text glyph on it. This is the honest size
    ' of a room, and `cells` is not: the level plaques ("4th", "5th", ...) are blocks of level
    ' colour with letters printed on them, so they flood-fill into ROOMS() at 4 cells and clear
    ' the MIN_ROOM gate while having ZERO cells anything can stand on. See PlaceRoomMarkers.
    floor_cells AS INTEGER
    cx      AS INTEGER        ' marker cell: where the monster glyph / headstone sits
    cy      AS INTEGER
    monster AS STRING * 18
    mslot   AS INTEGER        ' which of the level's 3 monsters (per-class kill numbers)
    is_boss AS INTEGER
    malive  AS INTEGER
    mhp     AS INTEGER
    mhp_now AS INTEGER
    mac     AS INTEGER
    treasure AS INTEGER
    treasure_name AS STRING * 22
    treasure_item AS INTEGER
    looted  AS INTEGER
    monster_fought AS INTEGER
    player_died AS INTEGER
    is_chamber AS INTEGER     ' a scratch CHAMBER encounter (3 monsters, no treasure)
    seen    AS INTEGER        ' the player has entered this room -- only then is its monster drawn
    ' Loot a fallen champion left here (recoverable by any player).
    ' EVERY carried item has a slot here. It used to stash only gold + sword/secret/esp/
    ' crystal while DropEverything cleared the WHOLE kit, so armour, shield, bow, boots,
    ' teleport scrolls and potions were destroyed by a death and could never be reclaimed --
    ' the hoard you walked back for handed you gold and a Crystal Ball and nothing else.
    drop_gold AS LONG
    drop_sword AS INTEGER
    drop_secret AS INTEGER
    drop_esp AS INTEGER
    drop_crystal AS INTEGER
    drop_armor AS INTEGER
    drop_shield AS INTEGER
    drop_bow AS INTEGER
    drop_boots AS INTEGER
    drop_teleport AS INTEGER
    drop_pot_sm AS INTEGER
    drop_pot_lg AS INTEGER
END TYPE

TYPE PCLASS
    name         AS STRING
    gold_goal    AS LONG
    combat_bonus AS INTEGER     ' added to the 2d6 attack roll (Oldschool mode)
    secret_bonus AS INTEGER     ' edge at finding secret doors
    blurb        AS STRING
    hp           AS INTEGER     ' D&D mode: base max hit points (fallback if not rolled)
    tohit        AS INTEGER     ' D&D mode: base bonus added to the d20 attack roll
    dmg          AS INTEGER     ' D&D mode: damage die (sides)
    ac           AS INTEGER     ' D&D mode: base armor class (defence)
    hitdie       AS INTEGER     ' D&D mode: hit die size for rolling HP at character creation
END TYPE

' One hot-seat player's complete state (parked here between turns; the active
' player's state lives in the working globals -- see Load/SaveActivePlayer).
TYPE PLAYER
    active   AS INTEGER         ' still in the game
    name     AS STRING * 40     ' fixed-length (variable-len in a UDT array crashes QB64); 40 fits long random names
    klass    AS INTEGER         ' class index 1..4
    gold     AS LONG
    goal     AS LONG
    has_key  AS INTEGER
    sword    AS INTEGER
    secret_card AS INTEGER
    esp      AS INTEGER
    crystal  AS INTEGER
    hp       AS INTEGER
    maxhp    AS INTEGER
    sstr     AS INTEGER
    sint     AS INTEGER
    swis     AS INTEGER
    sdex     AS INTEGER
    scon     AS INTEGER
    scha     AS INTEGER
    tohit    AS INTEGER
    ac       AS INTEGER
    dmgdie   AS INTEGER
    dmgbonus AS INTEGER
    cx       AS INTEGER         ' cursor pixel position
    cy       AS INTEGER
    kolor    AS _UNSIGNED LONG  ' board token colour
    ' --- the rest of the per-seat run state -------------------------------------
    ' These were plain globals with no home in this record, so in hot-seat they were
    ' SHARED between players: one player's potions, spell charges, XP and poison timer
    ' were everyone's (they were cleared per GAME, not per SEAT). Load/SaveActivePlayer
    ' park and restore them now, so each seat truly owns its own kit.
    armor    AS INTEGER         ' BODY ARMOR AC bonus
    shield   AS INTEGER         ' SHIELD AC bonus (separate slot, adds to armor)
    bow      AS INTEGER         ' Magic Bow: +2 to-hit
    boots    AS INTEGER         ' Elf Boots: +2 movement roll
    teleport AS INTEGER         ' Teleport scrolls / spell charges
    pot_sm   AS INTEGER         ' small healing potions held
    pot_lg   AS INTEGER         ' large healing potions held
    sp_fire  AS INTEGER         ' WIZARD Fire Ball charges
    sp_bolt  AS INTEGER         ' WIZARD Lightning Bolt charges
    clevel   AS INTEGER         ' D&D character level
    cxp      AS LONG            ' accumulated XP
    t_poison AS INTEGER         ' status timers -- poison darts (-1 HP/turn)
    t_fire   AS INTEGER         '                 bomb fire (-1 HP/turn)
    t_frost  AS INTEGER         '                 frost bomb (movement frozen)
    t_siren  AS INTEGER         '                 magic siren (encounter chance up)
    t_curse  AS INTEGER         '                 cursed: -1 hit/damage
END TYPE

DIM SHARED SECTORS(1 TO 9) AS SECTOR
' individual room blocks (per-block encounters), detected from the board art
DIM SHARED ROOMS(1 TO 400) AS ROOM, ROOM_N AS INTEGER
' How many DECORATION blocks DropDecorRooms threw away this board build (the level plaques).
' Kept only so `dungeon.run roomlint` can still report them -- they are not rooms, so they are
' not in ROOMS() and every surviving entry in ROOMS() holds a monster.
DIM SHARED DECOR_N AS INTEGER
' Spoils left where an adventurer FELL on the open PATHS. A room death stashes loot in
' the room's own drop_* fields; a path/wander death drops HERE, keyed to the board cell.
TYPE LOOSEDROP
    active AS INTEGER
    cx AS INTEGER
    cy AS INTEGER
    gold AS LONG
    sword AS INTEGER
    secret AS INTEGER
    esp AS INTEGER
    crystal AS INTEGER
    armor AS INTEGER          ' the rest of the kit -- see ROOM.drop_* for why these exist
    shield AS INTEGER
    bow AS INTEGER
    boots AS INTEGER
    teleport AS INTEGER
    pot_sm AS INTEGER
    pot_lg AS INTEGER
END TYPE
DIM SHARED LOOSE(1 TO 16) AS LOOSEDROP
DIM SHARED ROOMAT(0 TO 131, 0 TO 60) AS INTEGER   ' cell -> room index (0 = not a room cell)
' cell -> CRK_* (engine/BOARD.bas CellRoomKind%), filled once per board build by
' PlaceRoomMarkers. Cached because the test reads all 128 pixels of a cell, and marker
' placement, the size gate and `dungeon.run roomlint` all want the same answer.
DIM SHARED ROOMKIND(0 TO 131, 0 TO 60) AS INTEGER
' Scratch reachability map for `dungeon.run sectorauto` (ReachFromStart): can the player walk
' here at all? Separates a real hole in the sector cover from decorative art that merely happens
' to be painted a walkable colour -- the DUNGEON logo's yellow fill reads as `path` but is sealed.
DIM SHARED GAPREACH(0 TO 131, 0 TO 60) AS INTEGER
CONST MAXCHAMBER = 30                              ' named yellow CHAMBERS (3 monsters, no treasure)
DIM SHARED CHAMBERAT(0 TO 131, 0 TO 60) AS INTEGER ' cell -> chamber id (0 = not a chamber cell)
DIM SHARED NCHAMBER AS INTEGER
DIM SHARED CHM_CX(1 TO MAXCHAMBER) AS INTEGER, CHM_CY(1 TO MAXCHAMBER) AS INTEGER
DIM SHARED CHM_CELLS(1 TO MAXCHAMBER) AS INTEGER, CHM_SEC(1 TO MAXCHAMBER) AS INTEGER
DIM SHARED CHM_NAME(1 TO MAXCHAMBER) AS STRING
' Has a non-gauntlet chamber EVENT already fired in this hall? One per chamber per run,
' so re-entering cannot farm boons. Saved (v7) alongside CHM_DEAD.
DIM SHARED CHM_EVDONE(1 TO MAXCHAMBER) AS INTEGER
' Has the player ever set foot in this hall? Drives the ONE-TIME arrival crawl, which used to
' be an ELSE branch of the encounter and so never played on an entry that rolled a special
' event -- and never at all in a hall whose first entry rolled one. Saved (v8) with CHM_DEAD.
DIM SHARED CHM_SEEN(1 TO MAXCHAMBER) AS INTEGER

' --- per-level MAGIC ITEM pool (assets/data/<pack>/items.txt) ---
' Items used to OVERRIDE a treasures.txt slot, which meant an item's frequency was encoded
' as a slot POSITION -- so odds could only be 0/33/66/100%, and a level whose 3 slots were
' all items could never yield gold treasure at all (that silently happened to levels 5/6/8).
' Now the two are independent: ITEM_PCT decides HOW OFTEN a level yields an item, and the
' pool's weights decide WHICH. treasures.txt slots are always plain gold.
CONST MAXITEMPL = 12                               ' items one level may offer
DIM SHARED ITM_NAME(1 TO 9, 1 TO MAXITEMPL) AS STRING
DIM SHARED ITM_GOLD(1 TO 9, 1 TO MAXITEMPL) AS INTEGER
DIM SHARED ITM_CODE(1 TO 9, 1 TO MAXITEMPL) AS INTEGER
DIM SHARED ITM_W(1 TO 9, 1 TO MAXITEMPL) AS INTEGER
DIM SHARED ITM_N(1 TO 9) AS INTEGER
DIM SHARED ITEM_PCT(1 TO 9) AS INTEGER             ' % of this level's rooms that yield an item
DIM SHARED ITEMS_OLDFMT AS INTEGER                 ' TRUE if items.txt used the legacy slot form

' --- CHAMBER EVENT table (assets/data/<pack>/chamber-events.txt) ---
' Mechanics are keyed by `kind` in code; weight + depth band + prose are data. Drawn with
' the engine's WeightPickLvl% (engine/TABLE.bas), the same primitive the curio deck uses.
TYPE CHMEV_T
    kind   AS STRING * 12
    nm     AS STRING * 28
    weight AS INTEGER
    minlvl AS INTEGER
    maxlvl AS INTEGER
    text   AS STRING * 96
END TYPE
DIM SHARED CHM_EV(1 TO 40) AS CHMEV_T
DIM SHARED NCHMEV AS INTEGER
DIM SHARED CHM_DEAD(1 TO MAXCHAMBER) AS INTEGER   ' graves so far (0..3); 3 = chamber cleared
DIM SHARED cur_chamber AS INTEGER                 ' chamber the player is currently inside (0 = none)

' The level the player is CURRENTLY treading -- see PlayerLevel% in game/SECTOR.bas.
' A yellow corridor cell has no colour of its own to say which level it belongs to, so it only
' has a level if the sector mask paints one or a sectors.txt rect covers it. 96 of the board's
' 3156 walkable cells satisfy neither (`dungeon.run sectorauto`), and on those the lookup
' returns 0: the HUD reads level 0, the music will not switch, and a wandering monster there
' has no depth to roll from. This remembers the last level that DID resolve, so walking through
' an unclaimed corridor carries the level you came from until you reach one that is claimed.
DIM SHARED cur_level AS INTEGER

' The entrance heals you to full -- but only as the reward for WALKING home. Anything that
' PUTS you at START (Teleport Scroll, the obelisk, a Serious Wound dragging you back, a
' revive) sets this, and Game_OnEnterCell then withholds the heal until you have left the
' entrance zone under your own power. Without it a Teleport Scroll was a free full heal, and
' the obelisk's "reality folds" outcome was strictly better than any potion.
DIM SHARED start_heal_locked AS INTEGER
' The HP the character STARTED the run with. The entrance heals exactly this much -- a fixed
' number, not "to full" -- so going home matters less and less as you level, instead of being a
' free full heal forever. Captured at character creation, never re-derived.
DIM SHARED hp_start_amount AS INTEGER
' Hammering a reinforced door is LOUD. Attempts on the CURRENT door accumulate; each one adds
' DOORNOISE_PCT to the chance something in the dark comes to see what the racket is. Reset when
' the door gives way or you go and bother a different one.
DIM SHARED door_noise_tries AS INTEGER, door_noise_idx AS INTEGER
DIM SHARED door_ambush AS INTEGER          ' TRUE for one encounter: it struck first, and you cannot flee
DIM SHARED start_heals AS INTEGER              ' how many times the entrance has patched you up this run
DIM SHARED CHM_GX(1 TO MAXCHAMBER, 1 TO 3) AS INTEGER   ' 3 spread grave cells per chamber
DIM SHARED CHM_GY(1 TO MAXCHAMBER, 1 TO 3) AS INTEGER

' --- Solo play modes (single-player variants from the DUNGEON! manual) ---
CONST SOLO_OFF = 0, SOLO_TIME = 1, SOLO_ITEM = 2, SOLO_PREY = 3
DIM SHARED opt_solomode AS INTEGER      ' 0 off / 1 Time Limit / 2 Item Search / 3 Monster Prey
DIM SHARED opt_solomins AS INTEGER      ' Time-Limit budget in minutes (30/25/20/15)
DIM SHARED solo_on AS INTEGER           ' this run is actively running a solo mode
DIM SHARED solo_result AS INTEGER       ' 0 continue / OUT_WIN / OUT_LOSE (set by SoloTick)
DIM SHARED solo_msg AS STRING           ' why the solo run ended (shown on the lose/win banner)
DIM SHARED solo_deaths AS INTEGER       ' reserved (Item Search reads deaths(1) directly)
DIM SHARED solo_item_room AS INTEGER    ' ROOMS() index of the quest treasure (Item Search)
DIM SHARED solo_item_name AS STRING
DIM SHARED solo_item_lvl AS INTEGER
DIM SHARED solo_found AS INTEGER
DIM SHARED hunt_on AS INTEGER           ' Monster Prey: a hunter is loose
DIM SHARED hunt_cx AS INTEGER, hunt_cy AS INTEGER
DIM SHARED hunt_mon AS STRING, hunt_slot AS INTEGER, hunt_lvl AS INTEGER
DIM SHARED hunt_lastmoves AS INTEGER    ' moves_made at the hunter's last step (1 step per player step)
DIM SHARED HDIST(0 TO 131, 0 TO 60) AS INTEGER   ' BFS distance field for the hunter's pathing
DIM SHARED LABELMASK(0 TO 131, 0 TO 60) AS INTEGER   ' cell -> TRUE if a room label prints here (keep monsters off it)
DIM SHARED LBL_N AS INTEGER, LBL_X(1 TO 40) AS INTEGER, LBL_Y(1 TO 40) AS INTEGER, LBL_T(1 TO 40) AS STRING
' -- room/combat flavor text (loaded from editable assets/flavor/*.txt; see game/FLAVOR.bas) --
DIM SHARED REG_FLAV(1 TO 9, 1 TO 24) AS STRING, REG_N(1 TO 9) AS INTEGER   ' regular-room one-liners per level
DIM SHARED SP_KEY(1 TO 30) AS STRING, SP_X(1 TO 30) AS INTEGER, SP_Y(1 TO 30) AS INTEGER, SP_N AS INTEGER
DIM SHARED SP_FLAV(1 TO 30, 1 TO 8) AS STRING, SP_FN(1 TO 30) AS INTEGER   ' special (named) room deep flavor
DIM SHARED SP_ROOM(1 TO 30) AS INTEGER   ' each named label bound to its nearest detected room (BindSpecialRooms)
DIM SHARED MAXHIT(1 TO 30) AS STRING, MAXHIT_N AS INTEGER                  ' max-damage combat flavor
DIM SHARED FORFEIT_FLAV(1 TO 30) AS STRING, FORFEIT_N AS INTEGER           ' sad epitaphs shown when a run is forfeited
DIM SHARED LEVELUP_FLAV(1 TO 30) AS STRING, LEVELUP_N AS INTEGER           ' what gaining a character level FEELS like
DIM SHARED LEVELUP_KEY(1 TO 30) AS STRING                                  ' narration key per level-up line ('' = not spoken)
' --- AMBIENCE: the dungeon making noise at you (assets/data/<pack>/ambience.txt) ---
DIM SHARED AMB_LVL(1 TO 120) AS INTEGER, AMB_NAME(1 TO 120) AS STRING
DIM SHARED AMB_W(1 TO 120) AS INTEGER, AMB_N AS INTEGER
DIM SHARED amb_ticks AS LONG                                               ' frames until the next ambient noise
DIM SHARED AMB_SECS_MIN AS INTEGER, AMB_SECS_MAX AS INTEGER                ' gap between noises; MIN 0 = ambience off
DIM SHARED DOORNOISE_PCT AS INTEGER, DOORNOISE_CLEAR_PCT AS INTEGER        ' door-smashing racket -> wandering encounter odds

' TRUE = manifests print only the assets the selected packs are MISSING (`dungeon.run
' <any>manifest audit`). GAME.BI, not ENGINE.BI: the manifests are game content and every
' consumer lives in game/MANIFEST.bas -- audit-boundary.sh catches exactly this misfiling.
DIM SHARED man_audit AS INTEGER
' `pack=<name>` on any manifest command. Overrides the pack EVERY category resolves through,
' for both the audit's "does it exist" check and the WRITE path printed in the header -- so a
' generator filling a new pack is told exactly where its output goes, instead of the manifest
' silently describing whichever packs the player's saved settings happen to select.
DIM SHARED man_pack AS STRING
' TRUE = build MAN_BUF but print nothing and do not clear it, so a caller can READ the manifest
' instead of emitting it (placeholders does exactly that -- it needs the paths and sizes).
DIM SHARED man_quiet AS INTEGER
CONST PLACEHOLDER_LIST = "assets/PLACEHOLDERS.txt"   ' what `placeholders clean` deletes
' Paths written by `dungeon.run placeholders`. The AUDIT treats these as MISSING even though
' the file exists -- a stand-in is a reminder, not an asset, and an audit that counted it as
' done would quietly hide the very thing it is for.
DIM SHARED PH_PATH(1 TO 400) AS STRING, PH_N AS INTEGER, PH_LOADED AS INTEGER
' Byte size each placeholder was written at. An entry only counts while the file still
' matches -- real art overwriting a stand-in changes the size and drops the entry itself.
DIM SHARED PH_SIZE(1 TO 400) AS LONG
DIM SHARED fx_critkill AS INTEGER                                           ' TRUE = the killing blow was a CRIT (picks the killcrit aftermath text)

' --- LUCK: CHA-funded re-rolls (SETTINGS "Luck Re-rolls") -----------------------
' What finally gives CHA a job. luck_max is the CHA modifier, refilled on every level-up;
' luck_left is what remains this run. Offered on COMBAT rolls and SAVING THROWS only -- the
' places a bad number actually hurts -- and NOT on searches, movement or loot rolls.
'
' The prompt WAS an unconditional fuse: it appeared for a fixed 2s and then decided for you, on
' the argument that the tension IS the timer. That is a fine default and a bad mandate -- being
' hurried into a decision you did not ask for is exactly the complaint -- so the duration is now
' a setting, INCLUDING zero:
'
'   0 = no timer. The prompt waits for an answer ([R] spends, [SPACE] declines). The offer is
'       still made at the same moment, right after the roll and before it resolves, because that
'       is the only point at which a re-roll can mean anything.
'   1 / 2 seconds = the original fuse, at the player's chosen pressure.
'
' Capped at 2 deliberately: a 30-second "fuse" is not a fuse, and if you want no pressure the
' honest way to say so is 0, which stops pretending to be a timer at all.
CONST LUCKFUSE_MAX = 2
DIM SHARED opt_luckfuse AS INTEGER        ' SETTINGS: seconds on the luck prompt (0 = untimed)
DIM SHARED luck_left AS INTEGER, luck_max AS INTEGER
DIM SHARED opt_luck AS INTEGER            ' SETTINGS toggle: luck re-rolls on/off
DIM SHARED opt_startheal AS INTEGER       ' SETTINGS: does returning to the entrance heal you?

' --- FLOURISHES: DEX-funded follow-throughs -------------------------------------
' A pool the DEX modifier funds, refilled on every level-up. A flourish gesture spends one; a
' natural 20 hands one back (so landing crits keeps you in flourishes) and a natural 1 costs
' one (so fumbling dries you up). That loop is the mechanic: DEX decides how much rope you
' have, and how you fight decides how fast you burn it.
DIM SHARED flourish_left AS INTEGER, flourish_max AS INTEGER

' --- [R]EST: heal a point at a time, and roll for company -----------------------
DIM SHARED opt_rest AS INTEGER             ' SETTINGS: is in-dungeon resting allowed at all?
DIM SHARED g_rests AS INTEGER              ' how many points you have rested back this run
DIM SHARED REST_ENC_PCT AS INTEGER, REST_ENC_PER_LVL AS INTEGER   ' tuning.txt
DIM SHARED CLOSECALL_ROUNDS AS INTEGER, CLOSECALL_HP AS INTEGER   ' a long fight barely survived

' --- balancedump --includestats: per-monster tallies read back from the fight log ---
DIM SHARED FS_MON(1 TO 60) AS STRING, FS_ENC(1 TO 60) AS LONG
DIM SHARED FS_FLED(1 TO 60) AS LONG, FS_KILL(1 TO 60) AS LONG, FS_DIED(1 TO 60) AS LONG
DIM SHARED FS_N AS INTEGER

' --- what each ability DOES (assets/data/<pack>/stats.txt) ---
' Shown in the character creator's side panel. SH_LIVE separates what the game does TODAY from
' what is designed but unbuilt, so the panel can never promise a mechanic that does not exist.
DIM SHARED SH_STAT(1 TO 60) AS INTEGER, SH_LIVE(1 TO 60) AS INTEGER
DIM SHARED SH_TEXT(1 TO 60) AS STRING, SH_N AS INTEGER
DIM SHARED luck_rerolling AS INTEGER      ' guard: a re-roll can never itself be re-rolled
DIM SHARED CHM_FLAV_NAME(1 TO 32) AS STRING, CHM_FLAV_TXT(1 TO 32) AS STRING, CHM_FLAV_N AS INTEGER   ' per-chamber descriptions
DIM SHARED deaths(1 TO 4) AS INTEGER              ' per-player death tally (skull counter in the HUD)

' -- Crit/Fumble effects engine (data-driven; see game/EFFECTS.bas / InitEffects) --
' kind: 0 flavor-only, 1 heal player, 2 extra dmg to foe, 3 self-damage, 4 lose turn, 5 drop gold
TYPE FXROW
    say  AS STRING * 96      ' template; tokens {weapon} {mon} {n} are substituted at show time
    kind AS INTEGER
    die  AS INTEGER          ' magnitude die for the mechanical effect (0 = none)
END TYPE
DIM SHARED CRITFX(1 TO 30) AS FXROW, NCRIT AS INTEGER      ' player critical-hit results
DIM SHARED PFUMBLE(1 TO 30) AS FXROW, NPFUM AS INTEGER     ' player fumble results
DIM SHARED MFUMBLE(1 TO 30) AS FXROW, NMFUM AS INTEGER     ' monster natural-1 fumble results

' -- Curio-chest traps (data-driven; loaded from assets/data/traps.txt; see SpringTrap) --
TYPE TRAPROW
    kind AS INTEGER          ' mechanic: 1 poison, 2 bomb, 3 frost, 4 siren
    name AS STRING * 20
    save AS STRING * 4       ' CON / DEX / WIS
    word AS STRING * 8       ' save verb: SAVE / DODGE
    sfx  AS STRING * 8
    die  AS INTEGER          ' magnitude die (damage or turns)
    trig AS STRING * 72      ' trigger banner (line 1)
    smsg AS STRING * 72      ' save-success banner (line 1)
    ftit AS STRING * 56      ' failure banner title (line 1)
    fbod AS STRING * 72      ' failure banner body (line 2); {n} = rolled magnitude
END TYPE
DIM SHARED TRAPS(1 TO 20) AS TRAPROW, NTRAP AS INTEGER

' -- per-monster / per-class combat event text (data-driven; see game/CTEXT.bas) --
' Each row is one line for one (category, key, event). key "*" is the default used
' when a specific monster/class has no line of its own for that event.
TYPE EVTROW
    cat  AS INTEGER          ' 1 = monster, 2 = player class
    mkey AS STRING * 24      ' monster name / class name (UPPER), or "*"  (KEY is reserved)
    evt  AS INTEGER          ' 1 attack, 2 miss, 3 crit, 4 fumble, 5 death
    text AS STRING * 140     ' template; tokens like {mon} {dmg} {player} are filled at show time
    nkey AS STRING * 48      ' narration key, or "" -- only TOKEN-FREE lines can have one
END TYPE
DIM SHARED EVT(1 TO 1400) AS EVTROW, EVT_N AS INTEGER
' flavor-context globals: combat sets these so Fill$ can resolve the {tokens}
DIM SHARED FX_MON AS STRING, FX_DMG AS INTEGER, FX_LEVEL AS INTEGER
' The narration key of the line EventLine$ last picked, so the banner can speak the very line
' it is showing. Set on every call (empty when that line has no key) -- never left stale, or a
' templated line would borrow the previous line's audio.
DIM SHARED FX_NARRKEY AS STRING
DIM SHARED FX_ROOM AS STRING, FX_TREASURE AS STRING, FX_ITEM AS STRING

DIM SHARED AS LONG gold, target_gold
DIM SHARED class_name AS STRING
DIM SHARED CLASSES(1 TO 4) AS PCLASS
DIM SHARED player_class AS INTEGER
' hot-seat multiplayer (up to 4). num_players 1 = solo; >1 forces Boardgame Mode.
DIM SHARED PLAYERS(1 TO 4) AS PLAYER
DIM SHARED num_players AS INTEGER, cur_player AS INTEGER
' per-player log of named treasures claimed (for the character sheet).
DIM SHARED LOOT_NAME(1 TO 4, 1 TO 80) AS STRING, LOOT_GOLD(1 TO 4, 1 TO 80) AS LONG
DIM SHARED LOOT_N(1 TO 4) AS INTEGER
' Dungeon!-style monster + treasure pools, 3 per level (levels 1-9), randomised per game.
DIM SHARED MON_NAME(1 TO 9, 1 TO 3) AS STRING
' per-class 2d6 kill numbers from the cards: [level, slot, class] 1=Hero 2=Elf 3=Superhero 4=Wizard (13 = can't kill barehanded)
DIM SHARED MON_N(1 TO 9, 1 TO 3, 1 TO 4) AS INTEGER
DIM SHARED TRE_NAME(1 TO 9, 1 TO 3) AS STRING, TRE_GOLD(1 TO 9, 1 TO 3) AS INTEGER
DIM SHARED TRE_ITEM(1 TO 9, 1 TO 3) AS INTEGER   ' 0=gold, 1=MagicSword+1, 2=MagicSword+2, 3=SecretDoorCard
DIM SHARED BOSS_NAME(1 TO 4) AS STRING
' player inventory (special treasure cards)
DIM SHARED item_sword AS INTEGER      ' Magic Sword combat bonus held (0/1/2)
DIM SHARED item_secret_card AS INTEGER ' holds the Secret Door Card
DIM SHARED item_esp AS INTEGER        ' ESP Medallion: peek the treasure a monster guards
DIM SHARED item_crystal AS INTEGER    ' Crystal Ball: [V] scry every room's contents
' expanded magic-item deck (see ClaimTreasure / InitMonsterTables)
DIM SHARED item_armor AS INTEGER      ' AC bonus from BODY ARMOR worn (0 if none)
DIM SHARED item_shield AS INTEGER     ' AC bonus from a SHIELD (separate slot; adds to armor)
DIM SHARED item_bow AS INTEGER        ' Magic Bow: +2 to-hit (strike from range)
DIM SHARED item_boots AS INTEGER      ' Elf Boots: +2 to the movement roll
DIM SHARED item_teleport AS INTEGER   ' Teleport Scrolls / Teleport spell charges: [T] whisks you back to START
DIM SHARED spell_fire AS INTEGER, spell_bolt AS INTEGER   ' WIZARD-only: Fire Ball / Lightning Bolt spell charges (cast in combat)
DIM SHARED item_potion_small AS INTEGER, item_potion_large AS INTEGER   ' healing potions held ([H] to quaff)
DIM SHARED char_level AS INTEGER, char_xp AS LONG   ' D&D character level + accumulated XP (levels up on clearing a floor)
DIM SHARED combat_round AS INTEGER   ' current D&D combat round (shown on the combat panel)
' Kept combat context so any board redraw can repaint the combat panel -- it stays CONSTANT during a fight.
DIM SHARED combat_active AS INTEGER  ' TRUE only while DoCombatDnD is running
DIM SHARED combat_rm AS INTEGER
DIM SHARED combat_mon AS STRING
DIM SHARED combat_lead AS STRING
' -- status effects from curio traps (tick down as turns pass; shown in the HUD; JUICE reads poison_turns) --
DIM SHARED poison_turns AS INTEGER   ' poison darts: -1 HP per turn (damage over time)
DIM SHARED fire_turns AS INTEGER     ' bomb fire: -1 HP per turn (damage over time)
DIM SHARED frost_turns AS INTEGER    ' frost bomb: movement frozen this many turns
DIM SHARED siren_turns AS INTEGER    ' magic siren: encounter chance raised while it wails
DIM SHARED curse_turns AS INTEGER    ' cursed: -1 to hit AND damage while it lasts
' --- MONSTER ELEMENTAL EFFECTS (assets/data/<pack>/monster-effects.txt) ---
DIM SHARED ME_MON(1 TO 60) AS STRING, ME_KIND(1 TO 60) AS STRING
DIM SHARED ME_PCT(1 TO 60) AS INTEGER, ME_SAVE(1 TO 60) AS STRING
DIM SHARED ME_DIE(1 TO 60) AS INTEGER, ME_ROUNDS(1 TO 60) AS INTEGER
DIM SHARED ME_N AS INTEGER
DIM SHARED has_key AS INTEGER                     ' player holds the Level Key
DIM SHARED key_level AS INTEGER                   ' which dungeon level (2..9) hides the Level Key this game
DIM SHARED key_room AS INTEGER                    ' the ROOMS() index whose treasure IS the Level Key (Crystal Ball reveals it)
DIM SHARED loiter AS INTEGER                      ' rising danger from lingering (search/idle); triggers wandering monsters
' per-run chronicle for the Legendary Lords: what the champion did on each level
DIM SHARED lvl_kills(1 TO 9) AS INTEGER           ' monsters slain per dungeon level this run
DIM SHARED lvl_gold(1 TO 9) AS LONG               ' gold claimed per dungeon level this run
DIM SHARED lvl_reached(1 TO 9) AS INTEGER         ' levels the champion set foot on this run
DIM SHARED lvl_cleared(1 TO 9) AS INTEGER         ' levels fully cleared this run (reward + level-up once each)
DIM SHARED LORD_DETAIL(1 TO 200) AS STRING        ' raw saved chronicle per loaded lord (parsed on the detail screen)
DIM SHARED SECTORAT(0 TO 131, 0 TO 60) AS _BYTE   ' sector/level id per cell, from the sector mask (0 = none)
DIM SHARED SECTORMASK_ON AS INTEGER               ' TRUE = geometry from board-...-sector-mask.ans, not the rects
' -- movement + combat RULESET switches (Dungeon! rules, not engine prefs) --
DIM SHARED opt_oldschool AS INTEGER   ' TRUE: Dungeon! 2d6-vs-target combat; FALSE: D&D d20/HP combat
DIM SHARED opt_boardgame AS INTEGER   ' TRUE: roll dice + step-limited turns; FALSE: free "computer game" movement
DIM SHARED opt_movedice AS INTEGER    ' Boardgame move style: TRUE = roll 1d6 (house variant); FALSE = up to MOVE_MAX, your choice
DIM SHARED MOVE_MAX AS INTEGER        ' DUNGEON!: a player moves up to 5 spaces per turn, their choice -- no movement die
DIM SHARED opt_lootrecovery AS INTEGER ' TRUE: death leaves your loot in the room to reclaim (default in D&D mode)
DIM SHARED opt_maxdeaths AS INTEGER    ' lives before permadeath: reach this many deaths and you forfeit (1..9, default 3)
DIM SHARED player_out AS INTEGER       ' set TRUE the moment the active player uses up their last life (PlayGame ends the run)

' ---- CHRONICLE: per-run stats + a single-line event log (Game Summary / Event Log / Bestiary
'      / Treasury / Lords viewers). Reset by ChronicleReset at the start of each run. ----
DIM SHARED g_rooms_explored AS INTEGER, g_monsters_slain AS INTEGER, g_treasures_found AS INTEGER
DIM SHARED g_items_looted AS INTEGER, g_levels_completed AS INTEGER, g_secrets_found AS INTEGER
DIM SHARED g_crits AS INTEGER, g_fumbles AS INTEGER, g_wander_enc AS INTEGER, g_run_deaths AS INTEGER
' Criticals the player landed in the CURRENT fight (reset per encounter in DoCombat%, bumped
' by RecordCrit). Drives the post-fight healing-potion reward -- see CritPotionReward.
DIM SHARED combat_crits AS INTEGER
DIM SHARED g_gold_found AS LONG, g_secret_tries AS INTEGER
' -- the rest of the run scorecard (Game Summary + the death screen) --
' NOT here: turns taken and distance travelled. `turn_num` and `moves_made` already carry both,
' are already reset per run, and are already in the save -- so a g_turns/g_distance pair would
' have been a second source of truth that silently disagreed after any load.
' SETTINGS "Stats Overlay" -- the live run scorecard on the board, toggled in-game with TAB
' (the scoreboard key, which is what a stats overlay IS). TAB used to be "where am I?"; that
' moved to [L]ocate rather than inventing a third key for the thing people already reach for.
' What the epitaph needs. Recorded at the moment of death rather than reconstructed later:
' by the time the end screen runs, the fight is over, the room may have been re-entered, and
' PlayerLevel% has moved on with the corpse.
DIM SHARED g_death_mon AS STRING, g_death_lv AS INTEGER
' Where DeathStone last drew the stone ITSELF (not its fit box) -- the weapon and the pile are
' placed against it, and only DeathStone knows where the aspect fit actually put it.
DIM SHARED DEATH_STONE_X AS INTEGER, DEATH_STONE_Y AS INTEGER
DIM SHARED DEATH_STONE_W AS INTEGER, DEATH_STONE_H AS INTEGER
DIM SHARED death_skipped AS INTEGER    ' latched: one keypress skips the WHOLE death sequence
DIM SHARED g_saved AS INTEGER          ' times a SECOND WIND pulled you back from a downing blow
CONST STATROW_N = 24                    ' rows in the run scorecard (StatRowLabel$/StatRowValue$)
' AUTO-COMBAT: the game plays the fight for you, one action every opt_autodelay seconds.
' `autocombat_run` is the RUNTIME flag (the option is the player's preference; the flag is
' whether it is actually driving right now), so combat can switch it off for a fight without
' rewriting the setting -- see AutoCombatLive%.
' AUTO-MOVE: the game walks the dungeon for you, shallowest level first, halting on anything
' worth a decision. `automove_run` is the RUNTIME flag; the option is the player's preference.
CONST AUTOMOVE_STEP_SEC = 0.14         ' one auto step per this many seconds -- fast enough to
'                                        watch, slow enough that a halt banner is readable
' Pixel nudge applied to the MONSTER portrait inside its frame (MonsterLunge).
DIM SHARED PANEL_BUF AS LONG           ' scratch for the near-death panel tremor (PanelShudder)
DIM SHARED combat_lunge_x AS INTEGER, combat_lunge_y AS INTEGER
' --- 9-grid UI frame registry (assets/data/<pack>/ui-frames.txt, see LoadUIFrames) ---
CONST UIFRAME_MAX = 16
DIM SHARED UIFRAME_NAME(1 TO UIFRAME_MAX) AS STRING, UIFRAME_FILE(1 TO UIFRAME_MAX) AS STRING
DIM SHARED UIFRAME_TW(1 TO UIFRAME_MAX) AS INTEGER, UIFRAME_TH(1 TO UIFRAME_MAX) AS INTEGER
DIM SHARED UIFRAME_FILL(1 TO UIFRAME_MAX) AS INTEGER
DIM SHARED UIFRAME_N AS INTEGER
DIM SHARED chron_framed AS INTEGER     ' a Chronicle panel is currently drawn from frame ART
DIM SHARED opt_automove AS INTEGER
DIM SHARED automove_run AS INTEGER
DIM SHARED automove_t0 AS SINGLE
' Latches, so each halt condition fires ONCE rather than on every step thereafter.
DIM SHARED automove_room AS INTEGER    ' the room being walked to; held until it is dealt with
DIM SHARED automove_lastlvl AS INTEGER, automove_lastclear AS INTEGER, automove_hpwarn AS INTEGER
' Auto-move's own BFS field. NOT HDIST -- that belongs to the solo hunter, which can be
' running at the same time, and sharing it would have the two overwrite each other.
DIM SHARED ADIST(0 TO 131, 0 TO 60) AS INTEGER
DIM SHARED opt_autocombat AS INTEGER
DIM SHARED opt_autodelay AS INTEGER    ' 1, 2 or 3 seconds between auto actions
DIM SHARED autocombat_run AS INTEGER
DIM SHARED opt_statsoverlay AS INTEGER
' Which view that overlay box shows: 0 = RUN STATS (the original), 1 = BEARINGS (what is playing
' and being drawn, plus where you are). [TAB] shows/hides the box; [Shift-TAB] swaps the view.
DIM SHARED overlay_mode AS INTEGER
DIM SHARED g_rooms_cleared AS INTEGER   ' rooms whose monster you killed (NOT chamber spawns)
DIM SHARED g_chambers_cleared AS INTEGER
DIM SHARED g_max_level AS INTEGER       ' deepest level actually stood on
DIM SHARED g_items_used AS INTEGER      ' potions drunk, scrolls cast, teleports spent
DIM SHARED g_flourishes AS INTEGER      ' gestures landed (hit or crit zone)
DIM SHARED g_dmg_dealt AS LONG, g_dmg_healed AS LONG
DIM SHARED g_streak AS INTEGER, g_streak_best AS INTEGER   ' consecutive kills; broken by death or flight
CONST MAXEVLOG = 600
REDIM SHARED EVLOG(1 TO MAXEVLOG) AS STRING
DIM SHARED EVLOG_N AS INTEGER
' per-monster + per-treasure tallies for the Bestiary / Treasury (indexed by a name list)
CONST MAXBEAST = 48, MAXTRE = 64
REDIM SHARED BEAST_NAME(1 TO MAXBEAST) AS STRING
REDIM SHARED BEAST_ENC(1 TO MAXBEAST) AS INTEGER, BEAST_SLAIN(1 TO MAXBEAST) AS INTEGER
REDIM SHARED BEAST_FLED(1 TO MAXBEAST) AS INTEGER, BEAST_KILLEDBY(1 TO MAXBEAST) AS INTEGER
REDIM SHARED BEAST_LOOTED(1 TO MAXBEAST) AS INTEGER
DIM SHARED BEAST_N AS INTEGER
' DISCOVERED-EVER, across ALL runs -- not part of a save. A save is one expedition; the Bestiary
' is the player's accumulated knowledge, so wiping a run or dying for good must not erase it.
' Persisted on its own in gameplay-data-saves/dungeon-bestiary.dat.
REDIM SHARED BEAST_EVER(1 TO MAXBEAST) AS INTEGER
CONST BESTIARY_FILE = "gameplay-data-saves/dungeon-bestiary.dat"
REDIM SHARED TRE_STATNAME(1 TO MAXTRE) AS STRING
REDIM SHARED TRE_FOUND(1 TO MAXTRE) AS INTEGER, TRE_GP(1 TO MAXTRE) AS LONG
DIM SHARED TRE_STAT_N AS INTEGER

' --- SETTINGS screen layout (columnar grouped): per-option column + screen row,
'     plus the category header list. Filled by BuildSetLayout each time SETTINGS opens. ---
CONST NSCOL = 3                                  ' number of option columns
DIM SHARED SL_COLX(1 TO NSCOL) AS INTEGER        ' left cell-column x of each option column
' The first free row BELOW the longest settings column. The dice previews sit under the list,
' and the list grows -- hardcoding their row meant adding one option silently drew the preview
' caption through the last row of column 3. Derived in BuildSetLayout so it self-adjusts.
DIM SHARED SL_MAXROW AS INTEGER
' Per-column bottoms. SL_MAXROW alone is the bottom of the LONGEST column, and hanging the
' dice previews off that pushes them far below the short columns they actually sit under.
DIM SHARED SL_COLBOT(1 TO 4) AS INTEGER
DIM SHARED SL_COL(1 TO 64) AS INTEGER            ' per option id: which column (1..NSCOL)
DIM SHARED SL_ROW(1 TO 64) AS INTEGER            ' per option id: screen row
DIM SHARED SLH_N AS INTEGER                      ' category header count
DIM SHARED SLH_COL(1 TO 24) AS INTEGER, SLH_ROW(1 TO 24) AS INTEGER
DIM SHARED SLH_TXT(1 TO 24) AS STRING
DIM SHARED SORD(1 TO 64) AS INTEGER              ' option ids in reading order (col1 top-down, col2, col3) for up/down nav
DIM SHARED SORD_N AS INTEGER


' ============================================================================
'  Moved here from engine/ENGINE.BI (2026-07-29).
'
'  These were declared in the ENGINE header but NO engine/ file referenced them -- only
'  game/ and dungeon.bas did. The boundary audit could not see it: it checks "does engine
'  name a game symbol", so anything misfiled INTO the engine header is engine-owned by
'  definition and invisible. `audit-boundary.sh` now also reports ENGINE.BI globals with
'  zero engine references, which is the sharper question.
'
'  Most are plainly game-shaped: D&D ability scores and combat derivation (a non-RPG game
'  on this engine has no STR), the ruleset switches, run identity, and the turn machinery
'  (whose ENGINE.BI comment already conceded "rules that fill it live in game/").
' ============================================================================
DIM SHARED opt_flexstats AS INTEGER   ' 0 = OFF (rolled order), 1 = Assign roll (swap), 2 = Point distribution
DIM SHARED opt_gestures AS INTEGER     ' SETTINGS "Action Gestures": timing-bar mini-game (second-wind + crit flourish)
DIM SHARED opt_combatspeed AS INTEGER ' (legacy, kept for save compat) -- superseded by opt_msgdelay
DIM SHARED opt_hardcore AS INTEGER    ' TRUE: time passes while idle -> wandering monsters can find you
DIM SHARED opt_critfumble AS INTEGER  ' TRUE: the crit/fumble effects engine runs (cinematic + bonus/penalty rolls)
DIM SHARED run_seed AS DOUBLE          ' the RNG seed the current dungeon was built from (save/load reproduces it)
DIM SHARED player_str AS INTEGER, player_int AS INTEGER, player_wis AS INTEGER
DIM SHARED player_dex AS INTEGER, player_con AS INTEGER, player_cha AS INTEGER
DIM SHARED player_tohit AS INTEGER, player_ac AS INTEGER    ' final to-hit / AC after ability mods
DIM SHARED game_start AS DOUBLE                   ' TIMER at play start (elapsed-time display)
DIM SHARED player_name AS STRING                  ' champion name (Legendary Lords / save)
DIM SHARED dbg_on AS INTEGER, moves_made AS INTEGER   ' [~] debug overlay + move counter
' Scratch marks for Dump_Monster's nearest-first walk (game/DUMP.bas). Its own array on purpose:
' a dump must never be able to change the thing it is describing.
DIM SHARED DUMPMARK(1 TO 400) AS INTEGER
DIM SHARED settingsshot_on AS INTEGER                 ' dev: `settingsshot` -- save the SETTINGS render to PNG + exit (layout check)
DIM SHARED dbg_click_armed AS INTEGER                 ' debounce for debug click-to-place
DIM SHARED player_dmgbonus AS INTEGER  ' STR/INT damage mod

' ============================================================================
'  Manifest generation state. GAME-side: a manifest is a listing of THIS game's content,
'  and the art direction is direction for THIS game's assets. tests/audit-boundary.sh
'  caught these in ENGINE.BI where no engine/ file used them -- the ENGINE.BI hoarding
'  check, which is the one a one-directional name scan cannot see.
' ============================================================================
' --- authored ART DIRECTION, merged into the image manifest (assets/data/art-prompts.txt) ---
' The manifest's entity LIST is derived from the content tables so it cannot drift. But a derived
' list can only invent generic prompts, so the authored style/size/prompt per asset lives in data
' and is merged in by path. An asset with no row still appears, with a generic prompt.
CONST APROMPT_MAX = 300
DIM SHARED AP_PATH(1 TO APROMPT_MAX) AS STRING, AP_STYLE(1 TO APROMPT_MAX) AS STRING
DIM SHARED AP_SIZE(1 TO APROMPT_MAX) AS STRING, AP_TEXT(1 TO APROMPT_MAX) AS STRING
DIM SHARED AP_N AS INTEGER

' --- manifest output BUFFER (game/SPRITES.bas, game/MANIFEST.bas) -------------
' A manifest's TOTAL has to be printed BEFORE the list, so a generator can read one line and
' decide whether anything changed -- without a human comparing outputs. But the total is only
' known after walking the content tables. So the body appends into this buffer and the total is
' printed in front of it: ONE pass, so the number can never disagree with the list under it.
CONST MAN_MAX = 600
DIM SHARED MAN_BUF(1 TO MAN_MAX) AS STRING, MAN_N AS INTEGER
DIM SHARED MAN_ENTRIES AS INTEGER          ' emitted asset lines (excludes comments/blanks)

' Health-tier thresholds (assets/data/tuning.txt), % of max HP. GAME-side: the engine has no
' opinion on what "BLOODIED" means -- only HealthWord$ reads these. audit-boundary.sh caught them
' in ENGINE.BI with no engine consumer.
DIM SHARED TUNE_HP_GRAZED AS INTEGER
DIM SHARED TUNE_HP_WOUNDED AS INTEGER
DIM SHARED TUNE_HP_BLOODIED AS INTEGER

' TACTICAL COMBAT screen (SETTINGS row 52). A THIRD combat presentation alongside the classic
' Dungeon! 2d6 and the D&D d20/HP systems -- not a replacement, so opt_oldschool keeps its two
' meanings and nothing existing changes when this is off.
'
' Branched inside DoCombat%, which is the single funnel every encounter goes through -- room
' monsters, chamber monsters, wandering monsters and a curio that turns out to be a MIMIC. One
' branch therefore covers all of them; wiring each call site separately would have guaranteed one
' gets missed.
DIM SHARED opt_tactical AS INTEGER
