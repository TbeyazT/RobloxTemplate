local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

export type ActionCallback = (actionName: string, state: Enum.UserInputState, input: InputObject, gameProcessed: boolean) -> ()

local InputClass = {}
InputClass.__index = InputClass

function InputClass.new()
	local self = setmetatable({}, InputClass)

	self.HoveredInstance = nil
	
	self._bindings = {}     
	self._connections = {}  
	self._hoverCallback = nil

	self:InitHoverDetection()
	self:InitInputListeners()

	return self
end

local function matchesInput(input: InputObject, allowedInputs: {any}): boolean
	for _, allowed in ipairs(allowedInputs) do
		if allowed == input.KeyCode or allowed == input.UserInputType then
			return true
		end
	end
	return false
end

function InputClass:GetMousePosition2D(): Vector2
	local mousePos = UserInputService:GetMouseLocation()
	local viewportSize = workspace.CurrentCamera.ViewportSize
	local x = mousePos.X / viewportSize.X
	local y = mousePos.Y / viewportSize.Y
	return Vector2.new(x, y)
end

function InputClass:GetMouseWorldRay(BlackList: {Instance} | Instance | nil): RaycastResult?
	local screenMousePos = UserInputService:GetMouseLocation()
	local unitRay = Camera:ViewportPointToRay(screenMousePos.X, screenMousePos.Y)

	local filterTable = {}

	if LocalPlayer.Character then
		table.insert(filterTable, LocalPlayer.Character)
	end

	if BlackList then
		if typeof(BlackList) == "table" then
			for _, item in ipairs(BlackList) do
				table.insert(filterTable, item)
			end
		else
			table.insert(filterTable, BlackList)
		end
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = filterTable
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	return workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
end

function InputClass:IsMobile(): boolean
	return UserInputService.TouchEnabled 
end

function InputClass:IsPC(): boolean
	return not UserInputService.TouchEnabled
end

function InputClass:HasKeyboard(): boolean
	return UserInputService.KeyboardEnabled
end

function InputClass:BindAction(actionName: string, callback: ActionCallback, inputs: {Enum.KeyCode | Enum.UserInputType})
	self._bindings[actionName] = {
		Callback = callback,
		Inputs = inputs
	}
end

function InputClass:UnbindAction(actionName: string)
	self._bindings[actionName] = nil
end

function InputClass:BindHover(callback: (hoveredInstance: Instance?) -> ())
	self._hoverCallback = callback
end

function InputClass:InitHoverDetection()
	local conn = RunService.RenderStepped:Connect(function()
		local result = self:GetMouseWorldRay({})
		local hit = result and result.Instance or nil

		if hit ~= self.HoveredInstance then
			self.HoveredInstance = hit
			if self._hoverCallback then
				self._hoverCallback(hit)
			end
		end
	end)
	
	table.insert(self._connections, conn)
end

function InputClass:InitInputListeners()
	local function processInput(input: InputObject, state: Enum.UserInputState, gameProcessed: boolean)
		for actionName, binding in pairs(self._bindings) do
			if matchesInput(input, binding.Inputs) then
				task.spawn(binding.Callback, actionName, state, input, gameProcessed)
			end
		end
	end

	local beganConn = UserInputService.InputBegan:Connect(function(input, gpe)
		processInput(input, Enum.UserInputState.Begin, gpe)
	end)

	local endedConn = UserInputService.InputEnded:Connect(function(input, gpe)
		processInput(input, Enum.UserInputState.End, gpe)
	end)

	local changedConn = UserInputService.InputChanged:Connect(function(input, gpe)
		processInput(input, Enum.UserInputState.Change, gpe)
	end)

	table.insert(self._connections, beganConn)
	table.insert(self._connections, endedConn)
	table.insert(self._connections, changedConn)
end

function InputClass:Destroy()
	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end
	table.clear(self._connections)
	table.clear(self._bindings)
	self._hoverCallback = nil
	self.HoveredInstance = nil
end

return InputClass