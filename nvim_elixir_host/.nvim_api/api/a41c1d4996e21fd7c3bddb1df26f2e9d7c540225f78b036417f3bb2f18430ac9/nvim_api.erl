-module(nvim_api).
-export([api_hash/0, api_version/0, type_id/1, type_name/1, nvim_get_autocmds/2, nvim_create_autocmd/3, nvim_del_autocmd/2, nvim_clear_autocmds/2, nvim_create_augroup/3, nvim_del_augroup_by_id/2, nvim_del_augroup_by_name/2, nvim_exec_autocmds/3, nvim_buf_line_count/2, nvim_buf_attach/4, nvim_buf_detach/2, nvim_buf_get_lines/5, nvim_buf_set_lines/6, nvim_buf_set_text/7, nvim_buf_get_text/7, nvim_buf_get_offset/3, nvim_buf_get_var/3, nvim_buf_get_changedtick/2, nvim_buf_get_keymap/3, nvim_buf_set_keymap/6, nvim_buf_del_keymap/4, nvim_buf_set_var/4, nvim_buf_del_var/3, nvim_buf_get_name/2, nvim_buf_set_name/3, nvim_buf_is_loaded/2, nvim_buf_delete/3, nvim_buf_is_valid/2, nvim_buf_del_mark/3, nvim_buf_set_mark/6, nvim_buf_get_mark/3, nvim_buf_call/3, nvim_parse_cmd/3, nvim_cmd/3, nvim_create_user_command/4, nvim_del_user_command/2, nvim_buf_create_user_command/5, nvim_buf_del_user_command/3, nvim_get_commands/2, nvim_buf_get_commands/3, nvim_exec/3, nvim_command_output/2, nvim_execute_lua/3, nvim_buf_get_number/2, nvim_buf_clear_highlight/5, nvim_buf_add_highlight/7, nvim_buf_set_virtual_text/6, nvim_get_hl_by_id/3, nvim_get_hl_by_name/3, buffer_insert/4, buffer_get_line/3, buffer_set_line/4, buffer_del_line/3, buffer_get_line_slice/6, buffer_set_line_slice/7, buffer_set_var/4, buffer_del_var/3, window_set_var/4, window_del_var/3, tabpage_set_var/4, tabpage_del_var/3, vim_set_var/3, vim_del_var/2, nvim_get_option_info/2, nvim_set_option/3, nvim_get_option/2, nvim_buf_get_option/3, nvim_buf_set_option/4, nvim_win_get_option/3, nvim_win_set_option/4, nvim_call_atomic/2, nvim_subscribe/2, nvim_unsubscribe/2, nvim_out_write/2, nvim_err_write/2, nvim_err_writeln/2, nvim_notify/4, nvim_ui_term_event/3, nvim_create_namespace/2, nvim_get_namespaces/1, nvim_buf_get_extmark_by_id/5, nvim_buf_get_extmarks/6, nvim_buf_set_extmark/6, nvim_buf_del_extmark/4, nvim_buf_clear_namespace/5, nvim_set_decoration_provider/3, nvim_get_option_value/3, nvim_set_option_value/4, nvim_get_all_options_info/1, nvim_get_option_info2/3, nvim_tabpage_list_wins/2, nvim_tabpage_get_var/3, nvim_tabpage_set_var/4, nvim_tabpage_del_var/3, nvim_tabpage_get_win/2, nvim_tabpage_set_win/3, nvim_tabpage_get_number/2, nvim_tabpage_is_valid/2, nvim_open_tabpage/4, nvim_ui_attach/4, ui_attach/4, nvim_ui_set_focus/2, nvim_ui_detach/1, nvim_ui_try_resize/3, nvim_ui_set_option/3, nvim_ui_try_resize_grid/4, nvim_ui_pum_set_height/2, nvim_ui_pum_set_bounds/5, nvim_ui_send/2, nvim_get_hl_id_by_name/2, nvim_get_hl/3, nvim_set_hl/4, nvim_get_hl_ns/2, nvim_set_hl_ns/2, nvim_set_hl_ns_fast/2, nvim_feedkeys/4, nvim_input/2, nvim_input_mouse/7, nvim_replace_termcodes/5, nvim_exec_lua/3, nvim_strwidth/2, nvim_list_runtime_paths/1, nvim_get_runtime_file/3, nvim_set_current_dir/2, nvim_get_current_line/1, nvim_set_current_line/2, nvim_del_current_line/1, nvim_get_var/2, nvim_set_var/3, nvim_del_var/2, nvim_get_vvar/2, nvim_set_vvar/3, nvim_echo/4, nvim_list_bufs/1, nvim_get_current_buf/1, nvim_set_current_buf/2, nvim_list_wins/1, nvim_get_current_win/1, nvim_set_current_win/2, nvim_create_buf/3, nvim_open_term/3, nvim_chan_send/3, nvim_list_tabpages/1, nvim_get_current_tabpage/1, nvim_set_current_tabpage/2, nvim_paste/4, nvim_put/5, nvim_get_color_by_name/2, nvim_get_color_map/1, nvim_get_context/2, nvim_load_context/2, nvim_get_mode/1, nvim_get_keymap/2, nvim_set_keymap/5, nvim_del_keymap/3, nvim_get_api_info/1, nvim_set_client_info/6, nvim_get_chan_info/2, nvim_list_chans/1, nvim_list_uis/1, nvim_get_proc_children/2, nvim_get_proc/2, nvim_select_popupmenu_item/5, nvim_del_mark/2, nvim_get_mark/3, nvim_eval_statusline/3, nvim_exec2/3, nvim_command/2, nvim_eval/2, nvim_call_function/3, nvim_call_dict_function/4, nvim_parse_expression/4, nvim_open_win/4, nvim_win_set_config/3, nvim_win_get_config/2, nvim_win_get_buf/2, nvim_win_set_buf/3, nvim_win_get_cursor/2, nvim_win_set_cursor/3, nvim_win_get_height/2, nvim_win_set_height/3, nvim_win_get_width/2, nvim_win_set_width/3, nvim_win_get_var/3, nvim_win_set_var/4, nvim_win_del_var/3, nvim_win_get_position/2, nvim_win_get_tabpage/2, nvim_win_get_number/2, nvim_win_is_valid/2, nvim_win_hide/2, nvim_win_close/3, nvim_win_call/3, nvim_win_set_hl_ns/3, nvim_win_text_height/3, buffer_line_count/2, buffer_get_lines/5, buffer_set_lines/6, buffer_get_var/3, buffer_get_name/2, buffer_set_name/3, buffer_is_valid/2, buffer_get_mark/3, vim_command_output/2, buffer_get_number/2, buffer_clear_highlight/5, buffer_add_highlight/7, vim_set_option/3, vim_get_option/2, buffer_get_option/3, buffer_set_option/4, window_get_option/3, window_set_option/4, vim_subscribe/2, vim_unsubscribe/2, vim_out_write/2, vim_err_write/2, vim_report_error/2, tabpage_get_windows/2, tabpage_get_var/3, tabpage_get_window/2, tabpage_is_valid/2, ui_detach/1, ui_try_resize/3, vim_feedkeys/4, vim_input/2, vim_replace_termcodes/5, vim_strwidth/2, vim_list_runtime_paths/1, vim_change_directory/2, vim_get_current_line/1, vim_set_current_line/2, vim_del_current_line/1, vim_get_var/2, vim_get_vvar/2, vim_get_buffers/1, vim_get_current_buffer/1, vim_set_current_buffer/2, vim_get_windows/1, vim_get_current_window/1, vim_set_current_window/2, vim_get_tabpages/1, vim_get_current_tabpage/1, vim_set_current_tabpage/2, vim_name_to_color/2, vim_get_color_map/1, vim_get_api_info/1, vim_command/2, vim_eval/2, vim_call_function/3, window_get_buffer/2, window_get_cursor/2, window_set_cursor/3, window_get_height/2, window_set_height/3, window_get_width/2, window_set_width/3, window_get_var/3, window_get_position/2, window_get_tabpage/2, window_is_valid/2]).
api_hash() -> <<"a41c1d4996e21fd7c3bddb1df26f2e9d7c540225f78b036417f3bb2f18430ac9">>.
api_version() -> {0, 12, 6}.
type_id(<<"Buffer">>) -> {ok, 0};
type_id(<<"Tabpage">>) -> {ok, 2};
type_id(<<"Window">>) -> {ok, 1};
type_id(_) -> error.
type_name(0) -> {ok, <<"Buffer">>};
type_name(2) -> {ok, <<"Tabpage">>};
type_name(1) -> {ok, <<"Window">>};
type_name(_) -> error.
nvim_get_autocmds(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_autocmds">>}, [Arg1]}).
nvim_create_autocmd(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_create_autocmd">>}, [Arg1, Arg2]}).
nvim_del_autocmd(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_del_autocmd">>}, [Arg1]}).
nvim_clear_autocmds(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_clear_autocmds">>}, [Arg1]}).
nvim_create_augroup(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_create_augroup">>}, [Arg1, Arg2]}).
nvim_del_augroup_by_id(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_del_augroup_by_id">>}, [Arg1]}).
nvim_del_augroup_by_name(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_del_augroup_by_name">>}, [Arg1]}).
nvim_exec_autocmds(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_exec_autocmds">>}, [Arg1, Arg2]}).
nvim_buf_line_count(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_line_count">>}, [Arg1]}).
nvim_buf_attach(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_attach">>}, [Arg1, Arg2, Arg3]}).
nvim_buf_detach(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_detach">>}, [Arg1]}).
nvim_buf_get_lines(RequestId, Arg1, Arg2, Arg3, Arg4) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_get_lines">>}, [Arg1, Arg2, Arg3, Arg4]}).
nvim_buf_set_lines(RequestId, Arg1, Arg2, Arg3, Arg4, Arg5) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_set_lines">>}, [Arg1, Arg2, Arg3, Arg4, Arg5]}).
nvim_buf_set_text(RequestId, Arg1, Arg2, Arg3, Arg4, Arg5, Arg6) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_set_text">>}, [Arg1, Arg2, Arg3, Arg4, Arg5, Arg6]}).
nvim_buf_get_text(RequestId, Arg1, Arg2, Arg3, Arg4, Arg5, Arg6) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_get_text">>}, [Arg1, Arg2, Arg3, Arg4, Arg5, Arg6]}).
nvim_buf_get_offset(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_get_offset">>}, [Arg1, Arg2]}).
nvim_buf_get_var(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_get_var">>}, [Arg1, Arg2]}).
nvim_buf_get_changedtick(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_get_changedtick">>}, [Arg1]}).
nvim_buf_get_keymap(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_get_keymap">>}, [Arg1, Arg2]}).
nvim_buf_set_keymap(RequestId, Arg1, Arg2, Arg3, Arg4, Arg5) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_set_keymap">>}, [Arg1, Arg2, Arg3, Arg4, Arg5]}).
nvim_buf_del_keymap(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_del_keymap">>}, [Arg1, Arg2, Arg3]}).
nvim_buf_set_var(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_set_var">>}, [Arg1, Arg2, Arg3]}).
nvim_buf_del_var(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_del_var">>}, [Arg1, Arg2]}).
nvim_buf_get_name(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_get_name">>}, [Arg1]}).
nvim_buf_set_name(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_set_name">>}, [Arg1, Arg2]}).
nvim_buf_is_loaded(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_is_loaded">>}, [Arg1]}).
nvim_buf_delete(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_delete">>}, [Arg1, Arg2]}).
nvim_buf_is_valid(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_is_valid">>}, [Arg1]}).
nvim_buf_del_mark(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_del_mark">>}, [Arg1, Arg2]}).
nvim_buf_set_mark(RequestId, Arg1, Arg2, Arg3, Arg4, Arg5) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_set_mark">>}, [Arg1, Arg2, Arg3, Arg4, Arg5]}).
nvim_buf_get_mark(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_get_mark">>}, [Arg1, Arg2]}).
nvim_buf_call(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_call">>}, [Arg1, Arg2]}).
nvim_parse_cmd(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_parse_cmd">>}, [Arg1, Arg2]}).
nvim_cmd(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_cmd">>}, [Arg1, Arg2]}).
nvim_create_user_command(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_create_user_command">>}, [Arg1, Arg2, Arg3]}).
nvim_del_user_command(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_del_user_command">>}, [Arg1]}).
nvim_buf_create_user_command(RequestId, Arg1, Arg2, Arg3, Arg4) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_create_user_command">>}, [Arg1, Arg2, Arg3, Arg4]}).
nvim_buf_del_user_command(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_del_user_command">>}, [Arg1, Arg2]}).
nvim_get_commands(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_commands">>}, [Arg1]}).
nvim_buf_get_commands(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_get_commands">>}, [Arg1, Arg2]}).
nvim_exec(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_exec">>}, [Arg1, Arg2]}).
nvim_command_output(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_command_output">>}, [Arg1]}).
nvim_execute_lua(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_execute_lua">>}, [Arg1, Arg2]}).
nvim_buf_get_number(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_get_number">>}, [Arg1]}).
nvim_buf_clear_highlight(RequestId, Arg1, Arg2, Arg3, Arg4) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_clear_highlight">>}, [Arg1, Arg2, Arg3, Arg4]}).
nvim_buf_add_highlight(RequestId, Arg1, Arg2, Arg3, Arg4, Arg5, Arg6) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_add_highlight">>}, [Arg1, Arg2, Arg3, Arg4, Arg5, Arg6]}).
nvim_buf_set_virtual_text(RequestId, Arg1, Arg2, Arg3, Arg4, Arg5) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_set_virtual_text">>}, [Arg1, Arg2, Arg3, Arg4, Arg5]}).
nvim_get_hl_by_id(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_hl_by_id">>}, [Arg1, Arg2]}).
nvim_get_hl_by_name(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_hl_by_name">>}, [Arg1, Arg2]}).
buffer_insert(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_insert">>}, [Arg1, Arg2, Arg3]}).
buffer_get_line(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_get_line">>}, [Arg1, Arg2]}).
buffer_set_line(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_set_line">>}, [Arg1, Arg2, Arg3]}).
buffer_del_line(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_del_line">>}, [Arg1, Arg2]}).
buffer_get_line_slice(RequestId, Arg1, Arg2, Arg3, Arg4, Arg5) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_get_line_slice">>}, [Arg1, Arg2, Arg3, Arg4, Arg5]}).
buffer_set_line_slice(RequestId, Arg1, Arg2, Arg3, Arg4, Arg5, Arg6) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_set_line_slice">>}, [Arg1, Arg2, Arg3, Arg4, Arg5, Arg6]}).
buffer_set_var(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_set_var">>}, [Arg1, Arg2, Arg3]}).
buffer_del_var(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_del_var">>}, [Arg1, Arg2]}).
window_set_var(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"window_set_var">>}, [Arg1, Arg2, Arg3]}).
window_del_var(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"window_del_var">>}, [Arg1, Arg2]}).
tabpage_set_var(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"tabpage_set_var">>}, [Arg1, Arg2, Arg3]}).
tabpage_del_var(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"tabpage_del_var">>}, [Arg1, Arg2]}).
vim_set_var(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_set_var">>}, [Arg1, Arg2]}).
vim_del_var(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_del_var">>}, [Arg1]}).
nvim_get_option_info(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_option_info">>}, [Arg1]}).
nvim_set_option(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_set_option">>}, [Arg1, Arg2]}).
nvim_get_option(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_option">>}, [Arg1]}).
nvim_buf_get_option(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_get_option">>}, [Arg1, Arg2]}).
nvim_buf_set_option(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_set_option">>}, [Arg1, Arg2, Arg3]}).
nvim_win_get_option(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_get_option">>}, [Arg1, Arg2]}).
nvim_win_set_option(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_set_option">>}, [Arg1, Arg2, Arg3]}).
nvim_call_atomic(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_call_atomic">>}, [Arg1]}).
nvim_subscribe(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_subscribe">>}, [Arg1]}).
nvim_unsubscribe(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_unsubscribe">>}, [Arg1]}).
nvim_out_write(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_out_write">>}, [Arg1]}).
nvim_err_write(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_err_write">>}, [Arg1]}).
nvim_err_writeln(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_err_writeln">>}, [Arg1]}).
nvim_notify(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_notify">>}, [Arg1, Arg2, Arg3]}).
nvim_ui_term_event(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_ui_term_event">>}, [Arg1, Arg2]}).
nvim_create_namespace(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_create_namespace">>}, [Arg1]}).
nvim_get_namespaces(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_namespaces">>}, []}).
nvim_buf_get_extmark_by_id(RequestId, Arg1, Arg2, Arg3, Arg4) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_get_extmark_by_id">>}, [Arg1, Arg2, Arg3, Arg4]}).
nvim_buf_get_extmarks(RequestId, Arg1, Arg2, Arg3, Arg4, Arg5) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_get_extmarks">>}, [Arg1, Arg2, Arg3, Arg4, Arg5]}).
nvim_buf_set_extmark(RequestId, Arg1, Arg2, Arg3, Arg4, Arg5) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_set_extmark">>}, [Arg1, Arg2, Arg3, Arg4, Arg5]}).
nvim_buf_del_extmark(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_del_extmark">>}, [Arg1, Arg2, Arg3]}).
nvim_buf_clear_namespace(RequestId, Arg1, Arg2, Arg3, Arg4) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_buf_clear_namespace">>}, [Arg1, Arg2, Arg3, Arg4]}).
nvim_set_decoration_provider(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_set_decoration_provider">>}, [Arg1, Arg2]}).
nvim_get_option_value(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_option_value">>}, [Arg1, Arg2]}).
nvim_set_option_value(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_set_option_value">>}, [Arg1, Arg2, Arg3]}).
nvim_get_all_options_info(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_all_options_info">>}, []}).
nvim_get_option_info2(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_option_info2">>}, [Arg1, Arg2]}).
nvim_tabpage_list_wins(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_tabpage_list_wins">>}, [Arg1]}).
nvim_tabpage_get_var(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_tabpage_get_var">>}, [Arg1, Arg2]}).
nvim_tabpage_set_var(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_tabpage_set_var">>}, [Arg1, Arg2, Arg3]}).
nvim_tabpage_del_var(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_tabpage_del_var">>}, [Arg1, Arg2]}).
nvim_tabpage_get_win(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_tabpage_get_win">>}, [Arg1]}).
nvim_tabpage_set_win(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_tabpage_set_win">>}, [Arg1, Arg2]}).
nvim_tabpage_get_number(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_tabpage_get_number">>}, [Arg1]}).
nvim_tabpage_is_valid(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_tabpage_is_valid">>}, [Arg1]}).
nvim_open_tabpage(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_open_tabpage">>}, [Arg1, Arg2, Arg3]}).
nvim_ui_attach(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_ui_attach">>}, [Arg1, Arg2, Arg3]}).
ui_attach(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"ui_attach">>}, [Arg1, Arg2, Arg3]}).
nvim_ui_set_focus(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_ui_set_focus">>}, [Arg1]}).
nvim_ui_detach(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_ui_detach">>}, []}).
nvim_ui_try_resize(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_ui_try_resize">>}, [Arg1, Arg2]}).
nvim_ui_set_option(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_ui_set_option">>}, [Arg1, Arg2]}).
nvim_ui_try_resize_grid(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_ui_try_resize_grid">>}, [Arg1, Arg2, Arg3]}).
nvim_ui_pum_set_height(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_ui_pum_set_height">>}, [Arg1]}).
nvim_ui_pum_set_bounds(RequestId, Arg1, Arg2, Arg3, Arg4) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_ui_pum_set_bounds">>}, [Arg1, Arg2, Arg3, Arg4]}).
nvim_ui_send(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_ui_send">>}, [Arg1]}).
nvim_get_hl_id_by_name(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_hl_id_by_name">>}, [Arg1]}).
nvim_get_hl(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_hl">>}, [Arg1, Arg2]}).
nvim_set_hl(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_set_hl">>}, [Arg1, Arg2, Arg3]}).
nvim_get_hl_ns(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_hl_ns">>}, [Arg1]}).
nvim_set_hl_ns(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_set_hl_ns">>}, [Arg1]}).
nvim_set_hl_ns_fast(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_set_hl_ns_fast">>}, [Arg1]}).
nvim_feedkeys(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_feedkeys">>}, [Arg1, Arg2, Arg3]}).
nvim_input(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_input">>}, [Arg1]}).
nvim_input_mouse(RequestId, Arg1, Arg2, Arg3, Arg4, Arg5, Arg6) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_input_mouse">>}, [Arg1, Arg2, Arg3, Arg4, Arg5, Arg6]}).
nvim_replace_termcodes(RequestId, Arg1, Arg2, Arg3, Arg4) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_replace_termcodes">>}, [Arg1, Arg2, Arg3, Arg4]}).
nvim_exec_lua(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_exec_lua">>}, [Arg1, Arg2]}).
nvim_strwidth(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_strwidth">>}, [Arg1]}).
nvim_list_runtime_paths(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_list_runtime_paths">>}, []}).
nvim_get_runtime_file(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_runtime_file">>}, [Arg1, Arg2]}).
nvim_set_current_dir(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_set_current_dir">>}, [Arg1]}).
nvim_get_current_line(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_current_line">>}, []}).
nvim_set_current_line(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_set_current_line">>}, [Arg1]}).
nvim_del_current_line(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_del_current_line">>}, []}).
nvim_get_var(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_var">>}, [Arg1]}).
nvim_set_var(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_set_var">>}, [Arg1, Arg2]}).
nvim_del_var(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_del_var">>}, [Arg1]}).
nvim_get_vvar(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_vvar">>}, [Arg1]}).
nvim_set_vvar(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_set_vvar">>}, [Arg1, Arg2]}).
nvim_echo(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_echo">>}, [Arg1, Arg2, Arg3]}).
nvim_list_bufs(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_list_bufs">>}, []}).
nvim_get_current_buf(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_current_buf">>}, []}).
nvim_set_current_buf(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_set_current_buf">>}, [Arg1]}).
nvim_list_wins(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_list_wins">>}, []}).
nvim_get_current_win(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_current_win">>}, []}).
nvim_set_current_win(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_set_current_win">>}, [Arg1]}).
nvim_create_buf(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_create_buf">>}, [Arg1, Arg2]}).
nvim_open_term(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_open_term">>}, [Arg1, Arg2]}).
nvim_chan_send(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_chan_send">>}, [Arg1, Arg2]}).
nvim_list_tabpages(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_list_tabpages">>}, []}).
nvim_get_current_tabpage(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_current_tabpage">>}, []}).
nvim_set_current_tabpage(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_set_current_tabpage">>}, [Arg1]}).
nvim_paste(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_paste">>}, [Arg1, Arg2, Arg3]}).
nvim_put(RequestId, Arg1, Arg2, Arg3, Arg4) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_put">>}, [Arg1, Arg2, Arg3, Arg4]}).
nvim_get_color_by_name(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_color_by_name">>}, [Arg1]}).
nvim_get_color_map(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_color_map">>}, []}).
nvim_get_context(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_context">>}, [Arg1]}).
nvim_load_context(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_load_context">>}, [Arg1]}).
nvim_get_mode(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_mode">>}, []}).
nvim_get_keymap(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_keymap">>}, [Arg1]}).
nvim_set_keymap(RequestId, Arg1, Arg2, Arg3, Arg4) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_set_keymap">>}, [Arg1, Arg2, Arg3, Arg4]}).
nvim_del_keymap(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_del_keymap">>}, [Arg1, Arg2]}).
nvim_get_api_info(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_api_info">>}, []}).
nvim_set_client_info(RequestId, Arg1, Arg2, Arg3, Arg4, Arg5) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_set_client_info">>}, [Arg1, Arg2, Arg3, Arg4, Arg5]}).
nvim_get_chan_info(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_chan_info">>}, [Arg1]}).
nvim_list_chans(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_list_chans">>}, []}).
nvim_list_uis(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_list_uis">>}, []}).
nvim_get_proc_children(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_proc_children">>}, [Arg1]}).
nvim_get_proc(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_proc">>}, [Arg1]}).
nvim_select_popupmenu_item(RequestId, Arg1, Arg2, Arg3, Arg4) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_select_popupmenu_item">>}, [Arg1, Arg2, Arg3, Arg4]}).
nvim_del_mark(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_del_mark">>}, [Arg1]}).
nvim_get_mark(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_get_mark">>}, [Arg1, Arg2]}).
nvim_eval_statusline(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_eval_statusline">>}, [Arg1, Arg2]}).
nvim_exec2(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_exec2">>}, [Arg1, Arg2]}).
nvim_command(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_command">>}, [Arg1]}).
nvim_eval(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_eval">>}, [Arg1]}).
nvim_call_function(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_call_function">>}, [Arg1, Arg2]}).
nvim_call_dict_function(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_call_dict_function">>}, [Arg1, Arg2, Arg3]}).
nvim_parse_expression(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_parse_expression">>}, [Arg1, Arg2, Arg3]}).
nvim_open_win(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_open_win">>}, [Arg1, Arg2, Arg3]}).
nvim_win_set_config(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_set_config">>}, [Arg1, Arg2]}).
nvim_win_get_config(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_get_config">>}, [Arg1]}).
nvim_win_get_buf(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_get_buf">>}, [Arg1]}).
nvim_win_set_buf(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_set_buf">>}, [Arg1, Arg2]}).
nvim_win_get_cursor(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_get_cursor">>}, [Arg1]}).
nvim_win_set_cursor(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_set_cursor">>}, [Arg1, Arg2]}).
nvim_win_get_height(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_get_height">>}, [Arg1]}).
nvim_win_set_height(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_set_height">>}, [Arg1, Arg2]}).
nvim_win_get_width(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_get_width">>}, [Arg1]}).
nvim_win_set_width(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_set_width">>}, [Arg1, Arg2]}).
nvim_win_get_var(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_get_var">>}, [Arg1, Arg2]}).
nvim_win_set_var(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_set_var">>}, [Arg1, Arg2, Arg3]}).
nvim_win_del_var(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_del_var">>}, [Arg1, Arg2]}).
nvim_win_get_position(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_get_position">>}, [Arg1]}).
nvim_win_get_tabpage(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_get_tabpage">>}, [Arg1]}).
nvim_win_get_number(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_get_number">>}, [Arg1]}).
nvim_win_is_valid(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_is_valid">>}, [Arg1]}).
nvim_win_hide(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_hide">>}, [Arg1]}).
nvim_win_close(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_close">>}, [Arg1, Arg2]}).
nvim_win_call(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_call">>}, [Arg1, Arg2]}).
nvim_win_set_hl_ns(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_set_hl_ns">>}, [Arg1, Arg2]}).
nvim_win_text_height(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"nvim_win_text_height">>}, [Arg1, Arg2]}).
buffer_line_count(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_line_count">>}, [Arg1]}).
buffer_get_lines(RequestId, Arg1, Arg2, Arg3, Arg4) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_get_lines">>}, [Arg1, Arg2, Arg3, Arg4]}).
buffer_set_lines(RequestId, Arg1, Arg2, Arg3, Arg4, Arg5) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_set_lines">>}, [Arg1, Arg2, Arg3, Arg4, Arg5]}).
buffer_get_var(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_get_var">>}, [Arg1, Arg2]}).
buffer_get_name(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_get_name">>}, [Arg1]}).
buffer_set_name(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_set_name">>}, [Arg1, Arg2]}).
buffer_is_valid(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_is_valid">>}, [Arg1]}).
buffer_get_mark(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_get_mark">>}, [Arg1, Arg2]}).
vim_command_output(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_command_output">>}, [Arg1]}).
buffer_get_number(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_get_number">>}, [Arg1]}).
buffer_clear_highlight(RequestId, Arg1, Arg2, Arg3, Arg4) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_clear_highlight">>}, [Arg1, Arg2, Arg3, Arg4]}).
buffer_add_highlight(RequestId, Arg1, Arg2, Arg3, Arg4, Arg5, Arg6) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_add_highlight">>}, [Arg1, Arg2, Arg3, Arg4, Arg5, Arg6]}).
vim_set_option(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_set_option">>}, [Arg1, Arg2]}).
vim_get_option(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_get_option">>}, [Arg1]}).
buffer_get_option(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_get_option">>}, [Arg1, Arg2]}).
buffer_set_option(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"buffer_set_option">>}, [Arg1, Arg2, Arg3]}).
window_get_option(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"window_get_option">>}, [Arg1, Arg2]}).
window_set_option(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"window_set_option">>}, [Arg1, Arg2, Arg3]}).
vim_subscribe(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_subscribe">>}, [Arg1]}).
vim_unsubscribe(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_unsubscribe">>}, [Arg1]}).
vim_out_write(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_out_write">>}, [Arg1]}).
vim_err_write(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_err_write">>}, [Arg1]}).
vim_report_error(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_report_error">>}, [Arg1]}).
tabpage_get_windows(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"tabpage_get_windows">>}, [Arg1]}).
tabpage_get_var(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"tabpage_get_var">>}, [Arg1, Arg2]}).
tabpage_get_window(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"tabpage_get_window">>}, [Arg1]}).
tabpage_is_valid(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"tabpage_is_valid">>}, [Arg1]}).
ui_detach(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"ui_detach">>}, []}).
ui_try_resize(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"ui_try_resize">>}, [Arg1, Arg2]}).
vim_feedkeys(RequestId, Arg1, Arg2, Arg3) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_feedkeys">>}, [Arg1, Arg2, Arg3]}).
vim_input(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_input">>}, [Arg1]}).
vim_replace_termcodes(RequestId, Arg1, Arg2, Arg3, Arg4) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_replace_termcodes">>}, [Arg1, Arg2, Arg3, Arg4]}).
vim_strwidth(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_strwidth">>}, [Arg1]}).
vim_list_runtime_paths(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_list_runtime_paths">>}, []}).
vim_change_directory(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_change_directory">>}, [Arg1]}).
vim_get_current_line(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_get_current_line">>}, []}).
vim_set_current_line(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_set_current_line">>}, [Arg1]}).
vim_del_current_line(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_del_current_line">>}, []}).
vim_get_var(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_get_var">>}, [Arg1]}).
vim_get_vvar(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_get_vvar">>}, [Arg1]}).
vim_get_buffers(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_get_buffers">>}, []}).
vim_get_current_buffer(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_get_current_buffer">>}, []}).
vim_set_current_buffer(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_set_current_buffer">>}, [Arg1]}).
vim_get_windows(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_get_windows">>}, []}).
vim_get_current_window(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_get_current_window">>}, []}).
vim_set_current_window(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_set_current_window">>}, [Arg1]}).
vim_get_tabpages(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_get_tabpages">>}, []}).
vim_get_current_tabpage(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_get_current_tabpage">>}, []}).
vim_set_current_tabpage(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_set_current_tabpage">>}, [Arg1]}).
vim_name_to_color(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_name_to_color">>}, [Arg1]}).
vim_get_color_map(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_get_color_map">>}, []}).
vim_get_api_info(RequestId) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_get_api_info">>}, []}).
vim_command(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_command">>}, [Arg1]}).
vim_eval(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_eval">>}, [Arg1]}).
vim_call_function(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"vim_call_function">>}, [Arg1, Arg2]}).
window_get_buffer(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"window_get_buffer">>}, [Arg1]}).
window_get_cursor(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"window_get_cursor">>}, [Arg1]}).
window_set_cursor(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"window_set_cursor">>}, [Arg1, Arg2]}).
window_get_height(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"window_get_height">>}, [Arg1]}).
window_set_height(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"window_set_height">>}, [Arg1, Arg2]}).
window_get_width(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"window_get_width">>}, [Arg1]}).
window_set_width(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"window_set_width">>}, [Arg1, Arg2]}).
window_get_var(RequestId, Arg1, Arg2) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"window_get_var">>}, [Arg1, Arg2]}).
window_get_position(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"window_get_position">>}, [Arg1]}).
window_get_tabpage(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"window_get_tabpage">>}, [Arg1]}).
window_is_valid(RequestId, Arg1) -> nvim_rpc:encode_rpc({request, RequestId, {string, <<"window_is_valid">>}, [Arg1]}).
