; mapdata.asm - Planning-field level data (part of the single PRG) and loader.
; One variable-length record per level, coordinates are field tiles
; (0..MAP_COLS-1 / 0..MAP_ROWS-1, origin top-left):
;   +0 robot x, +1 robot y, +2 robot direction (ROBOT_DIR_*),
;   +3 number of goal fields G (1..MAX_GOALS), followed by G pairs (x, y),
;   then the number of packages P, followed by P pairs (x, y),
;   then the number of blockers N (trees: block the space, cannot be jumped
;   over or thrown across), followed by N pairs (x, y),
;   then the number of water fields W (block the ground: cannot be walked on
;   or dropped onto, but can be jumped over and thrown across), followed by
;   W pairs (x, y),
;   then the number of ice fields I (frozen water: the robot skates over it until
;   land is reached or the next field is blocked; jumping off it, landing on it or
;   throwing a package on it breaks it and the run fails), followed by I pairs.
;   then the number of keys K, followed by K pairs (x, y): keys lie on the ground, are
;   picked up / dropped / thrown like a package but are no deliveries,
;   then the number of lock/door pairs L (max MAX_LOCKS), followed by L records
;   (lock x, lock y, door x, door y). A closed door blocks like a tree (also jumping
;   and throwing); a key dropped or thrown onto its lock turns the door into floor.
; A level is won when every goal field holds a package, so give it at least as
; many packages as goal fields. More levels: add a record map<world><level> below
; and its !word in the world's block of plan_level_table (tools/level_editor.html
; builds the record).
;
; load_plan_level builds the static field layer in map_work (MAP_COLS*MAP_ROWS
; bytes, row-major, tile ids T_FLOOR/T_WALL(blocker)/T_BOX(package)/T_GOAL
; (free goal field)/T_BOXG(package standing on a goal field)/T_WATER) and the goal list
; goal_list (goal_count pairs x, y).
; The robot is not stored in that layer; it lives in robot_tx/robot_ty/robot_dir.

goal_list       = $0280         ; goal_count pairs (x, y) behind map_work
MAX_GOALS       = 16
lock_list       = $02A0         ; lock_count records (lock x, lock y, door x, door y)

ROBOT_DIR_RIGHT = 0             ; matches gfx_robot order ($80..$83)
ROBOT_DIR_LEFT  = 1
ROBOT_DIR_UP    = 2
ROBOT_DIR_DOWN  = 3

MAPREC_ROBOT_X   = 0
MAPREC_ROBOT_Y   = 1
MAPREC_ROBOT_DIR = 2
MAPREC_GOALS     = 3            ; count byte; goals, packages, blockers, water, ice, keys, locks follow

MAP_CELLS       = MAP_COLS * MAP_ROWS

; Levels per world: label map<world><level> (world 1-8, level 1-9), e.g. map11 =
; world 1, level 1. plan_level_table holds the worlds' blocks one after the other;
; world_table (world.asm) takes the first index and the number of levels of each
; world from the labels below, so a new level only needs its record and one !word
; in its world's block. In the game the levels keep a running index (level_no).
plan_level_table
world1_levels                           ; world 1: Meadow
        !word map11, map12, map13
        !word map14                     ; key, lock and door
WORLD1_LEVELS = (* - world1_levels) / 2
world2_levels                           ; world 2: Winter
        !word map21                     ; ice: skating (taught level by level)
        !word map22, map23, map24, map25, map26, map27, map28, map29 ; PLACEHOLDERS
WORLD2_LEVELS = (* - world2_levels) / 2
plan_level_count = (* - plan_level_table) / 2
!if WORLD1_LEVELS > 9 | WORLD2_LEVELS > 9 {
    !error "Hoechstens 9 Levels pro Welt"
}

