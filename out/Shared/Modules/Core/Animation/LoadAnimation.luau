return function(animator: Animator, id: string | number): AnimationTrack?
    if not animator then return nil end

    local fullId = "rbxassetid://" .. tostring(id)
    
    local animation
    
    if not animation then
        animation = Instance.new("Animation")
        animation.AnimationId = fullId
    end
    
    return animator:LoadAnimation(animation),animation:Destroy()
end