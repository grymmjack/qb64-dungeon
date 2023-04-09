'$INCLUDE:'const.bas'

TYPE ENUM
    index AS INTEGER
    label AS STRING
END TYPE

TYPE POSITION
    x AS INTEGER
    y AS INTEGER
END TYPE

TYPE GRID
    columns         AS INTEGER
    rows            AS INTEGER
    odd_char        AS STRING
    even_char       AS STRING
    odd_char_color  AS LONG
    even_char_color AS LONG
END TYPE

TYPE LAYER
    filename AS STRING
    handle   AS LONG
    label    AS STRING
    pos      AS POSITION
    opacity  AS LONG
    visible  AS INTEGER
    width    AS INTEGER
    height   AS INTEGER
END TYPE

TYPE PATH
    path_layer AS LAYER
    path_color AS LONG
END TYPE

TYPE LEVEL
    number AS INTEGER
    color  AS LONG
END TYPE

TYPE ROOM
    room_level          AS LEVEL
    has_monster         AS INTEGER
    has_treasure        AS INTEGER
    last_player_entered AS INTEGER
    monster_is_dead     AS INTEGER
    treasure_is_trapped AS INTEGER
END TYPE

TYPE BOARD
    grid       AS GRID
    img_grid   AS LONG
    img_tokens AS LONG
    img_rooms  AS LONG
    img_paths  AS LONG
    img_scene  AS LONG
END TYPE

TYPE TOKEN
    pos      AS POSITION
    bg_color AS _UNSIGNED LONG
    fg_color AS _UNSIGNED LONG
    char     AS STRING
END TYPE

TYPE TREASURE_CARD
    index       AS INTEGER
    name        AS STRING
    description AS STRING
    gold_value  AS INTEGER
    img_face    AS LONG
END TYPE

TYPE MONSTER_CARD
    index       AS INTEGER
    name             AS STRING
    description      AS STRING
    gold_value       AS INTEGER
    img_face         AS LONG
    attack_modifier  AS INTEGER
    defense_modifier AS INTEGER
END TYPE

TYPE SPELL_CARD
    index       AS INTEGER
    name            AS STRING
    description      AS STRING
    gold_value      AS INTEGER
    img_face        AS LONG
    attack_modifier AS INTEGER
END TYPE

TYPE PLAYER_CLASS
    name             AS STRING
    description      AS STRING
    has_spells       AS INTEGER
    attack_modifier  AS INTEGER
    defense_modifier AS INTEGER
END TYPE

TYPE PLAYER
    piece              AS TOKEN
    class              AS PLAYER_CLASS
    name               AS STRING
    gold               AS INTEGER
    gold_won           AS INTEGER
    gold_lost          AS INTEGER
    treasures_found    AS INTEGER
    treasures_lost     AS INTEGER
    kills              AS INTEGER
    deaths             AS INTEGER
    skipping_next_turn AS INTEGER
    move_roll          AS INTEGER
    attack_roll        AS INTEGER
    chance_roll        AS INTEGER
END TYPE

TYPE INVENTORY_SLOT
    card_type   AS ENUM
    card_index  AS INTEGER
END TYPE

DIM PLAYER_1 AS PLAYER
DIM PLAYER_1_INVENTORY(1 TO 32) AS INVENTORY_SLOT

DIM PLAYER_2 AS PLAYER
DIM PLAYER_2_INVENTORY(1 TO 32) AS INVENTORY_SLOT

DIM PLAYER_3 AS PLAYER
DIM PLAYER_3_INVENTORY(1 TO 32) AS INVENTORY_SLOT

DIM PLAYER_4 AS PLAYER
DIM PLAYER_4_INVENTORY(1 TO 32) AS INVENTORY_SLOT

DIM CARD_TYPES(1 TO 3) AS ENUM
CARD_TYPES(1).index = 0 : CARD_TYPES(1).label = "Treasure"
CARD_TYPES(2).index = 1 : CARD_TYPES(2).label = "Monster"
CARD_TYPES(3).index = 2 : CARD_TYPES(3).label = "Spell"

DIM MARKERS(1 TO 2) AS ENUM
MARKERS(1).index = 0 : MARKERS(1).label = "Skull"
MARKERS(2).index = 0 : MARKERS(2).label = "Trap"
