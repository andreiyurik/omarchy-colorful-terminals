-- Colorful Terminals keys, loaded by the marked block in ~/.config/hypr/hyprland.lua.
--
--   Super+Ctrl+Alt+1…9  open project N in a terminal, or jump to its open window
--   Super+Ctrl+Alt+0    open the Colorful Terminals settings panel
--   Super+Ctrl+Alt+Shift+1…8  give the focused terminal color 1…8
--   Super+Ctrl+Alt+Shift+0    take that color away again
--
-- Super+Ctrl+Alt because every other Super+digit combination is Omarchy's:
-- workspaces, moving windows, bar panels, and group tabs on Super+Alt.
--
-- All nine keys are always bound: the helper reads projects.conf when a key is
-- pressed, so hand edits work without a reload, and a key without a project
-- opens the panel. Keys are bound by keycode (code:10 is the 1 key), the same
-- way Omarchy binds its own digit keys, so they work on any keyboard layout.

local M = {}

local function trim(s)
  return (s:gsub("\r$", ""):match("^%s*(.-)%s*$"))
end

-- Same rules as lib/config.bash: "<folder> <#rrggbb>" with an optional
-- " # comment"; "key = value" is a setting. Returns kind, a, b.
function M.parse_line(line)
  line = trim(line)
  if line == "" or line:sub(1, 1) == "#" then return "blank" end

  local key, value = line:match("^([a-z][a-z0-9%-]*)%s*=%s*(.-)$")
  if key then return "setting", key, value end

  local first = line:sub(1, 1)
  if first ~= "~" and first ~= "/" then return "problem" end

  local comment_at = line:find("%s#%s") or line:find("%s#$")
  local body = comment_at and trim(line:sub(1, comment_at - 1)) or line
  local path, color = body:match("^(.-%S)%s+(#%x%x%x%x%x%x)$")
  if not path then return "problem" end
  if path ~= "~" and path:sub(1, 2) ~= "~/" and first ~= "/" then return "problem" end
  return "project", path, color:lower()
end

-- Projects in order, and the settings ("paint-3" = "#5a1a3a").
function M.read(conf)
  local projects, settings = {}, {}
  local file = io.open(conf, "r")
  if not file then return projects, settings end
  for line in file:lines() do
    local kind, a, b = M.parse_line(line)
    if kind == "project" then projects[#projects + 1] = { path = a, color = b } end
    if kind == "setting" then settings[a] = b:lower() end
  end
  file:close()
  return projects, settings
end

-- The palette on Super+Ctrl+Alt+Shift+1…8, the same as bin/colorful-terminals
-- (tests/keys.test.lua checks they agree): names for the keybindings list.
M.palette = { "Blue", "Green", "Red", "Violet", "Plum", "Brown", "Indigo", "Jade" }
M.palette_light = { "Blue", "Green", "Red", "Violet", "Pink", "Peach", "Lemon", "Mint" }

-- Omarchy's current theme is light when its background is: the same test as
-- the helper's theme_is_light.
function M.theme_is_light()
  local state = os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or "") .. "/.local/state")
  local file = io.open(state .. "/omarchy/current/theme/colors.toml", "r")
  if not file then return false end
  local hex
  for line in file:lines() do
    hex = line:match("^%s*background%s*=%s*\"?(#%x%x%x%x%x%x)")
    if hex then break end
  end
  file:close()
  if not hex then return false end
  local function channel(c)
    c = tonumber(c, 16) / 255
    if c <= 0.03928 then return c / 12.92 end
    return ((c + 0.055) / 1.055) ^ 2.4
  end
  local r, g, b = channel(hex:sub(2, 3)), channel(hex:sub(4, 5)), channel(hex:sub(6, 7))
  return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.35
end

-- "Blue" for a key on its palette color, or the color itself when it was changed.
function M.paint_name(n, settings, light)
  local own = settings["paint-" .. n]
  if own and own:match("^#%x%x%x%x%x%x$") then return own end
  return (light and M.palette_light or M.palette)[n]
end

local function folder_name(path)
  local name = path:gsub("/+$", ""):match("([^/]+)$")
  if not name or name == "~" then return path end
  return name
end

function M.setup(dir)
  local home = os.getenv("HOME") or ""
  local conf = home .. "/.config/colorful-terminals/projects.conf"
  local helper = o.shell_quote(dir .. "/bin/colorful-terminals")
  local projects, settings = M.read(conf)
  local light = M.theme_is_light()

  -- No commas in a description: Omarchy's keybindings list cuts it there.
  for n = 1, 9 do
    local keys = "SUPER + CTRL + ALT + code:" .. tostring(n + 9)
    local project = projects[n]
    local description = project and ("Project " .. n .. ": " .. folder_name(project.path))
      or ("Project " .. n .. ": not set (opens Colorful Terminals)")
    o.bind(keys, description, helper .. " open " .. n)
  end

  o.bind("SUPER + CTRL + ALT + code:19", "Colorful Terminals settings",
    "omarchy-shell shell toggle andreiyurik.colorful-terminals '{}'")

  -- The helper finds out whether a terminal is focused and hands it the color
  -- (see `colorful-terminals paint`); the colors are set in the panel.
  for n = 1, 8 do
    o.bind("SUPER + CTRL + ALT + SHIFT + code:" .. tostring(n + 9),
      "Terminal color " .. n .. ": " .. M.paint_name(n, settings, light), helper .. " paint " .. n)
  end
  o.bind("SUPER + CTRL + ALT + SHIFT + code:19", "Terminal color off", helper .. " paint 0")
end

return function(dir)
  M.setup(dir)
  return M
end
