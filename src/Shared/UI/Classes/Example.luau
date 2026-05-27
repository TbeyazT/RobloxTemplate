--!strict
local React = require("@Pckgs/React")
local ReactSpring = require("@Pckgs/ReactSpring")

local CounterScreen = {}
CounterScreen.Order = 10 

local function CounterApp()
    local count, setCount = React.useState(0)
    local hovered, setHovered = React.useState(false)
    local pressed, setPressed = React.useState(false)

    -- 1. Main Frame Entrance Animation (Slides up and fades in on mount)
    local frameStyles = ReactSpring.useSpring({
        from = {
            Position = UDim2.fromScale(0.5, 0.55),
            BackgroundTransparency = 1,
        },
        to = {
            Position = UDim2.fromScale(0.5, 0.5),
            BackgroundTransparency = 0,
        },
        config = {
            damping = 0.05, -- Standard comfortable damping
            frequency = 0.2, -- Smooth 300ms transition on mount
        }
    })

    -- 2. Responsive UI Spring Setup
    local buttonStyles, buttonApi = ReactSpring.useSpring(function()
        return {
            size = UDim2.fromScale(0.4, 0.2),
            config = {
                damping = 0.09, -- Creates a satisfying, responsive bounce
                frequency = 0.15, -- Super snappy 150ms settling time
            }
        }
    end)

    -- Handle interactive scale calculations seamlessly
    React.useEffect(function()
        local targetSize
        if pressed then
            targetSize = UDim2.fromScale(0.35, 0.175) -- Smooth compression scale
        elseif hovered then
            targetSize = UDim2.fromScale(0.44, 0.22)  -- Hover magnification scale
        else
            targetSize = UDim2.fromScale(0.4, 0.2)    -- Default idle scale
        end

        buttonApi.start({
            size = targetSize,
        })
    end, { hovered, pressed })

    React.useEffect(function()
        print("[CounterScreen] React component mounted!")
        return function()
            print("[CounterScreen] React component unmounted!")
        end
    end, {})

    return React.createElement("Frame", {
        Size = UDim2.fromScale(0.26, 0.4),
        Position = frameStyles.Position,
        BackgroundTransparency = frameStyles.BackgroundTransparency,
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(35, 35, 40),
        BorderSizePixel = 0,
    }, {
        UICorner = React.createElement("UICorner", {
            CornerRadius = UDim.new(0, 8),
        }),

        Title = React.createElement("TextLabel", {
            Size = UDim2.new(1, 0, 0.1, 0),
            Position = UDim2.fromScale(0, 0.04),
            BackgroundTransparency = 1,
            Text = "React Story Counter",
            TextColor3 = Color3.fromRGB(240, 240, 240),
            TextScaled = true,
            Font = Enum.Font.SourceSansBold,
        }),

        Button = React.createElement("ImageButton", {
            Size = buttonStyles.size,
            Position = UDim2.fromScale(0.5, 0.6),
            AnchorPoint = Vector2.new(0.5, 0.5),
            
            [React.Event.Activated] = function()
                setCount(count + 1)
            end,
            [React.Event.MouseEnter] = function()
                setHovered(true)
            end,
            [React.Event.MouseLeave] = function()
                setHovered(false)
                setPressed(false) -- Reset click if the user drags mouse off the button
            end,
            [React.Event.MouseButton1Down] = function()
                setPressed(true)
            end,
            [React.Event.MouseButton1Up] = function()
                setPressed(false)
            end,
        }, {
            Label = React.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                BackgroundTransparency = 1,
                Text = "Clicks: " .. tostring(count),
                TextColor3 = Color3.fromRGB(255, 255, 255),
                TextSize = 16,
                TextScaled = true,
                Font = Enum.Font.SourceSansSemibold,
            }),
        })
    })
end

function CounterScreen:Init()
    print("[CounterScreen] Initializing data layer...")
end

function CounterScreen:Render()
    return React.createElement(CounterApp)
end

function CounterScreen:Start()
    print("[CounterScreen] Active and listening.")
end

function CounterScreen:Destroy()
    print("[CounterScreen] Module clean-up completed.")
end

return CounterScreen