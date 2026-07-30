-- ==============================================================================
-- AQUA_HUB (COMBAT + MOVEMENT + VISUALS + TOGGLEABLE SKIN SYSTEM + GLOBAL RIVLOX BYPASS)
-- ==============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- 0.anticheat bypass module
-- ==========================================
pcall(function()
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    local oldIndex = mt.__index
    local oldNamecall = mt.__namecall

    if hookmetamethod then
        local originalHook
        originalHook = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            
            if method == "FireServer" and self and typeof(self.Name) == "string" then
                local n = self.Name:lower()
                if n:find("anticheat") or n:find("rivlox") or n:find("ban") or n:find("report") or n:find("detect") then
                    return
                end
            end
            return originalHook(self, ...)
        end)
    end

    mt.__index = newcclosure(function(t, k)
        if t == _G or t == shared then
            if k == "Rivlox" or k == "AntiCheat" or k == "AC_Data" then
                return nil
            end
        end
        return oldIndex(t, k)
    end)
    setreadonly(mt, true)
end)

-- 이전 실행된 커스텀 UI 제거
local oldUI = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("AQUA_UltimateUI") or game:GetService("CoreGui"):FindFirstChild("AQUA_UltimateUI")
if oldUI then oldUI:Destroy() end

-- ==========================================
-- 1. 기능 상태 변수 및 스킨 체인저 마스터 스위치
-- ==========================================
local combatDesyncActive = false
local aimAssistEnabled = false
local movementDesyncEnabled = false
local speedEnabled = false
local speedMultiplier = 1.05
local noclipEnabled = false
local flying = false
local flySpeed = 50
local espEnabled = false
local boxEspEnabled = false
local skeletonEnabled = false -- 기본값 false (켜야만 나옴)
local FOVRadius = 300
local Smoothness = 3

local skinChangerEnabled = true

local playerScripts = LocalPlayer.PlayerScripts
local controllers = playerScripts.Controllers

local EnumLibrary = require(ReplicatedStorage.Modules:WaitForChild("EnumLibrary", 10))
if EnumLibrary then EnumLibrary:WaitForEnumBuilder() end

local CosmeticLibrary = require(ReplicatedStorage.Modules:WaitForChild("CosmeticLibrary", 10))
local ItemLibrary = require(ReplicatedStorage.Modules:WaitForChild("ItemLibrary", 10))
local DataController = require(controllers:WaitForChild("PlayerDataController", 10))

local equipped, favorites = {}, {}
local constructingWeapon, viewingProfile = nil, nil
local lastUsedWeapon = nil

local function cloneCosmetic(name, cosmeticType, options)
    local base = CosmeticLibrary.Cosmetics[name]
    if not base then return nil end
    local data = {}
    for key, value in pairs(base) do data[key] = value end
    data.Name = name
    data.Type = data.Type or cosmeticType
    data.Seed = data.Seed or math.random(1, 1000000)
    if EnumLibrary then
        local success, enumId = pcall(EnumLibrary.ToEnum, EnumLibrary, name)
        if success and enumId then data.Enum, data.ObjectID = enumId, data.ObjectID or enumId end
    end
    if options then
        if options.inverted ~= nil then data.Inverted = options.inverted end
        if options.favoritesOnly ~= nil then data.OnlyUseFavorites = options.favoritesOnly end
    end
    return data
end

local saveFile = "unlockall/config.json"
local function saveConfig()
    if not writefile then return end
    pcall(function()
        local config = {equipped = {}, favorites = favorites}
        for weapon, cosmetics in pairs(equipped) do
            config.equipped[weapon] = {}
            for cosmeticType, cosmeticData in pairs(cosmetics) do
                if cosmeticData and cosmeticData.Name then
                    config.equipped[weapon][cosmeticType] = {
                        name = cosmeticData.Name, seed = cosmeticData.Seed, inverted = cosmeticData.Inverted
                    }
                end
            end
        end
        makefolder("unlockall")
        writefile(saveFile, HttpService:JSONEncode(config))
    end)
end

local function loadConfig()
    if not readfile or not isfile or not isfile(saveFile) then return end
    pcall(function()
        local config = HttpService:JSONDecode(readfile(saveFile))
        if config.equipped then
            for weapon, cosmetics in pairs(config.equipped) do
                equipped[weapon] = {}
                for cosmeticType, cosmeticData in pairs(cosmetics) do
                    local cloned = cloneCosmetic(cosmeticData.name, cosmeticType, {inverted = cosmeticData.inverted})
                    if cloned then cloned.Seed = cosmeticData.seed equipped[weapon][cosmeticType] = cloned end
                end
            end
        end
        favorites = config.favorites or {}
    end)
end

local originalOwnsCosmetic = CosmeticLibrary.OwnsCosmetic
CosmeticLibrary.OwnsCosmetic = function(self, inventory, name, weapon)
    if not skinChangerEnabled then return originalOwnsCosmetic(self, inventory, name, weapon) end
    if name:find("MISSING_") then return originalOwnsCosmetic(self, inventory, name, weapon) end
    local cosmetic = CosmeticLibrary.Cosmetics[name]
    if cosmetic then
        local cType = cosmetic.Type
        if cType == "Skin" or cType == "Charm" or cType == "Dance" or cType == "Emote" or cType == "Wrap" or cType == "Wrapping" or name:lower():find("charm") or name:lower():find("dance") or name:lower():find("emote") or name:lower():find("wrap") then
            return true
        end
    end
    return originalOwnsCosmetic(self, inventory, name, weapon)
end

CosmeticLibrary.OwnsCosmeticNormally = function(self, inventory, name, weapon)
    if not skinChangerEnabled then return false end
    local cosmetic = CosmeticLibrary.Cosmetics[name]
    if cosmetic and cosmetic.Type == "Skin" then return true end
    return false
