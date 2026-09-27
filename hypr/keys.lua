-- Colorful Terminals keys, loaded by the marked block in ~/.config/hypr/hyprland.lua.
--
--   Super+Ctrl+Alt+1…9  open project N in a terminal, or jump to its open window
--   Super+Ctrl+Alt+0    open the Colorful Terminals settings panel
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

  local key, value = line:match("^([a-z][a-z%-]*)%s*=%s*(.-)$")
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

function M.read(conf)
  local projects = {}
  local file = io.open(conf, "r")
  if not file then return projects end
  for line in file:lines() do
    local kind, a, b = M.parse_line(line)
    if kind == "project" then projects[#projects + 1] = { path = a, color = b } end
  end
  file:close()
  return projects
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
  local projects = M.read(conf)

  for n = 1, 9 do
    local keys = "SUPER + CTRL + ALT + code:" .. tostring(n + 9)
    local project = projects[n]
    local description = project and ("Project " .. n .. ": " .. folder_name(project.path))
      or ("Project " .. n .. " (not set, opens Colorful Terminals)")
    o.bind(keys, description, helper .. " open " .. n)
  end

  o.bind("SUPER + CTRL + ALT + code:19", "Colorful Terminals settings",
    "omarchy-shell shell toggle andreiyurik.colorful-terminals '{}'")
end

return function(dir)
  M.setup(dir)
  return M
end
