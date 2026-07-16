-- Real config, symlinked into ~/.config/wezterm/wezterm.lua by home.nix via
-- mkOutOfStoreSymlink. Edit this file directly -- WezTerm watches it and
-- hot-reloads on save, no rebuild.sh needed.

local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- Matches the terminal font already declared for VS Code in home.nix, and
-- the Nerd Font glyphs oh-my-posh's gruvbox theme needs (see
-- nerd-fonts.fira-code in home.nix's home.packages).
config.font = wezterm.font("FiraCode Nerd Font Mono")
config.font_size = 11.0
config.harfbuzz_features = { "calt=1", "clig=1", "liga=1" } -- ligatures on

-- Matches the oh-my-posh "gruvbox" prompt theme (home.nix).
config.color_scheme = "Gruvbox Dark (Gogh)"

config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.window_background_opacity = 0.9
-- Wayland/KDE Plasma only -- no-op under X11, and flaky on some driver/
-- compositor combos (wezterm/wezterm#7201). Harmless either way.
config.kde_window_background_blur = true

config.window_padding = {
  left = 4,
  right = 4,
  top = 10,
  bottom = 10,
}
config.scrollback_lines = 10000

-- Windows Terminal muscle memory. WezTerm's own defaults already cover tab
-- switching (CTRL+TAB / CTRL+SHIFT+TAB), so only the gaps are bound here.
config.keys = {
  -- ALT+SHIFT+'-' / '=' mirror Windows Terminal's split shortcuts.
  { key = "-", mods = "ALT|SHIFT", action = act.SplitPane({ direction = "Down" }) },
  { key = "=", mods = "ALT|SHIFT", action = act.SplitPane({ direction = "Right" }) },
  { key = "t", mods = "CTRL|SHIFT", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "w", mods = "CTRL|SHIFT", action = act.CloseCurrentPane({ confirm = true }) },
}

--------------------------------------------------------------------------
-- Functions / event handlers below -- settings above are the part worth
-- reading first.
--------------------------------------------------------------------------

-- get_foreground_process_name() returns nil for remote/multiplexer panes
-- (e.g. mid-SSH session) -- string.match would throw on that nil, which
-- would break exactly the SSH case the caller below falls back for.
local function is_shell(foreground_process_name)
  if not foreground_process_name then
    return false
  end
  local shell_names = { 'bash', 'zsh', 'fish', 'sh', 'ksh', 'dash' }
  local process = string.match(foreground_process_name, '[^/\\]+$')
    or foreground_process_name
  for _, shell in ipairs(shell_names) do
    if process == shell then
      return true
    end
  end
  return false
end

wezterm.on('open-uri', function(window, pane, uri)
  local editor = 'code'

  if uri:find '^file:' == 1 and not pane:is_alt_screen_active() then
    -- We're processing an hyperlink and the uri format should be: file://[HOSTNAME]/PATH[#linenr]
    -- Also the pane is not in an alternate screen (an editor, less, etc)
    local url = wezterm.url.parse(uri)
    if is_shell(pane:get_foreground_process_name()) then
      -- A shell has been detected. Wezterm can check the file type directly
      -- figure out what kind of file we're dealing with
      local success, stdout, _ = wezterm.run_child_process {
        'file',
        '--brief',
        '--mime-type',
        url.file_path,
      }
      if success then
        if stdout:find 'directory' then
          pane:send_text(
            wezterm.shell_join_args { 'cd', url.file_path } .. '\r'
          )
          pane:send_text(wezterm.shell_join_args {
            'ls',
            '-a',
            '-p',
            '--group-directories-first',
          } .. '\r')
          return false
        end

        if stdout:find 'text' then
          if url.fragment then
            pane:send_text(wezterm.shell_join_args {
              editor,
              '+' .. url.fragment,
              url.file_path,
            } .. '\r')
          else
            pane:send_text(
              wezterm.shell_join_args { editor, url.file_path } .. '\r'
            )
          end
          return false
        end
      end
    else
      -- No shell detected, we're probably connected with SSH, use fallback command.
      -- file_path/fragment are shell-escaped here (unlike the branch above,
      -- wezterm can't build an argv list for a remote shell it doesn't
      -- control) -- an unescaped filename containing a `"` or `$(...)` would
      -- otherwise be arbitrary command injection the moment this hyperlink
      -- is clicked.
      local quoted_path = "'" .. url.file_path:gsub("'", "'\\''") .. "'"
      local edit_cmd = url.fragment
          and editor .. ' +' .. url.fragment:gsub("'", "") .. ' "$_f"'
        or editor .. ' "$_f"'
      local cmd = '_f=' .. quoted_path
        .. '; { test -d "$_f" && { cd "$_f" ; ls -a -p --hyperlink --group-directories-first; }; } '
        .. '|| { test "$(file --brief --mime-type "$_f" | cut -d/ -f1 || true)" = "text" && '
        .. edit_cmd
        .. '; }; echo'
      pane:send_text(cmd .. '\r')
      return false
    end
  end

  -- without a return value, we allow default actions
end)

return config
