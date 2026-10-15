local memory = loadstring(game:HttpGet("https://raw.githubusercontent.com/WhyMayko/Memory-Module/main/Memory.luau"))().new()

local player = game:GetService("Players").LocalPlayer
local char = player.Character

print("WalkSpeed: " .. tostring(memory.walkspeed))
memory.walkspeed = 32

local prompt = workspace:FindFirstChildOfClass("ProximityPrompt")
if prompt then
    memory(prompt).Enabled = true
    memory(prompt).HoldDuration = 0
end

local frame = player.PlayerGui:FindFirstChildWhichIsA("Frame", true)
if frame then
    print("Frame visible: " .. tostring(memory(frame).visible))
    memory(frame).visible = false
end

memory:lookat(char.HumanoidRootPart, Vector3.new(0, 100, 0))
