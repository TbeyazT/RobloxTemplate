--!strict
local React = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('React'))

local Button = require(script.Parent.Parent.Parent:FindFirstChild('Classes'):FindFirstChild('UI'):FindFirstChild('Button'))

local CounterScreen = {}
CounterScreen.Order = 10 

local function CounterApp()
    local count, setCount = React.useState(0)

    React.useEffect(function()
        print("[CounterScreen] React component mounted!")
        return function()
            print("[CounterScreen] React component unmounted!")
        end
    end, {})

    return React.createElement("Frame", {
        Size = UDim2.fromScale(0.26, 0.4),
        Position = UDim2.fromScale(0.5, 0.5),
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

        Button = React.createElement(Button, {
            Size = UDim2.fromScale(0.4, 0.2),
            Position = UDim2.fromScale(0.5, 0.6),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(0, 162, 255),
            Text = "",
            
            [React.Event.Activated] = function()
                setCount(count + 1)
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
        }
        ,{
            ButtonCorner = React.createElement("UICorner", {
                CornerRadius = UDim.new(0, 4),
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