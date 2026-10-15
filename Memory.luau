Memory = Memory or {}
Memory.Offsets = nil
Memory.Types = nil

Memory.OffsetUrls = {
    "https://offsets.imtheo.lol/Offsets.json",
    "https://offsets.femboythighs.org/Offsets.json",
    "https://raw.githubusercontent.com/WhyMayko/Matcha-Scripts/refs/heads/main/Offsets/Offsets.json",
}

Memory.TypeUrls = {
    "https://offsets.imtheo.lol/types.json",
    "https://offsets.femboythighs.org/types.json",
    "https://raw.githubusercontent.com/WhyMayko/Matcha-Scripts/refs/heads/main/Offsets/types.json",
}

local players = game:GetService("Players")
local httpservice = game:GetService("HttpService")

local type_map = {
    ["float"] = "float",
    ["double"] = "double",
    ["int"] = "int",
    ["short"] = "int",
    ["bool"] = "byte",
    ["byte"] = "byte",
    ["unsigned char"] = "byte",
    ["string"] = "string",
    ["unsigned __int64"] = "uintptr_t",
    ["uintptr_t"] = "uintptr_t",
    ["pointer"] = "uintptr_t",
    ["Vector3"] = "vector3",
    ["Matrix3x3"] = "matrix3x3",
}

local class_hierarchy = {
    Part = { "BasePart", "Instance" },
    MeshPart = { "BasePart", "Instance" },
    WedgePart = { "BasePart", "Instance" },
    CornerWedgePart = { "BasePart", "Instance" },
    TrussPart = { "BasePart", "Instance" },
    Seat = { "BasePart", "Instance" },
    VehicleSeat = { "Seat", "BasePart", "Instance" },
    SpawnLocation = { "BasePart", "Instance" },
    BasePart = { "Instance" },
    Model = { "Instance" },
    Humanoid = { "Instance" },
    Camera = { "Instance" },
    Sound = { "Instance" },
    Animation = { "Instance" },
    AnimationTrack = { "Instance" },
    Animator = { "Instance" },
    Player = { "Instance" },
    Tool = { "Instance" },
    Shirt = { "Clothing", "Instance" },
    Pants = { "Clothing", "Instance" },
    Clothing = { "Instance" },
    ScreenGui = { "GuiObject", "GuiBase2D", "Instance" },
    BillboardGui = { "GuiObject", "GuiBase2D", "Instance" },
    SurfaceGui = { "GuiObject", "GuiBase2D", "Instance" },
    Frame = { "GuiObject", "GuiBase2D", "Instance" },
    ScrollingFrame = { "GuiObject", "GuiBase2D", "Instance" },
    TextLabel = { "GuiObject", "GuiBase2D", "Instance" },
    TextButton = { "GuiObject", "GuiBase2D", "Instance" },
    TextBox = { "GuiObject", "GuiBase2D", "Instance" },
    ImageLabel = { "GuiObject", "GuiBase2D", "Instance" },
    ImageButton = { "GuiObject", "GuiBase2D", "Instance" },
    GuiObject = { "GuiBase2D", "Instance" },
    GuiBase2D = { "Instance" },
    ProximityPrompt = { "Instance" },
    ClickDetector = { "Instance" },
    Lighting = { "Instance" },
}

local function fetch_json(urls)
    for _, url in ipairs(urls) do
        local raw = game:HttpGet(url)
        if raw and #raw > 10 then
            local data = httpservice:JSONDecode(raw)
            if data then
                return data
            end
        end
    end
    assert(false, "failed to fetch remote manifest!")
end

function Memory:Init(offsets_data, types_data)
    if offsets_data and types_data then
        self.Offsets = offsets_data
        self.Types = types_data
        return self
    end
    local off_doc = fetch_json(self.OffsetUrls)
    self.Offsets = off_doc.Offsets or off_doc
    local typ_doc = fetch_json(self.TypeUrls)
    self.Types = typ_doc.Types or typ_doc
    return self
end

function Memory:Resolve(inst, prop)
    if not self.Offsets then
        self:Init()
    end
    local class_name = (typeof(inst) == "Instance") and inst.ClassName or "Instance"
    local classes = { class_name }
    local bases = class_hierarchy[class_name]
    if bases then
        for _, b in ipairs(bases) do
            table.insert(classes, b)
        end
    end
    table.insert(classes, "Misc")

    local prop_lower = prop:lower()
    for _, cls in ipairs(classes) do
        local cls_offsets = self.Offsets[cls]
        if cls_offsets then
            for k, off in pairs(cls_offsets) do
                if k:lower() == prop_lower then
                    local raw_type = self.Types[cls] and self.Types[cls][k] or "float"
                    return off, type_map[raw_type] or "float", cls, k
                end
            end
        end
    end
    return nil, nil, nil, nil
