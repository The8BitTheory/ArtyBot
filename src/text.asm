str_title !text "ArtyBot - Plan - ",0   ; + "<world> <n>" (put_level_name)
str_title_pad !text "    ",0
str_program_count !text " PROGRAM: 00/99",0
str_select_help !text "Cur:move Ret:OK",0        ; two rows of INFO_W characters
                !byte $1F
                !text ":cancel",0
str_idle_help !text "Cur:move marker",0     ; two rows of INFO_W characters
              !text "Ret:edit Del:del",0
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
str_ice !text "Ice: you slide",0
str_key !text "Key: pick it up",0
str_lock !text "Lock: drop key",0
str_door !text "Door: needs key",0
; Plan screen legend (editor.asm draw_legend), max. 8 characters
str_leg_robot !text "ArtyBot",0
str_leg_looking !text "looking",0
str_leg_right !text "right",0
str_leg_left !text "left",0
str_leg_up !text "up",0
str_leg_down !text "down",0
str_leg_goal !text "Target",0
str_leg_box !text "Package",0
str_leg_tree !text "Tree",0
str_leg_water !text "Water",0
str_leg_ice !text "Ice",0
str_leg_key !text "Key",0
str_leg_lock !text "Lock",0
str_leg_door !text "Door",0
str_bottom_commands !text "F1:Run F7:Map F8:Title",0
str_quit_confirm !text "Back to title?",0
str_clear_confirm !text "Really clear",0
str_clear_confirm2 !text "commandlist?",0
str_quit_yes !text "< Yes >",0
str_quit_no !text "< No >",0
; Compatibility labels for the dormant gameplay module; the planning screen
; now uses its framed command-description row instead.
str_help !byte 0
str_status !text "STATUS",0
str_run_delivered !text " Delivered: ",0
str_run_list !text " ArtyBot Run ",0
str_bottom_run !text "Space:Go R:Redo F1:Plan F7:Map F8:Title",0
str_run_quit !text "To title? Return:yes "
             !byte $1F
             !text ":no",0
str_run_ready !text "Press Space to run the plan",0
str_run_going !text "Running... Space: pause R: restart",0
str_run_halted !text "Stopped here. Space: new run",0
str_run_paused !text "Paused. Space: go on R: restart",0
; Failure messages: max. 37 characters (message row of the run screen, columns 2-38)
str_run_blocked !text "No! Way is blocked. Hit F1 to debug",0
str_run_nopick !text "No! Nothing to grab. Hit F1 to debug",0
str_run_full !text "No! Hands full. Hit F1 to debug",0
str_run_nodrop !text "No! Nothing to drop. Hit F1 to debug",0
str_run_cantdrop !text "No! Can't drop here. Hit F1 to debug",0
str_run_done !text "All packages delivered!",0
str_done_par !text "Done! Par: ",0           ; + par, str_done_you, commands (stats_say_done)
str_done_you !text " Your value: ",0
str_run_end !text "No! Out of commands. Hit F1 to debug",0
str_run_water !text "No! Bots can't swim. Hit F1 to debug",0
str_run_tree !text "No! Tree in the way. Hit F1 to debug",0
str_run_noland !text "No! Can't land there. Hit F1 to debug",0
str_run_nothrow !text "No! Nothing to throw. Hit F1 to debug",0
str_run_cantthrow !text "No! Throw can't land. Hit F1 to debug",0
str_run_ice !text "No! The ice broke. Hit F1 to debug",0
str_run_unlock !text "Click! A door opened.",0
str_empty !byte 0
; World map (world.asm)
str_world_title !text " World ",0
str_bottom_world !text "Space:Play F1:Stats F3/5:World F8:Title",0
str_world_walk !text "WASD/Cursor: walk to a level",0
str_world_play !text "   Space: play",0
str_world_solved !text " - solved",0
str_world_gate !text "The gate is open - go through!",0
str_world_end !text "The road ends here - for now",0
; Level statistics overlay (world.asm)
str_stats_title !text " Level statistics: ",0
str_stats_close !text " Press any key to close ",0
str_stats_worlds !text "F3/F5: other world",0
str_stats_level !text "Level",0
str_stats_solved !text "Solved",0
str_stats_par !text "Par",0
str_stats_cmds !text "Cmds",0
str_stats_yes !text "Yes",0
str_stats_no !text "No",0
; --- Title screen (title.asm). No [ \ ] ^ _ @ here: those codes are title graphics.
str_title_menu  !text " Menu ",0
str_title_new   !text "Start New Game",0
str_title_instr !text "Instructions",0
str_title_cred  !text "Credits",0
str_title_quit  !text "Quit Game",0

