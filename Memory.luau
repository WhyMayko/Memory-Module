Memory = { Offsets = nil, Types = nil }

local players = game:GetService("Players")
local httpservice = game:GetService("HttpService")

local urls_offsets = {
    "https://offsets.imtheo.lol/offsets.json",
}
local urls_types = {
    "https://offsets.imtheo.lol/types.json",
}

local type_map = {
    float = "float", double = "double", int = "int", short = "int", bool = "bool", byte = "byte", BYTE = "byte",
    ["unsigned char"] = "byte", string = "string", ["unsigned __int64"] = "uintptr_t",
    uintptr_t = "uintptr_t", pointer = "uintptr_t", Vector3 = "vector3", Vector2 = "vector2",
    Color3 = "color3", Matrix3x3 = "matrix", UDim2 = "udim2"
}

local primitive_props = {
    position = "Position",
    rotation = "Rotation",
    size = "Size",
    assemblylinearvelocity = "AssemblyLinearVelocity",
    assemblyangularvelocity = "AssemblyAngularVelocity",
    velocity = "AssemblyLinearVelocity"
}

local inheritance = {
    Part = {"BasePart", "Instance"},
    MeshPart = {"MeshPart", "BasePart", "Instance"},
    WedgePart = {"BasePart", "Instance"},
    CornerWedgePart = {"BasePart", "Instance"},
    TrussPart = {"BasePart", "Instance"},
    Seat = {"Seat", "BasePart", "Instance"},
    VehicleSeat = {"VehicleSeat", "BasePart", "Instance"},
    SpawnLocation = {"SpawnLocation", "BasePart", "Instance"},
    UnionOperation = {"UnionOperation", "BasePart", "Instance"},
    Frame = {"GuiObject", "GuiBase2D", "Instance"},
    ScrollingFrame = {"GuiObject", "GuiBase2D", "Instance"},
    TextLabel = {"GuiObject", "GuiBase2D", "Instance"},
    TextButton = {"GuiObject", "GuiBase2D", "Instance"},
    TextBox = {"GuiObject", "GuiBase2D", "Instance"},
    ImageLabel = {"GuiObject", "GuiBase2D", "Instance"},
    ImageButton = {"GuiObject", "GuiBase2D", "Instance"},
    ViewportFrame = {"GuiObject", "GuiBase2D", "Instance"},
    VideoFrame = {"GuiObject", "GuiBase2D", "Instance"},
    ScreenGui = {"GuiObject", "GuiBase2D", "Instance"},
    BillboardGui = {"GuiObject", "GuiBase2D", "Instance"},
    SurfaceGui = {"GuiObject", "GuiBase2D", "Instance"},
    BloomEffect = {"BloomEffect", "Instance"},
    BlurEffect = {"BlurEffect", "Instance"},
    ColorCorrectionEffect = {"ColorCorrectionEffect", "Instance"},
    ColorGradingEffect = {"ColorGradingEffect", "Instance"},
    DepthOfFieldEffect = {"DepthOfFieldEffect", "Instance"},
    SunRaysEffect = {"SunRaysEffect", "Instance"},
    Humanoid = {"Humanoid", "Instance"},
    Camera = {"Camera", "Instance"},
    Player = {"Player", "Instance"},
    Team = {"Team", "Instance"},
    Tool = {"Tool", "Instance"},
    AnimationTrack = {"AnimationTrack", "Instance"},
    Animator = {"Animator", "Instance"},
    ParticleEmitter = {"ParticleEmitter", "Instance"},
    Beam = {"Beam", "Instance"},
    Attachment = {"Attachment", "Instance"},
    SpecialMesh = {"SpecialMesh", "Instance"},
    ProximityPrompt = {"ProximityPrompt", "Instance"},
    ClickDetector = {"ClickDetector", "Instance"},
    DragDetector = {"DragDetector", "Instance"},
    Lighting = {"Lighting", "Instance"},
    Atmosphere = {"Atmosphere", "Instance"},
    Sky = {"Sky", "Instance"},
    Terrain = {"Terrain", "Instance"},
    Sound = {"Sound", "Instance"},
    LocalScript = {"LocalScript", "Script", "Instance"},
    ModuleScript = {"ModuleScript", "Instance"},
    Script = {"Script", "Instance"},
    Workspace = {"Workspace", "World", "Instance"},
    World = {"World", "Instance"},
    DataModel = {"DataModel", "Instance"},
    RunService = {"RunService", "Instance"},
    UserInputService = {"UserInputService", "Instance"}
}

local function fetch(urls)
    for _, u in ipairs(urls) do
        local r = game:HttpGet(u)
        if r and #r > 10 then
            local d = httpservice:JSONDecode(r)
            if d then return d.Offsets or d.Types or d end
        end
    end
    assert(false, "failed to fetch remote manifest!")
end

function Memory:init(o, t)
    self.Offsets = o or fetch(urls_offsets)
    self.Types = t or fetch(urls_types)
    return self
end

