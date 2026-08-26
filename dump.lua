if not game:IsLoaded() then
	game.Loaded:Wait()
end
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local StarterGui = game:GetService("StarterGui")
local StarterPack = game:GetService("StarterPack")
local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer
end
local env = (typeof(getgenv) == "function" and getgenv()) or _G
if type(env) == "table" and type(env.UNIVERSAL_DUMP_UNLOAD) == "function" then
	pcall(env.UNIVERSAL_DUMP_UNLOAD)
end
local Config = {
	mainDir = "UniversalDumper",
    debug = false,
	decompile = true,
	dumpDebug = false,
	detailedDebug = false,
	threads = 1,
	timeout = 6,
	delay = 0,
	includeNil = true,
	includeBytecode = true,
	replaceUsername = true,
	disableRender = false,
	dumpTrees = true,
	dumpRemotes = true,
	dumpGui = true,
	dumpValues = true,
	dumpAttributes = true,
	hookNet = true,
	hookClientReceive = true,
	liveIntercept = true,
	liveConsole = false,
	liveFlushEvery = 20,
	liveWatchStats = true,
	liveWatchCharacter = true,
	liveInstallEarly = true,
	maxTreePerRoot = 60000,
	maxGui = 20000,
	maxScripts = 2000,
	skipCore = true,
	postHttp = false,
	httpSink = "",
}
local IGNORED_ANCESTORS = { "Chat", "CoreGui", "CorePackages" }
local IGNORED_NAMES = { "PlayerModule", "RbxCharacterSounds", "PlayerScriptsLoader", "ChatScript", "BubbleChat" }
local SERVER_SERVICES = {
	"ServerScriptService",
	"ServerStorage",
	"Teams",
	"MaterialService",
}
local SCRIPT_CLASSES = {
	LocalScript = true,
	ModuleScript = true,
	Script = true,
}
local function pickFn(...)
	for i = 1, select("#", ...) do
		local fn = select(i, ...)
		if typeof(fn) == "function" then
			return fn
		end
	end
	return nil
end
local decompileFn = pickFn(typeof(decompile) == "function" and decompile, env and env.decompile, typeof(disassemble) == "function" and disassemble)
local getNilInstances = pickFn(typeof(getnilinstances) == "function" and getnilinstances, env and env.getnilinstances, typeof(get_nil_instances) == "function" and get_nil_instances)
local getScriptHash = pickFn(typeof(getscripthash) == "function" and getscripthash, env and env.getscripthash)
local getScriptClosure = pickFn(typeof(getscriptclosure) == "function" and getscriptclosure, env and env.getscriptclosure)
local getConstants = pickFn(typeof(getconstants) == "function" and getconstants, env and env.getconstants, debug and debug.getconstants)
local getProtos = pickFn(typeof(getprotos) == "function" and getprotos, env and env.getprotos, debug and debug.getprotos)
local getInfo = pickFn(typeof(getinfo) == "function" and getinfo, env and env.getinfo, debug and debug.getinfo)
local getScripts = pickFn(typeof(getscripts) == "function" and getscripts, env and env.getscripts)
local getRunningScripts = pickFn(typeof(getrunningscripts) == "function" and getrunningscripts, env and env.getrunningscripts)
local getLoadedModules = pickFn(typeof(getloadedmodules) == "function" and getloadedmodules, env and env.getloadedmodules)
local getBytecode = pickFn(typeof(getscriptbytecode) == "function" and getscriptbytecode, env and env.getscriptbytecode)
local getConnections = pickFn(typeof(getconnections) == "function" and getconnections, env and env.getconnections)
local hookMeta = pickFn(typeof(hookmetamethod) == "function" and hookmetamethod, env and env.hookmetamethod)
local getNamecall = pickFn(typeof(getnamecallmethod) == "function" and getnamecallmethod, env and env.getnamecallmethod)
local checkCaller = pickFn(typeof(checkcaller) == "function" and checkcaller, env and env.checkcaller)
local newClosure = pickFn(typeof(newcclosure) == "function" and newcclosure, env and env.newcclosure) or function(f)
	return f
end
local writeFile = pickFn(typeof(writefile) == "function" and writefile, env and env.writefile)
local readFile = pickFn(typeof(readfile) == "function" and readfile, env and env.readfile)
local listFiles = pickFn(typeof(listfiles) == "function" and listfiles, env and env.listfiles)
local makeFolder = pickFn(typeof(makefolder) == "function" and makefolder, env and env.makefolder)
local isFolder = pickFn(typeof(isfolder) == "function" and isfolder, env and env.isfolder)
local httpRequest = pickFn(typeof(request) == "function" and request, typeof(http_request) == "function" and http_request, env and env.request)
local appendFile = pickFn(typeof(appendfile) == "function" and appendfile, env and env.appendfile)
local identifyExecutor = pickFn(typeof(identifyexecutor) == "function" and identifyexecutor, env and env.identifyexecutor)
local function trackConn(conn)
	if conn then
		table.insert(Core.connections, conn)
	end
	return conn
