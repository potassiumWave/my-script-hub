-- ==============================================================================
-- AQUA-HUB (COMBAT + RAGEBOT + AIMBOT + WORKING TRIGGERBOT + ESP + CHAR + SKIN CHANGER + FAST SHOOT + SHADER)
-- ==============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

pcall(function()
    for _, gui in ipairs(game:GetService("CoreGui"):GetChildren()) do
        if gui.Name == "AquaHUB" or gui.Name == "LinoriaGui" then
            gui:Destroy()
        end
    end
end)

local ragebotActive = false
local cameraDesyncEnabled = false
local speedEnabled = false
local speedMultiplier = 1.05
local noclipEnabled = false
local flying = false
local flySpeed = 50
local infiniteJumpEnabled = false
local fastShootEnabled = false

-- Aimbot Variables
local aimbotEnabled = false
local aimbotKeybind = Enum.UserInputType.MouseButton2
local aimbotTargetPart = "Head"
local aimbotSmoothness = 5
local aimbotFov = 150
local aimbotFovCircleVisible = true

local triggerbotEnabled = false
local triggerbotTargetPart = "Head"
local lastTriggerTime = 0

local espEnabled = false
local boxEspEnabled = false
local skeletonEspEnabled = false
local distanceEspEnabled = false
local healthEspEnabled = false
local rainbowHpEnabled = false
local espCustomColor = Color3.fromRGB(255, 255, 255)
local skinChangerEnabled = true

-- Shader Variables
local shaderEnabled = false
local shaderLightingColor = Color3.fromRGB(200, 220, 255)
local shaderBrightness = 2
local shaderExposure = 0.5
local shaderAtmosphereDensity = 0.25

local playerScripts = LocalPlayer:WaitForChild("PlayerScripts", 10)
local controllers = playerScripts and playerScripts:WaitForChild("Controllers", 10)

local EnumLibrary = nil
pcall(function()
    local lib = require(ReplicatedStorage.Modules:WaitForChild("EnumLibrary", 5))
    if type(lib) == "table" then
        EnumLibrary = lib
        if EnumLibrary.WaitForEnumBuilder then
            EnumLibrary:WaitForEnumBuilder()
        end
    end
end)

local CosmeticLibrary = nil
pcall(function()
    local lib = require(ReplicatedStorage.Modules:WaitForChild("CosmeticLibrary", 5))
    if type(lib) == "table" then CosmeticLibrary = lib end
end)

local ItemLibrary = nil
pcall(function()
    local lib = require(ReplicatedStorage.Modules:WaitForChild("ItemLibrary", 5))
    if type(lib) == "table" then ItemLibrary = lib end
end)

local DataController = nil
if controllers then
    pcall(function()
        local lib = require(controllers:WaitForChild("PlayerDataController", 5))
        if type(lib) == "table" then DataController = lib end
    end)
end

local equipped, favorites = {}, {}
local constructingWeapon, viewingProfile = nil, nil
local lastUsedWeapon = nil

local function cloneCosmetic(name, cosmeticType, options)
    if not CosmeticLibrary or type(CosmeticLibrary.Cosmetics) ~= "table" then return nil end
    local base = CosmeticLibrary.Cosmetics[name]
    if not base then return nil end
    local data = {}
    for key, value in pairs(base) do data[key] = value end
    data.Name = name
    data.Type = data.Type or cosmeticType
    data.Seed = data.Seed or math.random(1, 1000000)
    if EnumLibrary and type(EnumLibrary.ToEnum) == "function" then
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
        if makefolder then pcall(function() makefolder("unlockall") end) end
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

if CosmeticLibrary then
    pcall(function()
        local originalOwnsCosmetic = CosmeticLibrary.OwnsCosmetic
        if originalOwnsCosmetic then
            CosmeticLibrary.OwnsCosmetic = function(self, inventory, name, weapon)
                if not skinChangerEnabled then return originalOwnsCosmetic(self, inventory, name, weapon) end
                if type(name) == "string" and name:find("MISSING_") then return originalOwnsCosmetic(self, inventory, name, weapon) end
                local cosmetic = CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[name]
                if cosmetic then
                    local cType = cosmetic.Type
                    if cType == "Skin" or cType == "Charm" or cType == "Dance" or cType == "Emote" or cType == "Wrap" or cType == "Wrapping" or (type(name) == "string" and (name:lower():find("charm") or name:lower():find("dance") or name:lower():find("emote") or name:lower():find("wrap"))) then
                        return true
                    end
                end
                return originalOwnsCosmetic(self, inventory, name, weapon)
            end
        end

        CosmeticLibrary.OwnsCosmeticNormally = function(self, inventory, name, weapon)
            if not skinChangerEnabled then return false end
            local cosmetic = CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[name]
            if cosmetic and cosmetic.Type == "Skin" then return true end
            return false
        end

        CosmeticLibrary.OwnsCosmeticUniversally = function(self, inventory, name, weapon)
            if not skinChangerEnabled then return false end
            local cosmetic = CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[name]
            if cosmetic and cosmetic.Type == "Skin" then return true end
            return false
        end

        CosmeticLibrary.OwnsCosmeticForWeapon = function(self, inventory, name, weapon)
            if not skinChangerEnabled then return false end
            local cosmetic = CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[name]
            if cosmetic and cosmetic.Type == "Skin" then return true end
            return false
        end
    end)
