opt server_output = "ServerScriptService/Constants/Net.luau"
opt client_output = "Shared/Net.luau"

event DataLoaded = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Player: Instance,
        Data: map { [string.utf8]: unknown }
    }
}

event DataUpdated = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Player: Instance,
        Key: string.utf8,
        Value: unknown
    }
}

event PlayAudio = {
    from: Server,
    call: SingleAsync,
    data: struct {
        SoundName: string.utf8,
        properties: unknown
    }
}

event Notify = {
    from: Server,
    type: Reliable,
    call: ManyAsync,
    data: struct {
        Text: string.utf8,
        Duration: f32,
        TextColor: Color3?,
        FrameScale: f32?,
        UseRichAnimation: boolean?
    }
}

funct ChangeSetting = {
    call: Async,
    args: string.utf8,
    rets: boolean
}

funct EditTutorial = {
    call: Async,
    args: struct {
        Key: string.utf8,
        Value: unknown
    }
}

funct Rebirth = {
    call: Async,
    args: boolean,
    rets: unknown
}

--product
event PromptProduct = {
    from: Client,
    type: Reliable,
    call: SingleAsync,
    data: string.utf8,
}

--inventory

event EquipTool = {
    from:Client,
    type:Reliable,
    call:SingleAsync,
    data: string.utf8 -- maybe id soon
}

event UnequipTool = {
    from:Client,
    type:Reliable,
    call:SingleAsync,
    data: string.utf8 -- maybe id soon
}

--enemies

event ReplicateEnemy = {
    from:Server,
    type:Reliable,
    call:SingleAsync,
    data: struct {
        Name:string.utf8,
        ID:string.utf8,
        Position: Vector3
    }
}