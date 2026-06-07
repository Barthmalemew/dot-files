# shellcheck shell=bash

# Terminal palette mapping for the current kitty Gruvbox theme:
# 1 red, 2 green, 3 yellow, 4 blue, 5 purple, 6 aqua, 8 dim gray.
# Keep these faces on 0-15 palette indexes so terminal theme changes carry through.
bleopt complete_auto_complete=1
bleopt complete_auto_menu=
bleopt complete_auto_complete_opts-=auto-menu
bleopt complete_auto_complete_opts-=menu

ble-face syntax_default=none
ble-face syntax_command=fg=2
ble-face syntax_quoted=fg=2
ble-face syntax_quotation=fg=2,bold
ble-face syntax_escape=fg=5
ble-face syntax_expr=fg=6
ble-face syntax_error=fg=1,bold
ble-face syntax_varname=fg=5
ble-face syntax_delimiter=fg=6,bold
ble-face syntax_param_expansion=fg=5
ble-face syntax_history_expansion=fg=3,bold
ble-face syntax_function_name=fg=6,bold
ble-face syntax_comment=fg=8
ble-face syntax_glob=fg=3,bold
ble-face syntax_brace=fg=6,bold
ble-face syntax_tilde=fg=4,bold
ble-face syntax_document=fg=8
ble-face syntax_document_begin=fg=8,bold

ble-face command_builtin_dot=fg=1,bold
ble-face command_builtin=fg=2
ble-face command_alias=fg=6
ble-face command_function=fg=6
ble-face command_file=fg=2
ble-face command_keyword=fg=5
ble-face command_jobs=fg=3,bold
ble-face command_directory=fg=4,underline
ble-face command_suffix=fg=2
ble-face command_suffix_new=fg=3,bold

ble-face filename_directory=fg=4,underline
ble-face filename_directory_sticky=fg=3,underline
ble-face filename_link=fg=6,underline
ble-face filename_orphan=fg=1,underline
ble-face filename_setuid=fg=1,underline,bold
ble-face filename_setgid=fg=3,underline,bold
ble-face filename_executable=fg=2,underline
ble-face filename_other=underline
ble-face filename_socket=fg=5,underline
ble-face filename_pipe=fg=3,underline
ble-face filename_character=fg=3,underline
ble-face filename_block=fg=3,underline
ble-face filename_warning=fg=1,underline,bold
ble-face filename_url=fg=4,underline
ble-face filename_ls_colors=underline

ble-face argument_option=fg=6
ble-face argument_error=fg=1,bold
ble-face disabled=fg=8
ble-face overwrite_mode=fg=1,bold
ble-face region=reverse
ble-face region_target=fg=3,bold
ble-face region_match=fg=6,bold
ble-face region_insert=fg=2,bold

ble-face auto_complete=fg=8
ble-face menu_desc_default=fg=8
ble-face menu_desc_type=fg=6
ble-face menu_desc_quote=fg=2
ble-face menu_complete_match=fg=3,bold
ble-face menu_complete_selected=reverse
ble-face menu_filter_fixed=fg=3,bold
ble-face menu_filter_input=fg=6,bold
