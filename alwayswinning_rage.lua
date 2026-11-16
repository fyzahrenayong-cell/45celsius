--!nocheck
-- Always.winning | Rage core (silent + melee aura) — instant run, no setup
-- From Meow combat core; aimbot camera soft-aim excluded

if getgenv().AlwaysWinningRage and getgenv().AlwaysWinningRage.Unload then
    pcall(getgenv().AlwaysWinningRage.Unload)
end

local Players = cloneref and cloneref(game:GetService("Players")) or game:GetService("Players")
local RunService = cloneref and cloneref(game:GetService("RunService")) or game:GetService("RunService")
local Workspace = cloneref and cloneref(game:GetService("Workspace")) or game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

getgenv().meow_flags = getgenv().meow_flags or {}
local flags = getgenv().meow_flags

-- instant defaults (silent + melee on)
flags.silent_aim_enabled = true
flags.hit_chance = flags.hit_chance or 100
flags.fov_radius_smoothed = flags.fov_radius_smoothed or 400
flags.target_priority = flags.target_priority or "Closest"
flags.target_hitbox = flags.target_hitbox or "Head"
flags.knife_rage = true
flags.melee_safe_reach = flags.melee_safe_reach or 12
flags.melee_auto_face_back = true
flags.avoid_katana = flags.avoid_katana or false
flags.riot_shield_check = flags.riot_shield_check or false
flags.aimbot_enabled = false
flags.aimbot_active = false

getgenv().meowState = getgenv().meowState or {
    Destroyed = false,
    PriorityList = {},
    CurrentTarget = nil,
    LastTargetPlayer = nil,
    LastMeleeAttack = 0,
}
local meowState = getgenv().meowState
meowState.Destroyed = false

local fakePos = getgenv().fakePos or { Enabled = false, VirtualCF = nil, AutoHandoff = false, HandoffTicks = 0 }

local conns = {}
local function track(c) conns[#conns+1] = c; return c end

local function is_katana_user(char)
    if not char then return false end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") then
            local n = string.lower(t.Name)
            if n:find("katana", 1, true) or n:find("blade", 1, true) then return true end
        end
    end
    return false
end

silent_closest_hitbox = function(char)
    if not char then return nil end
    local mode = flags.target_hitbox or "Head"
    if mode == "Head" then
        return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    elseif mode == "HumanoidRootPart" or mode == "Torso" then
        return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    elseif mode == "Random" then
        local parts = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}
        return char:FindFirstChild(parts[math.random(1, #parts)]) or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end
silent_closest_part = silent_closest_hitbox
targeting_silent_part = silent_closest_hitbox
target_aim_part = silent_closest_hitbox
random_hitpart_name = function()
    local p = {"Head", "HumanoidRootPart", "Torso", "UpperTorso"}
    return p[math.random(1, #p)]
end

get_target = function()
    local myChar = LocalPlayer.Character
    if not myChar then return nil end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local bestTarget = nil
    local bestScore = math.huge
    local method = flags.target_priority or "Lowest Health"
    local fovRadius = flags.fov_radius_smoothed or 120
    local center = Camera.ViewportSize / 2

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character then
            local char = pl.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")

            if hum and hum.Health > 0 and root and not char:FindFirstChildOfClass("ForceField") then
                if not (flags.riot_shield_check and shield_blocks_shot(root, myRoot.Position)) then
                    if not (flags.avoid_katana and manip_is_deflecting(char)) then
                        local scrPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                        local fovDist = (Vector2.new(scrPos.X, scrPos.Y) - center).Magnitude

                        if not flags.silent_aim_enabled or fovDist <= fovRadius then
                            local dist = (root.Position - myRoot.Position).Magnitude
                            local health = hum.Health
                            local isPriority = ragebot_is_priority(pl)
                            local score = health

                            if method == "Distance" or method == "Closest Distance" then
                                score = dist
                            elseif method == "Crosshair" then
                                score = fovDist
                            elseif method == "FOV - Lowest Health" then
                                score = (health * 2) + fovDist
                            else
                                score = health
                            end

                            if isPriority then
                                score = score - 10000
                            end

                            if score < bestScore then
                                bestScore = score
                                bestTarget = {
                                    Player = pl,
                                    Character = char,
                                    Humanoid = hum,
                                    RootPart = root,
                                    HitPart = silent_closest_hitbox(char),
                                    Distance = dist,
                                    FOVDistance = fovDist,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    meowState.CurrentTarget = bestTarget
    if bestTarget then meowState.LastTargetPlayer = bestTarget.Player end
    return bestTarget
end

local function runMeleeAura()
    if not flags.knife_rage then return end
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local now = os.clock()
    if now - meowState.LastMeleeAttack < 0.12 then return end

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character then
            local root = pl.Character:FindFirstChild("HumanoidRootPart")
            local hum = pl.Character:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.Health > 0 then
                local dist = (root.Position - myRoot.Position).Magnitude
                if dist <= (flags.melee_safe_reach or 12) then
                    meowState.LastMeleeAttack = now
                    pcall(function()
                        if flags.melee_auto_face_back ~= false then
                            myRoot.CFrame = CFrame.new(myRoot.Position, myRoot.Position - root.CFrame.LookVector)
                        end
                        local tool = myChar:FindFirstChildOfClass("Tool")
                        if tool then tool:Activate() end
                    end)
                    break
                end
            end
        end
    end
end



if not hookmetamethod then
    warn("[Always.winning] hookmetamethod missing — silent redirect off")
else
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if not checkcaller or not checkcaller() then
            if flags.silent_aim_enabled then
                if (method == "Raycast" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRay") and self == Workspace then
                    local origin = args[1]
                    if fakePos.Enabled and fakePos.VirtualCF then
                        origin = fakePos.VirtualCF.Position
                        args[1] = origin
                    end
                    local target = meowState.CurrentTarget or get_target()
                    if target and target.HitPart then
                        local hitChance = flags.hit_chance or 100
                        if math.random(1, 100) <= hitChance then
                            local targetDir = (target.HitPart.Position - origin).Unit * 1000
                            args[2] = targetDir
                            if fakePos.Enabled and fakePos.AutoHandoff then
                                fakePos.HandoffTicks = 2
                            end
                            return oldNamecall(self, table.unpack(args))
                        end
                    end
                end
            end
        end
        return oldNamecall(self, ...)
    end)
end

track(RunService.Heartbeat:Connect(function()
    if meowState.Destroyed then return end
    pcall(function()
        meowState.CurrentTarget = get_target()
        runMeleeAura()
    end)
end))

getgenv().AlwaysWinningRage = {
    Unload = function()
        meowState.Destroyed = true
        flags.silent_aim_enabled = false
        flags.knife_rage = false
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        table.clear(conns)
        getgenv().AlwaysWinningRage = nil
        print("[Always.winning] rage unloaded")
    end,
    get_target = get_target,
    flags = flags,
    state = meowState,
}

print("[Always.winning] rage online — silent + melee aura (no aimbot)")
print("[Always.winning] FOV", flags.fov_radius_smoothed, "hitchance", flags.hit_chance)
