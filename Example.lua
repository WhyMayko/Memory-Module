local Memory = loadstring(game:HttpGet("https://raw.githubusercontent.com/WhyMayko/Memory-Module/main/Memory.luau"))()
Memory:Init()

local char = game:GetService("Players").LocalPlayer.Character

local hum = Memory:Bind(char.Humanoid)
print("Current WalkSpeed: " .. tostring(hum.Walkspeed))
print("Current Health: " .. tostring(hum.Health))

hum.Walkspeed = 28
print("New WalkSpeed: " .. tostring(hum.Walkspeed))

Memory:LookAt(char.HumanoidRootPart, Vector3.new(0, 100, 0))

local active_tracks = Memory:Animations(char.Humanoid)
for id in pairs(active_tracks) do
    print("Playing animation track: " .. id)
end
