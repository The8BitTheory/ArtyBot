str_title !text "ArtyBot - Plan - Level "
str_title_lvl !text "1: Factory",0       ; first character = level digit, patched at draw time
str_program_count !text " PROGRAM: 00/99",0
str_select_help !text "Cur:move Ret:OK",0        ; two rows of INFO_W characters
                !text "Del:delete "
                !byte $1F
                !text ":esc",0
str_delete_help !text "Return:delete",0
                !byte $1F
                !text ":keep",0
str_facing !text "Facing ",0
str_dir_right !text "Right",0
str_dir_left !text "Left",0
str_dir_up !text "Up",0
str_dir_down !text "Down",0
str_target !text "Target Area",0
str_package !text "Deliver this",0
str_package_done !text "Delivered",0
str_blocker !text "Blocked",0
str_water !text "Water: jump it",0
str_bottom_commands !text "F1: Run plan F8: Exit Artybot",0
str_quit_confirm !text "Really quit?",0
str_clear_confirm !text "Really clear",0
str_clear_confirm2 !text "commandlist?",0
str_quit_yes !text "< Yes >",0
str_quit_no !text "< No >",0
; Compatibility labels for the dormant gameplay module; the planning screen
; now uses its framed command-description row instead.
str_help !byte 0
str_status !text "STATUS",0
str_run_field !text " Level "
str_run_field_lvl !text "1: Factory ",0   ; first character = level digit, patched at draw time
str_run_list !text " ArtyBot Run ",0
str_bottom_run !text "Space:Go/Pause R:Redo F1:Plan F8:Exit",0
str_run_quit !text "Really quit? Return:yes "
             !byte $1F
             !text ":no",0
str_run_ready !text "Press Space to run the plan",0
str_run_going !text "Running... Space: pause R: restart",0
str_run_paused !text "Paused. Space: go on R: restart",0
str_run_blocked !text "ArtyBot is blocked. Space: retry",0
str_run_nopick !text "Nothing to pick up. Space: retry",0
str_run_full !text "Hands full. Space: retry",0
str_run_nodrop !text "Nothing to drop. Space: retry",0
str_run_cantdrop !text "Can't drop here. Space: retry",0
str_run_done !text "All packages delivered!",0
str_run_next !text "Done! Space: next level  R: replay",0
str_run_end !text "Not delivered. Space: retry",0
str_run_water !text "ArtyBot can't swim. Space: retry",0
str_run_tree !text "A tree is in the way. Space: retry",0
str_run_noland !text "Can't land there. Space: retry",0
str_run_nothrow !text "Nothing to throw. Space: retry",0
str_run_cantthrow !text "Can't throw there. Space: retry",0
