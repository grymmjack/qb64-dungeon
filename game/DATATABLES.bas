' ============================================================================
'  game/DATATABLES.bas -- WHAT DUNGEON!'S TABLES ARE.
'
'  One declaration per content table, and it is the LOADER's truth that is
'  declared here -- not the file's header comment. Where the two disagree the
'  loader is right by definition (it is what the game actually reads) and
'  `dungeon.run schemalint` reports the comment as stale, which is a real
'  finding: the comment is what a modder reads.
'
'  monster_events.txt is exactly that case. Its header comment documents three
'  columns; LoadEventText reads FOUR, the fourth being the optional narration
'  key. The data editor believed the comment and would have swallowed that key
'  into the line the player reads.
'
'  SPLIT RULES. A table whose last column can itself contain pipes is declared
'  with DataTableSplit: an inline colour is spelled |10, so splitting those rows
'  on every pipe and rejoining them shreds the string.
' ============================================================================
SUB DeclareDataTables
    '--- content ---
    DataTable "monsters.txt", "lvl|slot|name|HERO|ELF|SUP|WIZ"
    DataTable "treasures.txt", "lvl|slot|name|gold"
    DataTable "items.txt", "lvl|name|gold|type|weight"
    DataTable "bosses.txt", "slot|name"
    DataTable "curios.txt", "kind|name|weight|prompt"
    DataTable "traps.txt", "kind|name|save|word|sfx|die|trigger|savemsg|failtitle|failbody"
    DataTable "effects.txt", "table|kind|die|text"
    DataTable "monster-effects.txt", "monster|kind|chance|save|die|rounds"
    DataTable "chamber-events.txt", "kind|name|weight|minlvl|maxlvl|text"

    '--- board layout ---
    DataTable "sectors.txt", "id|label|col1|row1|col2|row2|rgb"
    DataTable "labels.txt", "col|row|text"
    DataTable "chambers.txt", "name|c1|r1|c2|r2"
    DataTable "triggers.txt", "level|col|row|scene|once"
    DataTable "overlays.txt", "level|col|row|art|scale|lit"

    '--- tuning + presentation ---
    DataTable "tuning.txt", "key|value"
    DataTable "classes.txt", "id|name|goal|cbt|sec|hp|th|dmg|ac|hd|blurb"
    DataTable "stats.txt", "stat|live|text"
    DataTable "dice-colors.txt", "id|name|body|ink"
    DataTable "dicesets.txt", "name|file"
    DataTable "ambience.txt", "level|sfx|weight"
    DataTable "art-prompts.txt", "path|style|size|prompt"
    DataTable "ui-fonts.txt", "region|fontfile|size"
    DataTable "ui-frames.txt", "name|file|tilew|tileh|note"
    DataTable "ui-fight-layout.txt", "name|col|row|cols|rows|kind|note"

    '--- strings and colours: ONE pipe, because the value contains its own ---
    DataTableSplit "strings.txt", "key|text", 2
    DataTable "theme/colors.txt", "key|rgb"

    '--- the 3D dice set format is its own thing: one directive per line ---
    DataTable "diceset.txt", "directive"

    '--- FLAVOR. Prose with a key in front, so the text keeps every pipe it has. ---
    DataTableSplit "flavor/regular.txt", "level|text", 2
    DataTableSplit "flavor/special.txt", "level|text", 2
    DataTableSplit "flavor/levelup.txt", "level|text", 2
    DataTableSplit "flavor/chambers.txt", "name|description", 2
    DataTableSplit "flavor/maxhit.txt", "text", 1
    DataTableSplit "flavor/forfeit.txt", "text", 1
    ' FOUR columns, not the three the header comment claims -- LoadEventText
    ' reads a narration key after the text, and it is optional so most rows
    ' stop at three.
    DataTable "flavor/monster_events.txt", "key|event|text|narrkey"
    DataTable "flavor/class_events.txt", "key|event|text|narrkey"
END SUB