end

CosmeticLibrary.OwnsCosmeticUniversally = function(self, inventory, name, weapon)
    if not skinChangerEnabled then return false end
    local cosmetic = CosmeticLibrary.Cosmetics[name]
    if cosmetic and cosmetic.Type == "Skin" then return true end
    return false
end

CosmeticLibrary.OwnsCosmeticForWeapon = function(self, inventory, name, weapon)
    if not skinChangerEnabled then return false end
    local cosmetic = CosmeticLibrary.Cosmetics[name]
    if cosmetic and cosmetic.Type == "Skin" then return true end
    return false
end

local originalGet = DataController.Get
DataController.Get = function(self, key)
    local data = originalGet(self, key)
    if not skinChangerEnabled then return data end

    if key == "CosmeticInventory" then
        local proxy = {}
        if data then for k, v in pairs(data) do 
            local cosmetic = CosmeticLibrary.Cosmetics[k]
            if cosmetic then proxy[k] = v end
        end end
        return setmetatable(proxy, {__index = function(t, k)
            local cosmetic = CosmeticLibrary.Cosmetics[k]
            if cosmetic then return true end
            return nil
        end})
    end
    if key == "FavoritedCosmetics" then
        local result = data and table.clone(data) or {}
        for weapon, favs in pairs(favorites) do
            result[weapon] = result[weapon] or {}
            for name, isFav in pairs(favs) do 
                result[weapon][name] = isFav
            end
        end
        return result
    end
    return data
end

local originalGetWeaponData = DataController.GetWeaponData
DataController.GetWeaponData = function(self, weaponName)
    local data = originalGetWeaponData(self, weaponName)
    if not skinChangerEnabled or not data then return data end
    local merged = {}
    for key, value in pairs(data) do merged[key] = value end
    merged.Name = weaponName
    if equipped[weaponName] then
        for cosmeticType, cosmeticData in pairs(equipped[weaponName]) do 
            merged[cosmeticType] = cosmeticData
        end
    end
    return merged
end

local FighterController
pcall(function() FighterController = require(controllers:WaitForChild("FighterController", 10)) end)

if hookmetamethod then
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local dataRemotes = remotes and remotes:FindFirstChild("Data")
    local equipRemote = dataRemotes and dataRemotes:FindFirstChild("EquipCosmetic")
    local favoriteRemote = dataRemotes and dataRemotes:FindFirstChild("FavoriteCosmetic")
    local replicationRemotes = remotes and remotes:FindFirstChild("Replication")
    local fighterRemotes = replicationRemotes and replicationRemotes:FindFirstChild("Fighter")
    local useItemRemote = fighterRemotes and fighterRemotes:FindFirstChild("UseItem")
    
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if getnamecallmethod() ~= "FireServer" then return oldNamecall(self, ...) end
        local args = {...}
        
        if useItemRemote and self == useItemRemote then
            local objectID = args[1]
            if FighterController then
                pcall(function()
                    local fighter = FighterController:GetFighter(LocalPlayer)
                    if fighter and fighter.Items then
                        for _, item in pairs(fighter.Items) do
                            if item:Get("ObjectID") == objectID then lastUsedWeapon = item.Name break end
                        end
                    end
                end)
            end
        end
        
        if skinChangerEnabled then
            if self == equipRemote then
                local weaponName, cosmeticType, cosmeticName, options = args[1], args[2], args[3], args[4] or {}
                
                if cosmeticName and cosmeticName ~= "None" and cosmeticName ~= "" then
                    local inventory = originalGet(DataController, "CosmeticInventory")
                    if inventory and rawget(inventory, cosmeticName) then 
                        return oldNamecall(self, ...) 
                    end
                end
                
                if cosmeticType == "Dance" or cosmeticType == "Emote" or (cosmeticName and (cosmeticName:lower():find("dance") or cosmeticName:lower():find("emote"))) then
                    equipped.Dances = equipped.Dances or {}
                    if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then
                        equipped.Dances[cosmeticType] = nil
                    else
                        local cloned = cloneCosmetic(cosmeticName, cosmeticType, {inverted = options.IsInverted, favoritesOnly = options.OnlyUseFavorites})
                        if cloned then equipped.Dances[cosmeticType] = cloned end
                    end
                    task.defer(function()
                        pcall(function() DataController.CurrentData:Replicate("CosmeticInventory") end)
                        task.wait(0.1)
                        saveConfig()
                    end)
                    return
                end
                
                equipped[weaponName] = equipped[weaponName] or {}
                if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then
                    equipped[weaponName][cosmeticType] = nil
                    if not next(equipped[weaponName]) then equipped[weaponName] = nil end
                else
                    local cloned = cloneCosmetic(cosmeticName, cosmeticType, {inverted = options.IsInverted, favoritesOnly = options.OnlyUseFavorites})
                    if cloned then equipped[weaponName][cosmeticType] = cloned end
                end
                
                task.defer(function()
                    pcall(function() DataController.CurrentData:Replicate("WeaponInventory") end)
                    task.wait(0.1)
                    saveConfig()
                end)
                return
            end
            
            if self == favoriteRemote then
                local wName, cName, isFav = args[1], args[2], args[3]
                local cosmetic = CosmeticLibrary.Cosmetics[cName]
                if cosmetic then
                    favorites[wName] = favorites[wName] or {}
                    favorites[wName][cName] = isFav or nil
                    saveConfig()
                    task.spawn(function() pcall(function() DataController.CurrentData:Replicate("FavoritedCosmetics") end) end)
                end
                return
            end
        end
        
        return oldNamecall(self, ...)
    end)
end

local ClientItem
pcall(function() ClientItem = require(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem) end)

