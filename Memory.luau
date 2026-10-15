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
    ["bool"] = "bool",
    ["byte"] = "byte",
    ["unsigned char"] = "byte",
    ["string"] = "string",
    ["unsigned __int64"] = "uintptr_t",
    ["uintptr_t"] = "uintptr_t",
    ["pointer"] = "uintptr_t",
    ["Vector3"] = "vector3",
    ["Matrix3x3"] = "matrix",
}

local function fetch_json(urls)
    for _, url in ipairs(urls) do
        local raw = game:HttpGet(url)
        if raw and #raw > 10 then
            local data = httpservice:JSONDecode(raw)
            if data then return data end
        end
    end
    assert(false, "failed to fetch remote manifest!")
end

function Memory:init(offsets_data, types_data)
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

local base_classes = {
    Part = "BasePart", MeshPart = "BasePart", WedgePart = "BasePart", CornerWedgePart = "BasePart", TrussPart = "BasePart", Seat = "BasePart", VehicleSeat = "BasePart", SpawnLocation = "BasePart",
    Frame = "GuiObject", ScrollingFrame = "GuiObject", TextLabel = "GuiObject", TextButton = "GuiObject", TextBox = "GuiObject", ImageLabel = "GuiObject", ImageButton = "GuiObject", ScreenGui = "GuiObject", BillboardGui = "GuiObject", SurfaceGui = "GuiObject"
}

function Memory:resolve(inst, prop)
    if not self.Offsets then self:init() end
    local prop_lower = prop:lower()
    local is_inst = typeof(inst) == "Instance"

    local function match_class(cls)
        local offsets = self.Offsets[cls]
        if not offsets then return end
        for k, off in pairs(offsets) do
            local kl = k:lower()
            if kl == prop_lower or (prop_lower == "enabled" and kl == "screengui_enabled") then
                local raw_type = self.Types[cls] and self.Types[cls][k] or "float"
                return off, type_map[raw_type] or "float", cls, k
            end
        end
    end

    if is_inst then
        local cname = inst.ClassName
        local off, kind, cls, k = match_class(cname)
        if off then return off, kind, cls, k end

        local base = base_classes[cname]
        if base then
            off, kind, cls, k = match_class(base)
            if off then return off, kind, cls, k end
        end
    end

    return match_class("Misc")
end

function Memory:read(kind, addr)
    if kind == "string" then
        local cap = memory_read("uintptr_t", addr + 24)
        local ptr = (cap >= 16) and memory_read("uintptr_t", addr) or addr
        return memory_read("string", ptr)
    elseif kind == "vector3" then
        return Vector3.new(memory_read("float", addr), memory_read("float", addr + 4), memory_read("float", addr + 8))
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
        local len = #str
        local ptr = (cap >= 16) and memory_read("uintptr_t", addr) or addr
        for i = 1, len do
            memory_write("byte", ptr + i - 1, string.byte(str, i))
        end
        memory_write("byte", ptr + len, 0)
        memory_write("uintptr_t", addr + 16, len)
    elseif kind == "vector3" then
        memory_write("float", addr, val.X)
        memory_write("float", addr + 4, val.Y)
        memory_write("float", addr + 8, val.Z)
    elseif kind == "matrix" then
        for i = 1, 9 do
            memory_write("float", addr + (i - 1) * 4, val[i])
        end
    else
        memory_write(kind, addr, val)
    end
end

function Memory:get(inst, prop)
    local addr = (typeof(inst) == "Instance") and inst.Address or inst
    local off, kind = self:resolve(inst, prop)
    assert(off, "property offset not found for " .. tostring(prop) .. "!")
    return self:read(kind, addr + off)
end

function Memory:set(inst, prop, value)
    local addr = (typeof(inst) == "Instance") and inst.Address or inst
    local off, kind, cls, k = self:resolve(inst, prop)
    assert(off, "property offset not found for " .. tostring(prop) .. "!")
    self:write(kind, addr + off, value)
    if cls == "Humanoid" and k:lower() == "walkspeed" and self.Offsets.Humanoid and self.Offsets.Humanoid.WalkspeedCheck then
        self:write("float", addr + self.Offsets.Humanoid.WalkspeedCheck, value)
    end
end

function Memory:bind(inst)
    local proxy = { Instance = inst, Address = (typeof(inst) == "Instance") and inst.Address or inst }
    return setmetatable(proxy, {
        __index = function(_, k)
            if k == "Instance" or k == "Address" then return proxy[k] end
            return self:get(inst, k)
        end,
        __newindex = function(_, k, v)
            self:set(inst, k, v)
        end
    })
end

function Memory:lookat(part, target_pos)
    if not self.Offsets then self:init() end
    local inst = (type(part) == "table" and part.Instance) and part.Instance or part
    local prim_ptr = memory_read("uintptr_t", inst.Address + self.Offsets.BasePart.Primitive)
    if not (prim_ptr and prim_ptr > 4096) then return false end
    local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = CFrame.lookAt(inst.Position, target_pos):GetComponents()
    self:write("matrix", prim_ptr + self.Offsets.Primitive.Rotation, { r00, r01, r02, r10, r11, r12, r20, r21, r22 })
    return true
end

function Memory:animations(animator)
    if not self.Offsets then self:init() end
    local inst = (type(animator) == "table" and animator.Instance) and animator.Instance or animator
    if typeof(inst) == "Instance" and inst.ClassName ~= "Animator" then
        inst = inst:FindFirstChildOfClass("Animator")
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
    if not self.Offsets then self:init() end
    local inst = (type(animation) == "table" and animation.Instance) and animation.Instance or animation
    local addr = (typeof(inst) == "Instance") and inst.Address or inst
    self:write("string", addr + self.Offsets.Misc.AnimationId, "rbxassetid://" .. tostring(id):match("%d+"))
    return true
end

local proxy_meta = {
    __call = function(_, inst)
        return Memory:bind(inst)
    end,
    __index = function(self, key)
        if typeof(key) == "Instance" then return Memory:bind(key) end
        if Memory[key] then return Memory[key] end
        local char = players.LocalPlayer and players.LocalPlayer.Character
        if char then
            local child = char:FindFirstChild(key)
            if child then return Memory:bind(child) end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                local off = Memory:resolve(hum, key)
                if off then return Memory:get(hum, key) end
            end
        end
        return rawget(self, key)
    end,
    __newindex = function(self, key, value)
        local char = players.LocalPlayer and players.LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            local off = Memory:resolve(hum, key)
            if off then
                Memory:set(hum, key, value)
                return
            end
        end
        rawset(self, key, value)
    end
}

setmetatable(Memory, {
    __call = function(_, inst)
        return Memory:bind(inst)
    end,
    __index = function(self, key)
        if typeof(key) == "Instance" then return Memory:bind(key) end
        return rawget(self, key)
    end
})

function Memory.new(offsets_data, types_data)
    if not Memory.Offsets then
        Memory:init(offsets_data, types_data)
    end
    local obj = {
        Offsets = Memory.Offsets,
        Types = Memory.Types,
    }
    return setmetatable(obj, proxy_meta)
end

_G.Memory = Memory
return Memory