end
local Core = { running = true, connections = {} }
local DecompileCache = {}
local ScriptsDumped = 0
local TimedOut = {}
local RemoteCatalog = {}
local OUT = ""
local WriteStats = { ok = 0, fail = 0, lastError = "" }
local Log = { lines = {}, phase = "boot" }
local toJsonSafe
local writePhase
local extractRemoteStrings
local function dbg(...)
	if not Config.debug then
		return
	end
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring(select(i, ...))
	end
	print("[Dump]", table.concat(parts, " "))
end
local function dbgWarn(...)
	if Config.debug then
		warn("[Dump]", ...)
	end
end
local function log(kind, text)
	local row = string.format("[%s] %s  %s", kind, Log.phase, text)
	table.insert(Log.lines, row)
	if Config.debug then
		print("[Dump] " .. text)
	end
	dbg(kind, text)
	if #Log.lines > 5000 then
		table.remove(Log.lines, 1)
	end
	if writeFile and OUT ~= "" and (#Log.lines % 20 == 0) then
		pcall(function()
			writeText("log.txt", table.concat(Log.lines, "\n"))
			writeText("progress.txt", Log.phase .. "\n" .. text)
		end)
	end
end
local function ensureDir(path)
	if not makeFolder then
		dbgWarn("makefolder API missing — writes may fail")
		return false
	end
	local built = ""
	for part in string.gmatch(path, "[^/]+") do
		built = built == "" and part or (built .. "/" .. part)
		if isFolder and isFolder(built) then
			continue
		end
		local ok, err = pcall(makeFolder, built)
		if not ok then
			dbgWarn("makefolder failed:", built, err)
			return false
		end
		dbg("mkdir", built)
	end
	return true
end
local function safePathSegment(text)
	text = tostring(text or "unknown")
	text = string.gsub(text, "[\\/:*?\"<>|\n\r]", " ")
	text = string.gsub(text, "%.%.", ". .")
	if #text > 180 then
		text = string.sub(text, -180)
	end
	return text
end
local function writeText(rel, text)
	if not writeFile then
		WriteStats.fail += 1
		WriteStats.lastError = "writefile API missing"
		dbgWarn("SKIP (no writefile):", rel)
		return false, "no writefile"
	end
	if OUT == "" then
		WriteStats.fail += 1
		WriteStats.lastError = "OUT not set"
		dbgWarn("SKIP (OUT empty):", rel)
		return false, "OUT empty"
	end
	ensureDir(OUT)
	local relPath = rel
	local dir = string.match(relPath, "^(.*)/[^/]+$")
	if dir then
		ensureDir(OUT .. "/" .. dir)
	end
	local full = OUT .. "/" .. relPath
	local ok, err = pcall(writeFile, full, text)
	if ok then
		WriteStats.ok += 1
		if Config.debug then
			dbg("WROTE", full, "(" .. #tostring(text) .. " bytes)")
		end
		if readFile and Config.debug then
			local rok, back = pcall(readFile, full)
			if not rok or back ~= text then
				dbgWarn("readback mismatch:", full, rok, back and #back or "nil")
			end
		end
		return true
	end
	WriteStats.fail += 1
	WriteStats.lastError = tostring(err)
	dbgWarn("WRITE FAILED:", full, err)
	return false, err
end
local function jsonEncode(value)
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(value)
	end)
	if ok then
		return encoded, nil
	end
	return nil, encoded
end
local function writeJson(rel, payload)
	local encoded, err = jsonEncode(payload)
	if not encoded then
		encoded, err = jsonEncode(toJsonSafe(payload))
	end
	if not encoded then
		log("err", "json failed " .. rel .. ": " .. tostring(err))
		return false
	end
	local ok, werr = writeText(rel, encoded)
	if not ok then
		log("err", "write failed " .. rel .. ": " .. tostring(werr))
	end
	return ok
end
local DISK_ROOT = ""
local function probeFilesystem()
	dbg("=== FILESYSTEM PROBE ===")
	dbg("writefile:", writeFile ~= nil)
	dbg("makefolder:", makeFolder ~= nil)
	dbg("isfolder:", isFolder ~= nil)
	dbg("readfile:", readFile ~= nil)
	dbg("listfiles:", listFiles ~= nil)
	if not writeFile then
		dbgWarn("FATAL: writefile missing — dump cannot save")
		return false
	end
	ensureDir(Config.mainDir)
	local probeRel = Config.mainDir .. "/_write_probe.txt"
	local stamp = "probe ok " .. os.time() .. " place=" .. tostring(game.PlaceId)
	local ok, err = pcall(writeFile, probeRel, stamp)
	dbg("probe write", probeRel, "=>", ok, err)
	if not ok then
		dbgWarn("FATAL: probe write failed:", err)
		return false
	end
	if readFile then
		local rok, content = pcall(readFile, probeRel)
		dbg("probe readback =>", rok, "bytes=", content and #content or 0)
		if not rok or content ~= stamp then
			dbgWarn("readback failed or mismatch")
			return false
		end
	end
	if listFiles then
		local lok, files = pcall(listFiles, Config.mainDir)
		if lok and type(files) == "table" then
			dbg("listfiles", Config.mainDir, "count=", #files)
			for i = 1, math.min(5, #files) do
				dbg(" ", files[i])
			end
		else
			dbgWarn("listfiles failed:", files)
		end
	end
	dbg("disk root (Wave):", DISK_ROOT)
	return true
end
local function instancePath(inst)
	local ok, full = pcall(function()
		return inst:GetFullName()
	end)
	return (ok and full ~= "") and full or tostring(inst)
end
local function replacePlayerName(text)
	if not Config.replaceUsername then
		return text
	end
	return string.gsub(text, LocalPlayer.Name, "LocalPlayer")
end
local function getFullNameForScript(inst)
	local path = replacePlayerName(instancePath(inst))
	local split = string.split(path, ".")
	if inst:IsDescendantOf(game) then
		for i, part in ipairs(split) do
			if string.find(part, "[%s%-]+") then
				split[i] = string.format("['%s']", part)
			end
		end
		local joined = table.concat(split, ".")
		local service = split[1]
		if service then
			joined = string.format('game:GetService("%s")%s', service, string.sub(joined, #service + 1))
			joined = string.gsub(joined, "%.%[", "[")
			return joined
		end
	end
	return path
end
toJsonSafe = function(value, depth, seen)
	depth = depth or 0
	if depth > 8 then
		return "…"
	end
	local t = typeof(value)
	if t == "nil" then
		return nil
	elseif t == "boolean" or t == "number" then
		return value
	elseif t == "string" then
		if #value > 4000 then
			value = string.sub(value, 1, 4000) .. "…"
		end
		return string.gsub(value, "[\0-\31]", "")
	elseif t == "Instance" then
		return { __instance = replacePlayerName(instancePath(value)), class = value.ClassName }
	elseif t == "Vector3" or t == "Vector2" or t == "CFrame" or t == "Color3" then
		return tostring(value)
	elseif t == "table" then
		seen = seen or {}
		if seen[value] then
			return { __cycle = true }
		end
		seen[value] = true
		local out = {}
		local n = 0
		for k, v in pairs(value) do
			n += 1
			if n > 300 then
				out.__truncated = true
				break
			end
			local key = typeof(k) == "string" and k or tostring(k)
			out[key] = toJsonSafe(v, depth + 1, seen)
		end
		return out
	end
	return tostring(value)
end
local REMOTE_PATTERNS = {
	"InvokeServer%(%s*[\\\"']([^\\\"']+)[\\\"']",
	"FireServer%(%s*[\\\"']([^\\\"']+)[\\\"']",
	"OnClientEvent%(%s*[\\\"']([^\\\"']+)[\\\"']",
}
writePhase = function(name, extra)
	if OUT == "" then
		return
	end
	writeText("progress.txt", string.format(
		"phase=%s\nat=%s\nscripts=%d\nwrites_ok=%d\nwrites_fail=%d\n%s",
		name,
		os.date("!%H:%M:%S"),
		ScriptsDumped,
		WriteStats.ok,
		WriteStats.fail,
		extra or ""
	))
	dbg("PHASE", name, extra or "")
end
extractRemoteStrings = function(source, scriptPath)
	if type(source) ~= "string" then
		return
	end
	for _, pattern in ipairs(REMOTE_PATTERNS) do
		for match in string.gmatch(source, pattern) do
			RemoteCatalog[match] = RemoteCatalog[match] or {}
			table.insert(RemoteCatalog[match], scriptPath)
		end
	end
end
local function isIgnored(inst)
	if not Config.skipCore then
		return false
	end
	for _, name in ipairs(IGNORED_ANCESTORS) do
		local anc = inst:FindFirstAncestor(name)
		if anc then
			return true
		end
	end
	for _, name in ipairs(IGNORED_NAMES) do
		if inst.Name == name or inst:FindFirstAncestor(name) then
			return true
		end
	end
	return false
end
local function isScript(inst)
	return typeof(inst) == "Instance" and SCRIPT_CLASSES[inst.ClassName] == true
end
local function addScript(set, list, inst, sourceTag)
	if not isScript(inst) or isIgnored(inst) then
		return
	end
	local path = instancePath(inst)
	if set[path] then
		return
	end
	set[path] = true
	table.insert(list, {
		script = inst,
		path = path,
		class = inst.ClassName,
		source = sourceTag,
		isNil = not inst:IsDescendantOf(game),
	})
end
local function collectAllScripts()
	local set = {}
	local list = {}
	for _, inst in ipairs(game:GetDescendants()) do
		addScript(set, list, inst, "descendants")
	end
	local apiSources = {
		{ fn = getScripts, tag = "getscripts" },
		{ fn = getRunningScripts, tag = "getrunningscripts" },
		{ fn = getLoadedModules, tag = "getloadedmodules" },
	}
	for _, item in ipairs(apiSources) do
		if item.fn then
			local ok, scripts = pcall(item.fn)
			if ok and type(scripts) == "table" then
				for _, script in ipairs(scripts) do
					addScript(set, list, script, item.tag)
				end
			end
		end
	end
	if Config.includeNil and getNilInstances then
		local ok, nilInsts = pcall(getNilInstances)
		if ok and type(nilInsts) == "table" then
			for _, inst in ipairs(nilInsts) do
				addScript(set, list, inst, "nil")
			end
		end
	end
	for _, serviceName in ipairs(SERVER_SERVICES) do
		pcall(function()
			local svc = game:GetService(serviceName)
			for _, inst in ipairs(svc:GetDescendants()) do
				addScript(set, list, inst, "server:" .. serviceName)
			end
		end)
	end
	return list
end
local function probeServerContainers()
	local rows = {}
	for _, serviceName in ipairs(SERVER_SERVICES) do
		local row = { service = serviceName, accessible = false, scripts = 0, instances = 0, note = "" }
		local ok, svc = pcall(function()
			return game:GetService(serviceName)
		end)
		if not ok or not svc then
			row.note = "GetService failed"
			table.insert(rows, row)
			continue
		end
		row.accessible = true
		local okDesc, desc = pcall(function()
			return svc:GetDescendants()
		end)
		if okDesc and type(desc) == "table" then
			row.instances = #desc
			for _, inst in ipairs(desc) do
				if isScript(inst) then
					row.scripts += 1
				end
			end
			row.note = row.instances > 0 and "visible to client" or "empty or filtered"
		else
			row.note = "GetDescendants blocked"
		end
		table.insert(rows, row)
	end
	return rows
end
local function decompileScript(scriptInst)
	if not decompileFn then
		return nil, "no decompiler"
	end
	local hash = nil
	if getScriptHash then
		pcall(function()
			hash = getScriptHash(scriptInst)
		end)
	end
	if hash and DecompileCache[hash] then
		return DecompileCache[hash], "cache"
	end
	local output = nil
	local ok = pcall(function()
		output = decompileFn(scriptInst)
	end)
	if not ok or type(output) ~= "string" or output:gsub("%s", "") == "" then
		if Config.includeBytecode and getBytecode then
			local bok, bytecode = pcall(function()
				return getBytecode(scriptInst)
			end)
			if bok and bytecode then
				output = "-- bytecode fallback\n" .. tostring(bytecode)
			end
		end
	end
	if type(output) ~= "string" or output == "" then
		return nil, "decompile failed"
	end
	if hash then
		DecompileCache[hash] = output
	end
	return output, "decompiled"
end
local function buildDebugBlock(scriptInst, source)
	if not Config.dumpDebug then
		return ""
	end
	local lines = { "", "-- Debug Info" }
	if not getScriptClosure then
		table.insert(lines, "-- (getscriptclosure unavailable)")
		return table.concat(lines, "\n")
	end
	local ok, closure = pcall(getScriptClosure, scriptInst)
	if not ok or type(closure) ~= "function" then
		table.insert(lines, "-- (could not get script closure)")
		return table.concat(lines, "\n")
	end
	if getConstants then
		local cok, constants = pcall(getConstants, closure)
		if cok and type(constants) == "table" then
			table.insert(lines, "-- # Constants: " .. tostring(#constants))
			if Config.detailedDebug then
				for i, value in ipairs(constants) do
					if i > 200 then
						table.insert(lines, "-- … truncated")
						break
					end
					table.insert(lines, string.format("-- [%d] (%s) %s", i, typeof(value), tostring(value)))
				end
			end
		end
	end
	if getProtos then
		local pok, protos = pcall(getProtos, closure)
		if pok and type(protos) == "table" then
			table.insert(lines, "-- # Protos: " .. tostring(#protos))
		end
	end
	return table.concat(lines, "\n")
end
local function scriptFileName(index, entry)
	local short = safePathSegment(entry.path)
	if #short > 90 then
		short = string.sub(short, 1, 45) .. ".." .. string.sub(short, -40)
	end
	return string.format("scripts/%04d_%s.lua", index, short)
end
local function dumpAllScripts(scriptList)
	Log.phase = "scripts"
	local total = math.min(#scriptList, Config.maxScripts)
	log("boot", string.format("decompiling %d / %d scripts (sequential)", total, #scriptList))
	ensureDir(OUT .. "/scripts")
	writePhase("scripts_start", "total=" .. total)
	local index = { totalFound = #scriptList, dumped = 0, failed = 0, timedOut = 0, items = {} }
	for i = 1, total do
		local entry = scriptList[i]
		local item = {
			path = entry.path,
			class = entry.class,
			source = entry.source,
			isNil = entry.isNil,
			isServerScript = entry.class == "Script",
		}
		local ok, err = pcall(function()
			local scriptInst = entry.script
			local relPath = scriptFileName(i, entry)
			local started = os.clock()
			local source = "-- decompile disabled"
			local status = "skipped"
			if Config.decompile and decompileFn then
				while (os.clock() - started) < Config.timeout do
					local output, mode = decompileScript(scriptInst)
					if output then
						source = output
						status = mode
						break
					end
					task.wait(0.15)
				end
				if status == "skipped" then
					status = "timeout"
					source = "-- Decompilation timed out after " .. Config.timeout .. "s"
					table.insert(TimedOut, entry.path)
					index.timedOut += 1
				end
			elseif Config.includeBytecode and getBytecode then
				local bok, bc = pcall(getBytecode, scriptInst)
				if bok and bc then
					source = "-- bytecode only\n" .. tostring(bc)
					status = "bytecode"
				end
			end
			local header = string.format(
				[[
%s]],
				tostring(scriptInst.Name),
				getFullNameForScript(scriptInst),
				entry.class,
				entry.source,
				status,
				os.clock() - started,
				source
			)
			extractRemoteStrings(source, entry.path)
			if writeText(relPath, header) then
				item.file = relPath
				item.status = status
				ScriptsDumped += 1
			else
				item.status = "write_failed"
				index.failed += 1
			end
		end)
		if not ok then
			item.error = tostring(err)
			item.status = "error"
			index.failed += 1
			dbgWarn("script error", i, entry.path, err)
		end
		table.insert(index.items, item)
		if i % 3 == 0 or i == total then
			log("prog", string.format("scripts %d/%d dumped=%d fail=%d", i, total, ScriptsDumped, index.failed))
			writePhase("scripts", string.format("%d/%d last=%s", i, total, entry.path))
		end
		if i % 15 == 0 then
			task.wait()
		end
	end
	index.dumped = ScriptsDumped
	writeJson("scripts-index.json", index)
	if #TimedOut > 0 then
		writeText("timed-out-scripts.txt", table.concat(TimedOut, "\n"))
	end
	log("done", string.format("scripts dumped=%d failed=%d timedOut=%d", ScriptsDumped, index.failed, index.timedOut))
	writePhase("scripts_done", string.format("dumped=%d fail=%d", ScriptsDumped, index.failed))
end
local function dumpRemotes()
	Log.phase = "remotes"
	local all = {}
	for _, inst in ipairs(game:GetDescendants()) do
		local className = inst.ClassName
		if className == "RemoteEvent" or className == "RemoteFunction"
			or className == "UnreliableRemoteEvent"
			or className == "BindableEvent" or className == "BindableFunction"
		then
			table.insert(all, {
				class = className,
				path = replacePlayerName(instancePath(inst)),
				name = inst.Name,
			})
		end
	end
	table.sort(all, function(a, b)
		return a.path < b.path
	end)
	writeJson("remotes-all.json", { count = #all, items = all })
	log("done", "remotes=" .. #all)
end
local function dumpValues()
	Log.phase = "values"
	local rows = {}
	local roots = { ReplicatedStorage, Workspace, LocalPlayer, StarterGui, StarterPack, Lighting }
	for _, root in ipairs(roots) do
		if root then
			for _, inst in ipairs(root:GetDescendants()) do
				if inst:IsA("ValueBase") then
					local row = {
						path = replacePlayerName(instancePath(inst)),
						class = inst.ClassName,
						name = inst.Name,
					}
					pcall(function()
						row.value = tostring(inst.Value)
					end)
					table.insert(rows, row)
				elseif Config.dumpAttributes then
					local attrs = inst:GetAttributes()
					if attrs and next(attrs) then
						table.insert(rows, {
							path = replacePlayerName(instancePath(inst)),
							class = inst.ClassName,
							attributes = toJsonSafe(attrs),
						})
					end
				end
			end
		end
	end
	writeJson("values-all.json", { count = #rows, items = rows })
	log("done", "values=" .. #rows)
end
local function dumpGui()
	Log.phase = "gui"
	local rows = {}
	local function scan(root, tag)
		if not root then
			return
		end
		for _, inst in ipairs(root:GetDescendants()) do
			if inst:IsA("GuiObject") then
				local row = {
					tag = tag,
					class = inst.ClassName,
					path = replacePlayerName(instancePath(inst)),
					name = inst.Name,
					visible = inst.Visible,
				}
				pcall(function()
					if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
						row.text = inst.Text
					end
				end)
				table.insert(rows, row)
				if #rows >= Config.maxGui then
					return
				end
			end
		end
	end
	scan(LocalPlayer:FindFirstChild("PlayerGui"), "PlayerGui")
	scan(StarterGui, "StarterGui")
	writeJson("gui-full.json", { count = #rows, items = rows })
	log("done", "gui=" .. #rows)
end
local function dumpTree(root, label)
	local rows = {}
	local n = 0
	for _, inst in ipairs(root:GetDescendants()) do
		n += 1
		if n > Config.maxTreePerRoot then
			break
		end
		if n % 500 == 0 then
			task.wait()
		end
		local row = {
			path = replacePlayerName(instancePath(inst)),
			class = inst.ClassName,
			name = inst.Name,
		}
		if inst:IsA("ValueBase") then
			pcall(function()
				row.value = tostring(inst.Value)
			end)
		end
		if Config.dumpAttributes then
			local attrs = inst:GetAttributes()
			if attrs and next(attrs) then
				row.attributes = toJsonSafe(attrs)
			end
		end
		table.insert(rows, row)
	end
	writeJson("trees/" .. label .. ".json", { root = label, count = #rows, items = rows })
	log("done", "tree " .. label .. "=" .. #rows)
end
local function dumpTrees()
	Log.phase = "trees"
	ensureDir(OUT .. "/trees")
	local roots = {
		{ Workspace, "Workspace" },
		{ ReplicatedStorage, "ReplicatedStorage" },
		{ ReplicatedFirst, "ReplicatedFirst" },
		{ StarterGui, "StarterGui" },
		{ StarterPack, "StarterPack" },
		{ LocalPlayer, "LocalPlayer" },
		{ Lighting, "Lighting" },
	}
	for _, pair in ipairs(roots) do
		if pair[1] then
			dumpTree(pair[1], pair[2])
		end
	end
end
local function buildRemoteCatalog()
	Log.phase = "catalog"
	local items = {}
	for name, paths in pairs(RemoteCatalog) do
		table.insert(items, { name = name, scripts = paths })
	end
	table.sort(items, function(a, b)
		return a.name < b.name
	end)
	writeJson("remote-catalog.json", { count = #items, items = items })
	log("done", "remote catalog=" .. #items)
end
local Live = {
	n = 0,
	netBuf = "",
	jsonBuf = {},
	remotesHooked = {},
	lastFlush = os.clock(),
}
local function serializeArgs(args, max)
	max = max or 12
	local parts = {}
	for i = 1, math.min(#args, max) do
		parts[i] = serializeArg(args[i])
	end
	if #args > max then
		table.insert(parts, "…+" .. (#args - max))
	end
	return table.concat(parts, ", ")
end
local function livePush(event)
	if not Core.running or not Config.liveIntercept then
		return
	end
	Live.n += 1
	event.n = Live.n
	event.t = os.time()
	event.clock = os.clock()
	local dir = event.dir or "?"
	local kind = event.kind or "?"
	local target = event.remote or event.name or event.path or "?"
	local argsText = event.argsText or event.retText or ""
	Live.netBuf ..= string.format(
		"%d\t%s\t%s\t%s\t%s\n",
		Live.n,
		os.date("%H:%M:%S", event.t),
		dir .. ":" .. kind,
		target,
		argsText
	)
	table.insert(Live.jsonBuf, event)
	if #Live.jsonBuf > 500 then
		table.remove(Live.jsonBuf, 1)
	end
	if Config.liveConsole or (Config.debug and Live.n <= 30) then
		dbg("LIVE", dir, kind, target, argsText)
	end
	if Live.n % Config.liveFlushEvery == 0 then
		pcall(flushLiveLogs)
	end
end
function flushLiveLogs()
	if OUT == "" or not writeFile then
		return
	end
	ensureDir(OUT .. "/live")
	if Live.netBuf ~= "" then
		writeText("live/net.log", Live.netBuf)
		writeText("net-live.log", Live.netBuf)
	end
	if #Live.jsonBuf > 0 then
		local lines = {}
		for _, ev in ipairs(Live.jsonBuf) do
			local line = jsonEncode(toJsonSafe(ev))
			if line then
				table.insert(lines, line)
			end
		end
		if appendFile then
			for _, line in ipairs(lines) do
				pcall(appendFile, OUT .. "/live/events.jsonl", line .. "\n")
			end
		else
			writeText("live/events.jsonl", table.concat(lines, "\n") .. "\n")
		end
	end
	writeJson("live/status.json", {
		at = os.time(),
		events = Live.n,
		remotesHooked = Live.remotesHooked,
		running = Core.running,
		note = "Live intercept active — play the game, logs update in real time",
	})
	Live.lastFlush = os.clock()
end
local function hookRemoteIncoming(remote)
	if not Config.liveIntercept or Live.remotesHooked[remote] then
		return
	end
	Live.remotesHooked[remote] = true
	if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
		trackConn(remote.OnClientEvent:Connect(function(...)
			local args = { ... }
			task.defer(function()
				livePush({
					dir = "S2C",
					kind = "OnClientEvent",
					remote = replacePlayerName(instancePath(remote)),
					argsText = serializeArgs(args),
				})
			end)
		end))
	end
	if remote:IsA("RemoteFunction") then
		trackConn(remote.OnClientInvoke:Connect(function(...)
			local args = { ... }
			task.defer(function()
				livePush({
					dir = "S2C",
					kind = "OnClientInvoke",
					remote = replacePlayerName(instancePath(remote)),
					argsText = serializeArgs(args),
				})
			end)
		end))
	end
end
local function hookAllRemotes()
	local n = 0
	for _, inst in ipairs(game:GetDescendants()) do
		if inst:IsA("RemoteEvent") or inst:IsA("UnreliableRemoteEvent") or inst:IsA("RemoteFunction") then
			hookRemoteIncoming(inst)
			n += 1
		end
	end
	trackConn(game.DescendantAdded:Connect(function(inst)
		if inst:IsA("RemoteEvent") or inst:IsA("UnreliableRemoteEvent") or inst:IsA("RemoteFunction") then
			task.defer(function()
				hookRemoteIncoming(inst)
				livePush({
					dir = "INST",
					kind = "RemoteAdded",
					remote = replacePlayerName(instancePath(inst)),
					argsText = inst.ClassName,
				})
			end)
		end
	end))
	log("done", "live S2C listeners on " .. n .. " remotes")
end
local function watchLeaderstats()
	if not Config.liveWatchStats then
		return
	end
	local ls = LocalPlayer:FindFirstChild("leaderstats")
	if not ls then
		trackConn(LocalPlayer.ChildAdded:Connect(function(child)
			if child.Name == "leaderstats" then
				watchLeaderstats()
			end
		end))
		return
	end
	for _, v in ipairs(ls:GetDescendants()) do
		if v:IsA("ValueBase") then
			trackConn(v:GetPropertyChangedSignal("Value"):Connect(function()
				livePush({
					dir = "STAT",
					kind = "leaderstats",
					name = v.Name,
					path = replacePlayerName(instancePath(v)),
					argsText = tostring(v.Value),
				})
			end))
		end
	end
end
local function watchCharacter(char)
	if not Config.liveWatchCharacter or not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		trackConn(hum:GetPropertyChangedSignal("Health"):Connect(function()
			livePush({
				dir = "STAT",
				kind = "Health",
				name = LocalPlayer.Name,
				argsText = string.format("%.1f/%.1f", hum.Health, hum.MaxHealth),
			})
		end))
		trackConn(hum.Died:Connect(function()
			livePush({ dir = "STAT", kind = "Died", name = LocalPlayer.Name, argsText = "" })
		end))
	end
end
local function installLiveIntercept()
	if not Config.liveIntercept then
		return
	end
	ensureDir(OUT .. "/live")
	writeText("live/README.txt", table.concat({
		"Live intercept — updates while you play after dump.lua runs",
		"",
		"Files:",
		"  net.log / net-live.log  — tab-separated remote traffic",
		"  events.jsonl            — structured events (C2S, S2C, stats)",
		"  status.json             — event count + hook status",
		"",
		"C2S = your client firing remotes (FireServer / InvokeServer)",
		"S2C = server pushing to you (OnClientEvent / OnClientInvoke)",
		"STAT = leaderstats / health changes",
		"INST = new remotes appearing at runtime",
		"",
		"Play normally: duel, throw knives, shop, trade — all gets captured.",
	}, "\n"))
	hookAllRemotes()
	watchLeaderstats()
	watchCharacter(LocalPlayer.Character)
	trackConn(LocalPlayer.CharacterAdded:Connect(watchCharacter))
	if hookMeta and getNamecall then
		local old
		old = hookMeta(game, "__namecall", newClosure(function(self, ...)
			local args = { ... }
			local method = getNamecall()
			local shouldLog = method == "FireServer" or method == "InvokeServer"
				or method == "PromptProductPurchase" or method == "PromptGamePassPurchase"
			if shouldLog and Core.running and (not checkCaller or not checkCaller()) then
				local remotePath = "?"
				pcall(function()
					remotePath = replacePlayerName(instancePath(self))
				end)
				if method == "InvokeServer" then
					local results = { old(self, table.unpack(args)) }
					task.defer(function()
						livePush({
							dir = "C2S",
							kind = "InvokeServer",
							remote = remotePath,
							argsText = serializeArgs(args),
							retText = serializeArg(results[1]),
						})
					end)
					return table.unpack(results)
				end
				task.defer(function()
					livePush({
						dir = "C2S",
						kind = method,
						remote = remotePath,
						argsText = serializeArgs(args),
					})
				end)
			end
			return old(self, table.unpack(args))
		end))
		Core.namecallHook = old
		log("done", "live C2S namecall hook installed")
	else
		log("warn", "live C2S hook unavailable (no hookmetamethod)")
	end
	trackConn(RunService.Heartbeat:Connect(function()
		if Live.n > 0 and (os.clock() - Live.lastFlush) > 3 then
			pcall(flushLiveLogs)
		end
	end))
	flushLiveLogs()
	log("done", "LIVE INTERCEPT ACTIVE — play the game, watch live/net.log grow")
	dbg("LIVE", "intercept running →", OUT .. "/live/")
end
local function netPush(direction, remotePath, detail)
	livePush({ dir = direction, kind = "legacy", remote = remotePath, argsText = detail })
end
local function installNetHooks()
	installLiveIntercept()
end
local function getPlaceName()
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(game.PlaceId)
	end)
	if ok and type(info) == "table" and info.Name then
		return safePathSegment(string.gsub(info.Name, "^%s+", ""))
	end
	return "UnknownPlace"
end
local function buildOutPath(placeId, placeName)
	placeName = string.gsub(placeName, "%s+", "_")
	placeName = string.gsub(placeName, "^_+", "")
	placeName = string.gsub(placeName, "_+$", "")
	if placeName == "" then
		placeName = "Place"
	end
	return string.format("%s/%s_%s", Config.mainDir, tostring(placeId), placeName)
end
local function writeLimitations()
	writeText("LIMITATIONS.txt", table.concat({
		"Universal Dumper — what client-side dumping CAN and CANNOT do",
		"==============================================================",
		"",
		"CAN dump from a client executor:",
		"  • LocalScripts, ModuleScripts, and any Script instances replicated to client",
		"  • Scripts returned by getscripts / getrunningscripts / getloadedmodules",
		"  • Nil-parented scripts (getnilinstances)",
		"  • Full ReplicatedStorage / Workspace / PlayerGui trees (client view)",
		"  • All RemoteEvents/Functions the client can see",
		"  • Client→server traffic (FireServer/InvokeServer) via hooks",
		"",
		"CANNOT dump from client alone:",
		"  • ServerScriptService / ServerStorage scripts that never replicate",
		"  • Pure server Script instances not loaded into client memory",
		"  • Server-side-only ModuleScripts never required on client",
		"",
		"For true server dumps you need:",
		"  • Roblox Studio access to the place file, OR",
		"  • A server-side plugin / Studio command bar script, OR",
		"  • Official place download if you own the game",
		"",
		"This tool maximizes everything reachable from the client.",
	}, "\n"))
end
local function runPhase(name, fn)
	Log.phase = name
	local ok, err = pcall(fn)
	if not ok then
		log("err", name .. " crashed: " .. tostring(err))
	end
	return ok
end
local function runAll()
	dbg("=== DUMP START ===")
	if not probeFilesystem() then
		dbgWarn("Aborting — filesystem probe failed. Check F9 console.")
		return
	end
	local placeId = game.PlaceId
	local placeName = getPlaceName()
	OUT = buildOutPath(placeId, placeName)
	ensureDir(OUT)
	dbg("OUT path:", OUT)
	dbg("On disk:", DISK_ROOT .. OUT:gsub("/", "\\"))
	writeText("WHERE.txt", table.concat({
		"Dump output folder (executor workspace):",
		OUT,
		"",
		"Likely on disk:",
		DISK_ROOT .. OUT:gsub("/", "\\"),
		"",
		"Open that folder after the dump finishes.",
	}, "\n"))
	local exploitName, exploitVersion = "Unknown", ""
	if identifyExecutor then
		local ok, a, b = pcall(identifyExecutor)
		if ok then
			exploitName, exploitVersion = tostring(a or "Unknown"), tostring(b or "")
		end
	end
	log("boot", string.format("place=%s (%s) executor=%s", tostring(placeId), placeName, exploitName))
	if Config.disableRender then
		pcall(function()
			RunService:Set3dRenderingEnabled(false)
		end)
	end
	local serverAccess = probeServerContainers()
	writeJson("server-access.json", {
		note = "Shows whether server containers are visible from client (usually NOT)",
		items = serverAccess,
	})
	writeLimitations()
	writeJson("meta.json", {
		at = os.time(),
		placeId = placeId,
		placeName = placeName,
		jobId = game.JobId,
		player = LocalPlayer.Name,
		userId = LocalPlayer.UserId,
		executor = { name = exploitName, version = exploitVersion },
		config = Config,
		apis = {
			decompile = decompileFn ~= nil,
			getscripts = getScripts ~= nil,
			getnilinstances = getNilInstances ~= nil,
			getscriptbytecode = getBytecode ~= nil,
			hookmetamethod = hookMeta ~= nil,
			getconnections = getConnections ~= nil,
		},
	})
	local scriptList = collectAllScripts()
	local serverScripts = 0
	for _, entry in ipairs(scriptList) do
		if entry.class == "Script" then
			serverScripts += 1
		end
	end
	log("boot", string.format("found %d scripts (%d Script/server-class)", #scriptList, serverScripts))
	writeJson("script-inventory.json", {
		count = #scriptList,
		serverClass = serverScripts,
		sample = (function()
			local s = {}
			for i = 1, math.min(20, #scriptList) do
				s[i] = { scriptList[i].path, scriptList[i].class, scriptList[i].source }
			end
			return s
		end)(),
	})
	if Config.dumpRemotes then
		runPhase("remotes", dumpRemotes)
		writePhase("remotes_done")
	end
	if Config.dumpValues then
		runPhase("values", dumpValues)
		writePhase("values_done")
	end
	if Config.dumpGui then
		runPhase("gui", dumpGui)
		writePhase("gui_done")
	end
	if Config.dumpTrees then
		runPhase("trees", dumpTrees)
		writePhase("trees_done")
	end
	runPhase("scripts", function()
		dumpAllScripts(scriptList)
	end)
	runPhase("catalog", buildRemoteCatalog)
	writePhase("catalog_done")
	if Config.hookNet then
		runPhase("hooks", installNetHooks)
		writePhase("hooks_done")
	end
	writeJson("complete.json", {
		at = os.time(),
		ok = true,
		output = OUT,
		diskPath = DISK_ROOT .. OUT:gsub("/", "\\"),
		writes = WriteStats,
		scriptsFound = #scriptList,
		scriptsDumped = ScriptsDumped,
		serverClassScripts = serverScripts,
		message = "Dump complete. Keep playing — net-live.log captures live remotes.",
	})
	writeText("log.txt", table.concat(Log.lines, "\n"))
	if Config.disableRender then
		pcall(function()
			RunService:Set3dRenderingEnabled(true)
		end)
	end
	log("boot", string.format("COMPLETE writes=%d fail=%d → %s", WriteStats.ok, WriteStats.fail, OUT))
	dbg("=== DUMP COMPLETE ===")
	dbg("writes ok:", WriteStats.ok, "fail:", WriteStats.fail)
	if WriteStats.fail > 0 then
		dbgWarn("last error:", WriteStats.lastError)
	end
	dbg("folder:", DISK_ROOT .. OUT:gsub("/", "\\"))
end
env.UNIVERSAL_DUMP_UNLOAD = function()
	Core.running = false
	for _, conn in ipairs(Core.connections) do
		pcall(function()
			if type(conn) == "RBXScriptConnection" then
				conn:Disconnect()
			end
		end)
	end
	Core.connections = {}
	if Net.buf ~= "" then
		writeText("net-live.log", Net.buf)
	end
	pcall(function()
		RunService:Set3dRenderingEnabled(true)
	end)
	env.UNIVERSAL_DUMP_UNLOAD = nil
end
task.spawn(function()
	local ok, err = pcall(runAll)
	if not ok then
		dbgWarn("FATAL crash:", err)
		pcall(function()
			if OUT ~= "" then
				writeText("CRASH.txt", tostring(err) .. "\n\n" .. table.concat(Log.lines, "\n"))
				writeJson("complete.json", {
					ok = false,
					error = tostring(err),
					output = OUT,
					writes = WriteStats,
					scriptsDumped = ScriptsDumped,
				})
			end
		end)
	end
end)