if ClientItem and ClientItem._CreateViewModel then
    local originalCreateViewModel = ClientItem._CreateViewModel
    ClientItem._CreateViewModel = function(self, viewmodelRef)
        local weaponName = self.Name
        local weaponPlayer = self.ClientFighter and self.ClientFighter.Player
        constructingWeapon = (weaponPlayer == LocalPlayer) and weaponName or nil
        
        if skinChangerEnabled and weaponPlayer == LocalPlayer and equipped[weaponName] and viewmodelRef then
            local dataKey = self:ToEnum("Data")
            local targetTable = viewmodelRef[dataKey] or viewmodelRef.Data
           
            if targetTable then
                if equipped[weaponName].Skin then
                    targetTable[self:ToEnum("Skin") or "Skin"] = equipped[weaponName].Skin
                    targetTable[self:ToEnum("Name") or "Name"] = equipped[weaponName].Skin.Name
                end
                if equipped[weaponName].Charm then
                    targetTable[self:ToEnum("Charm") or "Charm"] = equipped[weaponName].Charm
                end
                if equipped[weaponName].Wrap then
                    targetTable[self:ToEnum("Wrap") or "Wrap"] = equipped[weaponName].Wrap
                end
            end
        end
        
        local result = originalCreateViewModel(self, viewmodelRef)
        constructingWeapon = nil
        return result
    end
end

local viewModelModule = LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem:FindFirstChild("ClientViewModel")
if viewModelModule then
    local ClientViewModel = require(viewModelModule)
    
    if ClientViewModel.GetCharm then
        local originalGetCharmFunc = ClientViewModel.GetCharm
        ClientViewModel.GetCharm = function(self)
            if not skinChangerEnabled then return originalGetCharmFunc(self) end
            local weaponName = self.ClientItem and self.ClientItem.Name
            local weaponPlayer = self.ClientItem and self.ClientItem.ClientFighter and self.ClientItem.ClientFighter.Player
            if weaponName and weaponPlayer == LocalPlayer and equipped[weaponName] and equipped[weaponName].Charm then
                return equipped[weaponName].Charm
            end
            return originalGetCharmFunc(self)
        end
    end
    
    if ClientViewModel.GetWrap then
        local originalGetWrapFunc = ClientViewModel.GetWrap
        ClientViewModel.GetWrap = function(self)
            if not skinChangerEnabled then return originalGetWrapFunc(self) end
            local weaponName = self.ClientItem and self.ClientItem.Name
            local weaponPlayer = self.ClientItem and self.ClientItem.ClientFighter and self.ClientItem.ClientFighter.Player
            if weaponName and weaponPlayer == LocalPlayer and equipped[weaponName] and equipped[weaponName].Wrap then
                return equipped[weaponName].Wrap
            end
            return originalGetWrapFunc(self)
        end
    end

    local originalNew = ClientViewModel.new
    ClientViewModel.new = function(replicatedData, clientItem)
        local weaponPlayer = clientItem.ClientFighter and clientItem.ClientFighter.Player
        local weaponName = constructingWeapon or clientItem.Name
        if skinChangerEnabled and weaponPlayer == LocalPlayer and equipped[weaponName] then
            local ReplicatedClass = require(ReplicatedStorage.Modules.ReplicatedClass)
            local dataKey = ReplicatedClass:ToEnum("Data")
            replicatedData[dataKey] = replicatedData[dataKey] or {}
           
            local cosmetics = equipped[weaponName]
            if cosmetics.Skin then replicatedData[dataKey][ReplicatedClass:ToEnum("Skin")] = cosmetics.Skin end
            if cosmetics.Charm then replicatedData[dataKey][ReplicatedClass:ToEnum("Charm")] = cosmetics.Charm end
            if cosmetics.Wrap then replicatedData[dataKey][ReplicatedClass:ToEnum("Wrap")] = cosmetics.Wrap end
        end
        
        local result = originalNew(replicatedData, clientItem)
        
        if skinChangerEnabled and weaponPlayer == LocalPlayer and equipped[weaponName] and equipped[weaponName].Wrap and result._UpdateWrap then
            result:_UpdateWrap()
            task.delay(0.1, function() if not result._destroyed then result:_UpdateWrap() end end)
        end
        return result
    end
end

ItemLibrary.GetViewModelImageFromWeaponData = function(self, weaponData, highRes)
    if not skinChangerEnabled or not weaponData then return nil end
    local weaponName = weaponData.Name
    local shouldShowSkin = (weaponData.Skin and equipped[weaponName] and weaponData.Skin == equipped[weaponName].Skin) or (viewingProfile == LocalPlayer and equipped[weaponName] and equipped[weaponName].Skin)
    if shouldShowSkin and equipped[weaponName] and equipped[weaponName].Skin then
        local skinInfo = self.ViewModels[equipped[weaponName].Skin.Name]
        if skinInfo then return skinInfo[highRes and "ImageHighResolution" or "Image"] or skinInfo.Image end
    end
    return nil
end

local EmoteController
pcall(function() 
    EmoteController = require(controllers:WaitForChild("EmoteController", 10))
    if EmoteController and EmoteController.GetEmotes then
        local originalGetEmotes = EmoteController.GetEmotes
        EmoteController.GetEmotes = function(self)
            if not skinChangerEnabled then return originalGetEmotes(self) end
            local emotes = originalGetEmotes(self)
            for name, cosmetic in pairs(CosmeticLibrary.Cosmetics) do
                if cosmetic and (cosmetic.Type == "Dance" or cosmetic.Type == "Emote" or name:lower():find("dance") or name:lower():find("emote")) then
                    if not emotes[name] then
                        emotes[name] = { Name = name, Type = cosmetic.Type, ObjectID = cosmetic.ObjectID, Enum = cosmetic.Enum }
                    end
                end
            end
            return emotes
        end
    end
end)

