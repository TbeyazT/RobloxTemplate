--!strict
local StoryAdapter = {}

local ReactRoblox = require(game:GetService('ReplicatedStorage'):FindFirstChild('Packages'):FindFirstChild('ReactRoblox'))
local ProfileService = require(script.Parent.Parent:FindFirstChild('Controllers'):FindFirstChild('ProfileController'):FindFirstChild('Client'))

type ReactNode = any

type UIModuleRef = { 
    Init: ((self: any) -> ())?,
    Mount: ((self: any, parent: Instance) -> ())?,
    Render: ((self: any) -> ReactNode)?,
    Destroy: ((self: any) -> ())?,
    [string]: any
}

function StoryAdapter.wrap(module: UIModuleRef)
    return function(target: Instance)
        if typeof(target) == "Instance" then
            local root: any = nil

            local initFunc = module.Init
            if type(initFunc) == "function" then
                initFunc(module)
            end
            
            local mountFunc = module.Mount
            if type(mountFunc) == "function" then
                mountFunc(module, target)
            end

            local renderFunc = module.Render
            if type(renderFunc) == "function" then
                local element = renderFunc(module)
                if element then
                    xpcall(function()
                        root = ReactRoblox.createRoot(target)
                        root:render(element)
                    end, function(err)
                        warn("[StoryAdapter] ❌ React Render Error: " .. tostring(err))
                    end)
                end
            end

            return function()
                if root then
                    xpcall(function()
                        root:unmount()
                    end, function(err)
                        warn("[StoryAdapter] ❌ React Unmount Error: " .. tostring(err))
                    end)
                end

                local destroyFunc = module.Destroy
                if type(destroyFunc) == "function" then
                    destroyFunc(module)
                end
                
                ProfileService:Destroy()
            end
        end
        return function() end
    end
end

return StoryAdapter