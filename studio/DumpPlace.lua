-- Studio collector for places you own or are authorized to inspect.
-- Run as a Studio plugin (ScriptEditorService is plugin-security).
-- This is not a client executor script. It does not recover other people's server source.

local VERSION = "0.1.0"
local HttpService = game:GetService("HttpService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local Selection = game:GetService("Selection")

local SCRIPT_CLASSES = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
}

local function luaLongString(s)
	local eq = ""
	while string.find(s, "]" .. eq .. "]", 1, true) do
		eq = eq .. "="
	end
	return "[" .. eq .. "[" .. s .. "]" .. eq .. "]"
end

local function jsonEncode(value)
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(value)
	end)
	if ok then
		return encoded
	end
	return nil
end

local function instancePath(inst)
	local ok, name = pcall(function()
		return inst:GetFullName()
	end)
	if ok then
		return name
	end
	return inst.Name
end

local function uniqueIdOf(inst)
	local id = nil
	pcall(function()
		id = tostring(inst.UniqueId)
	end)
	if type(id) == "string" and id ~= "" and id ~= "nil" then
		return id
	end
	return nil
end

local function getEditorSource(inst)
	if not SCRIPT_CLASSES[inst.ClassName] then
		return nil, "not a script"
	end
	local ok, source = pcall(function()
		return ScriptEditorService:GetEditorSource(inst)
	end)
	if ok and type(source) == "string" then
		return source, "editor"
	end
	ok, source = pcall(function()
		return inst.Source
	end)
	if ok and type(source) == "string" then
		return source, "source-property"
	end
	return nil, "unavailable"
end

local function collectScripts(root)
	local items = {}
	local function visit(inst)
		if SCRIPT_CLASSES[inst.ClassName] then
			local source, origin = getEditorSource(inst)
			table.insert(items, {
				path = instancePath(inst),
				class = inst.ClassName,
				name = inst.Name,
				stableId = uniqueIdOf(inst),
				sourceAvailable = type(source) == "string",
				sourceOrigin = origin,
				source = source,
				executionContext = inst.ClassName == "LocalScript" and "client" or (inst.ClassName == "Script" and "server" or "unknown"),
				visibility = "studio",
				complete = type(source) == "string",
				confidence = type(source) == "string" and "VERIFIED" or "LOW",
			})
		end
		for _, child in ipairs(inst:GetChildren()) do
			visit(child)
		end
	end
	visit(root)
	return items
end

local function run()
	local roots = {
		game:GetService("ServerScriptService"),
		game:GetService("ServerStorage"),
		game:GetService("ReplicatedStorage"),
		game:GetService("StarterPlayer"),
		game:GetService("StarterGui"),
		game:GetService("Workspace"),
	}
	local selected = Selection:Get()
	if #selected > 0 then
		roots = selected
	end
	local scripts = {}
	for _, root in ipairs(roots) do
		for _, item in ipairs(collectScripts(root)) do
			table.insert(scripts, item)
		end
	end
	local recovered = 0
	for _, item in ipairs(scripts) do
		if item.sourceAvailable then
			recovered += 1
		end
	end
	local report = {
		schema = "roblox-dumper/studio-v0.1",
		schemaVersion = 1,
		collectorVersion = VERSION,
		mode = "studio",
		placeId = game.PlaceId,
		placeName = game.Name,
		timestamp = os.time(),
		scriptCount = #scripts,
		sourceRecovered = recovered,
		coverage = {
			scripts = { discovered = #scripts, verified = recovered, failed = #scripts - recovered },
			server = { recovered = recovered },
		},
		note = "Authorized Studio export. Merge with a client dump using the same schemaVersion.",
		scripts = scripts,
	}
	local encoded = jsonEncode(report)
	if not encoded then
		warn("[studio-dumper] JSONEncode failed")
		return
	end
	local storage = game:GetService("ServerStorage")
	local existing = storage:FindFirstChild("StudioDump_" .. tostring(game.PlaceId))
	if existing then
		existing:Destroy()
	end
	local holder = Instance.new("ModuleScript")
	holder.Name = "StudioDump_" .. tostring(game.PlaceId)
	holder.Source = "return " .. luaLongString(encoded)
	holder.Parent = storage
	print(string.format(
		"[studio-dumper] wrote ServerStorage.%s scripts=%d source=%d",
		holder.Name,
		#scripts,
		recovered
	))
end

run()