end

function Memory:ReadPointer(addr)
    return memory_read("uintptr_t", addr)
end

function Memory:ReadByte(addr)
    return memory_read("byte", addr)
end

function Memory:ReadInt(addr)
    return memory_read("int", addr)
end

function Memory:ReadFloat(addr)
    return memory_read("float", addr)
end

function Memory:ReadDouble(addr)
    return memory_read("double", addr)
end

function Memory:ReadBool(addr)
    return memory_read("byte", addr) ~= 0
end

function Memory:ReadString(addr)
    local cap = memory_read("uintptr_t", addr + 24)
    local ptr = (cap >= 16) and memory_read("uintptr_t", addr) or addr
    return memory_read("string", ptr)
end

function Memory:ReadVector3(addr)
    return Vector3.new(memory_read("float", addr), memory_read("float", addr + 4), memory_read("float", addr + 8))
end

function Memory:ReadMatrix(addr)
    local mat = {}
    for i = 1, 9 do
        mat[i] = memory_read("float", addr + (i - 1) * 4)
    end
    return mat
end

function Memory:WritePointer(addr, val)
    memory_write("uintptr_t", addr, val)
end

function Memory:WriteByte(addr, val)
    memory_write("byte", addr, val)
end

function Memory:WriteInt(addr, val)
    memory_write("int", addr, val)
end

function Memory:WriteFloat(addr, val)
    memory_write("float", addr, val)
end

function Memory:WriteDouble(addr, val)
    memory_write("double", addr, val)
end

function Memory:WriteBool(addr, val)
    memory_write("byte", addr, val and 1 or 0)
end

function Memory:WriteString(addr, val)
    local cap = memory_read("uintptr_t", addr + 24)
    local str = tostring(val)
    local len = #str
    local ptr = (cap >= 16) and memory_read("uintptr_t", addr) or addr
    for i = 1, len do
        memory_write("byte", ptr + i - 1, string.byte(str, i))
    end
    memory_write("byte", ptr + len, 0)
    memory_write("uintptr_t", addr + 16, len)
end

function Memory:WriteVector3(addr, val)
    memory_write("float", addr, val.X)
    memory_write("float", addr + 4, val.Y)
    memory_write("float", addr + 8, val.Z)
end

function Memory:WriteMatrix(addr, mat)
    for i = 1, 9 do
        memory_write("float", addr + (i - 1) * 4, mat[i])
    end
end

function Memory:Get(inst, prop)
    local addr = (typeof(inst) == "Instance") and inst.Address or inst
    local off, kind, cls, k = self:Resolve(inst, prop)
    assert(off, "property offset not found for " .. tostring(prop) .. "!")
    local target = addr + off

    if kind == "float" then return self:ReadFloat(target) end
    if kind == "double" then return self:ReadDouble(target) end
    if kind == "int" then return self:ReadInt(target) end
    if kind == "byte" then
        if self.Types[cls] and self.Types[cls][k] == "bool" then
            return self:ReadBool(target)
        end
        return self:ReadByte(target)
    end
    if kind == "uintptr_t" then return self:ReadPointer(target) end
    if kind == "vector3" then return self:ReadVector3(target) end
    if kind == "string" then return self:ReadString(target) end
    return self:ReadPointer(target)
end

function Memory:Set(inst, prop, value)
    local addr = (typeof(inst) == "Instance") and inst.Address or inst
    local off, kind, cls, k = self:Resolve(inst, prop)
    assert(off, "property offset not found for " .. tostring(prop) .. "!")
    local target = addr + off

    if kind == "float" then
        self:WriteFloat(target, value)
        if cls == "Humanoid" and k:lower() == "walkspeed" and self.Offsets.Humanoid and self.Offsets.Humanoid.WalkspeedCheck then
            self:WriteFloat(addr + self.Offsets.Humanoid.WalkspeedCheck, value)
        end
        return
    end
    if kind == "double" then return self:WriteDouble(target, value) end
    if kind == "int" then return self:WriteInt(target, value) end
    if kind == "byte" then
        if type(value) == "boolean" then
            return self:WriteBool(target, value)
        end
        return self:WriteByte(target, value)
    end
    if kind == "uintptr_t" then return self:WritePointer(target, value) end
    if kind == "vector3" then return self:WriteVector3(target, value) end
    if kind == "string" then return self:WriteString(target, value) end
end

function Memory:Bind(inst)
    local proxy = { Instance = inst, Address = (typeof(inst) == "Instance") and inst.Address or inst }
    local meta = {
        __index = function(_, k)
            if k == "Instance" or k == "Address" then
                return proxy[k]
            end
            return self:Get(inst, k)
        end,
        __newindex = function(_, k, v)
            self:Set(inst, k, v)
        end
    }
    return setmetatable(proxy, meta)
