local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local SoundController = require("../../Controllers/SoundController/Client")

local RunContext = require("@Pckgs/RunContext")
local React = require("@Pckgs/React")

local RichTextLabel = require("@UI/Instances/Label")

local Net = require("@Shared/Net")

local TYPE_SPEED = 0.03
local LETTER_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FRAME_IN_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SCALE_IN_TWEEN = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SCALE_OUT_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)

export type NotificationData = {
    id: string,
    Text: string,
    FrameScale: number?,
    UseRichAnimation: boolean?,
    TextColor: Color3?,
    Duration: any?,
    UpdateCallback: ((letters: { [number]: TextLabel }, dt: number) -> ())?,
}

type NotificationInterface = {
    Name: string,
    _dispatch: ((NotificationData) -> ())?,
    _updateText: ((id: string, text: string) -> ())?,
    _cancelNotif: ((id: string) -> ())?,
    _clearAll: (() -> ())?,
    SendNotification: (self: NotificationInterface, Data: any) -> string?,
    UpdateNotificationText: (self: NotificationInterface, id: string, text: string) -> boolean,
    CancelNotification: (self: NotificationInterface, id: string) -> boolean,
    RemoveNotification: (self: NotificationInterface, id: string) -> boolean,
    DismissNotification: (self: NotificationInterface, id: string) -> boolean,
    ClearNotification: (self: NotificationInterface, id: string) -> boolean,
    ClearAll: (self: NotificationInterface) -> (),
    Init: (self: NotificationInterface) -> (),
    Render: (self: NotificationInterface) -> any,
    Start: (self: NotificationInterface) -> (),
    Destroy: (self: NotificationInterface) -> (),
}

local Notification: NotificationInterface = {
    Name = script.Name,
    _dispatch = nil,
    _updateText = nil,
    _cancelNotif = nil,
    _clearAll = nil,
} :: any