end

if DataController and type(DataController.Get) == "function" then
    local originalGet = DataController.Get
    DataController.Get = function(self, key)
        local data = originalGet(self, key)
        if not skinChangerEnabled then return data end

        if key == "CosmeticInventory" then
            local proxy = {}
            if data then 
                for k, v in pairs(data) do 
                    local cosmetic = CosmeticLibrary and CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[k]
                    if cosmetic then proxy[k] = v end
                end 
            end
            return setmetatable(proxy, {__index = function(t, k)
                local cosmetic = CosmeticLibrary and CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[k]
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
end

if DataController and type(DataController.GetWeaponData) == "function" then
    local originalGetWeaponData = DataController.GetWeaponData
    DataController.GetWeaponData = function(self, weaponName)
        local data = originalGetWeaponData(self, weaponName)
        if not skinChangerEnabled or not data then return data end
        local merged = {}
        if type(data) == "table" then
            for key, value in pairs(data) do merged[key] = value end
        end
        merged.Name = weaponName
        if equipped[weaponName] then
            for cosmeticType, cosmeticData in pairs(equipped[weaponName]) do 
                merged[cosmeticType] = cosmeticData
            end
        end
        return merged
    end
end

local FighterController = nil
if controllers then
    pcall(function() 
        local lib = require(controllers:WaitForChild("FighterController", 5))
        if type(lib) == "table" then FighterController = lib end
    end)
end

if hookmetamethod then
    pcall(function()
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
                        local inventory = DataController and originalGet(DataController, "CosmeticInventory")
                        if inventory and rawget(inventory, cosmeticName) then 
                            return oldNamecall(self, ...) 
                        end
                    end
                    
                    if cosmeticType == "Dance" or cosmeticType == "Emote" or (type(cosmeticName) == "string" and (cosmeticName:lower():find("dance") or cosmeticName:lower():find("emote"))) then
                        equipped.Dances = equipped.Dances or {}
                        if not cosmeticName or cosmeticName == "None" or cosmeticName == "" then
                            equipped.Dances[cosmeticType] = nil
                        else
                            local cloned = cloneCosmetic(cosmeticName, cosmeticType, {inverted = options.IsInverted, favoritesOnly = options.OnlyUseFavorites})
                            if cloned then equipped.Dances[cosmeticType] = cloned end
                        end
                        task.defer(function()
                            pcall(function() 
                                if DataController and DataController.CurrentData then 
                                    DataController.CurrentData:Replicate("CosmeticInventory") 
                                end 
                            end)
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
                        pcall(function() 
                            if DataController and DataController.CurrentData then 
                                DataController.CurrentData:Replicate("WeaponInventory") 
                            end 
                        end)
                        task.wait(0.1)
                        saveConfig()
                    end)
                    return
                end
                
                if self == favoriteRemote then
                    local wName, cName, isFav = args[1], args[2], args[3]
                    local cosmetic = CosmeticLibrary and CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[cName]
                    if cosmetic then
                        favorites[wName] = favorites[wName] or {}
                        favorites[wName][cName] = isFav or nil
                        saveConfig()
                        task.spawn(function() 
                            pcall(function() 
                                if DataController and DataController.CurrentData then 
                                    DataController.CurrentData:Replicate("FavoritedCosmetics") 
                                end 
                            end) 
                        end)
                    end
                    return
                end
            end
            
            return oldNamecall(self, ...)
        end)
    end)
end

local ClientItem = nil
pcall(function() 
    ClientItem = require(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem) 
end)

if ClientItem and ClientItem._CreateViewModel then
    local originalCreateViewModel = ClientItem._CreateViewModel
    ClientItem._CreateViewModel = function(self, viewmodelRef)
        local weaponName = self.Name
        local weaponPlayer = self.ClientFighter and self.ClientFighter.Player
        constructingWeapon = (weaponPlayer == LocalPlayer) and weaponName or nil
        
        if weaponPlayer == LocalPlayer and equipped[weaponName] and viewmodelRef then
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

local viewModelModule = nil
pcall(function()
    viewModelModule = LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem:FindFirstChild("ClientViewModel")
end)

if viewModelModule then
    local ClientViewModel = require(viewModelModule)
    
    if ClientViewModel.GetCharm then
        local originalGetCharmFunc = ClientViewModel.GetCharm
        ClientViewModel.GetCharm = function(self)
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
        if weaponPlayer == LocalPlayer and equipped[weaponName] then
            local ReplicatedClass = require(ReplicatedStorage.Modules.ReplicatedClass)
            local dataKey = ReplicatedClass:ToEnum("Data")
            replicatedData[dataKey] = replicatedData[dataKey] or {}
            
            local cosmetics = equipped[weaponName]
            if cosmetics.Skin then replicatedData[dataKey][ReplicatedClass:ToEnum("Skin")] = cosmetics.Skin end
            if cosmetics.Charm then replicatedData[dataKey][ReplicatedClass:ToEnum("Charm")] = cosmetics.Charm end
            if cosmetics.Wrap then replicatedData[dataKey][ReplicatedClass:ToEnum("Wrap")] = cosmetics.Wrap end
        end
        
        local result = originalNew(replicatedData, clientItem)
        
        if weaponPlayer == LocalPlayer and equipped[weaponName] and equipped[weaponName].Wrap and result._UpdateWrap then
            result:_UpdateWrap()
            task.delay(0.1, function() if not result._destroyed then result:_UpdateWrap() end end)
        end
        return result
    end
end

if ItemLibrary then
    ItemLibrary.GetViewModelImageFromWeaponData = function(self, weaponData, highRes)
        if not weaponData then return nil end
        local weaponName = weaponData.Name
        local shouldShowSkin = (weaponData.Skin and equipped[weaponName] and weaponData.Skin == equipped[weaponName].Skin) or (viewingProfile == LocalPlayer and equipped[weaponName] and equipped[weaponName].Skin)
        if shouldShowSkin and equipped[weaponName] and equipped[weaponName].Skin then
            local skinInfo = self.ViewModels and self.ViewModels[equipped[weaponName].Skin.Name]
            if skinInfo then return skinInfo[highRes and "ImageHighResolution" or "Image"] or skinInfo.Image end
        end
        return nil
    end
end

local EmoteController
pcall(function() 
    EmoteController = require(controllers:WaitForChild("EmoteController", 10))
    if EmoteController and EmoteController.GetEmotes then
        local originalGetEmotes = EmoteController.GetEmotes
        EmoteController.GetEmotes = function(self)
            local emotes = originalGetEmotes(self)
            if CosmeticLibrary and CosmeticLibrary.Cosmetics then
                for name, cosmetic in pairs(CosmeticLibrary.Cosmetics) do
                    if cosmetic and (cosmetic.Type == "Dance" or cosmetic.Type == "Emote" or (type(name) == "string" and (name:lower():find("dance") or name:lower():find("emote")))) then
                        if not emotes[name] then
                            emotes[name] = { Name = name, Type = cosmetic.Type, ObjectID = cosmetic.ObjectID, Enum = cosmetic.Enum }
                        end
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
                    __u3v4w5["Key_0"] = __w9x0y1:EncodeCFrame(CFrame.new(__j8k9l0, __d2e3f4) * CFrame.Angles(__m1n2o3:ToOrientation()))
                    __u3v4w5["Key_1"] = __w9x0y1:EncodeCFrame(CFrame.new(__d2e3f4) * CFrame.Angles(__m1n2o3:ToOrientation()))
                    __u3v4w5["Key_2"] = __a9b0c1
                    __u3v4w5["Key_3"] = __w9x0y1:EncodeCFrame(__p4q5r6)
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
            if not self.__desync and not cameraDesyncEnabled then return end
            local myChar = LocalPlayer.Character
            if not myChar then return end
            local __f6g7h8 = myChar:FindFirstChild("HumanoidRootPart")
            if not __f6g7h8 then return end

            local __i9j0k1 = __c3d4e5 and __c3d4e5.Character and __c3d4e5.Character:FindFirstChild("HumanoidRootPart")
            if not __i9j0k1 then
                if not cameraDesyncEnabled then self:__desync_stop() end
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
        if cameraDesyncEnabled then return end
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

-- Aimbot FOV Circle Drawing
local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Filled = false
fovCircle.Radius = aimbotFov
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Thickness = 1
fovCircle.Transparency = 0.7

local function GetClosestAimbotTarget()
    local target = nil
    local shortestDist = aimbotFov
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local myTeam = LocalPlayer:GetAttribute("TeamID")
            local targetTeam = player:GetAttribute("TeamID")
            if not myTeam or not targetTeam or myTeam ~= targetTeam then
                local char = player.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local targetPart = char:FindFirstChild(aimbotTargetPart) or char:FindFirstChild("Head")
                    if hum and hum.Health > 0 and targetPart then
                        local screenPoint, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                        if onScreen then
                            local dist = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePos).Magnitude
                            if dist < shortestDist then
                                shortestDist = dist
                                target = targetPart
                            end
                        end
                    end
                end
            end
        end
    end
    return target
end

RunService.RenderStepped:Connect(function()
    fovCircle.Visible = aimbotEnabled and aimbotFovCircleVisible
    fovCircle.Radius = aimbotFov
    fovCircle.Position = UserInputService:GetMouseLocation()

    if aimbotEnabled then
        local isHoldingKey = false
        if typeof(aimbotKeybind) == "EnumItem" then
            if aimbotKeybind.EnumType == Enum.UserInputType then
                isHoldingKey = UserInputService:IsMouseButtonPressed(aimbotKeybind)
            elseif aimbotKeybind.EnumType == Enum.KeyCode then
                isHoldingKey = UserInputService:IsKeyDown(aimbotKeybind)
            end
        end

        if isHoldingKey then
            local targetPart = GetClosestAimbotTarget()
            if targetPart then
                local currentCFrame = Camera.CFrame
                local targetCFrame = CFrame.new(currentCFrame.Position, targetPart.Position)
                Camera.CFrame = currentCFrame:Lerp(targetCFrame, math.clamp(aimbotSmoothness / 10, 0.01, 1))
            end
        end
    end

    -- Shader Render Loop
    if shaderEnabled then
        Lighting.Brightness = shaderBrightness
        Lighting.ExposureCompensation = shaderExposure
        Lighting.Ambient = shaderLightingColor
        
        local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
        if not atmosphere then
            atmosphere = Instance.new("Atmosphere")
            atmosphere.Parent = Lighting
        end
        atmosphere.Density = shaderAtmosphereDensity
        atmosphere.Color = shaderLightingColor
    end
end)

local success, err = pcall(function()
    local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
    local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
    local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
    local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

    local Window = Library:CreateWindow({
        Title = 'Aqua-HUB',
        Center = true,
        AutoShow = true,
        TabPadding = 8,
        MenuFadeTime = 0.2
    })

    local Tabs = {
        Main = Window:AddTab('main'),
        World = Window:AddTab('world'),
        ESP = Window:AddTab('esp'),
        Visuals = Window:AddTab('visuals'),
        Character = Window:AddTab('character'),
        Misc = Window:AddTab('misc'),
        Settings = Window:AddTab('settings'),
    }

    local LeftGroupBox = Tabs.Main:AddLeftGroupbox('ragebot')
    local RightGroupBox = Tabs.Main:AddRightGroupbox('triggerbot')

    LeftGroupBox:AddToggle('RageBotEnabled', {
        Text = 'Wallbang / RageBot',
        Default = false,
    }):OnChanged(function(v)
        ragebotActive = v
        if __p6q7r8.__s9t0u1 then
            __p6q7r8.__s9t0u1.__active = v
        end
    end)

    -- ====================== AIMBOT GROUPBOX ======================
    local AimbotGroupBox = Tabs.Main:AddLeftGroupbox('Aimbot')
    AimbotGroupBox:AddToggle('AimbotEnabled', {
        Text = 'Aimbot Enabled',
        Default = false,
    }):OnChanged(function(v)
        aimbotEnabled = v
    end)

    AimbotGroupBox:AddDropdown('AimbotTargetPart', {
        Values = { 'Head', 'HumanoidRootPart', 'UpperTorso' },
        Default = 1,
        Text = 'Aimbot Target Part',
    }):OnChanged(function(v)
        aimbotTargetPart = v
    end)

    AimbotGroupBox:AddSlider('AimbotSmoothness', {
        Text = 'Smoothness',
        Default = 5,
        Min = 1,
        Max = 20,
        Rounding = 1,
    }):OnChanged(function(v)
        aimbotSmoothness = v
    end)

    AimbotGroupBox:AddSlider('AimbotFOV', {
        Text = 'FOV Radius',
        Default = 150,
        Min = 20,
        Max = 500,
        Rounding = 0,
    }):OnChanged(function(v)
        aimbotFov = v
    end)

    AimbotGroupBox:AddToggle('AimbotFOVCircle', {
        Text = 'Draw FOV Circle',
        Default = true,
    }):OnChanged(function(v)
        aimbotFovCircleVisible = v
    end)

    -- ====================== RAPID SHOT ======================
    local RapidShotBox = Tabs.Main:AddLeftGroupbox('Rapid Shot')
    RapidShotBox:AddToggle('RapidShotToggle', {
        Text = 'Rapid Shot Enabled',
        Default = false,
    }):OnChanged(function(v)
        if v then
            if game.GameId == 6035872082 then
                local Storage = game:GetService("ReplicatedStorage")
                local Items = require(Storage.Modules.ItemLibrary).Items

                local gunExceptions = {
                    ["Sniper"] = false,
                    ["Crossbow"] = false,
                    ["Bow"] = false,
                    ["RPG"] = false,
                }

                for name, data in pairs(Items) do
                    if typeof(data) == "table" and not gunExceptions[name] then
                        if data.ShootSpread then data.ShootSpread = 0 end
                        if data.ShootAccuracy then data.ShootAccuracy = 0 end
                        if data.ShootRecoil then data.ShootRecoil = 0 end
                        if data.ShootCooldown then data.ShootCooldown = 0.001 end
                        if data.ShootBurstCooldown then data.ShootBurstCooldown = 0.001 end
                    end
                end

                for name, data in pairs(Items) do
                    if typeof(data) == "table" then
                        if data.AttackCooldown then data.AttackCooldown = 0.001 end
                        if data.SwingCooldown then data.SwingCooldown = 0.001 end
                        if data.MeleeCooldown then data.MeleeCooldown = 0.001 end
                        if data.Cooldown then data.Cooldown = 0.001 end
                        if data.RecoveryTime then data.RecoveryTime = 0.001 end
                        if data.ResetTime then data.ResetTime = 0.001 end
                    end
                end
            end
        end
    end)

    -- ====================== FAST SHOOT ======================
    local FastShootBox = Tabs.Main:AddLeftGroupbox('Fast Shoot')
    FastShootBox:AddToggle('FastShootToggle', {
        Text = 'Fast Shoot Enabled',
        Default = false,
    }):OnChanged(function(v)
        fastShootEnabled = v
    end)

    RightGroupBox:AddToggle('TrigEnabled', {
        Text = 'enabled',
        Default = false,
    }):OnChanged(function(v)
        triggerbotEnabled = v
    end)

    RightGroupBox:AddSlider('ReactionTime', {
        Text = 'reaction time',
        Default = 25,
        Min = 0,
        Max = 200,
        Rounding = 0,
        Suffix = 'ms',
    })

    RightGroupBox:AddSlider('Forget_Time', {
        Text = 'forget time',
        Default = 0.5,
        Min = 0,
        Max = 5,
        Rounding = 1,
        Suffix = 's',
    })

    RightGroupBox:AddDropdown('TargetPart', {
        Values = { 'Head', 'HumanoidRootPart', 'Torso' },
        Default = 1,
        Text = 'target part',
    }):OnChanged(function(v)
        triggerbotTargetPart = v
    end)

    -- ====================== WORLD TAB (SHADER) ======================
    local WorldGroupBox = Tabs.World:AddLeftGroupbox('Lighting & Shader')
    WorldGroupBox:AddToggle('ShaderToggle', {
        Text = 'Enable Shader',
        Default = false,
    }):OnChanged(function(v)
        shaderEnabled = v
        if not v then
            Lighting.Brightness = 1
            Lighting.ExposureCompensation = 0
            Lighting.Ambient = Color3.fromRGB(0, 0, 0)
            local atm = Lighting:FindFirstChildOfClass("Atmosphere")
            if atm then atm:Destroy() end
        end
    end)

    WorldGroupBox:AddSlider('ShaderBrightness', {
        Text = 'Brightness',
        Default = 2,
        Min = 0,
        Max = 5,
        Rounding = 1,
    }):OnChanged(function(v)
        shaderBrightness = v
    end)

    WorldGroupBox:AddSlider('ShaderExposure', {
        Text = 'Exposure',
        Default = 0.5,
        Min = -2,
        Max = 2,
        Rounding = 1,
    }):OnChanged(function(v)
        shaderExposure = v
    end)

    WorldGroupBox:AddSlider('ShaderAtmosphereDensity', {
        Text = 'Atmosphere Density',
        Default = 0.25,
        Min = 0,
        Max = 1,
        Rounding = 2,
    }):OnChanged(function(v)
        shaderAtmosphereDensity = v
    end)

    WorldGroupBox:AddLabel('Shader Color'):AddColorPicker('ShaderColorPicker', {
        Default = Color3.fromRGB(200, 220, 255),
        Title = 'Lighting Color',
        Callback = function(v) shaderLightingColor = v end
    })

    -- ====================== ESP TAB ======================
    local EspLeftBox = Tabs.ESP:AddLeftGroupbox('Visual ESP')
    EspLeftBox:AddToggle('EspToggle', { Text = 'Name ESP', Default = false }):OnChanged(function(v) espEnabled = v end)
    EspLeftBox:AddToggle('BoxEspToggle', { Text = 'Box ESP', Default = false }):OnChanged(function(v) boxEspEnabled = v end)
    EspLeftBox:AddToggle('SkeletonEspToggle', { Text = 'Skeleton ESP', Default = false }):OnChanged(function(v) skeletonEspEnabled = v end)
    EspLeftBox:AddToggle('DistanceEspToggle', { Text = 'Distance Display', Default = false }):OnChanged(function(v) distanceEspEnabled = v end)
    EspLeftBox:AddToggle('HealthEspToggle', { Text = 'Health Bar & HP', Default = false }):OnChanged(function(v) healthEspEnabled = v end)
    EspLeftBox:AddToggle('RainbowHpToggle', { Text = 'Rainbow HP Bar & Text', Default = false }):OnChanged(function(v) rainbowHpEnabled = v end)

    EspLeftBox:AddLabel('ESP Color'):AddColorPicker('EspColorPicker', {
        Default = Color3.fromRGB(255, 255, 255),
        Title = 'ESP Custom Color',
        Callback = function(v) espCustomColor = v end
    })

    -- ====================== VISUALS TAB ======================
    Tabs.Visuals:AddLeftGroupbox('Skin Changer'):AddToggle('SkinChangerToggle', {
        Text = 'Skin Changer Enabled',
        Default = true,
    }):OnChanged(function(v) skinChangerEnabled = v end)

    -- ====================== CHARACTER TAB ======================
    local CharLeftBox = Tabs.Character:AddLeftGroupbox('Movement')
    CharLeftBox:AddToggle('SpeedToggle', { Text = 'Custom Speed', Default = false }):OnChanged(function(v) speedEnabled = v end)
    CharLeftBox:AddSlider('SpeedMultiplierSlider', {
        Text = 'Speed Multiplier',
        Default = 1.05,
        Min = 1.0,
        Max = 3.0,
        Rounding = 2,
    }):OnChanged(function(v)
        speedMultiplier = v
    end)

    CharLeftBox:AddToggle('NoclipToggle', { Text = 'Noclip', Default = false }):OnChanged(function(v) noclipEnabled = v end)
    CharLeftBox:AddToggle('FlyToggle', { Text = 'Fly', Default = false }):OnChanged(function(v) flying = v end)
    CharLeftBox:AddSlider('FlySpeedSlider', { Text = 'Fly Speed', Default = 50, Min = 10, Max = 500, Rounding = 0 }):OnChanged(function(v) flySpeed = v end)
    CharLeftBox:AddToggle('InfiniteJumpToggle', { Text = 'Infinite Jump', Default = false }):OnChanged(function(v) infiniteJumpEnabled = v end)

    CharLeftBox:AddToggle('CamDesyncToggle', {
        Text = 'Camera Desync',
        Default = false,
    }):OnChanged(function(v)
        cameraDesyncEnabled = v
        if __p6q7r8.__s9t0u1 then
            if v then
                local target = __p6q7r8.__s9t0u1:__find()
                if target then __p6q7r8.__s9t0u1:__desync_start(target) end
            else
                __p6q7r8.__s9t0u1:__desync_stop()
            end
        end
    end)

    ThemeManager:SetLibrary(Library)
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({})
    SaveManager:BuildConfigSection(Tabs.Settings)
    ThemeManager:ApplyToTab(Tabs.Settings)

    Library:Notify('Aqua-HUB Loaded Successfully!', 3)
end)

if not success then
    warn("UI Load Error: ", err)
end

Library.ToggleKeybind = Enum.KeyCode.LeftShift

UserInputService.JumpRequest:Connect(function()
    if infiniteJumpEnabled then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

RunService.Stepped:Connect(function()
    if not fastShootEnabled then return end
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            local handle = tool:FindFirstChild("Handle")
            if handle then
                for _, obj in pairs(handle:GetChildren()) do
                    if obj:IsA("Sound") and (obj.Name:lower():find("shoot") or obj.Name:lower():find("fire")) then
                        obj.TimePosition = 0
                    end
                end
            end
        end
    end)
end)

local ActiveDrawings = {
    Names = {}, Distances = {}, Boxes = {}, Skeletons = {}, HpBars = {}, HpBacks = {}, HpTexts = {}
}

local function createSkeletonLines()
    local lines = {}
    local partsPair = {
        {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
        {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
        {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
        {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
        {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"}
    }
    for i = 1, #partsPair do
        local success, l = pcall(function() return Drawing.new("Line") end)
        if success and l then
            l.Visible = false
            l.Color = espCustomColor
            l.Thickness = 1
            table.insert(lines, {line = l, p1 = partsPair[i][1], p2 = partsPair[i][2]})
        end
    end
    return lines
end

local renderThrottle = 0
RunService.RenderStepped:Connect(function(dt)
    renderThrottle = (renderThrottle + 1) % 2
    if renderThrottle ~= 0 then return end

    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChild("Humanoid")

    local rainbowColor = Color3.fromHSV(tick() % 5 / 5, 1, 1)

    if triggerbotEnabled then
        pcall(function()
            local raycastParams = RaycastParams.new()
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            raycastParams.IgnoreWater = true
            
            local ignoreList = {char}
            if workspace:FindFirstChild("Ignored") then table.insert(ignoreList, workspace.Ignored) end
            raycastParams.FilterDescendantsInstances = ignoreList

            local unitRay = Camera:ScreenPointToRay(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            local rayResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)

            if rayResult and rayResult.Instance then
                local hitPart = rayResult.Instance
                local hitModel = hitPart.Parent
                local targetPlayer = Players:GetPlayerFromCharacter(hitModel)

                if targetPlayer and targetPlayer ~= LocalPlayer then
                    local myTeam = LocalPlayer:GetAttribute("TeamID")
                    local targetTeam = targetPlayer:GetAttribute("TeamID")
                    
                    if not myTeam or not targetTeam or myTeam ~= targetTeam then
                        local targetHum = hitModel:FindFirstChildOfClass("Humanoid")
                        if targetHum and targetHum.Health > 0 then
                            local isValidPart = false
                            if triggerbotTargetPart == "Head" and hitPart.Name == "Head" then
                                isValidPart = true
                            elseif triggerbotTargetPart == "HumanoidRootPart" and hitPart.Name == "HumanoidRootPart" then
                                isValidPart = true
                            elseif triggerbotTargetPart == "Torso" and (hitPart.Name == "UpperTorso" or hitPart.Name == "LowerTorso" or hitPart.Name == "Torso") then
                                isValidPart = true
                            end

                            if isValidPart then
                                local currentTime = tick()
                                if currentTime - lastTriggerTime > 0.1 then
                                    VirtualUser:Button1Down(Vector2.new(0,0))
                                    task.wait(0.02)
                                    VirtualUser:Button1Up(Vector2.new(0,0))
                                    lastTriggerTime = currentTime
                                end
                            end
                        end
                    end
                end
            end
        end)
    end

    if speedEnabled and humanoid and rootPart then
        local moveDir = humanoid.MoveDirection
        if moveDir.Magnitude > 0 then
            rootPart.CFrame = rootPart.CFrame + (moveDir * (humanoid.WalkSpeed * (speedMultiplier - 1)) * dt * 2)
        end
    end

    if noclipEnabled and char then
        local parts = char:GetDescendants()
        for i = 1, #parts do
            local part = parts[i]
            if part:IsA("BasePart") then part.CanCollide = false end
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

    local currentPlayers = {}
    local playersList = Players:GetPlayers()
    for i = 1, #playersList do currentPlayers[playersList[i]] = true end

    local function cleanDrawing(tbl, player)
        if tbl[player] then
            pcall(function()
                tbl[player].Visible = false
                tbl[player]:Remove()
            end)
            tbl[player] = nil
        end
    end

    for player in pairs(ActiveDrawings.Names) do
        if not currentPlayers[player] or not player.Character or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
            cleanDrawing(ActiveDrawings.Names, player)
            cleanDrawing(ActiveDrawings.Distances, player)
            cleanDrawing(ActiveDrawings.Boxes, player)
            cleanDrawing(ActiveDrawings.HpBars, player)
            cleanDrawing(ActiveDrawings.HpBacks, player)
            cleanDrawing(ActiveDrawings.HpTexts, player)
            if ActiveDrawings.Skeletons[player] then
                for _, item in ipairs(ActiveDrawings.Skeletons[player]) do
                    pcall(function()
                        item.line.Visible = false
                        item.line:Remove()
                    end)
                end
                ActiveDrawings.Skeletons[player] = nil
            end
        end
    end

    for i = 1, #playersList do
        local player = playersList[i]
        if player ~= LocalPlayer and player.Character then
            local pChar = player.Character
            local pRoot = pChar:FindFirstChild("HumanoidRootPart")
            local pHum = pChar:FindFirstChild("Humanoid")

            pcall(function()
                if espEnabled and pRoot and pHum and pHum.Health > 0 then
                    if not ActiveDrawings.Names[player] then
                        local success, txt = pcall(function() return Drawing.new("Text") end)
                        if success and txt then
                            txt.Visible = false
                            txt.Center = true
                            txt.Outline = true
                            txt.Size = 14
                            ActiveDrawings.Names[player] = txt
                        end
                    end
                    local txt = ActiveDrawings.Names[player]
                    if txt then
                        txt.Color = espCustomColor
                        local vec, onScr = Camera:WorldToViewportPoint(pRoot.Position + Vector3.new(0, 2.7, 0))
                        if onScr then
                            txt.Position = Vector2.new(vec.X, vec.Y)
                            txt.Text = player.Name
                            txt.Visible = true
                        else
                            txt.Visible = false
                        end
                    end
                else
                    cleanDrawing(ActiveDrawings.Names, player)
                end

                if distanceEspEnabled and pRoot and rootPart and pHum and pHum.Health > 0 then
                    if not ActiveDrawings.Distances[player] then
                        local success, distTxt = pcall(function() return Drawing.new("Text") end)
                        if success and distTxt then
                            distTxt.Visible = false
                            distTxt.Center = true
                            distTxt.Outline = true
                            distTxt.Size = 18
                            ActiveDrawings.Distances[player] = distTxt
                        end
                    end
                    local distTxt = ActiveDrawings.Distances[player]
                    if distTxt then
                        distTxt.Color = espCustomColor
                        local vec, onScr = Camera:WorldToViewportPoint(pRoot.Position - Vector3.new(0, 3.2, 0))
                        if onScr then
                            distTxt.Position = Vector2.new(vec.X, vec.Y)
                            local distVal = math.floor((pRoot.Position - rootPart.Position).Magnitude)
                            distTxt.Text = "[" .. distVal .. "m]"
                            distTxt.Visible = true
                        else
                            distTxt.Visible = false
                        end
                    end
                else
                    cleanDrawing(ActiveDrawings.Distances, player)
                end

                if boxEspEnabled and pRoot and pHum and pHum.Health > 0 then
                    if not ActiveDrawings.Boxes[player] then
                        local success, box = pcall(function() return Drawing.new("Square") end)
                        if success and box then
                            box.Visible = false
                            box.Thickness = 1
                            box.Filled = false
                            ActiveDrawings.Boxes[player] = box
                        end
                    end
                    local box = ActiveDrawings.Boxes[player]
                    if box then
                        box.Color = espCustomColor
                        local vec, onScr = Camera:WorldToViewportPoint(pRoot.Position)
                        if onScr then
                            local size = Vector2.new(2500 / vec.Z, 3500 / vec.Z)
                            box.Size = size
                            box.Position = Vector2.new(vec.X - size.X / 2, vec.Y - size.Y / 2)
                            box.Visible = true
                        else
                            box.Visible = false
                        end
                    end
                else
                    cleanDrawing(ActiveDrawings.Boxes, player)
                end

                if healthEspEnabled and pRoot and pHum and pHum.Health > 0 then
                    if not ActiveDrawings.HpBacks[player] then
                        local success1, hpBack = pcall(function() return Drawing.new("Square") end)
                        local success2, hpBar = pcall(function() return Drawing.new("Square") end)
                        local success3, hpTxt = pcall(function() return Drawing.new("Text") end)
                        if success1 and hpBack then hpBack.Visible = false hpBack.Filled = true hpBack.Color = Color3.fromRGB(0, 0, 0) ActiveDrawings.HpBacks[player] = hpBack end
                        if success2 and hpBar then hpBar.Visible = false hpBar.Filled = true ActiveDrawings.HpBars[player] = hpBar end
                        if success3 and hpTxt then hpTxt.Visible = false hpTxt.Center = false hpTxt.Outline = true hpTxt.Size = 16 ActiveDrawings.HpTexts[player] = hpTxt end
                    end

                    local hpBack = ActiveDrawings.HpBacks[player]
                    local hpBar = ActiveDrawings.HpBars[player]
                    local hpTxt = ActiveDrawings.HpTexts[player]

                    local vec, onScr = Camera:WorldToViewportPoint(pRoot.Position)
                    if onScr and hpBack and hpBar and hpTxt then
                        local size = Vector2.new(2500 / vec.Z, 3500 / vec.Z)
                        local barWidth = 6
                        local barX = (vec.X - size.X / 2) - barWidth - 6
                        local barY = vec.Y - size.Y / 2
                        local barHeight = size.Y

                        hpBack.Size = Vector2.new(barWidth, barHeight)
                        hpBack.Position = Vector2.new(barX, barY)
                        hpBack.Visible = true

                        local healthPercent = math.clamp(pHum.Health / pHum.MaxHealth, 0, 1)
                        local currentHeight = barHeight * healthPercent

                        hpBar.Size = Vector2.new(barWidth - 2, currentHeight - 2)
                        hpBar.Position = Vector2.new(barX + 1, barY + (barHeight - currentHeight) + 1)
                        
                        if rainbowHpEnabled then
                            hpBar.Color = rainbowColor
                        else
                            hpBar.Color = Color3.fromRGB(255 - (healthPercent * 255), healthPercent * 255, 0)
                        end
                        hpBar.Visible = true

                        hpTxt.Position = Vector2.new(barX + barWidth + 4, barY + (barHeight / 2) - 8)
                        hpTxt.Text = math.floor(pHum.Health) + " HP"
                        hpTxt.Color = rainbowHpEnabled and rainbowColor or Color3.fromRGB(255, 255, 255)
                        hpTxt.Visible = true
                    else
                        if hpBack then hpBack.Visible = false end
                        if hpBar then hpBar.Visible = false end
                        if hpTxt then hpTxt.Visible = false end
                    end
                else
                    cleanDrawing(ActiveDrawings.HpBacks, player)
                    cleanDrawing(ActiveDrawings.HpBars, player)
                    cleanDrawing(ActiveDrawings.HpTexts, player)
                end

                if skeletonEspEnabled and pHum and pHum.Health > 0 then
                    if not ActiveDrawings.Skeletons[player] then
                        ActiveDrawings.Skeletons[player] = createSkeletonLines()
                    end
                    local skel = ActiveDrawings.Skeletons[player]
                    if skel then
                        for _, item in ipairs(skel) do
                            item.line.Color = espCustomColor
                            local part1 = pChar:FindFirstChild(item.p1)
                            local part2 = pChar:FindFirstChild(item.p2)
                            if part1 and part2 then
                                local v1, on1 = Camera:WorldToViewportPoint(part1.Position)
                                local v2, on2 = Camera:WorldToViewportPoint(part2.Position)
                                if on1 and on2 then
                                    item.line.From = Vector2.new(v1.X, v1.Y)
                                    item.line.To = Vector2.new(v2.X, v2.Y)
                                    item.line.Visible = true
                                else
                                    item.line.Visible = false
                                end
                            else
                                item.line.Visible = false
                            end
                        end
                    end
                else
                    if ActiveDrawings.Skeletons[player] then
                        for _, item in ipairs(ActiveDrawings.Skeletons[player]) do
                            pcall(function()
                                item.line.Visible = false
                                item.line:Remove()
                            end)
                        end
                        ActiveDrawings.Skeletons[player] = nil
                    end
                end
            end)
        end
    end
end)
