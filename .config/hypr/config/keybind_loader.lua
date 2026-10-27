--##############################################
--## KEYBIND LOADER — reads keybinds.json and
--## registers everything with hl.bind()
--##
--## This is the "single source of truth": any shortcut
--## change (including from the Quickshell UI) only needs
--## to be written to keybinds.json — this file rebuilds
--## every bind whenever Hyprland/hl reloads its config.
--##############################################

---@module 'hl'

local M = {}

-- Path to the JSON file shared between Lua and QML
local JSON_PATH = os.getenv("HOME") .. "/.config/quickshell/cartoon-shell/data/keybinds.json"

--------------------------------------------------------------------
-- Minimal, self-contained JSON decoder (no external dependency).
-- Enough for the keybinds.json structure (object/array/string/number/
-- boolean/null) — not meant to be a fully spec-compliant parser.
--------------------------------------------------------------------
local function jsonDecode(str)
	local pos = 1

	local function skipWhitespace()
		local _, e = str:find("^%s*", pos)
		if e then pos = e + 1 end
	end

	local parseValue

	local function parseString()
		pos = pos + 1 -- skip opening "
		local startPos = pos
		local out = {}
		while true do
			local c = str:sub(pos, pos)
			if c == "" then error("JSON error: unterminated string at position " .. pos) end
			if c == '"' then
				table.insert(out, str:sub(startPos, pos - 1))
				pos = pos + 1
				break
			elseif c == "\\" then
				table.insert(out, str:sub(startPos, pos - 1))
				local nextC = str:sub(pos + 1, pos + 1)
				local map = { n = "\n", t = "\t", r = "\r", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
				table.insert(out, map[nextC] or nextC)
				pos = pos + 2
				startPos = pos
			else
				pos = pos + 1
			end
		end
		return table.concat(out)
	end

	local function parseNumber()
		local s, e = str:find("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
		local numStr = str:sub(s, e)
		pos = e + 1
		return tonumber(numStr)
	end

	local function parseArray()
		pos = pos + 1
		local arr = {}
		skipWhitespace()
		if str:sub(pos, pos) == "]" then
			pos = pos + 1
			return arr
		end
		while true do
			skipWhitespace()
			table.insert(arr, parseValue())
			skipWhitespace()
			local c = str:sub(pos, pos)
			if c == "," then
				pos = pos + 1
			elseif c == "]" then
				pos = pos + 1
				break
			else
				error("JSON error: expected ',' or ']' at position " .. pos)
			end
		end
		return arr
	end

	local function parseObject()
		pos = pos + 1
		local obj = {}
		skipWhitespace()
		if str:sub(pos, pos) == "}" then
			pos = pos + 1
			return obj
		end
		while true do
			skipWhitespace()
			local key = parseString()
			skipWhitespace()
			pos = pos + 1 -- skip ':'
			skipWhitespace()
			obj[key] = parseValue()
			skipWhitespace()
			local c = str:sub(pos, pos)
			if c == "," then
				pos = pos + 1
			elseif c == "}" then
				pos = pos + 1
				break
			else
				error("JSON error: expected ',' or '}' at position " .. pos)
			end
		end
		return obj
	end

	parseValue = function()
		skipWhitespace()
		local c = str:sub(pos, pos)
		if c == '"' then
			return parseString()
		elseif c == "{" then
			return parseObject()
		elseif c == "[" then
			return parseArray()
		elseif c == "t" then
			pos = pos + 4
			return true
		elseif c == "f" then
			pos = pos + 5
			return false
		elseif c == "n" then
			pos = pos + 4
			return nil
		else
			return parseNumber()
		end
	end

	return parseValue()
end

--------------------------------------------------------------------
-- Dispatch table: maps a JSON "type" to a function building the
-- corresponding hl.dsp.* action. Add new action types here — you
-- should not need to touch keybindings.lua anymore.
--------------------------------------------------------------------
-- Route recorder commands through the ~/Videos/Recordings directory.
-- The Hyprland shortcut definitions live in Cartoon Shell's keybinds.json, which
-- is loaded at runtime and is not bundled in this repository archive. Normalize
-- wf-recorder/wl-screenrec commands here so existing shortcuts and options stay intact.
local function prepareScreenRecordingCommand(command)
	if type(command) ~= "string" then return command end
	if not command:find("wf%-recorder") and not command:find("wl%-screenrec") then
		return command
	end

	local outputDir = "$HOME/Videos/Recordings"
	command = command
		:gsub("%$%{HOME%}/Recordings", outputDir)
		:gsub("%$HOME/Recordings", outputDir)
		:gsub("~/Recordings", outputDir)
		:gsub("%$XDG_VIDEOS_DIR", outputDir)

	-- Running from the destination directory also handles relative -f filenames,
	-- independent of Hyprland's current working directory. The subshell keeps the
	-- caller's working directory unchanged and preserves the original command logic.
	return '(mkdir -p "' .. outputDir .. '" && cd "' .. outputDir .. '" && { ' .. command .. '; })'
end

-- Route screenshot commands to ~/Pictures/Screenshots, regardless of the compositor's
-- current working directory. Keep the original capture options and clipboard
-- behavior; when grim normally streams the image to wl-copy, save it first.
local function prepareScreenshotCommand(command)
	if type(command) ~= "string" then return command end
	local isScreenshotCommand = command:find("grim", 1, true)
		or command:find("hyprshot", 1, true)
		or command:find("grimblast", 1, true)
	if not isScreenshotCommand then return command end

	local outputDir = "$HOME/Pictures/Screenshots"

	-- Preserve clipboard functionality while also saving common grim-to-wl-copy
	-- screenshot shortcuts to a uniquely named PNG.
	command = command:gsub("(grim.-)%s+%-%s*|%s*(wl%-copy[^;&|]*)", function(grimCommand, clipboardCommand)
		return 'FILE="' .. outputDir .. '/screenshot_$(date +\'%Y-%m-%d_%H-%M-%S\').png" && '
			.. grimCommand .. ' "$FILE" && ' .. clipboardCommand:gsub("^wl%-copy", "wl-copy -t image/png", 1) .. ' < "$FILE"'
	end, 1)

	-- Redirect common screenshot folders (including the former misspelling) and
	-- relative output paths into the same directory.
	command = command
		:gsub("%$%{HOME%}/Screenshots", outputDir)
		:gsub("%$HOME/Screenshots", outputDir)
		:gsub("~/Screenshots", outputDir)
		:gsub("%$%{HOME%}/Screenshorts", outputDir)
		:gsub("%$HOME/Screenshorts", outputDir)
		:gsub("~/Screenshorts", outputDir)
		:gsub("%$XDG_PICTURES_DIR", outputDir)

	-- Hyprshot supports an explicit output folder. Normalize it when present, or
	-- add it for the default form so output does not depend on its default folder.
	if command:find("hyprshot", 1, true) then
		if command:find("%-%-output%-folder%s+%S+") then
			command = command:gsub("%-%-output%-folder%s+%S+", '--output-folder "' .. outputDir .. '"', 1)
		elseif command:find("%-o%s+%S+") then
			command = command:gsub("%-o%s+%S+", '-o "' .. outputDir .. '"', 1)
		else
			command = command:gsub("(hyprshot)", '%1 -o "' .. outputDir .. '"', 1)
		end
	end

	-- Create and enter the destination directory in a subshell. This also makes
	-- filenames such as screenshot.png (relative paths) land in ~/Pictures/Screenshots.
	return '(mkdir -p "' .. outputDir .. '" && cd "' .. outputDir .. '" && export XDG_PICTURES_DIR="' .. outputDir .. '" && { ' .. command .. '; })'
end

local dispatch = {
	exec_cmd = function(args)
		local command = prepareScreenshotCommand(args[1])
		return hl.dsp.exec_cmd(prepareScreenRecordingCommand(command))
	end,
	["window.close"] = function() return hl.dsp.window.close() end,
	["window.float"] = function(args) return hl.dsp.window.float(args[1]) end,
	["window.pseudo"] = function() return hl.dsp.window.pseudo() end,
	["window.fullscreen"] = function() return hl.dsp.window.fullscreen() end,
	["window.move"] = function(args) return hl.dsp.window.move(args[1]) end,
	["window.drag"] = function() return hl.dsp.window.drag() end,
	["window.resize"] = function() return hl.dsp.window.resize() end,
	exit = function() return hl.dsp.exit() end,
	focus = function(args) return hl.dsp.focus(args[1]) end,
	["workspace.toggle_special"] = function(args) return hl.dsp.workspace.toggle_special(args[1]) end,
}

-- Registers a single shortcut (not a 1-9 range).
local function bindOne(sc)
	local build = dispatch[sc.type]
	if not build then
		print("[keybind_loader] Skipping '" .. tostring(sc.id) .. "': unsupported type '" .. tostring(sc.type) .. "'")
		return
	end
	local opts = {}
	if sc.locked then opts.locked = true end
	if sc.repeating then opts.repeating = true end
	if sc.extra then
		for k, v in pairs(sc.extra) do opts[k] = v end
	end
	hl.bind(sc.key, build(sc.args or {}), opts)
end

-- Registers the SUPER+1..9 / SUPER+SHIFT+1..9 range (not stored as
-- individual entries in the JSON, just one "workspace_range" entry).
local function bindRange(sc, mainMod)
	local shift = sc.args and sc.args[1] and sc.args[1].shift
	for i = 1, 9 do
		local combo = mainMod .. (shift and " + SHIFT + " or " + ") .. i
		if shift then
			hl.bind(combo, hl.dsp.window.move({ workspace = i }))
		else
			hl.bind(combo, hl.dsp.focus({ workspace = i }))
		end
	end
end

--- Reads keybinds.json and registers every bind with hl.
--- Call this at the top of keybindings.lua instead of typing out each
--- hl.bind() call by hand.
function M.load()
	local f = io.open(JSON_PATH, "r")
	if not f then
		error("[keybind_loader] Could not find " .. JSON_PATH)
	end
	local content = f:read("*a")
	f:close()

	local data = jsonDecode(content)
	local mainMod = data.mainMod or "SUPER"

	for _, category in ipairs(data.categories) do
		for _, sc in ipairs(category.shortcuts) do
			if sc.type == "workspace_range" then
				bindRange(sc, mainMod)
			else
				bindOne(sc)
			end
		end
	end
end

return M