pcall(function()
    local ViewProfile = require(LocalPlayer.PlayerScripts.Modules.Pages.ViewProfile)
    if ViewProfile and ViewProfile.Fetch then
        local originalFetch = ViewProfile.Fetch
        ViewProfile.Fetch = function(self, targetPlayer)
            viewingProfile = targetPlayer
            return originalFetch(self, targetPlayer)
        end
    end
end)

loadConfig()

-- ==========================================
-- 2. 디싱크 및 사일런트 (Rivlox 우회 적용)
-- ==========================================
local __p6q7r8 = getgenv()
if __p6q7r8.__s9t0u1 then
    pcall(function() __p6q7r8.__s9t0u1:Shutdown() end)
end

local successGun, __t6u7v8 = pcall(function()
    return require(LocalPlayer.PlayerScripts.Modules.ItemTypes.Gun)
end)
local successUtil, __w9x0y1 = pcall(function()
    return require(ReplicatedStorage.Modules.Utility)
end)

__p6q7r8.__s9t0u1 = {}

do
    local __i1j2k3 = __p6q7r8.__s9t0u1

    function __i1j2k3:__init()
        self.__active = false
        self.__target = nil
        self.__desync = false
        self.__conn1 = nil
        self.__conn2 = nil
        self.__task1 = nil
        self.__oldfunc = nil
        self:__setup()
    end

    function __i1j2k3:__setup()
        self.__conn1 = RunService.Heartbeat:Connect(function()
            if not self.__active then return end
            self.__target = self:__find()
        end)

        if __t6u7v8 and __w9x0y1 then
            local __l4m5n6 = __t6u7v8.StartShooting
            self.__oldfunc = __l4m5n6
            __t6u7v8.StartShooting = function(__o7p8q9, ...)
                local __r0s1t2 = {__l4m5n6(__o7p8q9, ...)}
                if not self.__active then return unpack(__r0s1t2) end
                if not __o7p8q9.ClientFighter or not __o7p8q9.ClientFighter.IsLocalPlayer then
                    return unpack(__r0s1t2)
                end

                local __u3v4w5 = __r0s1t2[3]
                if not __u3v4w5 or typeof(__u3v4w5) ~= "table" then
                    return unpack(__r0s1t2)
                end

                __r0s1t2[4] = true
                local __x6y7z8 = self.__target

                if not __x6y7z8 or not __x6y7z8.Character then
                    return unpack(__r0s1t2)
                end

                if not self.__desync or self.__curr ~= __x6y7z8 then
                    self:__desync_start(__x6y7z8)
                    task.wait(0.1)
                end

                if self.__task1 then
                    task.cancel(self.__task1)
                    self.__task1 = nil
                end

                local __a9b0c1 = __x6y7z8.Character:FindFirstChild("Head")
                if not __a9b0c1 then return unpack(__r0s1t2) end

                local __d2e3f4 = __a9b0c1.Position
                local __g5h6i7 = __a9b0c1.CFrame
                local __j8k9l0 = __d2e3f4 - Vector3.new(0, 5, 0)
                local __m1n2o3 = CFrame.lookAt(__j8k9l0, __d2e3f4)
                local __p4q5r6 = __g5h6i7:ToObjectSpace(CFrame.new(__d2e3f4 + Vector3.new(math.random(), math.random(), math.random())))

                pcall(function()
                    __u3v4w5[utf8.char(0)] = __w9x0y1:EncodeCFrame(CFrame.new(__j8k9l0, __d2e3f4) * CFrame.Angles(__m1n2o3:ToOrientation()))
                    __u3v4w5[utf8.char(1)] = __w9x0y1:EncodeCFrame(CFrame.new(__d2e3f4) * CFrame.Angles(__m1n2o3:ToOrientation()))
                    __u3v4w5[utf8.char(2)] = __a9b0c1
                    __u3v4w5[utf8.char(3)] = __w9x0y1:EncodeCFrame(__p4q5r6)
                end)

                self.__task1 = task.delay(0.15, function()
                    self:__desync_stop()
                end)

                return unpack(__r0s1t2)
            end
        end
    end

    function __i1j2k3:__find()
        local myChar = LocalPlayer.Character
        if not myChar then return nil end
        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return nil end
       
        local closest = nil
        local closestDist = math.huge
        local MAX_DISTANCE = 200

        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            if player:GetAttribute("TeamID") == LocalPlayer:GetAttribute("TeamID") then continue end
           
            local char = player.Character
            if not char then continue end

            local root = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head")
            local hum = char:FindFirstChildWhichIsA("Humanoid")
            
            if not (root and head and hum and hum.Health > 0) then continue end
           
            local dist = (myRoot.Position - root.Position).Magnitude
            if dist > MAX_DISTANCE then continue end
           
            if dist < closestDist then
                closestDist = dist
                closest = player
            end
        end
        return closest
    end

    function __i1j2k3:__desync_start(__c3d4e5)
        if self.__conn2 then self.__conn2:Disconnect() end
        self.__desync = true
        self.__curr = __c3d4e5

        self.__conn2 = RunService.Heartbeat:Connect(function()
            if not self.__desync then return end
            local myChar = LocalPlayer.Character
            if not myChar then return end
            local __f6g7h8 = myChar:FindFirstChild("HumanoidRootPart")
            if not __f6g7h8 then return end

            local __i9j0k1 = __c3d4e5.Character and __c3d4e5.Character:FindFirstChild("HumanoidRootPart")
            if not __i9j0k1 then
                self:__desync_stop()
                return
            end

            local __l2m3n4 = __f6g7h8.CFrame
            local __o5p6q7 = __f6g7h8.Velocity
            local __r8s9t0 = __f6g7h8.RotVelocity

            __f6g7h8.CFrame = __i9j0k1.CFrame * CFrame.new(0, -5, 0)

            RunService:BindToRenderStep("__restore", 101, function()
                __f6g7h8.CFrame = __l2m3n4
                __f6g7h8.Velocity = __o5p6q7
                __f6g7h8.RotVelocity = __r8s9t0
                RunService:UnbindFromRenderStep("__restore")
            end)
        end)
    end

    function __i1j2k3:__desync_stop()
        self.__desync = false
        self.__curr = nil
        if self.__conn2 then
            self.__conn2:Disconnect()
            self.__conn2 = nil
        end
    end

    function __i1j2k3:Shutdown()
        self.__active = false
        if self.__conn1 then self.__conn1:Disconnect() end
        if self.__conn2 then self.__conn2:Disconnect() end
        if self.__task1 then task.cancel(self.__task1) end
        if self.__oldfunc and __t6u7v8 then
            __t6u7v8.StartShooting = self.__oldfunc
        end
    end

    __i1j2k3:__init()
