local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local React = require("@Pckgs/React")
local ReactRoblox = require("@Pckgs/ReactRoblox")

export type UIModule = {
    Name: string,
    Order: number,
    Init:    ((self: UIModule) -> ())?,
    Mount:   ((self: UIModule, parent: Instance) -> ())?,
    Render:  ((self: UIModule) -> any)?,
    Start:   ((self: UIModule) -> ())?,
    Destroy: ((self: UIModule) -> ())?, 
    [string]: any
}

local _screens: { [string]: UIModule } = {}
local _mainRoot: any = nil 

local UI = {
	_hasStarted = false,
	_loadedModules = {} :: { UIModule }
}

local PREFIX = "[UI-System]"

local function App(props: { screens: { UIModule } })
	local children = {}

	for _, uiModule in ipairs(props.screens) do
		local renderFunc = uiModule.Render
		if type(renderFunc) == "function" then
			local element = renderFunc(uiModule)
			if element then
				table.insert(children, element)
			end
		end
	end

	return React.createElement("Folder", { Name = HttpService:GenerateGUID() }, table.unpack(children))
end

function UI:Init()
	if self._hasStarted then return end

	local classesFolder = script.Parent:WaitForChild("Classes")
	local screensToLoad: { UIModule } = {}

	print(PREFIX .. " Initializing UI...")

	for _, child in ipairs(classesFolder:GetChildren()) do
		if child:IsA("ModuleScript") then
			local success: boolean, moduleData: any = xpcall(function()
				return require(child)::UIModule
			end, debug.traceback)

			if success and type(moduleData) == "table" then
				local rawModule: any = moduleData 
				rawModule.Name = child.Name
				rawModule.Order = if type(rawModule.Order) == "number" then rawModule.Order else 999 
				
				local uiModule = rawModule :: UIModule
				_screens[child.Name] = uiModule
				table.insert(screensToLoad, uiModule)
			else
				warn(string.format("%s ❌ Error requiring '%s': %s", PREFIX, child.Name, tostring(moduleData)))
			end
		end
	end

	table.sort(screensToLoad, function(a: UIModule, b: UIModule): boolean
		return a.Order < b.Order
	end)

	print(string.format("%s ✅ Loaded %d modules. Running Lifecycle...", PREFIX, #screensToLoad))

	for _, uiModule in ipairs(screensToLoad) do
		local initFunc = uiModule.Init
		if type(initFunc) == "function" then
			xpcall(function() 
				initFunc(uiModule)
			end, function(err: any)
				warn(string.format("%s ❌ Init Error in %s: %s", PREFIX, uiModule.Name, tostring(err)))
			end)
		end
	end

	local localPlayer = Players.LocalPlayer
	assert(localPlayer, "LocalPlayer is nil")
	
	local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
	assert(playerGui, "PlayerGui was not found")
	
	local mainGui = playerGui:WaitForChild("MainGui", 10)
	assert(mainGui, "MainGui was not found")

	for _, uiModule in ipairs(screensToLoad) do
		local mountFunc = uiModule.Mount
		if type(mountFunc) == "function" then
			xpcall(function() 
				mountFunc(uiModule, mainGui)
			end, function(err: any)
				warn(string.format("%s ❌ Mount Error in %s: %s", PREFIX, uiModule.Name, tostring(err)))
			end)
		end
	end

	xpcall(function()
		_mainRoot = ReactRoblox.createRoot(mainGui)
		_mainRoot:render(React.createElement(App, { screens = screensToLoad }))
	end, function(err: any)
		warn(string.format("%s ❌ React Initialization Error: %s", PREFIX, tostring(err)))
	end)

	for _, uiModule in ipairs(screensToLoad) do
		local startFunc = uiModule.Start
		if type(startFunc) == "function" then
			task.spawn(function()
				xpcall(function() 
					startFunc(uiModule)
				end, function(err: any)
					warn(string.format("%s ❌ Start Error in %s: %s", PREFIX, uiModule.Name, tostring(err)))
				end)
			end)
		end
	end

	self._hasStarted = true
	self._loadedModules = screensToLoad  
	print(PREFIX .. " UI System Fully Booted.")
end

function UI.Get(name: string): UIModule?
	return _screens[name]
end

function UI:Destroy()
	if not self._hasStarted then return end
	
	if _mainRoot then
		xpcall(function()
			_mainRoot:unmount()
		end, function(err)
			warn(string.format("%s ❌ React Unmount Error: %s", PREFIX, tostring(err)))
		end)
		_mainRoot = nil
	end

	for _, uiModule: UIModule in ipairs(self._loadedModules or {}) do
		local destroyFunc = uiModule.Destroy
		if type(destroyFunc) == "function" then
			xpcall(function()
				destroyFunc(uiModule)
			end, function(err)
				warn(string.format("%s ❌ Destroy Error in %s: %s", PREFIX, uiModule.Name, tostring(err)))
			end)
		end
	end

	self._hasStarted = false
	table.clear(self._loadedModules)
	self._loadedModules = {}
	table.clear(_screens)
end

return UI