map11
        !byte 0, 4, ROBOT_DIR_RIGHT     ; robot: left edge, facing right
        !byte 3                         ; # goal fields (x, y)
        !byte 3, 3
        !byte 7, 3
        !byte 5, 5
        !byte 3                         ; # packages (x, y)
        !byte 5, 3
        !byte 3, 5
        !byte 7, 5
        !byte 22                         ; # blockers (x, y): trees
        !byte 2, 2
        !byte 3, 2
        !byte 4, 2
        !byte 5, 2
        !byte 6, 2
        !byte 7, 2
        !byte 8, 2
        !byte 2, 3
        !byte 4, 3
        !byte 6, 3
        !byte 8, 3
        !byte 2, 5
        !byte 4, 5
        !byte 6, 5
        !byte 8, 5
        !byte 2, 6
        !byte 3, 6
        !byte 4, 6
        !byte 5, 6
        !byte 6, 6
        !byte 7, 6
        !byte 8, 6
        !byte 0                         ; # water fields
        !byte 0                         ; # ice fields (frozen water)
        !byte 0, 0                      ; # keys, locks

; map12: a river (column 5) splits the field. Robot and packages start on the
; left bank, both goals are on the right bank. The upper goal (6,2) is fenced in
; by trees and only open towards the river: its package has to be thrown across.
;   .....~....
;   .R.T.~T...
;   .....~GT..
;   ..P..~T...
;   .....~..T.
;   T....~....
;   .....~....
;   ...P.~..G.
;   .T...~....
;   .....~...T
map12
        !byte 1, 1, ROBOT_DIR_DOWN      ; robot: left bank, facing down
        !byte 2                         ; goal fields (x, y): right bank
        !byte 6, 2                      ; only reachable from the water side
        !byte 8, 7
        !byte 2                         ; packages (x, y): left bank
        !byte 2, 3
        !byte 3, 7
        !byte 8                         ; blockers (x, y)
        !byte 6, 1                      ; trees fencing in the upper goal
        !byte 7, 2
        !byte 6, 3
        !byte 3, 1
        !byte 0, 5
        !byte 1, 8
        !byte 8, 4
        !byte 9, 9
        !byte 10                        ; water fields (x, y): the river
        !byte 5, 0
        !byte 5, 1
        !byte 5, 2
        !byte 5, 3
        !byte 5, 4
        !byte 5, 5
        !byte 5, 6
        !byte 5, 7
        !byte 5, 8
        !byte 5, 9
        !byte 0                         ; ice fields (frozen water)
        !byte 0, 0                      ; keys, locks

; map13 (Sokoban-style warehouse): walls of the classic puzzle are trees, 7 goals,
; 7 packages (one already stands on its goal). Robot starts in the upper-left
; nook facing down. Redrawn from the original 8x9 map, shifted by (1,0).
; Map (T tree, p package, G goal, P package on a goal, R robot):
;      TTTTT  
;    TTT...T  
;    TGRp..T  
;    TTT.pGT  
;    TGTTp.T  
;    T.T.G.TT 
;    Tp.PppGT 
;    T...G..T 
;    TTTTTTTT 
;             
map13
        !byte 3, 2, ROBOT_DIR_DOWN      ; robot
        !byte 7                         ; goal fields (x, y)
        !byte 2, 2
        !byte 6, 3
        !byte 2, 4
        !byte 5, 5
        !byte 7, 6
        !byte 5, 7
        !byte 4, 6
        !byte 7                         ; packages (x, y)
        !byte 4, 2
        !byte 5, 3
        !byte 5, 4
        !byte 2, 6
        !byte 4, 6
        !byte 5, 6
        !byte 6, 6
        !byte 35                        ; blockers (x, y)
        !byte 1, 1
        !byte 1, 2
        !byte 1, 3
        !byte 1, 4
        !byte 1, 5
        !byte 1, 6
        !byte 1, 7
        !byte 1, 8
        !byte 2, 1
        !byte 2, 3
        !byte 2, 8
        !byte 3, 0
        !byte 3, 1
        !byte 3, 3
        !byte 3, 4
        !byte 3, 5
        !byte 3, 8
        !byte 4, 0
        !byte 4, 4
        !byte 4, 8
        !byte 5, 0
        !byte 5, 8
        !byte 6, 0
        !byte 6, 8
        !byte 7, 0
        !byte 7, 1
        !byte 7, 2
        !byte 7, 3
        !byte 7, 4
        !byte 7, 5
        !byte 7, 8
        !byte 8, 5
        !byte 8, 6
        !byte 8, 7
        !byte 8, 8
        !byte 0                         ; water fields
        !byte 0                         ; ice fields (frozen water)
        !byte 0, 0                      ; keys, locks