end

-- ==========================================
-- 3. UI 시스템
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AQUA_UltimateUI"
ScreenGui.ResetOnSpawn = false
if not pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end) then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local MenuBtn = Instance.new("TextButton", ScreenGui)
MenuBtn.Name = "ToggleMenu"
MenuBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MenuBtn.Position = UDim2.new(0, 30, 0.3, 0)
MenuBtn.Size = UDim2.new(0, 110, 0, 40)
MenuBtn.Font = Enum.Font.Code
MenuBtn.Text = "Aqua Hub"
MenuBtn.TextColor3 = Color3.fromRGB(162, 137, 245)
MenuBtn.TextSize = 13
MenuBtn.ZIndex = 100
Instance.new("UICorner", MenuBtn).CornerRadius = UDim.new(0, 6)

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
MainFrame.Position = UDim2.new(0.25, 0, 0.2, 0)
MainFrame.Size = UDim2.new(0, 600, 0, 420)
MainFrame.Visible = true
MainFrame.Active = true
MainFrame.ZIndex = 50
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

MenuBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

local dragging, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

local TitleBar = Instance.new("TextLabel", MainFrame)
TitleBar.BackgroundTransparency = 1
TitleBar.Position = UDim2.new(0, 15, 0, 0)
TitleBar.Size = UDim2.new(1, -30, 0, 35)
TitleBar.Font = Enum.Font.Code
TitleBar.Text = "Aqua Hub - Rivlox Bypassed + Fixed Skeleton"
TitleBar.TextColor3 = Color3.fromRGB(180, 185, 195)
TitleBar.TextSize = 13
TitleBar.TextXAlignment = Enum.TextXAlignment.Left
TitleBar.ZIndex = 51

-- ==========================================
-- 4. 탭 전환 시스템 (Main / Info)
-- ==========================================
local TabBarContainer = Instance.new("Frame", MainFrame)
TabBarContainer.BackgroundTransparency = 1
TabBarContainer.Position = UDim2.new(0, 15, 0, 35)
TabBarContainer.Size = UDim2.new(1, -30, 0, 30)
TabBarContainer.ZIndex = 52

local MainTabBtn = Instance.new("TextButton", TabBarContainer)
MainTabBtn.BackgroundColor3 = Color3.fromRGB(35, 30, 50)
MainTabBtn.Position = UDim2.new(0, 0, 0, 0)
MainTabBtn.Size = UDim2.new(0, 90, 0, 24)
MainTabBtn.Font = Enum.Font.Code
MainTabBtn.Text = "[ MAIN ]"
MainTabBtn.TextColor3 = Color3.fromRGB(162, 137, 245)
MainTabBtn.TextSize = 11
MainTabBtn.ZIndex = 53
Instance.new("UICorner", MainTabBtn).CornerRadius = UDim.new(0, 4)

local InfoTabBtn = Instance.new("TextButton", TabBarContainer)
InfoTabBtn.BackgroundColor3 = Color3.fromRGB(20, 22, 27)
InfoTabBtn.Position = UDim2.new(0, 98, 0, 0)
InfoTabBtn.Size = UDim2.new(0, 80, 0, 24)
InfoTabBtn.Font = Enum.Font.Code
InfoTabBtn.Text = "[ INFO ]"
InfoTabBtn.TextColor3 = Color3.fromRGB(130, 135, 145)
InfoTabBtn.TextSize = 11
InfoTabBtn.ZIndex = 53
Instance.new("UICorner", InfoTabBtn).CornerRadius = UDim.new(0, 4)

local MainContentPage = Instance.new("Frame", MainFrame)
MainContentPage.BackgroundTransparency = 1
MainContentPage.Position = UDim2.new(0, 15, 0, 70)
MainContentPage.Size = UDim2.new(1, -30, 1, -80)
MainContentPage.Visible = true
MainContentPage.ZIndex = 52

local InfoContentPage = Instance.new("ScrollingFrame", MainFrame)
InfoContentPage.BackgroundTransparency = 1
InfoContentPage.Position = UDim2.new(0, 15, 0, 70)
InfoContentPage.Size = UDim2.new(1, -30, 1, -80)
InfoContentPage.CanvasSize = UDim2.new(0, 0, 1, 0)
InfoContentPage.ScrollBarThickness = 4
InfoContentPage.Visible = false
InfoContentPage.ZIndex = 52
Instance.new("UIListLayout", InfoContentPage).Padding = UDim.new(0, 8)