str_title_nocont !text " Not available yet ",0
str_title_tag   !text "- a robot programming puzzle -",0
str_title_by    !text "by Goodwell",0
str_title_comp1 !text "Created for the Forum64 KI Coding",0
str_title_comp2 !text "Competition in October 2026",0
str_title_credits !text " Credits ",0
; --- Instructions (title.asm title_instructions). Per page: header, footer,
; lines ("#" = yellow heading), $FF. Max. 36 characters per line, 22 lines.
str_instr1     !text " How to play (1/2) ",0
                !text " Any key: next page ",0
                !text "#Meet ArtyBot",0
                !text "ArtyBot is a great robot with one",0
                !text "tiny flaw: he does exactly what you",0
                !text "tell him. Not more, not less.",0
                !text "(Okay, that is kind of the point.)",0
                !byte 0
                !text "#Your job",0
                !text "Get every package onto a target.",0
                !text "Write a plan, run it, lean back.",0
                !byte 0
                !text "#How it goes",0
                !text "1 Walk to a level on the world map",0
                !text "  and press Space.",0
                !text "2 Have a quick preview with F1.",0
                !text "3 Hit F1 again to go back to",0
                !text "  plan mode.",0
                !text "4 Build a command list: click the",0
                !text "  icons or press Q W E A S D Z X C.",0
                !text "  New commands go in at the marker.",0
                !text "5 Hit F1 and Space to run the plan.",0
                !text "6 Didn't work? F1 takes you back to",0
                !text "  the plan. Fix it, try again.",0
                !byte $FF
str_instr2     !text " How to play (2/2) ",0
                !text " Any key: let's go ",0
                !text "#Commands",0
                !text "Move Fwd/Back  one field",0
                !text "Turn           left, right or 180",0
                !text "Pick Up/Drop   the field in front",0
                !text "Jump           over one field",0
                !text "Throw          package lands 2 ahead",0
                !byte 0
                !text "#Things on the field",0
                !text "Trees block everything. Rude.",0
                !text "Water: ArtyBot can't swim, but he",0
                !text "  can jump or throw across it.",0
                !text "Ice: you slide until you hit land.",0
                !text "  It's thin - don't jump onto it.",0
                !text "Keys: drop or throw one into the",0
                !text "  lock and a door opens.",0
                !byte 0
                !text "#Editing the plan",0
                !text "Cursor moves the marker. Return",0
                !text "grabs the command above it;",0
                !text "then Cursor moves it. Del deletes",0
                !text "it (asks first). Par shows once",0
                !text "solved. Beat it, if you can!",0
                !byte $FF
; --- End screen (title.asm, same charset rules as the title)
str_end_tag     !text "Congratulations! Every level solved.",0
str_end_record  !text " Your record ",0
str_end_total   !text " Total cmds: ",0
str_end_key1    !text "Return: title",0
str_end_key2    !text "F7: back to map",0
str_credits     !text "ArtyBot",0
                !text " ",0
                !text "Idea, design, levels:  Goodwell",0
                !text "Code, Art, Sound:      Claude 5.5",0
                !text "Assembler:             ACME",0
                !text " ",0
                !text "Dedicated to  Julia, Ben & Silvia",0
                !byte $FF