; map14 (Meadow 4, "Locked gates"): two walls of trees (x = 3 and x = 6) split the
; meadow into three rooms; each wall has a closed door. The locks stand elsewhere:
; the key lying in the first room opens the first door via the lock (1,2); behind it
; lies the second key, whose lock (5,2) opens the last door. Trees and closed doors
; block jumping and throwing, so keys and packages have to be carried through the
; doors. A key can be dropped or thrown onto its lock.
;   T tree  k key  L lock  D door  P package  G goal  R robot
;
;    TTTTTTTTTT
;    T........T
;    T.TTTTTT.T
;    T.T..D.T.T
;    T.T.GL.T.T
;    T.TTTTkT.T
;    T......T.T
;    TTTTTTTT.T
;    P........T
;    ^TTTTTTTTT
;    (. floor  T tree  ~ water  # ice  G goal  P package  * package on goal
;     k key  L lock  D door  > < ^ v robot)
map14
        !byte 0, 9, ROBOT_DIR_UP
        !byte 1                         ; goal fields (x, y)
        !byte 4, 4
        !byte 1                         ; packages (x, y)
        !byte 0, 8
        !byte 57                        ; blockers (x, y)
        !byte 0, 0, 1, 0, 2, 0, 3, 0
        !byte 4, 0, 5, 0, 6, 0, 7, 0
        !byte 8, 0, 9, 0, 0, 1, 9, 1
        !byte 0, 2, 2, 2, 3, 2, 4, 2
        !byte 5, 2, 6, 2, 7, 2, 9, 2
        !byte 0, 3, 2, 3, 7, 3, 9, 3
        !byte 0, 4, 2, 4, 7, 4, 9, 4
        !byte 0, 5, 2, 5, 3, 5, 4, 5
        !byte 5, 5, 7, 5, 9, 5, 0, 6
        !byte 7, 6, 9, 6, 0, 7, 1, 7
        !byte 2, 7, 3, 7, 4, 7, 5, 7
        !byte 6, 7, 7, 7, 9, 7, 9, 8
        !byte 1, 9, 2, 9, 3, 9, 4, 9
        !byte 5, 9, 6, 9, 7, 9, 8, 9
        !byte 9, 9
        !byte 0                         ; water fields (x, y)
        !byte 0                         ; ice fields (frozen water)
        !byte 1                         ; keys (x, y)
        !byte 6, 5
        !byte 1                         ; lock/door pairs: lock x, y, door x, door y
        !byte 5, 4, 5, 3