MainTabBtn.MouseButton1Click:Connect(function()
    MainContentPage.Visible = true
    InfoContentPage.Visible = false
    MainTabBtn.BackgroundColor3 = Color3.fromRGB(35, 30, 50)
    MainTabBtn.TextColor3 = Color3.fromRGB(162, 137, 245)
    InfoTabBtn.BackgroundColor3 = Color3.fromRGB(20, 22, 27)
    InfoTabBtn.TextColor3 = Color3.fromRGB(130, 135, 145)
end)

InfoTabBtn.MouseButton1Click:Connect(function()
    MainContentPage.Visible = false
    InfoContentPage.Visible = true
    InfoTabBtn.BackgroundColor3 = Color3.fromRGB(35, 30, 50)
    InfoTabBtn.TextColor3 = Color3.fromRGB(162, 137, 245)
    MainTabBtn.BackgroundColor3 = Color3.fromRGB(20, 22, 27)
    MainTabBtn.TextColor3 = Color3.fromRGB(130, 135, 145)
end)

-- ==========================================
-- 5. Main 페이지 컬럼 구성
-- ==========================================
local function createCategory(parent, title, posX)
    local f = Instance.new("ScrollingFrame", parent)
    f.BackgroundColor3 = Color3.fromRGB(17, 18, 22)
    f.Position = UDim2.new(0, posX, 0, 0)
    f.Size = UDim2.new(0, 180, 1, 0)
    f.CanvasSize = UDim2.new(0, 0, 2, 0)
    f.ScrollBarThickness = 4
    f.ZIndex = 53
    Instance.new("UIListLayout", f).Padding = UDim.new(0, 8)
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel", f)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0, 25)
    lbl.Font = Enum.Font.Code
    lbl.Text = " -- " .. title .. " -- "
    lbl.TextColor3 = Color3.fromRGB(162, 137, 245)
    lbl.TextSize = 13
    lbl.ZIndex = 54
    return f
end

local combatCol = createCategory(MainContentPage, "COMBAT", 0)
local movementCol = createCategory(MainContentPage, "MOVEMENT", 195)
local visualsCol = createCategory(MainContentPage, "VISUALS", 390)

local function addToggle(parent, name, defaultState, callback)
    local btn = Instance.new("TextButton", parent)
    btn.BackgroundColor3 = defaultState and Color3.fromRGB(35, 30, 50) or Color3.fromRGB(25, 27, 32)
    btn.Size = UDim2.new(1, -10, 0, 30)
    btn.Font = Enum.Font.Code
    btn.Text = defaultState and " [✓] " .. name or " [ ] " .. name
    btn.TextColor3 = defaultState and Color3.fromRGB(162, 137, 245) or Color3.fromRGB(150, 155, 165)
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.ZIndex = 55
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    local state = defaultState
    btn.MouseButton1Click:Connect(function()
        state = not state
        if state then
            btn.Text = " [✓] " .. name
            btn.TextColor3 = Color3.fromRGB(162, 137, 245)
            btn.BackgroundColor3 = Color3.fromRGB(35, 30, 50)
        else
            btn.Text = " [ ] " .. name
            btn.TextColor3 = Color3.fromRGB(150, 155, 165)
            btn.BackgroundColor3 = Color3.fromRGB(25, 27, 32)
        end
        callback(state)
    end)
end

addToggle(combatCol, "고성능 디싱크/사일런트", false, function(v)
    combatDesyncActive = v
    if __p6q7r8.__s9t0u1 then
        __p6q7r8.__s9t0u1.__active = v
    end
end)

addToggle(combatCol, "Aimbot (우클릭 보정)", false, function(v)
    aimAssistEnabled = v
end)

addToggle(visualsCol, "Skin Changer (스킨체인저)", true, function(v)
    skinChangerEnabled = v
end)

addToggle(movementCol, "카메라 회전 디싱크", false, function(v)
    movementDesyncEnabled = v
    if v then
        _G.CameraRotationThread = (_G.CameraRotationThread or 0) + 1
        local thread = _G.CameraRotationThread
        task.spawn(function()
            local successPC, cameraController = pcall(function()
                return require(LocalPlayer.PlayerScripts.Controllers.CameraController)
            end)
            local updateRotation = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes.Replication.Fighter.UpdateCameraRotation
            local utility = successUtil and __w9x0y1 or nil

            while thread == _G.CameraRotationThread and movementDesyncEnabled do
                if cameraController and updateRotation and utility then
                    local rotation = cameraController.Rotation
                    local yaw = rotation and rotation.Y or 0
                    pcall(function()
                        updateRotation:FireServer(
                            utility:EncodeCameraRotation(Vector2.new(math.rad(179), yaw)),
                            nil
                        )
                    end)
                end
                task.wait()
            end
        end)
    else
        _G.CameraRotationThread = (_G.CameraRotationThread or 0) + 1
    end
end)

addToggle(movementCol, "Custom Speed", false, function(v) speedEnabled = v end)
addToggle(movementCol, "Noclip", false, function(v) noclipEnabled = v end)
addToggle(movementCol, "Fly (비행)", false, function(v) flying = v end)

local flySpeedBtn = Instance.new("TextButton", movementCol)
flySpeedBtn.BackgroundColor3 = Color3.fromRGB(25, 27, 32)
flySpeedBtn.Size = UDim2.new(1, -10, 0, 30)
flySpeedBtn.Font = Enum.Font.Code
flySpeedBtn.Text = " Fly Speed: " .. flySpeed
flySpeedBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
flySpeedBtn.TextSize = 12
flySpeedBtn.TextXAlignment = Enum.TextXAlignment.Left
flySpeedBtn.ZIndex = 55
Instance.new("UICorner", flySpeedBtn).CornerRadius = UDim.new(0, 4)