end

function Memory:LookAt(part, target_pos)
    if not self.Offsets then
        self:Init()
    end
    local inst = (type(part) == "table" and part.Instance) and part.Instance or part
    local prim_ptr = memory_read("uintptr_t", inst.Address + self.Offsets.BasePart.Primitive)
    if not (prim_ptr and prim_ptr > 4096) then return false end
    local rot_addr = prim_ptr + self.Offsets.Primitive.Rotation
    local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = CFrame.lookAt(inst.Position, target_pos):GetComponents()
    local mat = { r00, r01, r02, r10, r11, r12, r20, r21, r22 }
    self:WriteMatrix(rot_addr, mat)
    return true
end

function Memory:Animations(animator)
    if not self.Offsets then
        self:Init()
    end
    local inst = (type(animator) == "table" and animator.Instance) and animator.Instance or animator
    if typeof(inst) == "Instance" then
        if inst:IsA("Humanoid") or inst:IsA("Model") then
            inst = inst:FindFirstChildOfClass("Animator")
        end
    end
    if not inst then return {} end
    local addr = (typeof(inst) == "Instance") and inst.Address or inst
    local head = memory_read("uintptr_t", addr + self.Offsets.Animator.ActiveAnimations)
    if not (head and head > 4096) then return {} end
    local current = memory_read("uintptr_t", head)
    local result = {}
    local count = 0
    while current and current ~= head and count < 40 do
        count = count + 1
        local track = memory_read("uintptr_t", current + 16)
        if track and track > 4096 then
            local anim_ptr = memory_read("uintptr_t", track + self.Offsets.AnimationTrack.Animation)
            if anim_ptr and anim_ptr > 4096 then
                local raw = self:ReadString(anim_ptr + self.Offsets.Misc.AnimationId)
                local id = raw and raw:match("%d+$")
                if id then
                    local tp = memory_read("float", track + self.Offsets.AnimationTrack.TimePosition)
                    result[id] = { id = id, tp = tp, track = track }
                end
            end
        end
        current = memory_read("uintptr_t", current)
    end
    return result
end

function Memory:SetAnimationId(animation, id)
    if not self.Offsets then
        self:Init()
    end
    local inst = (type(animation) == "table" and animation.Instance) and animation.Instance or animation
    local addr = (typeof(inst) == "Instance") and inst.Address or inst
    local target = "rbxassetid://" .. tostring(id):match("%d+")
    self:WriteString(addr + self.Offsets.Misc.AnimationId, target)
    return true
end

Memory.bind = Memory.Bind
Memory.get = Memory.Get
Memory.set = Memory.Set
Memory.lookat = Memory.LookAt
Memory.animations = Memory.Animations
Memory.set_animation_id = Memory.SetAnimationId
Memory.pointer = Memory.ReadPointer
Memory.read_pointer = Memory.ReadPointer
Memory.read_byte = Memory.ReadByte
Memory.read_int = Memory.ReadInt
Memory.read_float = Memory.ReadFloat
Memory.read_double = Memory.ReadDouble
Memory.read_bool = Memory.ReadBool
Memory.read_string = Memory.ReadString
Memory.read_vector3 = Memory.ReadVector3
Memory.read_matrix = Memory.ReadMatrix
Memory.write_pointer = Memory.WritePointer
Memory.write_byte = Memory.WriteByte
Memory.write_int = Memory.WriteInt
Memory.write_float = Memory.WriteFloat
Memory.write_double = Memory.WriteDouble
Memory.write_bool = Memory.WriteBool
Memory.write_string = Memory.WriteString
Memory.write_vector3 = Memory.WriteVector3
Memory.write_matrix = Memory.WriteMatrix

function Memory.new(offsets_data, types_data)
    if not Memory.Offsets then
        Memory:Init(offsets_data, types_data)
    end
    local obj = {
        Offsets = Memory.Offsets,
        Types = Memory.Types,
    }
    local meta = {
        __index = function(self, key)
            if Memory[key] then return Memory[key] end
            local char = players.LocalPlayer and players.LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                local off = Memory:Resolve(hum, key)
                if off then return Memory:Get(hum, key) end
            end
            return rawget(self, key)
        end,
        __newindex = function(self, key, value)
            local char = players.LocalPlayer and players.LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                local off = Memory:Resolve(hum, key)
                if off then
                    Memory:Set(hum, key, value)
                    return
                end
            end
            rawset(self, key, value)
        end
    }
    return setmetatable(obj, meta)
end

_G.Memory = Memory
return Memory