local function NotificationItem(props: { data: NotificationData, onComplete: () -> () })
    local data = props.data
    local frameRef = React.useRef(nil :: Frame?)
    local textLabelRef = React.useRef(nil :: TextLabel?)
    local uiScaleRef = React.useRef(nil :: UIScale?)
    local uiStrokeRef = React.useRef(nil :: UIStroke?)
    local letterRefsMap = React.useRef({} :: { [number]: TextLabel })

    React.useEffect(function()
        if not data.UpdateCallback or not data.UseRichAnimation then return end

        local connection = RunService.RenderStepped:Connect(function(dt)
            data.UpdateCallback(letterRefsMap.current, dt)
        end)

        return function()
            connection:Disconnect()
        end
    end, { data.UpdateCallback, data.UseRichAnimation })

    React.useEffect(function()
        local textLabel = textLabelRef.current
        if not textLabel then return end

        if not data.UseRichAnimation then
            textLabel.Text = data.Text
            if textLabel.MaxVisibleGraphemes > 0 then
                textLabel.MaxVisibleGraphemes = utf8.len(data.Text) :: number
            end
        end
    end, { data.Text })

    React.useEffect(function()
        local frame = frameRef.current
        local uiScale = uiScaleRef.current
        local uiStroke = uiStrokeRef.current
        if not frame or not uiScale then return end

        local isCancelled = false
        local durationFired = false
        local durationConn: any = nil
        local waitingThread: thread? = nil

        -- Connect duration signal IMMEDIATELY on mount so events are never missed
        local duration = data.Duration
        if typeof(duration) == "table" or typeof(duration) == "userdata" then
            local function onSignalFired()
                durationFired = true
                if waitingThread and coroutine.status(waitingThread) == "suspended" then
                    task.spawn(waitingThread)
                end
            end

            if typeof(duration.Once) == "function" then
                pcall(function() durationConn = duration:Once(onSignalFired) end)
            elseif typeof(duration.Connect) == "function" then
                pcall(function() durationConn = duration:Connect(onSignalFired) end)
            end
        end

        task.spawn(function()
            -- Fade & Scale In
            TweenService:Create(frame, FRAME_IN_TWEEN, { BackgroundTransparency = 0 }):Play()
            TweenService:Create(uiScale, SCALE_IN_TWEEN, { Scale = 1 }):Play()
            if uiStroke then
                TweenService:Create(uiStroke, FRAME_IN_TWEEN, { Transparency = 0 }):Play()
            end

            task.wait(0.1)
            if isCancelled then return end

            -- Typewriter Effect
            local textLabel = textLabelRef.current
            if not data.UseRichAnimation and textLabel then
                textLabel.Text = data.Text
                textLabel.MaxVisibleGraphemes = 0
                textLabel.TextTransparency = 0
                if data.TextColor then textLabel.TextColor3 = data.TextColor end

                local textLen = utf8.len(data.Text) or 0
                for i = 1, textLen do
                    if isCancelled or durationFired then break end -- Cancel typewriter if duration signal fired
                    textLabel.MaxVisibleGraphemes = i
                    pcall(function()
                        SoundController:PlaySound("Typewriter")
                    end)
                    task.wait(TYPE_SPEED)
                end
                textLabel.MaxVisibleGraphemes = -1
            end

            -- Wait for Duration (Signal or Number)
            if not isCancelled and not durationFired then
                if typeof(duration) == "number" then
                    local elapsed = 0
                    while elapsed < duration and not isCancelled and not durationFired do
                        task.wait(0.05)
                        elapsed += 0.05
                    end
                elseif typeof(duration) == "table" or typeof(duration) == "userdata" then
                    if not durationFired then
                        waitingThread = coroutine.running()
                        coroutine.yield()
                    end
                else
                    task.wait(2)
                end
            end

            if durationConn then
                pcall(function() durationConn:Disconnect() end)
                durationConn = nil
            end

            if isCancelled then return end

            -- Fade & Scale Out
            local outInfo = TweenInfo.new(0.3, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
            TweenService:Create(frame, outInfo, { BackgroundTransparency = 1 }):Play()
            TweenService:Create(uiScale, SCALE_OUT_TWEEN, { Scale = 0 }):Play()
            if uiStroke then
                TweenService:Create(uiStroke, outInfo, { Transparency = 1 }):Play()
            end
            if textLabel then
                TweenService:Create(textLabel, outInfo, { TextTransparency = 1 }):Play()
            end

            task.wait(0.35)
            if isCancelled then return end
            props.onComplete()
        end)

        return function()
            isCancelled = true
            if durationConn then
                pcall(function() durationConn:Disconnect() end)
            end
        end
    end, {})

    local baseSize = UDim2.new(2.4, 0, 0.3, 0)
    local finalSize = if data.FrameScale then
        UDim2.fromScale(baseSize.X.Scale * data.FrameScale, baseSize.Y.Scale * data.FrameScale)
    else
        baseSize

    local textFont = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

    local RichLabelComponent = typeof(RichTextLabel) == "table" and RichTextLabel.App or RichTextLabel

    return React.createElement("Frame", {
        ref = frameRef,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = finalSize,
        BackgroundTransparency = 1,
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
    }, {
        UIScale = React.createElement("UIScale", {
            ref = uiScaleRef,
            Scale = 0,
        }),

        UIStroke = React.createElement("UIStroke", {
            ref = uiStrokeRef,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
            Color = Color3.fromRGB(0, 0, 0),
            LineJoinMode = Enum.LineJoinMode.Round,
            StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
            Thickness = 0,
            Transparency = 1,
        }),

        TextContent = if data.UseRichAnimation then
            React.createElement(RichLabelComponent, {
                Text = data.Text,
                TextSize = 18,
                TextColor3 = data.TextColor or Color3.fromRGB(255, 255, 255),
                TextScaled = true,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center,
                FontFace = textFont,
                Size = UDim2.fromScale(0.96, 0.68),
                Position = UDim2.fromScale(0.5, 0.5),
                AnchorPoint = Vector2.new(0.5, 0.5),
                renderLetter = function(letter)
                    return React.createElement("TextLabel", {
                        ref = function(rbx: TextLabel?)
                            letterRefsMap.current[letter.Index] = rbx :: any
                        end,
                        Text = letter.Char,
                        TextColor3 = data.TextColor or Color3.fromRGB(255, 255, 255),
                        TextSize = letter.TextSize,
                        TextScaled = false,
                        BackgroundTransparency = 1,
                        TextTransparency = 0,
                        Size = letter.Size,
                        Position = letter.Position,
                        TextXAlignment = Enum.TextXAlignment.Center,
                        TextYAlignment = Enum.TextYAlignment.Center,
                        FontFace = textFont,
                    })
                end,
            })
        else
            React.createElement("TextLabel", {
                ref = textLabelRef,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.fromScale(0.96, 0.68),
                Position = UDim2.fromScale(0.5, 0.5),
                BackgroundTransparency = 1,
                TextScaled = true,
                Text = "",
                TextColor3 = data.TextColor or Color3.fromRGB(255, 255, 255),
                TextTransparency = 1,
                FontFace = textFont,
            }),

        UIGradient = React.createElement("UIGradient", {
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.5, 0.15),
                NumberSequenceKeypoint.new(1, 1),
            }),
        }),
    })