flySpeedBtn.MouseButton1Click:Connect(function()
    if flySpeed == 50 then flySpeed = 100
    elseif flySpeed == 100 then flySpeed = 150
    elseif flySpeed == 150 then flySpeed = 200
    elseif flySpeed == 200 then flySpeed = 300
    elseif flySpeed == 300 then flySpeed = 500
    else flySpeed = 50 end
    flySpeedBtn.Text = " Fly Speed: " .. flySpeed
end)

addToggle(visualsCol, "ESP (이름 표시)", false, function(v) espEnabled = v end)
addToggle(visualsCol, "Box ESP (박스)", false, function(v) boxEspEnabled = v end)
addToggle(visualsCol, "Skeleton ESP (뼈대)", false, function(v) skeletonEnabled = v end) -- 토글 연동 완료

-- ==========================================
-- 6. Info 페이지
-- ==========================================
local infoLabel = Instance.new("TextLabel", InfoContentPage)
infoLabel.BackgroundTransparency = 1
infoLabel.Size = UDim2.new(1, -10, 0, 220)
infoLabel.Font = Enum.Font.Code
infoLabel.Text = [[
[ AQUA HUB - INFORMATION ]

• Status: Rivlox Anti-Cheat Bypassed Globally
• Version: v2.8.1 (Fixed Skeleton & Clean Cleanup)
• Developer: User & AI Collaborator

Notice:
- Skeleton ESP defaults to OFF and cleans up completely upon player death/removal.
]]
infoLabel.TextColor3 = Color3.fromRGB(170, 175, 185)
infoLabel.TextSize = 12
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.ZIndex = 53

-- ==========================================
-- 7. 메인 렌더링 및 철저한 ESP 정리 루프
-- ==========================================
local ActiveDrawings = {
    Names = {},
    Boxes = {},
    Skeletons = {}
}

local function GetClosestPlayerToCursor()
    local closestPlayer = nil
    local shortestDistance = FOVRadius
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            local targetPartObj = player.Character:FindFirstChild("Head")

            if humanoid and humanoid.Health > 0 and targetPartObj then
                local screenPoint, onScreen = Camera:WorldToViewportPoint(targetPartObj.Position)
                if onScreen then
                    local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePos).Magnitude
                    if distance < shortestDistance then
                        shortestDistance = distance
                        closestPlayer = player
                    end
                end
            end
        end
    end
    return closestPlayer
end

