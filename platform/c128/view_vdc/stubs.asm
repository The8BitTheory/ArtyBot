; stubs.asm (VDC-View) - Platzhalter fuer Bildschirme, die noch fehlen (Weltkarte, Planen, Run;
; Teilschritte 4-6). Treffertests melden "nichts getroffen" (Carry 0), Zeichnen tut nichts.

; Weltkarte, Statistik
world_draw
world_redraw_gates
world_init_sprites
wm_draw_status
stats_layout
stats_draw
theme_load
        rts
world_sprites
spr_init
spr_update
        jmp vp_show
wm_hit_cell
        clc
        rts

; Planen
draw_planning_screen
draw_title_and_counters
draw_map_objects
draw_palette_panel
draw_program_list
draw_program_row
draw_program_counts
draw_scrollbar
draw_legend
editor_draw_info
editor_draw_message2
editor_clear_palette_interior
plan_draw_quit_confirm
plan_draw_clear_confirm
        rts
palette_hit_test
list_hit_test
arrow_hit_test
plan_hit_field
plan_hit_footer
plan_hit_confirm
        clc
        rts

; Run
draw_run_screen
draw_run_field
draw_run_cell
draw_run_delivered
draw_run_list
run_draw_message
run_init_sprites
run_set_robot_image
run_update_sprites
run_goal_anim
        rts