function Memory:resolve(inst, prop)
    if not self.Offsets then self:init() end
    local pl = prop:lower()
    local is_inst = typeof(inst) == "Instance"

    local function match(cls)
        local o = self.Offsets[cls]
        if not o then return end
        for k, off in pairs(o) do
            local kl = k:lower()
            if kl == pl or (pl == "enabled" and kl == "screengui_enabled") then
                local raw = self.Types[cls] and self.Types[cls][k] or "float"
                return off, type_map[raw] or "float", cls, k
            end
        end
    end

    if is_inst then
        local c = inst.ClassName
        if c == "UIGradient" then
            if pl == "offset" then return 296, "vector2", "UIGradient", "Offset" end
            if pl == "x" then return 296, "float", "UIGradient", "X" end
            if pl == "y" then return 300, "float", "UIGradient", "Y" end
        end

        local is_part = c == "Part" or c == "MeshPart" or c == "BasePart" or (inheritance[c] and inheritance[c][1] == "BasePart")
        if is_part and primitive_props[pl] then
            local pk = primitive_props[pl]
            local po = self.Offsets.Primitive and self.Offsets.Primitive[pk]
            if po then
                local pkind = (pk == "Rotation") and "matrix" or "vector3"
                return po, pkind, "Primitive", pk
            end
        end

        local off, kind, cls, k = match(c)
        if off then return off, kind, cls, k end

        local chain = inheritance[c]
        if chain then
            for _, base in ipairs(chain) do
                off, kind, cls, k = match(base)
                if off then return off, kind, cls, k end
            end
        end
        off, kind, cls, k = match("Instance")
        if off then return off, kind, cls, k end
    end
    return match("Misc")
end

function Memory:read(kind, addr)
    if kind == "string" then
        local cap = memory_read("uintptr_t", addr + 24)
        local ptr = (cap >= 16) and memory_read("uintptr_t", addr) or addr
        return memory_read("string", ptr)
    elseif kind == "vector2" then
        return Vector2.new(memory_read("float", addr), memory_read("float", addr + 4))
    elseif kind == "vector3" then
        return Vector3.new(memory_read("float", addr), memory_read("float", addr + 4), memory_read("float", addr + 8))
    elseif kind == "color3" then
        return Color3.new(memory_read("float", addr), memory_read("float", addr + 4), memory_read("float", addr + 8))
    elseif kind == "udim2" then
        return UDim2.new(
            memory_read("float", addr),
            memory_read("int", addr + 4),
            memory_read("float", addr + 8),
            memory_read("int", addr + 12)
        )
    elseif kind == "bool" then
        return memory_read("byte", addr) ~= 0
    end
    return memory_read(kind, addr)
end

