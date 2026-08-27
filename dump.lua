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

local VERSION = "0.3.0"
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
	snapshotDiff = true,
	snapshotEvery = 20,
	maxSnapshots = 10,
	maxTreePerRoot = 60000,
	maxGui = 20000,
	maxScripts = 2000,
	skipCore = true,
	postHttp = false,
	httpSink = "",
}
local SERIAL_CAPS = {
	stringMax = 4000,
	depth = 8,
	tableEntries = 300,
	argCount = 12,
}
local IGNORED_ANCESTORS = { "Chat", "CoreGui", "CorePackages" }
local IGNORED_NAMES = { "PlayerModule", "RbxCharacterSounds", "PlayerScriptsLoader", "ChatScript", "BubbleChat" }
local NONREPLICATED_CONTAINERS = {
	"ServerScriptService",
	"ServerStorage",
}
local NETWORK_REMOTE_CLASSES = {
	RemoteEvent = true,
	RemoteFunction = true,
	UnreliableRemoteEvent = true,
}
local BINDABLE_CLASSES = {
	BindableEvent = true,
	BindableFunction = true,
}
local SCRIPT_CLASSES = {
	LocalScript = true,
	ModuleScript = true,
	Script = true,
}
local STATIC_REMOTE_METHODS = {
	"FireServer",
	"InvokeServer",
	"OnClientEvent",
	"OnClientInvoke",
	"FireClient",
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
local hookFn = pickFn(typeof(hookfunction) == "function" and hookfunction, env and env.hookfunction, typeof(hookfunc) == "function" and hookfunc)
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

local Core = { running = true, connections = {}, namecallHook = nil, hookedMethods = {} }
local DecompileCache = {}
local ScriptsDumped = 0
local TimedOut = {}
local StaticRemoteRefs = {}
local RemoteIndex = {}
local ScriptSeen = {}
local ScriptHashByPath = {}
local ScriptMeta = {}
local HashUsed = {}
local ScriptIndex = { totalFound = 0, dumped = 0, failed = 0, timedOut = 0, items = {} }
local Snap = { n = 0, last = nil, lastAt = 0 }
local OUT = ""
local WriteStats = { ok = 0, fail = 0, lastError = "" }
local Log = { lines = {}, phase = "boot" }
local DISK_ROOT = ""
local Live = {
	n = 0,
	pending = {},
	pendingNet = "",
	recent = {},
	fallbackFiles = {},
	remotesHooked = {},
	invokePrev = {},
	invokeWrap = {},
	lastFlush = os.clock(),
	lastRewrap = os.clock(),
	lastCatalogWrite = 0,
	c2sGuard = 0,
}

local writeText
local writeJson
local log
local toJsonSafe
local serializeValue
local serializeArg
local serializeArgList
local extractRemoteStrings
local writePhase
local flushLiveLogs
local livePush
local writeRemoteCatalog
local dumpOneScript
local observeRemoteCall
local wrapOnClientInvoke
local hookRemoteIncoming
local ensureRemoteRecord
local takeSnapshot
local writeManifest
local writeAnalysisReport

local function trackConn(conn)
	if conn then
		table.insert(Core.connections, conn)
	end
	return conn
end

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

writeText = function(rel, text)
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

writeJson = function(rel, payload)
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

local function appendText(rel, text)
	if not text or text == "" then
		return true
	end
	if OUT == "" then
		return false, "OUT empty"
	end
	local dir = string.match(rel, "^(.*)/[^/]+$")
	if dir then
		ensureDir(OUT .. "/" .. dir)
	else
		ensureDir(OUT)
	end
	if appendFile then
		local ok, err = pcall(appendFile, OUT .. "/" .. rel, text)
		if ok then
			WriteStats.ok += 1
			return true
		end
		dbgWarn("appendfile failed:", rel, err)
	end
	Live.fallbackFiles[rel] = (Live.fallbackFiles[rel] or "") .. text
	return writeText(rel, Live.fallbackFiles[rel])
end

log = function(kind, text)
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

local function instanceUniqueId(inst)
	local id = nil
	pcall(function()
		id = inst.UniqueId
	end)
	if type(id) == "string" and id ~= "" then
		return id
	end
	pcall(function()
		id = inst:GetDebugId()
	end)
	if type(id) == "string" and id ~= "" then
		return id
	end
	return nil
end

local function fnv1aHex(s)
	local h = 2166136261
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		h = bit32.mul(h, 16777619)
	end
	return string.format("%08x", h)
end

local function toHex(s)
	return (string.gsub(s, ".", function(c)
		return string.format("%02x", string.byte(c))
	end))
end

--[=[ serializer ]=]
local function serializeVector3(v)
	return { type = "Vector3", x = v.X, y = v.Y, z = v.Z }
end
local function serializeVector2(v)
	return { type = "Vector2", x = v.X, y = v.Y }
end
local function serializeColor3(v)
	return { type = "Color3", r = v.R, g = v.G, b = v.B }
end

serializeValue = function(value, depth, seen, trunc)
	depth = depth or 0
	seen = seen or {}
	trunc = trunc or {}
	if depth > SERIAL_CAPS.depth then
		trunc.depth = true
		return { type = "truncated", reason = "depth" }
	end
	local t = typeof(value)
	if t == "nil" then
		return { type = "nil" }
	elseif t == "boolean" or t == "number" then
		return value
	elseif t == "string" then
		if #value > SERIAL_CAPS.stringMax then
			trunc.stringMax = (trunc.stringMax or 0) + 1
			value = string.sub(value, 1, SERIAL_CAPS.stringMax) .. "…"
		end
		return string.gsub(value, "[\0-\31]", "")
	elseif t == "Instance" then
		return {
			type = "Instance",
			class = value.ClassName,
			name = value.Name,
			path = replacePlayerName(instancePath(value)),
			uniqueId = instanceUniqueId(value),
		}
	elseif t == "Vector3" then
		return serializeVector3(value)
	elseif t == "Vector2" then
		return serializeVector2(value)
	elseif t == "Vector3int16" then
		return { type = "Vector3int16", x = value.X, y = value.Y, z = value.Z }
	elseif t == "Vector2int16" then
		return { type = "Vector2int16", x = value.X, y = value.Y }
	elseif t == "CFrame" then
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = value:GetComponents()
		return {
			type = "CFrame",
			x = x,
			y = y,
			z = z,
			r00 = r00,
			r01 = r01,
			r02 = r02,
			r10 = r10,
			r11 = r11,
			r12 = r12,
			r20 = r20,
			r21 = r21,
			r22 = r22,
		}
	elseif t == "Color3" then
		return serializeColor3(value)
	elseif t == "EnumItem" then
		return {
			type = "EnumItem",
			enum = tostring(value.EnumType),
			name = value.Name,
			value = value.Value,
		}
	elseif t == "UDim" then
		return { type = "UDim", scale = value.Scale, offset = value.Offset }
	elseif t == "UDim2" then
		return {
			type = "UDim2",
			x = { scale = value.X.Scale, offset = value.X.Offset },
			y = { scale = value.Y.Scale, offset = value.Y.Offset },
		}
	elseif t == "Ray" then
		return {
			type = "Ray",
			origin = serializeVector3(value.Origin),
			direction = serializeVector3(value.Direction),
		}
	elseif t == "BrickColor" then
		return { type = "BrickColor", name = value.Name, number = value.Number }
	elseif t == "NumberRange" then
		return { type = "NumberRange", min = value.Min, max = value.Max }
	elseif t == "NumberSequence" then
		local keys = {}
		for i, kp in ipairs(value.Keypoints) do
			keys[i] = { time = kp.Time, value = kp.Value, envelope = kp.Envelope }
		end
		return { type = "NumberSequence", keypoints = keys }
	elseif t == "ColorSequence" then
		local keys = {}
		for i, kp in ipairs(value.Keypoints) do
			keys[i] = { time = kp.Time, value = serializeColor3(kp.Value) }
		end
		return { type = "ColorSequence", keypoints = keys }
	elseif t == "Rect" then
		return {
			type = "Rect",
			min = serializeVector2(value.Min),
			max = serializeVector2(value.Max),
			width = value.Width,
			height = value.Height,
		}
	elseif t == "PhysicalProperties" then
		local row = {
			type = "PhysicalProperties",
			density = value.Density,
			friction = value.Friction,
			elasticity = value.Elasticity,
			frictionWeight = value.FrictionWeight,
			elasticityWeight = value.ElasticityWeight,
		}
		pcall(function()
			row.acousticAbsorption = value.AcousticAbsorption
		end)
		return row
	elseif t == "table" then
		if seen[value] then
			return { type = "cycle" }
		end
		seen[value] = true
		local entries = {}
		local n = 0
		for k, v in pairs(value) do
			n += 1
			if n > SERIAL_CAPS.tableEntries then
				trunc.tableEntries = true
				break
			end
			table.insert(entries, {
				k = serializeValue(k, depth + 1, seen, trunc),
				v = serializeValue(v, depth + 1, seen, trunc),
			})
		end
		seen[value] = nil
		local row = { type = "table", entries = entries }
		if trunc.tableEntries then
			row.truncated = true
		end
		return row
	end
	return { type = t, value = tostring(value) }
end

toJsonSafe = function(value, depth, seen)
	return serializeValue(value, depth, seen, {})
end

local function compactValue(ser)
	if ser == nil then
		return "nil"
	end
	local ty = typeof(ser)
	if ty == "boolean" or ty == "number" then
		return tostring(ser)
	elseif ty == "string" then
		if #ser > 80 then
			return string.format("%q", string.sub(ser, 1, 80) .. "…")
		end
		return string.format("%q", ser)
	elseif ty ~= "table" then
		return tostring(ser)
	end
	local t = ser.type
	if t == "nil" then
		return "nil"
	elseif t == "truncated" then
		return "…"
	elseif t == "cycle" then
		return "{cycle}"
	elseif t == "Instance" then
		return (ser.class or "Instance") .. ":" .. (ser.path or ser.name or "?")
	elseif t == "Vector3" then
		return string.format("Vector3(%.5g,%.5g,%.5g)", ser.x, ser.y, ser.z)
	elseif t == "Vector2" then
		return string.format("Vector2(%.5g,%.5g)", ser.x, ser.y)
	elseif t == "CFrame" then
		return string.format("CFrame(%.5g,%.5g,%.5g)", ser.x, ser.y, ser.z)
	elseif t == "Color3" then
		return string.format("Color3(%.5g,%.5g,%.5g)", ser.r, ser.g, ser.b)
	elseif t == "EnumItem" then
		return tostring(ser.enum) .. "." .. tostring(ser.name)
	elseif t == "table" then
		return "{…}"
	elseif t then
		return t
	end
	return "?"
end

serializeArg = function(value)
	local trunc = {}
	local ser = serializeValue(value, 0, {}, trunc)
	return ser, trunc
end

serializeArgList = function(args, n)
	n = n or #args
	local trunc = {}
	local max = SERIAL_CAPS.argCount
	local out = {}
	for i = 1, math.min(n, max) do
		local ser, t = serializeArg(args[i])
		out[i] = ser
		if t.depth then
			trunc.depth = true
		end
		if t.stringMax then
			trunc.stringMax = true
		end
		if t.tableEntries then
			trunc.tableEntries = true
		end
	end
	if n > max then
		trunc.argCount = n - max
	end
	local parts = {}
	for i = 1, #out do
		parts[i] = compactValue(out[i])
	end
	if trunc.argCount then
		table.insert(parts, "…+" .. trunc.argCount)
	end
	local types = {}
	for i = 1, math.min(n, max) do
		types[i] = typeof(args[i])
	end
	return out, trunc, table.concat(parts, ", "), types
end

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
	local lineNo = 0
	local function consider(line)
		local trimmed = string.gsub(line, "^%s+", "")
		if trimmed == "" or string.sub(trimmed, 1, 2) == "--" then
			return
		end
		for _, method in ipairs(STATIC_REMOTE_METHODS) do
			if string.find(line, method, 1, true) then
				local ident = string.match(line, "([%w_]+)%s*:%s*" .. method)
				if not ident then
					ident = string.match(line, '%["([%w_]+)"%]%s*:?%s*' .. method)
				end
				if not ident then
					ident = string.match(line, "%['([%w_]+)'%]%s*:?%s*" .. method)
				end
				if not ident then
					ident = string.match(line, method .. "%s*%(%s*[\"']([^\"']+)[\"']")
				end
				local expr = trimmed
				if #expr > 160 then
					expr = string.sub(expr, 1, 160) .. "…"
				end
				table.insert(StaticRemoteRefs, {
					script = scriptPath,
					line = lineNo,
					expression = expr,
					method = method,
					name = ident,
					confidence = ident and "medium" or "low",
				})
			end
		end
	end
	for line in string.gmatch(source, "[^\n]+") do
		lineNo += 1
		consider(line)
	end
	if not string.match(source, "\n$") and lineNo == 0 and #source > 0 then
		lineNo = 1
		consider(source)
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

local function isNetworkRemote(inst)
	return typeof(inst) == "Instance" and NETWORK_REMOTE_CLASSES[inst.ClassName] == true
end

local function addScript(set, list, inst, sourceTag)
	if not isScript(inst) or isIgnored(inst) then
		return
	end
	local path = instancePath(inst)
	local existing = set[path]
	if existing then
		for _, tag in ipairs(existing.discovery) do
			if tag == sourceTag then
				return
			end
		end
		table.insert(existing.discovery, sourceTag)
		return
	end
	local entry = {
		script = inst,
		path = path,
		class = inst.ClassName,
		source = sourceTag,
		discovery = { sourceTag },
		isNil = not inst:IsDescendantOf(game),
	}
	set[path] = entry
	table.insert(list, entry)
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
	return list
end

local function probeNonReplicatedContainers()
	local rows = {}
	for _, serviceName in ipairs(NONREPLICATED_CONTAINERS) do
		local row = {
			service = serviceName,
			accessible = false,
			scripts = 0,
			instances = 0,
			note = "diagnostic only — not a server dump",
		}
		local ok, svc = pcall(function()
			return game:GetService(serviceName)
		end)
		if not ok or not svc then
			row.note = "GetService failed (still not a server dump)"
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
			if row.instances > 0 then
				row.note = "some instances visible to this client; unreplicated source is still unavailable"
			else
				row.note = "empty or filtered from the client — expected"
			end
		else
			row.note = "GetDescendants blocked from client — expected"
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
				if hash then
					DecompileCache[hash] = output
				end
				return output, "bytecode"
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

local function assessConfidence(scriptInst, source, status)
	local syntax = "n/a"
	local constCount, protoCount = nil, nil
	if status == "decompiled" or status == "cache" then
		local loadFn = loadstring or load
		if type(loadFn) == "function" and type(source) == "string" then
			local okLoad = pcall(loadFn, source)
			syntax = okLoad and "valid" or "invalid"
		else
			syntax = "unknown"
		end
	end
	if getScriptClosure then
		local ok, closure = pcall(getScriptClosure, scriptInst)
		if ok and type(closure) == "function" then
			if getConstants then
				local cok, constants = pcall(getConstants, closure)
				if cok and type(constants) == "table" then
					constCount = #constants
				end
			end
			if getProtos then
				local pok, protos = pcall(getProtos, closure)
				if pok and type(protos) == "table" then
					protoCount = #protos
				end
			end
		end
	end
	local confidence = "low"
	if status == "decompiled" or status == "cache" then
		if syntax == "valid" then
			confidence = "high"
		elseif syntax == "invalid" then
			confidence = "low"
		else
			confidence = "medium"
		end
	elseif status == "bytecode" then
		confidence = "low"
	elseif status == "timeout" or status == "decompile failed" then
		confidence = "low"
	end
	return {
		decompile = status,
		syntax = syntax,
		constants = constCount,
		protos = protoCount,
		confidence = confidence,
		elapsed = nil,
	}
end

local function scriptPipeline(status, syntax, bytecodeAvailable)
	local sourceAvailable = status == "decompiled" or status == "cache"
	local decompileAttempted = status ~= "skipped"
	local validation = "n/a"
	if syntax == "valid" then
		validation = "passed"
	elseif syntax == "invalid" then
		validation = "failed"
	end
	return {
		discovered = true,
		identified = true,
		sourceAvailable = sourceAvailable,
		bytecodeAvailable = bytecodeAvailable == true,
		decompileAttempted = decompileAttempted,
		validated = syntax == "valid",
		validation = validation,
	}
end

local function buildDebugBlock(scriptInst)
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

local function contentHash(scriptInst, source)
	local raw = nil
	if getScriptHash then
		pcall(function()
			raw = getScriptHash(scriptInst)
		end)
	end
	if type(raw) == "string" and raw ~= "" then
		if string.match(raw, "^[0-9a-fA-F]+$") then
			return string.lower(raw)
		end
		if #raw <= 64 then
			return toHex(raw)
		end
		return fnv1aHex(raw)
	end
	return "src_" .. fnv1aHex(tostring(source or "") .. "\0" .. instancePath(scriptInst))
end

local function scriptFileName(hash, path)
	local key = hash
	if HashUsed[key] and HashUsed[key] ~= path then
		key = hash .. "_" .. fnv1aHex(path)
	end
	HashUsed[key] = path
	return "scripts/" .. safePathSegment(key) .. ".lua", key
end

local function writeScriptMetadata()
	ensureDir(OUT .. "/metadata")
	ensureDir(OUT .. "/scripts")
	local payload = {
		count = #ScriptMeta,
		items = ScriptMeta,
	}
	writeJson("metadata/scripts.json", payload)
	writeJson("scripts/metadata.json", payload)
	writeJson("scripts-index.json", ScriptIndex)
end

dumpOneScript = function(entry)
	local item = {
		path = entry.path,
		class = entry.class,
		source = entry.source,
		discovery = entry.discovery or { entry.source },
		isNil = entry.isNil,
		serverClassInstance = entry.class == "Script",
		serverOnlyRecovered = false,
	}
	local ok, err = pcall(function()
		local scriptInst = entry.script
		local started = os.clock()
		local source = "-- decompile disabled"
		local status = "skipped"
		local bytecodeAvailable = false
		if getBytecode then
			pcall(function()
				local bc = getBytecode(scriptInst)
				bytecodeAvailable = type(bc) == "string" and #bc > 0
			end)
		end
		if Config.decompile and decompileFn then
			while (os.clock() - started) < Config.timeout do
				local output, mode = decompileScript(scriptInst)
				if output then
					source = output
					status = mode
					if mode == "bytecode" then
						bytecodeAvailable = true
					end
					break
				end
				task.wait(0.15)
			end
			if status == "skipped" then
				status = "timeout"
				source = "-- Decompilation timed out after " .. Config.timeout .. "s"
				table.insert(TimedOut, entry.path)
				ScriptIndex.timedOut += 1
			end
		elseif Config.includeBytecode and getBytecode then
			local bok, bc = pcall(getBytecode, scriptInst)
			if bok and bc then
				source = "-- bytecode only\n" .. tostring(bc)
				status = "bytecode"
				bytecodeAvailable = true
			end
		end
		local assess = assessConfidence(scriptInst, source, status)
		local elapsed = os.clock() - started
		assess.elapsed = elapsed
		local pipeline = scriptPipeline(status, assess.syntax, bytecodeAvailable)
		local hash = contentHash(scriptInst, source)
		local relPath, storedHash = scriptFileName(hash, entry.path)
		local header = string.format(
			"-- name: %s\n-- path: %s\n-- class: %s\n-- collected: %s\n-- discovery: %s\n-- decompile: %s\n-- syntax: %s\n-- validation: %s\n-- bytecode: %s\n-- constants: %s\n-- protos: %s\n-- confidence: %s\n-- hash: %s\n-- elapsed: %.3fs\n\n%s%s",
			tostring(scriptInst.Name),
			getFullNameForScript(scriptInst),
			entry.class,
			entry.source,
			table.concat(entry.discovery or { entry.source }, ","),
			assess.decompile,
			assess.syntax,
			pipeline.validation,
			tostring(bytecodeAvailable),
			tostring(assess.constants),
			tostring(assess.protos),
			assess.confidence,
			storedHash,
			elapsed,
			source,
			buildDebugBlock(scriptInst)
		)
		extractRemoteStrings(source, entry.path)
		if writeText(relPath, header) then
			item.file = relPath
			item.hash = storedHash
			item.status = status
			item.syntax = assess.syntax
			item.confidence = assess.confidence
			item.constants = assess.constants
			item.protos = assess.protos
			item.pipeline = pipeline
			item.bytecodeAvailable = bytecodeAvailable
			item.firstSeen = os.time()
			ScriptsDumped += 1
			ScriptHashByPath[entry.path] = storedHash
			local displayPath = replacePlayerName(entry.path)
			local existingMeta = nil
			for _, meta in ipairs(ScriptMeta) do
				if meta.path == displayPath then
					existingMeta = meta
					break
				end
			end
			if existingMeta then
				existingMeta.last_seen = os.time()
				existingMeta.discovery = entry.discovery or existingMeta.discovery
				if existingMeta.hash ~= storedHash then
					existingMeta.versions = (existingMeta.versions or 1) + 1
					existingMeta.hash_history = existingMeta.hash_history or { existingMeta.hash }
					table.insert(existingMeta.hash_history, storedHash)
					existingMeta.hash = storedHash
					existingMeta.file = relPath
					existingMeta.decompile = assess.decompile
					existingMeta.syntax = assess.syntax
					existingMeta.pipeline = pipeline
					existingMeta.confidence = assess.confidence
				end
			else
				table.insert(ScriptMeta, {
					path = displayPath,
					class = entry.class,
					hash = storedHash,
					file = relPath,
					collected = entry.source,
					discovery = entry.discovery or { entry.source },
					first_seen = os.time(),
					last_seen = os.time(),
					versions = 1,
					decompile = assess.decompile,
					syntax = assess.syntax,
					constants = assess.constants,
					protos = assess.protos,
					confidence = assess.confidence,
					pipeline = pipeline,
					source = pipeline.sourceAvailable,
					bytecode = bytecodeAvailable,
					validation = pipeline.validation,
					isNil = entry.isNil,
					serverClassInstance = entry.class == "Script",
					serverOnlyRecovered = false,
				})
			end
		else
			item.status = "write_failed"
			ScriptIndex.failed += 1
		end
	end)
	if not ok then
		item.error = tostring(err)
		item.status = "error"
		ScriptIndex.failed += 1
		dbgWarn("script error", entry.path, err)
	end
	table.insert(ScriptIndex.items, item)
	ScriptSeen[entry.path] = true
	return item
end

local function dumpAllScripts(scriptList)
	Log.phase = "scripts"
	local total = math.min(#scriptList, Config.maxScripts)
	ScriptIndex.totalFound = #scriptList
	log("boot", string.format("decompiling %d / %d scripts (sequential)", total, #scriptList))
	ensureDir(OUT .. "/scripts")
	ensureDir(OUT .. "/metadata")
	writePhase("scripts_start", "total=" .. total)
	for i = 1, total do
		local entry = scriptList[i]
		dumpOneScript(entry)
		if i % 3 == 0 or i == total then
			log("prog", string.format("scripts %d/%d dumped=%d fail=%d", i, total, ScriptsDumped, ScriptIndex.failed))
			writePhase("scripts", string.format("%d/%d last=%s", i, total, entry.path))
		end
		if i % 15 == 0 then
			task.wait()
		end
	end
	ScriptIndex.dumped = ScriptsDumped
	writeScriptMetadata()
	if #TimedOut > 0 then
		writeText("timed-out-scripts.txt", table.concat(TimedOut, "\n"))
	end
	log("done", string.format("scripts dumped=%d failed=%d timedOut=%d", ScriptsDumped, ScriptIndex.failed, ScriptIndex.timedOut))
	writePhase("scripts_done", string.format("dumped=%d fail=%d", ScriptsDumped, ScriptIndex.failed))
end

local function readTags(inst)
	local tags = nil
	pcall(function()
		tags = inst:GetTags()
	end)
	if type(tags) == "table" and #tags > 0 then
		return tags
	end
	return nil
end

local function readAttributes(inst)
	if not Config.dumpAttributes then
		return nil
	end
	local attrs = nil
	pcall(function()
		attrs = inst:GetAttributes()
	end)
	if type(attrs) == "table" and next(attrs) then
		return serializeValue(attrs)
	end
	return nil
end

ensureRemoteRecord = function(inst)
	if typeof(inst) ~= "Instance" then
		return nil
	end
	local path = replacePlayerName(instancePath(inst))
	local rec = RemoteIndex[path]
	if rec then
		rec.last_seen = os.time()
		return rec
	end
	local className = inst.ClassName
	local channel = BINDABLE_CLASSES[className] and "bindable" or "network"
	rec = {
		path = path,
		class = className,
		name = inst.Name,
		attributes = readAttributes(inst),
		tags = readTags(inst),
		channel = channel,
		refs = { instance = true, static = {}, runtime = false },
		stats = { c2s = 0, s2c = 0, firstSeen = os.time(), lastSeen = os.time() },
		argSchema = {},
	}
	RemoteIndex[path] = rec
	return rec
end

observeRemoteCall = function(path, className, dir, argTypes)
	local rec = RemoteIndex[path]
	if not rec then
		rec = {
			path = path,
			class = className or "Remote",
			name = string.match(path, "[^%.]+$") or path,
			channel = "network",
			refs = { instance = false, static = {}, runtime = true },
			stats = { c2s = 0, s2c = 0, firstSeen = os.time(), lastSeen = os.time() },
			argSchema = {},
		}
		RemoteIndex[path] = rec
	end
	rec.refs.runtime = true
	rec.stats.lastSeen = os.time()
	if not rec.stats.firstSeen then
		rec.stats.firstSeen = os.time()
	end
	if dir == "C2S" then
		rec.stats.c2s += 1
	elseif dir == "S2C" then
		rec.stats.s2c += 1
	end
	if type(argTypes) == "table" and #argTypes > 0 then
		rec.argSchema = argTypes
	end
end

writeRemoteCatalog = function()
	local items = {}
	for _, rec in pairs(RemoteIndex) do
		rec.refs.static = {}
		table.insert(items, rec)
	end
	table.sort(items, function(a, b)
		return a.path < b.path
	end)
	local unmatched = {}
	for _, ref in ipairs(StaticRemoteRefs) do
		local attached = false
		if ref.name then
			for _, rec in ipairs(items) do
				if rec.name == ref.name then
					table.insert(rec.refs.static, ref)
					attached = true
				end
			end
		end
		if not attached then
			table.insert(unmatched, ref)
		end
	end
	local byKey = {}
	for _, ref in ipairs(unmatched) do
		local key = ref.name or (tostring(ref.method) .. "@" .. tostring(ref.script) .. ":" .. tostring(ref.line))
		byKey[key] = byKey[key] or {}
		table.insert(byKey[key], ref)
	end
	for key, refs in pairs(byKey) do
		table.insert(items, {
			path = key,
			class = "Unknown",
			name = refs[1].name or key,
			channel = "static-only",
			refs = { instance = false, static = refs, runtime = false },
			stats = { c2s = 0, s2c = 0 },
			argSchema = {},
			confidence = "low",
			note = "static reference only — no matching remote instance",
		})
	end
	for _, rec in ipairs(items) do
		if rec.refs.instance and rec.refs.runtime then
			rec.confidence = "high"
		elseif rec.refs.instance or rec.refs.runtime then
			rec.confidence = "medium"
		else
			rec.confidence = "low"
		end
	end
	table.sort(items, function(a, b)
		return a.path < b.path
	end)
	local payload = {
		note = "Instance-first remote index. refs.static is {script,line,expression,method,confidence}. Bindables are channel=bindable.",
		count = #items,
		items = items,
	}
	writeJson("remote-catalog.json", payload)
	ensureDir(OUT .. "/remotes")
	writeJson("remotes/catalog.json", payload)
	Live.lastCatalogWrite = os.clock()
end

local function dumpRemotes()
	Log.phase = "remotes"
	local all = {}
	for _, inst in ipairs(game:GetDescendants()) do
		local className = inst.ClassName
		if NETWORK_REMOTE_CLASSES[className] or BINDABLE_CLASSES[className] then
			local rec = ensureRemoteRecord(inst)
			table.insert(all, {
				class = className,
				path = rec.path,
				name = rec.name,
				channel = rec.channel,
				attributes = rec.attributes,
				tags = rec.tags,
			})
		end
	end
	table.sort(all, function(a, b)
		return a.path < b.path
	end)
	writeJson("remotes-all.json", {
		count = #all,
		items = all,
		note = "channel=network are remotes; channel=bindable are client-local.",
	})
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
						row.value = serializeValue(inst.Value)
					end)
					table.insert(rows, row)
				elseif Config.dumpAttributes then
					local attrs = inst:GetAttributes()
					if attrs and next(attrs) then
						table.insert(rows, {
							path = replacePlayerName(instancePath(inst)),
							class = inst.ClassName,
							attributes = serializeValue(attrs),
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
				row.value = serializeValue(inst.Value)
			end)
		end
		if Config.dumpAttributes then
			local attrs = inst:GetAttributes()
			if attrs and next(attrs) then
				row.attributes = serializeValue(attrs)
			end
		end
		table.insert(rows, row)
		local line = jsonEncode({
			root = label,
			path = row.path,
			class = row.class,
			name = row.name,
			value = row.value,
			attributes = row.attributes,
		})
		if line then
			appendText("instances.jsonl", line .. "\n")
		end
	end
	writeJson("trees/" .. label .. ".json", { root = label, count = #rows, items = rows })
	log("done", "tree " .. label .. "=" .. #rows)
end

local function dumpTrees()
	Log.phase = "trees"
	ensureDir(OUT .. "/trees")
	writeText("instances.jsonl", "")
	Live.fallbackFiles["instances.jsonl"] = ""
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

local function fingerprintSig(value)
	local enc = jsonEncode(value)
	if not enc then
		enc = jsonEncode(toJsonSafe(value))
	end
	return enc and fnv1aHex(enc) or "?"
end

local function snapshotRoots()
	return { Workspace, ReplicatedStorage, ReplicatedFirst, StarterGui, StarterPack, LocalPlayer, Lighting }
end

local function captureSnapshotState()
	local remotes, scripts, values, gui, attrs = {}, {}, {}, {}, {}
	local n = 0
	for _, root in ipairs(snapshotRoots()) do
		if not root then
			continue
		end
		local ok, desc = pcall(function()
			return root:GetDescendants()
		end)
		if not ok or type(desc) ~= "table" then
			continue
		end
		for _, inst in ipairs(desc) do
			n += 1
			if n % 400 == 0 then
				task.wait()
			end
			local path = replacePlayerName(instancePath(inst))
			if isNetworkRemote(inst) then
				local rec = RemoteIndex[path]
				remotes[path] = {
					class = inst.ClassName,
					c2s = rec and rec.stats.c2s or 0,
					s2c = rec and rec.stats.s2c or 0,
				}
			elseif isScript(inst) and not isIgnored(inst) then
				scripts[path] = {
					class = inst.ClassName,
					hash = ScriptHashByPath[instancePath(inst)] or ScriptHashByPath[path],
				}
			elseif inst:IsA("ValueBase") then
				local ser = nil
				pcall(function()
					ser = serializeValue(inst.Value)
				end)
				values[path] = fingerprintSig(ser)
			elseif inst:IsA("GuiObject") then
				gui[path] = { class = inst.ClassName, visible = inst.Visible }
			end
			if Config.dumpAttributes then
				local a = inst:GetAttributes()
				if a and next(a) then
					attrs[path] = fingerprintSig(serializeValue(a))
				end
			end
		end
	end
	for path, rec in pairs(RemoteIndex) do
		if rec.channel == "network" and not remotes[path] then
			remotes[path] = { class = rec.class, c2s = rec.stats.c2s, s2c = rec.stats.s2c }
		end
	end
	return {
		remotes = remotes,
		scripts = scripts,
		values = values,
		gui = gui,
		attrs = attrs,
	}
end

local function mapDiff(oldMap, newMap)
	local added, removed, changed = {}, {}, {}
	oldMap = oldMap or {}
	newMap = newMap or {}
	for path, nv in pairs(newMap) do
		local ov = oldMap[path]
		if ov == nil then
			table.insert(added, path)
		else
			local osig = type(ov) == "table" and (jsonEncode(ov) or fingerprintSig(ov)) or tostring(ov)
			local nsig = type(nv) == "table" and (jsonEncode(nv) or fingerprintSig(nv)) or tostring(nv)
			if osig ~= nsig then
				table.insert(changed, { path = path, before = ov, after = nv })
			end
		end
	end
	for path in pairs(oldMap) do
		if newMap[path] == nil then
			table.insert(removed, path)
		end
	end
	return added, removed, changed
end

writeAnalysisReport = function()
	local validated, bytecodeOnly = 0, 0
	for _, meta in ipairs(ScriptMeta) do
		if meta.validation == "passed" then
			validated += 1
		end
		if meta.bytecode and not meta.source then
			bytecodeOnly += 1
		end
	end
	local remoteInst, runtimeObs, staticOnly, highR = 0, 0, 0, 0
	for _, rec in pairs(RemoteIndex) do
		if rec.refs.instance then
			remoteInst += 1
		end
		if rec.refs.runtime then
			runtimeObs += 1
		end
		if rec.channel == "static-only" then
			staticOnly += 1
		end
		if rec.confidence == "high" then
			highR += 1
		end
	end
	ensureDir(OUT .. "/analysis")
	writeJson("analysis/report.json", {
		at = os.time(),
		scripts = {
			scriptInstances = ScriptIndex.totalFound,
			dumped = ScriptsDumped,
			validated = validated,
			bytecodeOnly = bytecodeOnly,
		},
		remotes = {
			instances = remoteInst,
			runtimeObserved = runtimeObs,
			staticOnly = staticOnly,
			highConfidence = highR,
		},
		snapshots = Snap.n,
		serverOnlyRecovered = 0,
	})
end

writeManifest = function()
	writeJson("manifest.json", {
		schema = "roblox-dumper/v0.3",
		version = VERSION,
		mode = "client",
		files = {
			metadata = "metadata.json",
			scripts = "scripts/metadata.json",
			remotes = "remotes/catalog.json",
			observations = "remotes/observations.jsonl",
			instances = "instances.jsonl",
			live = "live/events.jsonl",
			snapshots = "snapshots/",
			analysis = "analysis/",
			visibility = "server-visibility.json",
		},
		snapshots = Snap.n,
		scriptsDumped = ScriptsDumped,
		liveEvents = Live.n,
	})
end

takeSnapshot = function()
	if not Config.snapshotDiff or OUT == "" then
		return
	end
	if Snap.n >= Config.maxSnapshots then
		return
	end
	local state = captureSnapshotState()
	Snap.n += 1
	local id = Snap.n
	local rec = {
		id = id,
		at = os.time(),
		clock = os.clock(),
		counts = { remotes = 0, scripts = 0, values = 0, gui = 0, attrs = 0 },
		remotes = state.remotes,
		scripts = state.scripts,
		values = state.values,
		gui = state.gui,
		attrs = state.attrs,
	}
	for _ in pairs(state.remotes) do
		rec.counts.remotes += 1
	end
	for _ in pairs(state.scripts) do
		rec.counts.scripts += 1
	end
	for _ in pairs(state.values) do
		rec.counts.values += 1
	end
	for _ in pairs(state.gui) do
		rec.counts.gui += 1
	end
	for _ in pairs(state.attrs) do
		rec.counts.attrs += 1
	end
	ensureDir(OUT .. "/snapshots")
	writeJson(string.format("snapshots/%06d.json", id), rec)
	if Snap.last then
		local prev = Snap.last
		local diff = { from = prev.id, to = id, at = rec.at }
		diff.remotesAdded, diff.remotesRemoved, diff.remotesChanged = mapDiff(prev.remotes, rec.remotes)
		diff.scriptsAdded, diff.scriptsRemoved, diff.scriptsChanged = mapDiff(prev.scripts, rec.scripts)
		diff.valuesAdded, diff.valuesRemoved, diff.valuesChanged = mapDiff(prev.values, rec.values)
		diff.guiAdded, diff.guiRemoved, diff.guiChanged = mapDiff(prev.gui, rec.gui)
		diff.attrsAdded, diff.attrsRemoved, diff.attrsChanged = mapDiff(prev.attrs, rec.attrs)
		local encoded = jsonEncode(diff)
		if encoded then
			appendText("analysis/diffs.jsonl", encoded .. "\n")
		end
	end
	Snap.last = rec
	Snap.lastAt = os.clock()
	pcall(writeManifest)
	pcall(writeAnalysisReport)
	log("done", string.format("snapshot %06d remotes=%d scripts=%d values=%d", id, rec.counts.remotes, rec.counts.scripts, rec.counts.values))
end

--[=[ live intercept ]=]
livePush = function(event)
	if not Core.running or not Config.liveIntercept then
		return
	end
	Live.n += 1
	event.seq = Live.n
	event.t = os.time()
	event.clock = os.clock()
	if not event.thread then
		event.thread = tostring(coroutine.running())
	end
	local dir = event.dir or "?"
	local method = event.method or event.kind or "?"
	event.method = method
	event.kind = method
	local target = event.remote or event.name or event.path or "?"
	local argsText = event.argsText or ""
	local line = string.format(
		"%d\t%s\t%s\t%s\t%s\n",
		Live.n,
		os.date("%H:%M:%S", event.t),
		dir .. ":" .. method,
		target,
		argsText
	)
	table.insert(Live.pending, event)
	Live.pendingNet ..= line
	table.insert(Live.recent, event)
	if #Live.recent > 500 then
		table.remove(Live.recent, 1)
	end
	if Config.liveConsole or (Config.debug and Live.n <= 30) then
		dbg("LIVE", dir, method, target, argsText)
	end
	if Live.n % Config.liveFlushEvery == 0 then
		pcall(flushLiveLogs)
	end
end

flushLiveLogs = function()
	if OUT == "" or not writeFile then
		return
	end
	ensureDir(OUT .. "/live")
	local pending = Live.pending
	local pendingNet = Live.pendingNet
	local flushed = 0
	if pendingNet ~= "" then
		local okNet = appendText("live/net.log", pendingNet)
		local okLive = appendText("net-live.log", pendingNet)
		if okNet or okLive then
			Live.pendingNet = ""
		end
	end
	if #pending > 0 then
		local lines = {}
		for _, ev in ipairs(pending) do
			local line = jsonEncode(ev)
			if not line then
				line = jsonEncode(toJsonSafe(ev))
			end
			if line then
				table.insert(lines, line)
			end
		end
		if #lines == 0 or appendText("live/events.jsonl", table.concat(lines, "\n") .. "\n") then
			flushed = #pending
			local obs = {}
			for _, ev in ipairs(pending) do
				if ev.dir == "C2S" or ev.dir == "S2C" then
					local ol = jsonEncode(ev)
					if not ol then
						ol = jsonEncode(toJsonSafe(ev))
					end
					if ol then
						table.insert(obs, ol)
					end
				end
			end
			if #obs > 0 then
				appendText("remotes/observations.jsonl", table.concat(obs, "\n") .. "\n")
			end
			Live.pending = {}
		end
	end
	local hooked = 0
	for _ in pairs(Live.remotesHooked) do
		hooked += 1
	end
	writeJson("live/status.json", {
		at = os.time(),
		events = Live.n,
		remotesHooked = hooked,
		pendingFlushed = flushed,
		running = Core.running,
		note = "Pending queue is cleared after each successful flush. recent[] is UI-only.",
	})
	if os.clock() - Live.lastCatalogWrite > 5 then
		pcall(writeRemoteCatalog)
	end
	Live.lastFlush = os.clock()
end

local function pushRemoteEvent(dir, method, remote, args, n, returns, retN, source)
	local path = "?"
	local className = nil
	pcall(function()
		path = replacePlayerName(instancePath(remote))
		className = remote.ClassName
	end)
	local argsSer, trunc, argsText, argTypes = serializeArgList(args, n)
	local retSer, retTrunc, retText = nil, nil, nil
	if returns then
		retSer, retTrunc, retText = serializeArgList(returns, retN)
		if retTrunc and retTrunc.argCount then
			trunc = trunc or {}
			trunc.returns = retTrunc
		end
	end
	if next(trunc) == nil then
		trunc = nil
	end
	observeRemoteCall(path, className, dir, argTypes)
	local role = "event"
	if method == "OnClientInvoke" or method == "InvokeServer" then
		role = "invoke"
	end
	livePush({
		dir = dir,
		method = method,
		source = source,
		remote = path,
		class = className,
		family = className,
		role = role,
		args = argsSer,
		returns = retSer,
		argsText = argsText,
		retText = retText,
		truncated = trunc,
		thread = tostring(coroutine.running()),
	})
end

wrapOnClientInvoke = function(remote)
	if not Config.liveIntercept or not remote or not remote:IsA("RemoteFunction") then
		return
	end
	local existing = nil
	pcall(function()
		existing = remote.OnClientInvoke
	end)
	if Live.invokeWrap[remote] and existing == Live.invokeWrap[remote] then
		return
	end
	local prev = existing
	if prev and prev == Live.invokeWrap[remote] then
		prev = Live.invokePrev[remote]
	end
	Live.invokePrev[remote] = prev
	local wrap
	wrap = function(...)
		local n = select("#", ...)
		local args = { ... }
		if not prev then
			task.defer(function()
				pushRemoteEvent("S2C", "OnClientInvoke", remote, args, n, nil, nil, "OnClientInvoke")
			end)
			return
		end
		local packed = table.pack(pcall(prev, ...))
		if packed[1] then
			local results = { table.unpack(packed, 2, packed.n) }
			local retN = packed.n - 1
			task.defer(function()
				pushRemoteEvent("S2C", "OnClientInvoke", remote, args, n, results, retN, "OnClientInvoke")
			end)
			return table.unpack(packed, 2, packed.n)
		end
		task.defer(function()
			pushRemoteEvent("S2C", "OnClientInvoke", remote, args, n, nil, nil, "OnClientInvoke")
		end)
		error(packed[2], 0)
	end
	Live.invokeWrap[remote] = wrap
	pcall(function()
		remote.OnClientInvoke = wrap
	end)
end

hookRemoteIncoming = function(remote)
	if not Config.liveIntercept or Live.remotesHooked[remote] then
		return
	end
	Live.remotesHooked[remote] = true
	ensureRemoteRecord(remote)
	if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
		trackConn(remote.OnClientEvent:Connect(function(...)
			local n = select("#", ...)
			local args = { ... }
			task.defer(function()
				pushRemoteEvent("S2C", "OnClientEvent", remote, args, n, nil, nil, "OnClientEvent")
			end)
		end))
	end
	if remote:IsA("RemoteFunction") then
		wrapOnClientInvoke(remote)
	end
end

local function dumpLateScript(inst, sourceTag)
	if not isScript(inst) or isIgnored(inst) then
		return
	end
	local path = instancePath(inst)
	if ScriptSeen[path] then
		local newHash = nil
		if getScriptHash then
			pcall(function()
				newHash = getScriptHash(inst)
			end)
		end
		local old = ScriptHashByPath[path]
		if type(newHash) == "string" and newHash ~= "" and old and newHash ~= old and ScriptsDumped < Config.maxScripts then
			dumpOneScript({
				script = inst,
				path = path,
				class = inst.ClassName,
				source = "hash-changed",
				discovery = { "hash-changed" },
				isNil = not inst:IsDescendantOf(game),
			})
			writeScriptMetadata()
			livePush({
				dir = "INST",
				method = "ScriptHashChanged",
				remote = replacePlayerName(path),
				class = inst.ClassName,
				argsText = old .. " -> " .. newHash,
				source = sourceTag,
			})
			return
		end
		for _, meta in ipairs(ScriptMeta) do
			if meta.path == replacePlayerName(path) then
				meta.last_seen = os.time()
				break
			end
		end
		return
	end
	if ScriptsDumped >= Config.maxScripts then
		livePush({
			dir = "INST",
			method = "ScriptAddedCapped",
			remote = replacePlayerName(path),
			class = inst.ClassName,
			argsText = inst.ClassName,
			source = sourceTag,
		})
		return
	end
	local entry = {
		script = inst,
		path = path,
		class = inst.ClassName,
		source = sourceTag,
		discovery = { sourceTag },
		isNil = not inst:IsDescendantOf(game),
	}
	dumpOneScript(entry)
	ScriptIndex.dumped = ScriptsDumped
	writeScriptMetadata()
	livePush({
		dir = "INST",
		method = "ScriptAdded",
		remote = replacePlayerName(path),
		class = inst.ClassName,
		argsText = inst.ClassName,
		source = sourceTag,
	})
end

local function hookAllRemotes()
	local n = 0
	for _, inst in ipairs(game:GetDescendants()) do
		if isNetworkRemote(inst) then
			hookRemoteIncoming(inst)
			n += 1
		end
	end
	trackConn(game.DescendantAdded:Connect(function(inst)
		task.defer(function()
			if not Core.running then
				return
			end
			if isNetworkRemote(inst) then
				hookRemoteIncoming(inst)
				livePush({
					dir = "INST",
					method = "RemoteAdded",
					remote = replacePlayerName(instancePath(inst)),
					class = inst.ClassName,
					argsText = inst.ClassName,
					source = "DescendantAdded",
				})
			elseif isScript(inst) then
				dumpLateScript(inst, "DescendantAdded")
			end
		end)
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
				local ser = serializeValue(v.Value)
				livePush({
					dir = "STAT",
					method = "leaderstats",
					name = v.Name,
					path = replacePlayerName(instancePath(v)),
					args = { ser },
					argsText = compactValue(ser),
					source = "leaderstats",
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
				method = "Health",
				name = LocalPlayer.Name,
				argsText = string.format("%.1f/%.1f", hum.Health, hum.MaxHealth),
				source = "Humanoid",
			})
		end))
		trackConn(hum.Died:Connect(function()
			livePush({ dir = "STAT", method = "Died", name = LocalPlayer.Name, argsText = "", source = "Humanoid" })
		end))
	end
end

local function callWithC2SGuard(fn, ...)
	Live.c2sGuard += 1
	local packed = table.pack(pcall(fn, ...))
	Live.c2sGuard -= 1
	if not packed[1] then
		error(packed[2], 0)
	end
	return table.unpack(packed, 2, packed.n)
end

local function logC2S(self, method, args, n, results, retN, source)
	if not Core.running or not Config.liveIntercept then
		return
	end
	if checkCaller and checkCaller() then
		return
	end
	if typeof(self) ~= "Instance" then
		return
	end
	if method == "FireServer" or method == "InvokeServer" then
		if not (self:IsA("RemoteEvent") or self:IsA("RemoteFunction") or self:IsA("UnreliableRemoteEvent")) then
			return
		end
	end
	pushRemoteEvent("C2S", method, self, args, n, results, retN, source)
end

local function hookC2SMethods()
	if not hookFn then
		return 0
	end
	local hooked = 0
	local specs = {
		{ "RemoteEvent", "FireServer" },
		{ "RemoteFunction", "InvokeServer" },
		{ "UnreliableRemoteEvent", "FireServer" },
	}
	for _, spec in ipairs(specs) do
		local className, methodName = spec[1], spec[2]
		local ok = pcall(function()
			local dummy = Instance.new(className)
			local fn = dummy[methodName]
			dummy:Destroy()
			if typeof(fn) ~= "function" then
				return
			end
			local old
			old = hookFn(fn, newClosure(function(self, ...)
				if Live.c2sGuard > 0 then
					return old(self, ...)
				end
				local n = select("#", ...)
				local args = { ... }
				if methodName == "InvokeServer" then
					local results = table.pack(callWithC2SGuard(old, self, ...))
					task.defer(function()
						logC2S(self, methodName, args, n, results, results.n, "hookfunction")
					end)
					return table.unpack(results, 1, results.n)
				end
				local results = table.pack(callWithC2SGuard(old, self, ...))
				task.defer(function()
					logC2S(self, methodName, args, n, nil, nil, "hookfunction")
				end)
				return table.unpack(results, 1, results.n)
			end))
			table.insert(Core.hookedMethods, { className = className, method = methodName, original = old })
			hooked += 1
		end)
		if not ok then
			dbgWarn("hookfunction failed", className, methodName)
		end
	end
	return hooked
end

local function installLiveIntercept()
	if not Config.liveIntercept then
		return
	end
	ensureDir(OUT .. "/live")
	writeText("live/README.txt", table.concat({
		"Live intercept — client collector telemetry after dump.lua runs",
		"",
		"Files:",
		"  net.log / net-live.log  — tab-separated remote traffic (append-only)",
		"  events.jsonl            — unified event records (pending queue flushed then cleared)",
		"  status.json             — event count + hook status",
		"",
		"Event fields: seq, t, clock, dir, remote, class, method, source, args, returns, truncated, thread",
		"",
		"C2S = client firing remotes (FireServer / InvokeServer) via __namecall and hookfunction",
		"S2C = server pushing to you (OnClientEvent; OnClientInvoke callback wrap)",
		"STAT = leaderstats / health changes",
		"INST = new remotes or scripts appearing at runtime",
		"",
		"OnClientInvoke is a callback property, not an event. This collector wraps it.",
	}, "\n"))
	hookAllRemotes()
	watchLeaderstats()
	watchCharacter(LocalPlayer.Character)
	trackConn(LocalPlayer.CharacterAdded:Connect(watchCharacter))
	local methodHooks = hookC2SMethods()
	if methodHooks > 0 then
		log("done", "live C2S method hooks=" .. methodHooks)
	end
	if hookMeta and getNamecall then
		local old
		old = hookMeta(game, "__namecall", newClosure(function(self, ...)
			if Live.c2sGuard > 0 then
				return old(self, ...)
			end
			local n = select("#", ...)
			local args = { ... }
			local method = getNamecall()
			local shouldLog = method == "FireServer" or method == "InvokeServer"
				or method == "PromptProductPurchase" or method == "PromptGamePassPurchase"
			if shouldLog and Core.running and (not checkCaller or not checkCaller()) then
				if method == "InvokeServer" then
					local results = table.pack(callWithC2SGuard(old, self, ...))
					task.defer(function()
						logC2S(self, method, args, n, results, results.n, "namecall")
					end)
					return table.unpack(results, 1, results.n)
				end
				local results = table.pack(callWithC2SGuard(old, self, ...))
				task.defer(function()
					logC2S(self, method, args, n, nil, nil, "namecall")
				end)
				return table.unpack(results, 1, results.n)
			end
			return old(self, ...)
		end))
		Core.namecallHook = old
		log("done", "live C2S namecall hook installed")
	else
		log("warn", "live C2S namecall unavailable (no hookmetamethod)")
	end
	trackConn(RunService.Heartbeat:Connect(function()
		if not Core.running then
			return
		end
		if Live.n > 0 and (os.clock() - Live.lastFlush) > 3 then
			pcall(flushLiveLogs)
		end
		if os.clock() - Live.lastRewrap > 1 then
			Live.lastRewrap = os.clock()
			for remote, wrap in pairs(Live.invokeWrap) do
				local current = nil
				pcall(function()
					current = remote.OnClientInvoke
				end)
				if current ~= wrap then
					wrapOnClientInvoke(remote)
				end
			end
		end
		if Config.snapshotDiff and Snap.n > 0 and Snap.n < Config.maxSnapshots then
			if (os.clock() - Snap.lastAt) > Config.snapshotEvery then
				pcall(takeSnapshot)
			end
		end
	end))
	flushLiveLogs()
	log("done", "LIVE INTERCEPT ACTIVE — play the game, watch live/net.log grow")
	dbg("LIVE", "intercept running →", OUT .. "/live/")
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
		"roblox-dumper " .. VERSION .. " — client collector",
		"================================================",
		"",
		"This is a client-side snapshot + telemetry tool.",
		"It cannot reconstruct unreplicated server source.",
		"",
		"CAN dump from a client executor:",
		"  • LocalScripts, ModuleScripts, and Script instances replicated to this client",
		"  • Scripts returned by getscripts / getrunningscripts / getloadedmodules",
		"  • Nil-parented scripts (getnilinstances)",
		"  • ReplicatedStorage / Workspace / PlayerGui trees (client view)",
		"  • RemoteEvent / RemoteFunction / UnreliableRemoteEvent instances the client can see",
		"  • Client→server and server→client traffic the client actually observes",
		"",
		"CANNOT dump from client alone:",
		"  • ServerScriptService / ServerStorage scripts that never replicate",
		"  • Server-only ModuleScripts never required on the client",
		"  • Server remote handlers and server runtime state",
		"",
		"server-visibility.json is a diagnostic of the client view of those containers.",
		"An empty or filtered tree is expected. It is not a failed server dump.",
		"",
		"For an authorized server dump of a place you own, use a Studio collector",
		"(ScriptEditorService / place file). See ROADMAP.md in the repository.",
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

local function restoreInvokeWraps()
	for remote, wrap in pairs(Live.invokeWrap) do
		pcall(function()
			if remote.OnClientInvoke == wrap then
				remote.OnClientInvoke = Live.invokePrev[remote]
			end
		end)
	end
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
	log("boot", string.format("v%s place=%s (%s) executor=%s", VERSION, tostring(placeId), placeName, exploitName))
	if Config.disableRender then
		pcall(function()
			RunService:Set3dRenderingEnabled(false)
		end)
	end
	local visibility = {
		note = "Diagnostic of the client view of non-replicated containers. This is not a server dump.",
		items = probeNonReplicatedContainers(),
	}
	writeJson("server-visibility.json", visibility)
	writeJson("server-access.json", visibility)
	writeLimitations()
	local metaPayload = {
		at = os.time(),
		version = VERSION,
		mode = "client",
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
			getscripthash = getScriptHash ~= nil,
			hookmetamethod = hookMeta ~= nil,
			hookfunction = hookFn ~= nil,
			getconnections = getConnections ~= nil,
			getinfo = getInfo ~= nil,
			httprequest = httpRequest ~= nil,
		},
	}
	writeJson("meta.json", metaPayload)
	writeJson("metadata.json", metaPayload)
	local scriptList = collectAllScripts()
	local serverClassInstances = 0
	for _, entry in ipairs(scriptList) do
		if entry.class == "Script" then
			serverClassInstances += 1
		end
	end
	log("boot", string.format("found %d scripts (%d Script-class visible to client; serverOnlyRecovered=0)", #scriptList, serverClassInstances))
	writeJson("script-inventory.json", {
		scriptInstances = #scriptList,
		serverClassInstances = serverClassInstances,
		serverOnlyRecovered = 0,
		note = "serverClassInstances are Script-class objects visible to the client, not recovered ServerScriptService source.",
		sample = (function()
			local s = {}
			for i = 1, math.min(20, #scriptList) do
				s[i] = { scriptList[i].path, scriptList[i].class, scriptList[i].source, scriptList[i].discovery }
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
	local hooksInstalled = false
	if Config.hookNet and Config.liveInstallEarly then
		runPhase("hooks", installLiveIntercept)
		writePhase("hooks_early")
		hooksInstalled = true
	end
	runPhase("scripts", function()
		dumpAllScripts(scriptList)
	end)
	runPhase("catalog", writeRemoteCatalog)
	writePhase("catalog_done")
	if Config.hookNet and not hooksInstalled then
		runPhase("hooks", installLiveIntercept)
		writePhase("hooks_done")
	end
	pcall(takeSnapshot)
	pcall(writeManifest)
	pcall(writeAnalysisReport)
	writeJson("complete.json", {
		at = os.time(),
		ok = true,
		version = VERSION,
		mode = "client",
		output = OUT,
		diskPath = DISK_ROOT .. OUT:gsub("/", "\\"),
		writes = WriteStats,
		scriptInstances = #scriptList,
		scriptsDumped = ScriptsDumped,
		serverClassInstances = serverClassInstances,
		serverOnlyRecovered = 0,
		snapshots = Snap.n,
		message = "Client dump complete. Keep playing — live/events.jsonl and snapshots/ update while you play.",
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
			if typeof(conn) == "RBXScriptConnection" then
				conn:Disconnect()
			end
		end)
	end
	Core.connections = {}
	restoreInvokeWraps()
	if Core.namecallHook and hookMeta then
		pcall(function()
			hookMeta(game, "__namecall", Core.namecallHook)
		end)
	end
	pcall(flushLiveLogs)
	pcall(writeRemoteCatalog)
	pcall(takeSnapshot)
	pcall(writeManifest)
	pcall(writeAnalysisReport)
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
					version = VERSION,
					error = tostring(err),
					output = OUT,
					writes = WriteStats,
					scriptsDumped = ScriptsDumped,
				})
			end
		end)
	end
end)
