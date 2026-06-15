repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

-- FINAL DEBUG LOADER:
-- Does NOT use vape/profiles/commit.txt for downloads.
-- It pulls from amrho94/Vape/main so your newest GitHub upload is actually used.
pcall(function()
	if isfile and isfile('vape/guis/new.lua') then
		delfile('vape/guis/new.lua')
	end
end)

local vape
local RAW_BASE = 'https://raw.githubusercontent.com/amrho94/Vape/main/'

local real_loadstring = loadstring

local function compileChunk(source, chunkName)
	local fn, err = real_loadstring(source, chunkName)
	if not fn then
		error(('Failed to compile %s:\n%s'):format(tostring(chunkName), tostring(err)))
	end
	return fn
end

local function runChunk(source, chunkName, ...)
	local fn = compileChunk(source, chunkName)
	local ok, result = pcall(fn, ...)
	if not ok then
		error(('Failed to run %s:\n%s'):format(tostring(chunkName), tostring(result)))
	end
	return result
end

local queue_on_teleport = queue_on_teleport or function() end

local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end

local isfolder = isfolder or function(folder)
	if listfiles then
		local suc = pcall(function()
			listfiles(folder)
		end)
		return suc
	end
	return false
end

local makefolder = makefolder or function(folder)
	error('Executor is missing makefolder. Cannot create folder: '..tostring(folder))
end

local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))

local function ensureFolder(path)
	if not isfolder(path) then
		makefolder(path)
	end
end

local function downloadFile(path, func)
	local shouldRefresh = path:find('vape/guis/', 1, true) and path:sub(-4) == '.lua'
	if shouldRefresh and isfile(path) then
		pcall(function()
			delfile(path)
		end)
	end

	if not isfile(path) then
		local rawPath = select(1, path:gsub('vape/', ''))
		local suc, res = pcall(function()
			return game:HttpGet(RAW_BASE..rawPath, true)
		end)
		if not suc or res == '404: Not Found' or type(res) ~= 'string' or res == '' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end

	return (func or readfile)(path)
end

local function finishLoading()
	vape.Init = nil
	vape:Load()

	task.spawn(function()
		repeat
			vape:Save()
			task.wait(10)
		until not vape.Loaded
	end)

	local teleportedServers
	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.VapeIndependent) then
			teleportedServers = true
			local teleportScript = [[
				shared.vapereload = true
				if shared.VapeDeveloper then
					loadstring(readfile('vape/loader.lua'), 'loader')()
				else
					loadstring(game:HttpGet('https://raw.githubusercontent.com/amrho94/Vape/main/loader.lua', true), 'loader')()
				end
			]]

			if shared.VapeDeveloper then
				teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
			end
			if shared.VapeCustomProfile then
				teleportScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..teleportScript
			end

			vape:Save()
			queue_on_teleport(teleportScript)
		end
	end))

	if not shared.vapereload then
		if not vape.Categories then return end
		if vape.Categories.Main.Options['GUI bind indicator'].Enabled then
			vape:CreateNotification(
				'Finished Loading',
				vape.VapeButton and 'Press the button in the top right to open GUI'
					or 'Press '..table.concat(vape.Keybind, ' + '):upper()..' to open GUI',
				5
			)
		end
	end
end

ensureFolder('vape')
ensureFolder('vape/profiles')
ensureFolder('vape/assets')
ensureFolder('vape/guis')
ensureFolder('vape/games')

if not isfile('vape/profiles/gui.txt') then
	writefile('vape/profiles/gui.txt', 'new')
end

local gui = readfile('vape/profiles/gui.txt')
ensureFolder('vape/assets/'..gui)

local guiSource = downloadFile('vape/guis/'..gui..'.lua')
vape = runChunk(guiSource, 'gui')
shared.vape = vape

if not shared.VapeIndependent then
	runChunk(downloadFile('vape/games/universal.lua'), 'universal')

	if isfile('vape/games/'..game.PlaceId..'.lua') then
		runChunk(readfile('vape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId), ...)
	else
		if not shared.VapeDeveloper then
			local suc, res = pcall(function()
				return game:HttpGet(RAW_BASE..'games/'..game.PlaceId..'.lua', true)
			end)
			if suc and res ~= '404: Not Found' then
				writefile('vape/games/'..game.PlaceId..'.lua', res)
				runChunk(res, tostring(game.PlaceId), ...)
			end
		end
	end

	finishLoading()
else
	vape.Init = finishLoading
	return vape
end
