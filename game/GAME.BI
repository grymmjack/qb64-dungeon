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
    cx      AS INTEGER        ' centre cell (for the tombstone marker + combat)
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
    ' loot a fallen champion left here (multiplayer only -- recoverable by any player)
    drop_gold AS LONG
    drop_sword AS INTEGER
    drop_secret AS INTEGER
    drop_esp AS INTEGER
    drop_crystal AS INTEGER
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
END TYPE

DIM SHARED SECTORS(1 TO 9) AS SECTOR
' individual room blocks (per-block encounters), detected from the board art
DIM SHARED ROOMS(1 TO 400) AS ROOM, ROOM_N AS INTEGER
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
END TYPE
DIM SHARED LOOSE(1 TO 16) AS LOOSEDROP
DIM SHARED ROOMAT(0 TO 131, 0 TO 60) AS INTEGER   ' cell -> room index (0 = not a room cell)
CONST MAXCHAMBER = 30                              ' named yellow CHAMBERS (3 monsters, no treasure)
DIM SHARED CHAMBERAT(0 TO 131, 0 TO 60) AS INTEGER ' cell -> chamber id (0 = not a chamber cell)
DIM SHARED NCHAMBER AS INTEGER
DIM SHARED CHM_CX(1 TO MAXCHAMBER) AS INTEGER, CHM_CY(1 TO MAXCHAMBER) AS INTEGER
DIM SHARED CHM_CELLS(1 TO MAXCHAMBER) AS INTEGER, CHM_SEC(1 TO MAXCHAMBER) AS INTEGER
DIM SHARED CHM_NAME(1 TO MAXCHAMBER) AS STRING
' Has a non-gauntlet chamber EVENT already fired in this hall? One per chamber per run,
' so re-entering cannot farm boons. Saved (v7) alongside CHM_DEAD.
DIM SHARED CHM_EVDONE(1 TO MAXCHAMBER) AS INTEGER

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
END TYPE
DIM SHARED EVT(1 TO 1400) AS EVTROW, EVT_N AS INTEGER
' flavor-context globals: combat sets these so Fill$ can resolve the {tokens}
DIM SHARED FX_MON AS STRING, FX_DMG AS INTEGER, FX_LEVEL AS INTEGER
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
DIM SHARED g_gold_found AS LONG, g_secret_tries AS INTEGER
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
REDIM SHARED TRE_STATNAME(1 TO MAXTRE) AS STRING
REDIM SHARED TRE_FOUND(1 TO MAXTRE) AS INTEGER, TRE_GP(1 TO MAXTRE) AS LONG
DIM SHARED TRE_STAT_N AS INTEGER

' --- SETTINGS screen layout (columnar grouped): per-option column + screen row,
'     plus the category header list. Filled by BuildSetLayout each time SETTINGS opens. ---
CONST NSCOL = 3                                  ' number of option columns
DIM SHARED SL_COLX(1 TO NSCOL) AS INTEGER        ' left cell-column x of each option column
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
DIM SHARED opt_artstyle AS INTEGER        ' 0 = ANSI only, 1 = Pixel Art, 2 = Hybrid (ANSI board + pixel portraits)
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
DIM SHARED settingsshot_on AS INTEGER                 ' dev: `settingsshot` -- save the SETTINGS render to PNG + exit (layout check)
DIM SHARED dbg_click_armed AS INTEGER                 ' debounce for debug click-to-place
DIM SHARED player_dmgbonus AS INTEGER  ' STR/INT damage mod