end

local function NotificationList()
    local notifications, setNotifications = React.useState({} :: { NotificationData })

    React.useEffect(function()
        Notification._dispatch = function(newNotification: NotificationData)
            setNotifications(function(prev)
                local newArray = table.clone(prev)
                table.insert(newArray, newNotification)
                return newArray
            end)
        end

        Notification._updateText = function(id: string, newText: string)
            setNotifications(function(prev)
                local newArray = table.clone(prev)
                for _, item in ipairs(newArray) do
                    if item.id == id then
                        item.Text = newText
                        break
                    end
                end
                return newArray
            end)
        end

        Notification._cancelNotif = function(id: string)
            setNotifications(function(prev)
                local newArray = table.clone(prev)
                for k, v in ipairs(newArray) do
                    if v.id == id then
                        table.remove(newArray, k)
                        break
                    end
                end
                return newArray
            end)
        end

        Notification._clearAll = function()
            setNotifications({})
        end

        return function()
            Notification._dispatch = nil
            Notification._updateText = nil
            Notification._cancelNotif = nil
            Notification._clearAll = nil
        end
    end, {})

    local children = {
        UIListLayout = React.createElement("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            Padding = UDim.new(0, 0),
        }),
    }

    for _, item in ipairs(notifications) do
        children[item.id] = React.createElement(NotificationItem, {
            data = item,
            onComplete = function()
                setNotifications(function(prev)
                    local newArray = table.clone(prev)
                    for k, v in ipairs(newArray) do
                        if v.id == item.id then
                            table.remove(newArray, k)
                            break
                        end
                    end
                    return newArray
                end)
            end,
        })
    end

    return React.createElement("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromScale(0.42, 0.200),
        Position = UDim2.fromScale(0.5, 0.13),
        BackgroundTransparency = 1,
        ZIndex = 3,
        Name = "TbeyazT",
    }, children)
end

function Notification:SendNotification(Data: any): string?
    if not Data or not Data.Text then return nil end

    local notificationId = HttpService:GenerateGUID(false)
    local payload: NotificationData = {
        id = notificationId,
        Text = Data.Text,
        FrameScale = Data.FrameScale,
        UseRichAnimation = Data.UseRichAnimation,
        TextColor = Data.TextColor,
        Duration = Data.Duration,
        UpdateCallback = Data.UpdateCallback,
    }

    local dispatch = self._dispatch
    if dispatch then
        dispatch(payload)
    end

    return notificationId
end

function Notification:UpdateNotificationText(id: string, text: string): boolean
    local updater = self._updateText
    if updater then
        updater(id, text)
        return true
    end
    return false
end

function Notification:CancelNotification(id: string): boolean
    local canceler = self._cancelNotif
    if canceler then
        canceler(id)
        return true
    end
    return false
end

function Notification:RemoveNotification(id: string): boolean
    return self:CancelNotification(id)
end

function Notification:DismissNotification(id: string): boolean
    return self:CancelNotification(id)
end

function Notification:ClearNotification(id: string): boolean
    return self:CancelNotification(id)
end

function Notification:ClearAll()
    local clear = self._clearAll
    if clear then
        clear()
    end
end

function Notification:Init(): ()
    Net.Notify.On(function(data)
        self:SendNotification(data)
    end)
end

function Notification:Render(): any
    return React.createElement(NotificationList)
end

function Notification:Start()
end

function Notification:Destroy()
end

return Notification