; map21 (Winter 1, "Slippery bridge"): a lake of open water cuts the field in two,
; only a strip of ice (x = 3..5) leads across. Stepping onto the ice carries the
; robot over to the other bank in one move (forwards or backwards). Both packages
; lie on the north bank, both goals on the south bank: cross three times.
;
;    T........T
;    ...P..P.T.
;    ..........
;    ~~~###~~~~
;    ~~~###~~~~
;    ~~~###~~~~
;    ~~~###~~~~
;    .T........
;    ...G^G....
;    T........T
;    (. snow  # ice  ~ water  T pine  P package  G goal  ^ robot)
map21
        !byte 4, 8, ROBOT_DIR_UP
        !byte 2                       ; goal fields (x, y)
        !byte 3, 8, 5, 8
        !byte 2                       ; packages (x, y)
        !byte 3, 1, 6, 1
        !byte 6                       ; blockers (x, y)
        !byte 0, 0, 9, 0, 0, 9, 9, 9, 8, 1, 1, 7
        !byte 28                      ; water fields
        !byte 0, 3, 1, 3, 2, 3, 6, 3, 7, 3, 8, 3, 9, 3
        !byte 0, 4, 1, 4, 2, 4, 6, 4, 7, 4, 8, 4, 9, 4
        !byte 0, 5, 1, 5, 2, 5, 6, 5, 7, 5, 8, 5, 9, 5
        !byte 0, 6, 1, 6, 2, 6, 6, 6, 7, 6, 8, 6, 9, 6
        !byte 12                      ; ice fields (frozen water)
        !byte 3, 3, 4, 3, 5, 3, 3, 4, 4, 4, 5, 4
        !byte 3, 5, 4, 5, 5, 5, 3, 6, 4, 6, 5, 6
        !byte 0, 0                      ; keys, locks

; the robot, goal one field further: Pick Up, Move Fwd, Drop Off).
; map22 (Winter 2, "Brakes"): a skating rink with two snow islands holding the
; goals. Skating, the robot only stops on the ice when the next field is blocked:
; the pines at (6,4) and (3,7) stop it right beside the islands. Without them it
; would skate past to the far bank.
;
;    T.........
;    ..######..
;    P.######..
;    ..###G##..
;    .>####T#..
;    ..######..
;    P.##G###..
;    ..#T####..
;    ..######..
;    T........T
;    (. snow  # ice  T pine  P package  G goal  > robot)
map22
        !byte 1, 4, ROBOT_DIR_RIGHT
        !byte 2                       ; goal fields (x, y)
        !byte 5, 3, 4, 6
        !byte 2                       ; packages (x, y)
        !byte 0, 2, 0, 6
        !byte 5                       ; blockers (x, y)
        !byte 0, 0, 0, 9, 9, 9, 6, 4, 3, 7
        !byte 0                       ; water fields
        !byte 44                      ; ice fields (frozen water)
        !byte 2, 1, 3, 1, 4, 1, 5, 1, 6, 1, 7, 1, 2, 2, 3, 2
        !byte 4, 2, 5, 2, 6, 2, 7, 2, 2, 3, 3, 3, 4, 3, 6, 3
        !byte 7, 3, 2, 4, 3, 4, 4, 4, 5, 4, 7, 4, 2, 5, 3, 5
        !byte 4, 5, 5, 5, 6, 5, 7, 5, 2, 6, 3, 6, 5, 6, 6, 6
        !byte 7, 6, 2, 7, 4, 7, 5, 7, 6, 7, 7, 7, 2, 8, 3, 8
        !byte 4, 8, 5, 8, 6, 8, 7, 8
        !byte 0, 0                      ; keys, locks

; map23 (Winter 3, "Steering"):
; an open rink: plan a chain of slides. Up past the pine at (3,0) to stop in row 1,
; right to the field edge, drop onto the corner goal. That package then stops the
; next slide up column 9 right beside the second goal.
;
;    ###T#####T
;    ##########
;    #########G
;    ########G#
;    ##########
;    ##########
;    ##########
;    ##########
;    ##########
;    P^P.......
;    (. snow  # ice  ~ water  T pine  P package  G goal  K key  L/M lock  D/E door)
map23
        !byte 1, 9, ROBOT_DIR_UP
        !byte 2                     ; goal fields (x, y)
        !byte 9, 2, 8, 3
        !byte 2                     ; packages (x, y)
        !byte 0, 9, 2, 9
        !byte 2                     ; blockers (x, y)
        !byte 3, 0, 9, 0
        !byte 0                     ; water fields (x, y)
        !byte 86                    ; ice fields (frozen water) (x, y)
        !byte 0, 0, 1, 0, 2, 0, 4, 0, 5, 0, 6, 0, 7, 0, 8, 0
        !byte 0, 1, 1, 1, 2, 1, 3, 1, 4, 1, 5, 1, 6, 1, 7, 1
        !byte 8, 1, 9, 1, 0, 2, 1, 2, 2, 2, 3, 2, 4, 2, 5, 2
        !byte 6, 2, 7, 2, 8, 2, 0, 3, 1, 3, 2, 3, 3, 3, 4, 3
        !byte 5, 3, 6, 3, 7, 3, 9, 3, 0, 4, 1, 4, 2, 4, 3, 4
        !byte 4, 4, 5, 4, 6, 4, 7, 4, 8, 4, 9, 4, 0, 5, 1, 5
        !byte 2, 5, 3, 5, 4, 5, 5, 5, 6, 5, 7, 5, 8, 5, 9, 5
        !byte 0, 6, 1, 6, 2, 6, 3, 6, 4, 6, 5, 6, 6, 6, 7, 6
        !byte 8, 6, 9, 6, 0, 7, 1, 7, 2, 7, 3, 7, 4, 7, 5, 7
        !byte 6, 7, 7, 7, 8, 7, 9, 7, 0, 8, 1, 8, 2, 8, 3, 8
        !byte 4, 8, 5, 8, 6, 8, 7, 8, 8, 8, 9, 8
        !byte 0                     ; keys (x, y)
        !byte 0                     ; lock/door pairs: lock x, y, door x, y

; map24 (Winter 4, "Thin ice"):
; the trap: right in front of the robot a narrow ditch, behind it the ice and the
; goal. Jumping across the ditch lands on the ice and breaks it. The way that works
; is the snow bridge at (7,6): step onto the ice from there and skate up to the bank.
;
;    T........T
;    ..G.......
;    ..........
;    ##########
;    ##########
;    ##########
;    ~~~~~~~.~~
;    ..........
;    ..P^......
;    T........T
;    (. snow  # ice  ~ water  T pine  P package  G goal  K key  L/M lock  D/E door)
map24
        !byte 3, 8, ROBOT_DIR_UP
        !byte 1                     ; goal fields (x, y)
        !byte 2, 1
        !byte 1                     ; packages (x, y)
        !byte 2, 8
        !byte 4                     ; blockers (x, y)
        !byte 0, 0, 9, 0, 0, 9, 9, 9
        !byte 9                     ; water fields (x, y)
        !byte 0, 6, 1, 6, 2, 6, 3, 6, 4, 6, 5, 6, 6, 6, 8, 6
        !byte 9, 6
        !byte 30                    ; ice fields (frozen water) (x, y)
        !byte 0, 3, 1, 3, 2, 3, 3, 3, 4, 3, 5, 3, 6, 3, 7, 3
        !byte 8, 3, 9, 3, 0, 4, 1, 4, 2, 4, 3, 4, 4, 4, 5, 4
        !byte 6, 4, 7, 4, 8, 4, 9, 4, 0, 5, 1, 5, 2, 5, 3, 5
        !byte 4, 5, 5, 5, 6, 5, 7, 5, 8, 5, 9, 5
        !byte 0                     ; keys (x, y)
        !byte 0                     ; lock/door pairs: lock x, y, door x, y

; map25 (Winter 5, "Don't throw it"):
; throwing across the ice is fine: from the bank at (3,6) a package flies over
; (3,5) onto the near goal. The far goal is too far: a throw from (6,6) lands on the
; ice at (6,4), which breaks, and the package is gone. Carry it onto the ice instead
; (solver: skate up column 6 onto the goal island, on up to the pines, throw back
; down over (6,2); or skate up column 7, the pine at (7,2) stops beside the goal).
;
;    TTTTTTTTTT
;    T########T
;    T######T#T
;    T#####G##T
;    T##G#####T
;    T########T
;    ..........
;    ...P^P....
;    ..........
;    T........T
;    (. snow  # ice  ~ water  T pine  P package  G goal  K key  L/M lock  D/E door)
map25
        !byte 4, 7, ROBOT_DIR_UP
        !byte 2                     ; goal fields (x, y)
        !byte 6, 3, 3, 4
        !byte 2                     ; packages (x, y)
        !byte 3, 7, 5, 7
        !byte 23                    ; blockers (x, y)
        !byte 0, 0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0
        !byte 8, 0, 9, 0, 0, 1, 9, 1, 0, 2, 7, 2, 9, 2, 0, 3
        !byte 9, 3, 0, 4, 9, 4, 0, 5, 9, 5, 0, 9, 9, 9
        !byte 0                     ; water fields (x, y)
        !byte 37                    ; ice fields (frozen water) (x, y)
        !byte 1, 1, 2, 1, 3, 1, 4, 1, 5, 1, 6, 1, 7, 1, 8, 1
        !byte 1, 2, 2, 2, 3, 2, 4, 2, 5, 2, 6, 2, 8, 2, 1, 3
        !byte 2, 3, 3, 3, 4, 3, 5, 3, 7, 3, 8, 3, 1, 4, 2, 4
        !byte 4, 4, 5, 4, 6, 4, 7, 4, 8, 4, 1, 5, 2, 5, 3, 5
        !byte 4, 5, 5, 5, 6, 5, 7, 5, 8, 5
        !byte 0                     ; keys (x, y)
        !byte 0                     ; lock/door pairs: lock x, y, door x, y

; map26..map29: PLACEHOLDERS until the ice levels are built (package in front of
; the robot, goal one field further: Pick Up, Move Fwd, Drop Off).
map26
        !byte 4, 8, ROBOT_DIR_UP
        !byte 1, 4, 6                   ; goal
        !byte 1, 4, 7                   ; package
        !byte 0, 0, 0, 0, 0             ; trees, water, ice, keys, locks
map27
        !byte 4, 8, ROBOT_DIR_UP
        !byte 1, 4, 6                   ; goal
        !byte 1, 4, 7                   ; package
        !byte 0, 0, 0, 0, 0             ; trees, water, ice, keys, locks
map28
        !byte 4, 8, ROBOT_DIR_UP
        !byte 1, 4, 6                   ; goal
        !byte 1, 4, 7                   ; package
        !byte 0, 0, 0, 0, 0             ; trees, water, ice, keys, locks
map29
        !byte 4, 8, ROBOT_DIR_UP
        !byte 1, 4, 6                   ; goal
        !byte 1, 4, 7                   ; package
        !byte 0, 0, 0, 0, 0             ; trees, water, ice, keys, locks

; A = level number. Copies its record into the game variables and builds the
; field layer including the blockers. Invalid numbers fall back to level 0.
!zone load_plan_level
load_plan_level
        cmp #plan_level_count
        bcc .valid
        lda #0
.valid  sta level_no
        asl
        tax
        lda plan_level_table,x
        sta ptr0
        lda plan_level_table+1,x
        sta ptr0+1
        ldy #MAPREC_ROBOT_X
        lda (ptr0),y
        sta robot_tx
        ldy #MAPREC_ROBOT_Y
        lda (ptr0),y
        sta robot_ty
        ldy #MAPREC_ROBOT_DIR
        lda (ptr0),y
        sta robot_dir

        ; Empty field.
        ldx #0
        lda #T_FLOOR
.clear  sta map_work,x
        inx
        cpx #MAP_CELLS
        bne .clear

        ; Goal fields: remember them in goal_list and mark the field layer.
        ldy #MAPREC_GOALS
        lda (ptr0),y
        sta goal_count
        sta cnt
        iny
        lda #0
        sta tmp3                ; offset into goal_list
.goal   lda cnt
        beq .goals_done
        lda (ptr0),y
        sta tmp0
        iny
        lda (ptr0),y
        sta tmp1
        iny
        ldx tmp3
        lda tmp0
        sta goal_list,x
        lda tmp1
        sta goal_list+1,x
        inx
        inx
        stx tmp3
        jsr map_index           ; keeps Y
        lda #T_GOAL
        sta map_work,x
        dec cnt
        jmp .goal
.goals_done

        ; Packages (a package that starts on a goal field counts as delivered).
        lda (ptr0),y
        iny
        sta cnt
.pkg    lda cnt
        beq .pkgs_done
        lda (ptr0),y
        sta tmp0
        iny
        lda (ptr0),y
        sta tmp1
        iny
        jsr map_index
        lda map_work,x
        cmp #T_GOAL
        beq .on_goal
        lda #T_BOX
        bne .put
.on_goal
        lda #T_BOXG
.put    sta map_work,x
        dec cnt
        jmp .pkg
.pkgs_done

        ; Blockers from the level record.
        lda (ptr0),y
        iny
        sta cnt
.blk    lda cnt
        beq .water
        lda (ptr0),y
        sta tmp0
        iny
        lda (ptr0),y
        sta tmp1
        iny
        jsr map_index           ; keeps Y
        lda #T_WALL
        sta map_work,x
        dec cnt
        jmp .blk

        ; Water fields from the level record.
.water  lda (ptr0),y
        iny
        sta cnt
.wat    lda cnt
        beq .done
        lda (ptr0),y
        sta tmp0
        iny
        lda (ptr0),y
        sta tmp1
        iny
        jsr map_index           ; keeps Y
        lda #T_WATER
        sta map_work,x
        dec cnt
        jmp .wat

        ; Ice fields (frozen water) from the level record.
.done   lda (ptr0),y
        iny
        sta cnt
.ice    lda cnt
        beq .end
        lda (ptr0),y
        sta tmp0
        iny
        lda (ptr0),y
        sta tmp1
        iny
        jsr map_index           ; keeps Y
        lda #T_ICE
        sta map_work,x
        dec cnt
        jmp .ice

        ; Keys lying on the ground.
.end    lda (ptr0),y
        iny
        sta cnt
.key    lda cnt
        beq .locks
        lda (ptr0),y
        sta tmp0
        iny
        lda (ptr0),y
        sta tmp1
        iny
        jsr map_index           ; keeps Y
        lda #T_KEY
        sta map_work,x
        dec cnt
        jmp .key

        ; Lock/door pairs: lock_list gets the four bytes, the field layer the tiles.
.locks  lda (ptr0),y
        iny
        sta lock_count
        sta cnt
        lda #0
        sta tmp3                ; offset into lock_list
.lock   lda cnt
        beq .lend
        ldx tmp3
        lda (ptr0),y            ; lock x
        sta lock_list,x
        sta tmp0
        iny
        lda (ptr0),y            ; lock y
        sta lock_list+1,x
        sta tmp1
        iny
        lda (ptr0),y            ; door x
        sta lock_list+2,x
        iny
        lda (ptr0),y            ; door y
        sta lock_list+3,x
        iny
        inx
        inx
        inx
        inx
        stx tmp3
        jsr map_index           ; keeps Y: the lock
        lda #T_LOCK
        sta map_work,x
        ldx tmp3
        lda lock_list-2,x       ; door x
        sta tmp0
        lda lock_list-1,x       ; door y
        sta tmp1
        jsr map_index
        lda #T_DOOR
        sta map_work,x
        dec cnt
        jmp .lock
.lend   rts

; tmp0 = x, tmp1 = y -> X = row-major index into map_work.
!zone map_index
map_index
        lda tmp1
        asl
        asl
        asl
        clc
        adc tmp1
        adc tmp1                ; y * 10
        clc
        adc tmp0
        tax
        rts

; Draw the field layer and the robot from the loaded level. All field characters are
; multicolour (colour RAM +8) on the shared greens $D022/$D023 of the run screen.
!zone draw_map_objects
draw_map_objects
        lda #0
        sta ui_row
.row    lda #0
        sta ui_col
.col    lda ui_row
        sta tmp0
        asl
        asl
        asl
        clc
        adc tmp0
        adc tmp0                ; row * 10
        clc
        adc ui_col
        tax
        lda map_work,x
        tax
        lda map_tile_colors,x
        sta cur_col
        lda map_tile_chars,x
        pha
        lda ui_col
        clc
        adc #MAP_SCR_X
        tax
        lda ui_row
        clc
        adc #MAP_SCR_Y
        tay
        jsr set_cursor
        pla
        jsr put_char
        inc ui_col
        lda ui_col
        cmp #MAP_COLS
        bne .col
        inc ui_row
        lda ui_row
        cmp #MAP_ROWS
        bne .row
        lda robot_tx
        clc
        adc #MAP_SCR_X
        tax
        lda robot_ty
        clc
        adc #MAP_SCR_Y
        tay
        jsr set_cursor
        lda theme_plan_robot
        sta cur_col
        lda robot_dir
        clc
        adc #ROBOT_CHAR_BASE
        jmp put_char

map_tile_chars                  ; indexed by tile id
        !byte FLOOR_CHAR, BLOCK_CHAR, PKG_CHAR, GOAL_CHAR, PKG_CHAR, WATER_CHAR, ICE_CHAR, WATER_CHAR
        !byte KEY_CHAR, LOCK_CHAR, LOCK_CHAR, DOOR_CHAR
; map_tile_colors (colour RAM per tile id) comes from the theme, see world.asm.
map_info_colors                 ; help-text colour per tile id
        !byte COL_WHITE, COL_GREEN, COL_YELLOW, COL_CYAN, COL_YELLOW, COL_CYAN, COL_CYAN, COL_CYAN
        !byte COL_YELLOW, COL_YELLOW, COL_YELLOW, COL_YELLOW

; Hover code for the field tile under the mouse, or $FF.
;   $50+dir robot, $61 blocker, $62 package, $63 goal, $64 delivered, $65 water
!zone map_hover_code
map_hover_code
        lda mouse_x_hi
        bne .none
        lda mouse_x_lo
        lsr
        lsr
        lsr
        sec
        sbc #MAP_SCR_X
        bcc .none
        cmp #MAP_COLS
        bcs .none
        sta tmp0
        lda mouse_y
        lsr
        lsr
        lsr
        sec
        sbc #MAP_SCR_Y
        bcc .none
        cmp #MAP_ROWS
        bcs .none
        sta tmp1
        lda tmp0
        cmp robot_tx
        bne .tile
        lda tmp1
        cmp robot_ty
        bne .tile
        lda robot_dir
        clc
        adc #$50
        rts
.tile   jsr map_index
        lda map_work,x
        beq .none               ; plain floor: no help text
        clc
        adc #$60
        rts
.none   lda #$FF
        rts

; Hover code in A ($50..$63) -> help text in the info row.
!zone draw_map_info
draw_map_info
        cmp #$60
        bcs .object
        sec
        sbc #$50                ; robot direction
        pha
        ldx #INFO_X
        ldy #INFO_Y
        jsr set_cursor
        lda #<str_facing
        ldx #>str_facing
        jsr put_str
        pla
        asl
        tax
        lda dir_name_ptrs,x
        pha
        lda dir_name_ptrs+1,x
        tax
        pla
        jmp put_str
.object sec
        sbc #$60
        tay
        lda map_info_colors,y
        sta cur_col
        tya
        asl
        tax
        lda map_text_ptrs,x
        pha
        lda map_text_ptrs+1,x
        tax
        ldy #INFO_Y
        stx tmp0
        ldx #INFO_X
        jsr set_cursor
        pla
        ldx tmp0
        jmp put_str

dir_name_ptrs
        !word str_dir_right, str_dir_left, str_dir_up, str_dir_down
map_text_ptrs                   ; indexed by tile id (floor unused)
        !word 0, str_blocker, str_package, str_target, str_package_done, str_water, str_ice, str_water
        !word str_key, str_lock, str_lock, str_door
