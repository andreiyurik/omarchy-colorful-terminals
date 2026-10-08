-- Hyprland keys: run hypr/keys.lua against stub o.bind/hl.unbind.
-- Usage: HOME=<temp home> lua tests/keys.test.lua <repo>
local repo = arg[1]
local failures, passes = 0, 0
local function eq(name, expected, actual)
  if expected == actual then passes = passes + 1 else
    failures = failures + 1
    print(("  FAIL: %s\n        expected: %s\n        actual:   %s"):format(name, tostring(expected), tostring(actual)))
  end
end

local binds, unbinds
local function reset()
  binds, unbinds = {}, {}
  o = {
    shell_quote = function(s) return "'" .. s:gsub("'", "'\\''") .. "'" end,
    bind = function(keys, description, dispatcher) binds[#binds + 1] = { keys = keys, description = description, dispatcher = dispatcher } end,
  }
  hl = { unbind = function(keys) unbinds[#unbinds + 1] = keys end }
end
local function write(text)
  local dir = os.getenv("HOME") .. "/.config/colorful-terminals"
  os.execute("mkdir -p '" .. dir .. "'")
  local f = assert(io.open(dir .. "/projects.conf", "w"))
  f:write(text)
  f:close()
end
local function load()
  reset()
  return dofile(repo .. "/hypr/keys.lua")(repo)
end

print("keys: parsing matches the bash reader")
local M = load()
local function parsed(line) return table.concat({ M.parse_line(line) }, "|") end
eq("project", "project|~/code/shop|#1a3a5a", parsed("~/code/shop  #1A3A5A"))
eq("comment", "project|~/a|#111111", parsed("~/a #111111   # work"))
eq("comment at end", "project|~/a|#111111", parsed("~/a  #111111 #"))
eq("spaces in folder", "project|~/My Projects/web app|#222222", parsed("~/My Projects/web app  #222222"))
eq("setting", "setting|replace-group-keys|yes", parsed("replace-group-keys = yes"))
eq("setting with a digit", "setting|paint-3|#681e1e", parsed("paint-3 = #681e1e"))
eq("comment line", "blank", parsed("# ~/a #111111"))
eq("bad color", "problem", parsed("~/a green"))
eq("~user", "problem", parsed("~bob/a #111111"))
eq("relative", "problem", parsed("code #111111"))

print("keys: bindings")
write("~/code/shop  #111111\n# note\n~/code/blog/  #222222\n~/x green\n")
load()
eq("nine project keys, the panel key, nine color keys", 19, #binds)
eq("keys by keycode, clear of Omarchy's", "SUPER + CTRL + ALT + code:10", binds[1].keys)
eq("named after the folder", "Project 1: shop", binds[1].description)
eq("trailing slash ignored", "Project 2: blog", binds[2].description)
eq("free slot says what it does", "Project 3: not set (opens Colorful Terminals)", binds[3].description)
eq("key 9", "SUPER + CTRL + ALT + code:18", binds[9].keys)
eq("panel on 0", "SUPER + CTRL + ALT + code:19", binds[10].keys)
eq("helper opens by number", "'" .. repo .. "/bin/colorful-terminals' open 1", binds[1].dispatcher)
eq("nothing of Omarchy's is unbound", 0, #unbinds)
eq("color keys add Shift", "SUPER + CTRL + ALT + SHIFT + code:10", binds[11].keys)
eq("color key says what it is and names the color", "Terminal color 1: Blue", binds[11].description)
eq("color 8 is named too", "Terminal color 8: Black", binds[18].description)
eq("color key runs the helper", "'" .. repo .. "/bin/colorful-terminals' paint 1", binds[11].dispatcher)
eq("color 8", "SUPER + CTRL + ALT + SHIFT + code:17", binds[18].keys)
eq("0 takes the color away", "SUPER + CTRL + ALT + SHIFT + code:19", binds[19].keys)
eq("0 runs paint 0", "'" .. repo .. "/bin/colorful-terminals' paint 0", binds[19].dispatcher)
eq("0 is named", "Terminal color off", binds[19].description)

write("replace-group-keys = yes\n~/a  #111111\n")
load()
eq("an old replace-group-keys line changes nothing", 0, #unbinds)
eq("and still binds every key", 19, #binds)

print("keys: re-binding at runtime")
write("~/code/shop  #111111\n")
reset()
dofile(repo .. "/hypr/keys.lua")(repo, { rebind = true })
eq("re-binding unbinds every key of ours first", 19, #unbinds)
eq("starting with project 1", "SUPER + CTRL + ALT + code:10", unbinds[1])
eq("then binds them all again", 19, #binds)
local same = true
for i = 1, 19 do if unbinds[i] ~= binds[i].keys then same = false end end
eq("the same keys, nothing else", true, same)
eq("with fresh names", "Project 1: shop", binds[1].description)

print("keys: color names")
local function descriptions_with(text)
  write("~/a  #111111\n" .. text)
  load()
  return binds[13].description
end
eq("a changed color key shows its color", "Terminal color 3: #5a1a3a", descriptions_with("paint-3 = #5a1a3a\n"))
eq("a bad color line keeps the palette name", "Terminal color 3: Red", descriptions_with("paint-3 = red\n"))
local state = os.getenv("HOME") .. "/state"
os.execute("mkdir -p '" .. state .. "/omarchy/current/theme'")
local function with_theme(background, body)
  local f = assert(io.open(state .. "/omarchy/current/theme/colors.toml", "w"))
  f:write("[colors]\nbackground = \"" .. background .. "\"\nforeground = \"#000000\"\n")
  f:close()
  os.execute("rm -rf '" .. os.getenv("HOME") .. "/.local/state'")
  os.execute("mkdir -p '" .. os.getenv("HOME") .. "/.local' && ln -s '" .. state .. "' '" .. os.getenv("HOME") .. "/.local/state'")
  return body()
end
eq("a light theme names the light palette", "Terminal color 5: Peach",
  with_theme("#eff1f5", function() write("~/a  #111111\n"); load(); return binds[15].description end))
eq("a dark theme names the dark palette", "Terminal color 5: Orange",
  with_theme("#1a1b26", function() write("~/a  #111111\n"); load(); return binds[15].description end))
os.execute("rm -rf '" .. os.getenv("HOME") .. "/.local/state'")

-- The names must stay the ones the helper uses.
local function helper_array(name)
  local f = assert(io.open(repo .. "/bin/colorful-terminals", "r"))
  local text = f:read("a")
  f:close()
  local list = text:match("\n" .. name .. "=%(([^)]*)%)")
  local out = {}
  for word in list:gmatch("%S+") do out[#out + 1] = word end
  return table.concat(out, " ")
end
eq("dark names match the helper", helper_array("palette_names"), table.concat(M.palette, " "))
eq("light names match the helper", helper_array("light_names"), table.concat(M.palette_light, " "))

os.remove(os.getenv("HOME") .. "/.config/colorful-terminals/projects.conf")
load()
eq("no config still binds every key", 19, #binds)

print(("  %d passed, %d failed"):format(passes, failures))
os.exit(failures == 0 and 0 or 1)