RunService.RenderStepped:Connect(function(dt)
    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChild("Humanoid")

    if speedEnabled and humanoid and rootPart then
        local moveDir = humanoid.MoveDirection
        if moveDir.Magnitude > 0 then
            rootPart.CFrame = rootPart.CFrame + (moveDir * (humanoid.WalkSpeed * (speedMultiplier - 1)) * dt)
        end
    end

    if noclipEnabled and char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end

    if flying and rootPart then
        local camCFrame = Camera.CFrame
        local moveVector = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVector = moveVector + camCFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVector = moveVector - camCFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVector = moveVector - camCFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVector = moveVector + camCFrame.RightVector end
        
        rootPart.Velocity = Vector3.new(0, 0, 0)
        rootPart.CFrame = rootPart.CFrame + (moveVector * flySpeed * dt)
    end

    if aimAssistEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local target = GetClosestPlayerToCursor()
        if target and target.Character and target.Character:FindFirstChild("Head") then
            local targetPos = target.Character.Head.Position
            local camPos = Camera.CFrame.Position
            local targetCFrame = CFrame.new(camPos, targetPos)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, 1 / Smoothness)
        end
    end

    local currentPlayers = {}
    for _, p in ipairs(Players:GetPlayers()) do
        currentPlayers[p] = true
    end

    -- 사용자가 나갔거나 죽은 플레이어의 이름/박스/스켈레톤 리소스 완벽 정리
    for player, txt in pairs(ActiveDrawings.Names) do
        if not currentPlayers[player] or not player.Character or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
            txt.Visible = false
            txt:Remove()
            ActiveDrawings.Names[player] = nil
        end
    end

    for player, box in pairs(ActiveDrawings.Boxes) do
        if not currentPlayers[player] or not player.Character or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
            box.Visible = false
            box:Remove()
            ActiveDrawings.Boxes[player] = nil
        end
    end

    for player, skel in pairs(ActiveDrawings.Skeletons) do
        if not skeletonEnabled or not currentPlayers[player] or not player.Character or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
            for _, line in pairs(skel) do
                line.Visible = false
                line:Remove()
            end
            ActiveDrawings.Skeletons[player] = nil
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local pChar = player.Character
            local pRoot = pChar:FindFirstChild("HumanoidRootPart")
            local pHead = pChar:FindFirstChild("Head")
            local pHum = pChar:FindFirstChild("Humanoid")

            -- 이름 ESP
            if espEnabled and pRoot and pHum and pHum.Health > 0 then
                if not ActiveDrawings.Names[player] then
                    local txt = Drawing.new("Text")
                    txt.Visible = false
                    txt.Center = true
                    txt.Outline = true
                    txt.Color = Color3.fromRGB(255, 255, 255)
                    txt.Size = 13
                    ActiveDrawings.Names[player] = txt
                end
                local txt = ActiveDrawings.Names[player]
                local vec, onScr = Camera:WorldToViewportPoint(pRoot.Position + Vector3.new(0, 2.5, 0))
                if onScr then
                    txt.Position = Vector2.new(vec.X, vec.Y)
                    txt.Text = player.Name
                    txt.Visible = true
                else
                    txt.Visible = false
                end
            else
                if ActiveDrawings.Names[player] then
                    ActiveDrawings.Names[player].Visible = false
                    ActiveDrawings.Names[player]:Remove()
                    ActiveDrawings.Names[player] = nil
                end
            end

            -- 박스 ESP
            if boxEspEnabled and pRoot and pHum and pHum.Health > 0 then
                if not ActiveDrawings.Boxes[player] then
                    local box = Drawing.new("Square")
                    box.Visible = false
                    box.Color = Color3.fromRGB(255, 255, 255)
                    box.Thickness = 1
                    box.Filled = false
                    ActiveDrawings.Boxes[player] = box
                end
                local box = ActiveDrawings.Boxes[player]
                local vec, onScr = Camera:WorldToViewportPoint(pRoot.Position)
                if onScr then
                    local size = Vector2.new(2500 / vec.Z, 3500 / vec.Z)
                    box.Size = size
                    box.Position = Vector2.new(vec.X - size.X / 2, vec.Y - size.Y / 2)
                    box.Visible = true
                else
                    box.Visible = false
                end
            else
                if ActiveDrawings.Boxes[player] then
                    ActiveDrawings.Boxes[player].Visible = false
                    ActiveDrawings.Boxes[player]:Remove()
                    ActiveDrawings.Boxes[player] = nil
                end
            end

            -- 스켈레톤 ESP (토글이 켜져 있을 때만 작동하며 대상이 죽거나 사라지면 깨끗이 소멸)
            if skeletonEnabled and pHum and pHum.Health > 0 then
                local torso = pChar:FindFirstChild("Torso") or pChar:FindFirstChild("UpperTorso")
                local leftArm = pChar:FindFirstChild("Left Arm") or pChar:FindFirstChild("LeftUpperArm")
                local rightArm = pChar:FindFirstChild("Right Arm") or pChar:FindFirstChild("RightUpperArm")
                local leftLeg = pChar:FindFirstChild("Left Leg") or pChar:FindFirstChild("LeftUpperLeg")
                local rightLeg = pChar:FindFirstChild("Right Leg") or pChar:FindFirstChild("RightUpperLeg")

                if pHead and torso then
                    if not ActiveDrawings.Skeletons[player] then
                        ActiveDrawings.Skeletons[player] = {
                            HeadToTorso = Drawing.new("Line"),
                            TorsoToLeftArm = Drawing.new("Line"),
                            TorsoToRightArm = Drawing.new("Line"),
                            TorsoToLeftLeg = Drawing.new("Line"),
                            TorsoToRightLeg = Drawing.new("Line")
                        }
                        for _, line in pairs(ActiveDrawings.Skeletons[player]) do
                            line.Visible = false
                            line.Color = Color3.fromRGB(255, 255, 255)
                            line.Thickness = 1
                        end
                    end

                    local skel = ActiveDrawings.Skeletons[player]
                    local headPos, headOn = Camera:WorldToViewportPoint(pHead.Position)
                    local torsoPos, torsoOn = Camera:WorldToViewportPoint(torso.Position)

                    if headOn and torsoOn then
                        skel.HeadToTorso.From = Vector2.new(headPos.X, headPos.Y)
                        skel.HeadToTorso.To = Vector2.new(torsoPos.X, torsoPos.Y)
                        skel.HeadToTorso.Visible = true
                    else
                        skel.HeadToTorso.Visible = false
                    end

                    if leftArm and torso then
                        local lArmPos, lArmOn = Camera:WorldToViewportPoint(leftArm.Position)
                        if torsoOn and lArmOn then
                            skel.TorsoToLeftArm.From = Vector2.new(torsoPos.X, torsoPos.Y)
                            skel.TorsoToLeftArm.To = Vector2.new(lArmPos.X, lArmPos.Y)
                            skel.TorsoToLeftArm.Visible = true
                        else
                            skel.TorsoToLeftArm.Visible = false
                        end
                    end

                    if rightArm and torso then
                        local rArmPos, rArmOn = Camera:WorldToViewportPoint(rightArm.Position)
                        if torsoOn and rArmOn then
                            skel.TorsoToRightArm.From = Vector2.new(torsoPos.X, torsoPos.Y)
                            skel.TorsoToRightArm.To = Vector2.new(rArmPos.X, rArmPos.Y)
                            skel.TorsoToRightArm.Visible = true
                        else
                            skel.TorsoToRightArm.Visible = false
                        end
                    end

                    if leftLeg and torso then
                        local lLegPos, lLegOn = Camera:WorldToViewportPoint(leftLeg.Position)
                        if torsoOn and lLegOn then
                            skel.TorsoToLeftLeg.From = Vector2.new(torsoPos.X, torsoPos.Y)
                            skel.TorsoToLeftLeg.To = Vector2.new(lLegPos.X, lLegPos.Y)
                            skel.TorsoToLeftLeg.Visible = true
                        else
                            skel.TorsoToLeftLeg.Visible = false
                        end
                    end

                    if rightLeg and torso then
                        local rLegPos, rLegOn = Camera:WorldToViewportPoint(rightLeg.Position)
                        if torsoOn and rLegOn then
                            skel.TorsoToRightLeg.From = Vector2.new(torsoPos.X, torsoPos.Y)
                            skel.TorsoToRightLeg.To = Vector2.new(rLegPos.X, rLegPos.Y)
                            skel.TorsoToRightLeg.Visible = true
                        else
                            skel.TorsoToRightLeg.Visible = false
                        end
                    end
                else
                    if ActiveDrawings.Skeletons[player] then
                        for _, line in pairs(ActiveDrawings.Skeletons[player]) do
                            line.Visible = false
                            line:Remove()
                        end
                        ActiveDrawings.Skeletons[player] = nil
                    end
                end
            else
                if ActiveDrawings.Skeletons[player] then
                    for _, line in pairs(ActiveDrawings.Skeletons[player]) do
                        line.Visible = false
                        line:Remove()
                    end
                    ActiveDrawings.Skeletons[player] = nil
                end
            end
        end
    end
end)
