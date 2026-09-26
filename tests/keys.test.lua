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
eq("comment line", "blank", parsed("# ~/a #111111"))
eq("bad color", "problem", parsed("~/a green"))
eq("~user", "problem", parsed("~bob/a #111111"))
eq("relative", "problem", parsed("code #111111"))

print("keys: bindings")
write("~/code/shop  #111111\n# note\n~/code/blog/  #222222\n~/x green\n")
load()
eq("nine project keys plus the panel key", 10, #binds)
eq("keys by keycode", "SUPER + ALT + code:10", binds[1].keys)
eq("named after the folder", "Project 1: shop", binds[1].description)
eq("trailing slash ignored", "Project 2: blog", binds[2].description)
eq("free slot says what it does", "Project 3 (not set, opens Colorful Terminals)", binds[3].description)
eq("key 9", "SUPER + ALT + code:18", binds[9].keys)
eq("panel on 0", "SUPER + ALT + code:19", binds[10].keys)
eq("helper opens by number", "'" .. repo .. "/bin/colorful-terminals' open 1", binds[1].dispatcher)
eq("nothing unbound by default", 0, #unbinds)

write("replace-group-keys = yes\n~/a  #111111\n")
load()
eq("replace unbinds the nine digit keys", 9, #unbinds)
eq("unbinds before binding", "SUPER + ALT + code:10", unbinds[1])

os.remove(os.getenv("HOME") .. "/.config/colorful-terminals/projects.conf")
load()
eq("no config still binds keys that open the panel", 10, #binds)

print(("  %d passed, %d failed"):format(passes, failures))
os.exit(failures == 0 and 0 or 1)