function Memory:write(kind, addr, val)
    if type(val) == "boolean" or kind == "bool" then
        memory_write("byte", addr, val and 1 or 0)
    elseif kind == "string" then
        local cap = memory_read("uintptr_t", addr + 24)
        local str = tostring(val)
        local ptr = (cap >= 16) and memory_read("uintptr_t", addr) or addr
        for i = 1, #str do memory_write("byte", ptr + i - 1, string.byte(str, i)) end
        memory_write("byte", ptr + #str, 0)
        memory_write("uintptr_t", addr + 16, #str)
    elseif kind == "vector2" then
        memory_write("float", addr, val.X)
        memory_write("float", addr + 4, val.Y)
    elseif kind == "vector3" then
        memory_write("float", addr, val.X)
        memory_write("float", addr + 4, val.Y)
        memory_write("float", addr + 8, val.Z)
    elseif kind == "color3" then
        memory_write("float", addr, val.R)
        memory_write("float", addr + 4, val.G)
        memory_write("float", addr + 8, val.B)
    elseif kind == "udim2" then
        memory_write("float", addr, val.X.Scale)
        memory_write("int", addr + 4, val.X.Offset)
        memory_write("float", addr + 8, val.Y.Scale)
        memory_write("int", addr + 12, val.Y.Offset)
    elseif kind == "matrix" then
        for i = 1, 9 do memory_write("float", addr + (i - 1) * 4, val[i]) end
    else
        memory_write(kind, addr, val)
    end
end

function Memory:get(inst, prop)
    local addr = (typeof(inst) == "Instance") and inst.Address or inst
    local off, kind, cls = self:resolve(inst, prop)
    assert(off, "property offset not found for " .. tostring(prop) .. "!")
    if cls == "Primitive" then
        addr = memory_read("uintptr_t", addr + self.Offsets.BasePart.Primitive)
        assert(addr and addr > 4096, "primitive pointer invalid!")
    end
    return self:read(kind, addr + off)
end

function Memory:set(inst, prop, value)
    local addr = (typeof(inst) == "Instance") and inst.Address or inst
    local off, kind, cls, k = self:resolve(inst, prop)
    assert(off, "property offset not found for " .. tostring(prop) .. "!")
    if cls == "Primitive" then
        addr = memory_read("uintptr_t", addr + self.Offsets.BasePart.Primitive)
        assert(addr and addr > 4096, "primitive pointer invalid!")
    end
    self:write(kind, addr + off, value)
    if cls == "Humanoid" and k:lower() == "walkspeed" and self.Offsets.Humanoid.WalkspeedCheck then
        self:write("float", addr + self.Offsets.Humanoid.WalkspeedCheck, value)
    end
end

function Memory:gradient(inst)
    local target = (type(inst) == "table" and inst.Instance) and inst.Instance or inst
    local grad = target
    if typeof(target) == "Instance" and target.ClassName ~= "UIGradient" then
        grad = target:FindFirstChildOfClass("UIGradient")
    end
    if not grad then return nil end
    local addr = (typeof(grad) == "Instance") and grad.Address or grad
    if not (addr and addr > 4096) then return nil end

    return setmetatable({ Instance = grad, Address = addr }, {
        __index = function(_, k)
            local kl = tostring(k):lower()
            if kl == "offset" then
                return Vector2.new(memory_read("float", addr + 296), memory_read("float", addr + 300))
            elseif kl == "x" then
                return memory_read("float", addr + 296)
            elseif kl == "y" then
                return memory_read("float", addr + 300)
            elseif kl == "ready" then
                return memory_read("float", addr + 300) <= 0.255
            elseif kl == "progress" then
                local y = memory_read("float", addr + 300)
                return math.clamp(1.0 - (y - 0.25) / 0.50, 0, 1)
            end
        end,
        __newindex = function(_, k, v)
            local kl = tostring(k):lower()
            if kl == "offset" then
                memory_write("float", addr + 296, v.X)
                memory_write("float", addr + 300, v.Y)
            elseif kl == "x" then
                memory_write("float", addr + 296, v)
            elseif kl == "y" then
                memory_write("float", addr + 300, v)
            end
        end
    })
end

function Memory:bind(inst)
    local addr = (typeof(inst) == "Instance") and inst.Address or inst
    return setmetatable({ Instance = inst, Address = addr }, {
        __index = function(_, k)
            if tostring(k):lower() == "gradient" then
                return self:gradient(inst)
            end
            return self:get(inst, k)
        end,
        __newindex = function(_, k, v) self:set(inst, k, v) end
    })
end

function Memory:lookat(part, target_pos)
    local inst = (type(part) == "table" and part.Instance) and part.Instance or part
    local prim = memory_read("uintptr_t", inst.Address + self.Offsets.BasePart.Primitive)
    if not (prim and prim > 4096) then return false end
    local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = CFrame.lookAt(inst.Position, target_pos):GetComponents()
    self:write("matrix", prim + self.Offsets.Primitive.Rotation, { r00, r01, r02, r10, r11, r12, r20, r21, r22 })
    return true
end

function Memory:animations(animator)
    local inst = (type(animator) == "table" and animator.Instance) and animator.Instance or animator
    if typeof(inst) == "Instance" and inst.ClassName ~= "Animator" then
        inst = inst:FindFirstChildOfClass("Animator")
    end
    if not inst then return {} end
    local head = memory_read("uintptr_t", inst.Address + self.Offsets.Animator.ActiveAnimations)
    if not (head and head > 4096) then return {} end
    local current, result, count = memory_read("uintptr_t", head), {}, 0
    while current and current ~= head and count < 40 do
        count = count + 1
        local track = memory_read("uintptr_t", current + 16)
        if track and track > 4096 then
            local anim_ptr = memory_read("uintptr_t", track + self.Offsets.AnimationTrack.Animation)
            if anim_ptr and anim_ptr > 4096 then
                local raw = self:read("string", anim_ptr + self.Offsets.Misc.AnimationId)
                local id = raw and raw:match("%d+$")
                if id then
                    result[id] = { id = id, tp = memory_read("float", track + self.Offsets.AnimationTrack.TimePosition), track = track }
                end
            end
        end
        current = memory_read("uintptr_t", current)
    end
    return result
end

function Memory:set_animation_id(animation, id)
    local inst = (type(animation) == "table" and animation.Instance) and animation.Instance or animation
    self:write("string", ((typeof(inst) == "Instance") and inst.Address or inst) + self.Offsets.Misc.AnimationId, "rbxassetid://" .. tostring(id):match("%d+"))
    return true
end

local proxy_meta = {
    __call = function(_, inst) return Memory:bind(inst) end,
    __index = function(self, key)
        if typeof(key) == "Instance" then return Memory:bind(key) end
        if Memory[key] then return Memory[key] end
        local hum = players.LocalPlayer and players.LocalPlayer.Character and players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            local off = Memory:resolve(hum, key)
            if off then return Memory:get(hum, key) end
        end
        return rawget(self, key)
    end,
    __newindex = function(self, key, value)
        local hum = players.LocalPlayer and players.LocalPlayer.Character and players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            local off = Memory:resolve(hum, key)
            if off then return Memory:set(hum, key, value) end
        end
        rawset(self, key, value)
    end
}

setmetatable(Memory, {
    __call = function(_, inst) return Memory:bind(inst) end,
    __index = function(self, key) return typeof(key) == "Instance" and Memory:bind(key) or rawget(self, key) end
})

function Memory.new(o, t)
    if not Memory.Offsets then Memory:init(o, t) end
    return setmetatable({ Offsets = Memory.Offsets, Types = Memory.Types }, proxy_meta)
end

_G.Memory = Memory
return Memory
