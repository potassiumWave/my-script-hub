-- ==============================================================================
-- AQUA_HUB 코드 뜯지마라 쌉쌉꾸야
-- ==============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- 0. anticheat bypass module
-- ==========================================
pcall(function()
    if getrawmetatable then
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
    end
end)

-- 이전 실행된 커스텀 UI 안전하게 제거
pcall(function()
    local oldUI = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("AQUA_UltimateUI") or game:GetService("CoreGui"):FindFirstChild("AQUA_UltimateUI")
    if oldUI then oldUI:Destroy() end
end)

-- ==========================================
-- 1. 기능 상태 변수 및 스킨 체인저 마스터 스위치
-- ==========================================
local combatDesyncActive = false
local aimAssistEnabled = false
local triggerBotEnabled = false -- 트리거봇 변수 추가
local teamCheckEnabled = true   -- 팀 체크 변수 추가
local movementDesyncEnabled = false
local speedEnabled = false
local speedMultiplier = 1.05
local noclipEnabled = false
local flying = false
local flySpeed = 50
local espEnabled = false
local boxEspEnabled = false
local skeletonEnabled = false
local FOVRadius = 300
local Smoothness = 3

local skinChangerEnabled = true

local playerScripts = LocalPlayer:WaitForChild("PlayerScripts", 10)
local controllers = playerScripts and playerScripts:FindFirstChild("Controllers")

local EnumLibrary, CosmeticLibrary, ItemLibrary, DataController
pcall(function()
    EnumLibrary = require(ReplicatedStorage.Modules:WaitForChild("EnumLibrary", 5))
    if EnumLibrary then EnumLibrary:WaitForEnumBuilder() end
    CosmeticLibrary = require(ReplicatedStorage.Modules:WaitForChild("CosmeticLibrary", 5))
    ItemLibrary = require(ReplicatedStorage.Modules:WaitForChild("ItemLibrary", 5))
    DataController = require(controllers:WaitForChild("PlayerDataController", 5))
end)

local equipped, favorites = {}, {}

local function cloneCosmetic(name, cosmeticType, options)
    if not CosmeticLibrary or not CosmeticLibrary.Cosmetics then return nil end
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
        if makefolder then makefolder("unlockall") end
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

pcall(function()
    if CosmeticLibrary then
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
    end
end)

pcall(function()
    if DataController and DataController.Get then
        local originalGet = DataController.Get
        DataController.Get = function(self, key)
            local data = originalGet(self, key)
            if not skinChangerEnabled then return data end

            if key == "CosmeticInventory" then
                local proxy = {}
                if data then for k, v in pairs(data) do 
                    local cosmetic = CosmeticLibrary and CosmeticLibrary.Cosmetics and CosmeticLibrary.Cosmetics[k]
                    if cosmetic then proxy[k] = v end
                end end
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
end)

loadConfig()

-- 팀 체크 함수
local function isEnemy(player)
    if player == LocalPlayer then return false end
    if not teamCheckEnabled then return true end
    if player.Team and LocalPlayer.Team then
        return player.Team ~= LocalPlayer.Team
    end
    return true
end

-- ==========================================
-- 2. 디싱크 및 사일런트 (안전 장치 포함)
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

        if successGun and successUtil and __t6u7v8 and __w9x0y1 then
            local __l4m5n6 = __t6u7v8.StartShooting
            if __l4m5n6 then
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
                        task.wait(0.05)
                    end

                    if self.__task1 then
                        task.cancel(self.__task1)
                        self.__task1 = nil
                    end

                    local __a9b0c1 = __x6y7z8.Character:FindFirstChild("Head")
                    if not __a9b0c1 then return unpack(__r0s1t2) end

                    local __d2e3f4 = __a9b0c1.Position
                    local __g5h6i7 = __a9b0c1.CFrame
                    local __j8k9l0 = __d2e3f4 - Vector3.new(0, 3, 0)
                    local __m1n2o3 = CFrame.lookAt(__j8k9l0, __d2e3f4)

                    pcall(function()
                        __u3v4w5[utf8.char(0)] = __w9x0y1:EncodeCFrame(CFrame.new(__j8k9l0, __d2e3f4) * CFrame.Angles(__m1n2o3:ToOrientation()))
                    end)

                    self.__task1 = task.delay(0.1, function()
                        self:__desync_stop()
                    end)

                    return unpack(__r0s1t2)
                end
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
            if not isEnemy(player) then continue end
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
            __f6g7h8.CFrame = __i9j0k1.CFrame * CFrame.new(0, -3, 0)

            RunService:BindToRenderStep("__restore", 101, function()
                if __f6g7h8 and __l2m3n4 then
                    __f6g7h8.CFrame = __l2m3n4
                end
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
        if self.__oldfunc and successGun and __t6u7v8 then
            __t6u7v8.StartShooting = self.__oldfunc
        end
    end

    __i1j2k3:__init()
end

-- ==========================================
-- 3. 안정적인 UI 시스템 (ScreenGui)
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AQUA_UltimateUI"
ScreenGui.ResetOnSpawn = false
pcall(function()
    if syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = game:GetService("CoreGui")
    elseif gethui then
        ScreenGui.Parent = gethui()
    else
        ScreenGui.Parent = game:GetService("CoreGui")
    end
end)
if not ScreenGui.Parent then
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
TitleBar.Text = "Aqua Hub - Triggerbot Added Build"
TitleBar.TextColor3 = Color3.fromRGB(180, 185, 195)
TitleBar.TextSize = 13
TitleBar.TextXAlignment = Enum.TextXAlignment.Left
TitleBar.ZIndex = 51

-- ==========================================
-- 4. 탭 시스템
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
-- 5. 메뉴 컬럼 생성
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
        pcall(function() callback(state) end)
    end)
end

addToggle(combatCol, "팀 체크 (아팀 보호)", true, function(v)
    teamCheckEnabled = v
end)

addToggle(combatCol, "고성능 디싱크/사일런트", false, function(v)
    combatDesyncActive = v
    if __p6q7r8.__s9t0u1 then
        __p6q7r8.__s9t0u1.__active = v
    end
end)

addToggle(combatCol, "Aimbot (우클릭 보정)", false, function(v)
    aimAssistEnabled = v
end)

addToggle(combatCol, "Triggerbot (트리거봇)", false, function(v)
    triggerBotEnabled = v
end)

addToggle(visualsCol, "Skin Changer (스킨체인저)", true, function(v)
    skinChangerEnabled = v
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
addToggle(visualsCol, "Skeleton ESP (뼈대)", false, function(v) skeletonEnabled = v end)

-- ==========================================
-- 6. Info 페이지
-- ==========================================
local infoLabel = Instance.new("TextLabel", InfoContentPage)
infoLabel.BackgroundTransparency = 1
infoLabel.Size = UDim2.new(1, -10, 0, 220)
infoLabel.Font = Enum.Font.Code
infoLabel.Text = [[
[ AQUA HUB - INFORMATION ]

• Status: Anti-Crash & Triggerbot Added
• Version: v2.9.0 (Null-Safe Execution)
• Developer: User & AI Collaborator

Notice:
- Triggerbot automatically fires when your crosshair is on an enemy.
]]
infoLabel.TextColor3 = Color3.fromRGB(170, 175, 185)
infoLabel.TextSize = 12
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.ZIndex = 53

-- ==========================================
-- 7. 메인 루프 (트리거봇 및 기타 기능 포함)
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
        if isEnemy(player) and player.Character then
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
    pcall(function()
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

        -- 트리거봇 로직 (마우스 크로스헤어 타겟팅)
        if triggerBotEnabled then
            local mouseTarget = LocalPlayer:GetMouse().Target
            if mouseTarget and mouseTarget.Parent then
                local targetPlayer = Players:GetPlayerFromCharacter(mouseTarget.Parent)
                if targetPlayer and isEnemy(targetPlayer) then
                    pcall(function()
                        mouse1click()
                    end)
                end
            end
        end

        local currentPlayers = {}
        for _, p in ipairs(Players:GetPlayers()) do
            currentPlayers[p] = true
        end

        for player, txt in pairs(ActiveDrawings.Names) do
            if not currentPlayers[player] or not player.Character or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
                pcall(function() txt.Visible = false txt:Remove() end)
                ActiveDrawings.Names[player] = nil
            end
        end

        for player, box in pairs(ActiveDrawings.Boxes) do
            if not currentPlayers[player] or not player.Character or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
                pcall(function() box.Visible = false box:Remove() end)
                ActiveDrawings.Boxes[player] = nil
            end
        end

        for player, skel in pairs(ActiveDrawings.Skeletons) do
            if not skeletonEnabled or not currentPlayers[player] or not player.Character or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
                for _, line in pairs(skel) do
                    pcall(function() line.Visible = false line:Remove() end)
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

                if espEnabled and pRoot and pHum and pHum.Health > 0 then
                    if not ActiveDrawings.Names[player] then
                        pcall(function()
                            local txt = Drawing.new("Text")
                            txt.Visible = false
                            txt.Center = true
                            txt.Outline = true
                            txt.Color = Color3.fromRGB(255, 255, 255)
                            txt.Size = 13
                            ActiveDrawings.Names[player] = txt
                        end)
                    end
                    local txt = ActiveDrawings.Names[player]
                    if txt then
                        local vec, onScr = Camera:WorldToViewportPoint(pRoot.Position + Vector3.new(0, 2.5, 0))
                        if onScr then
                            txt.Position = Vector2.new(vec.X, vec.Y)
                            txt.Text = player.Name
                            txt.Visible = true
                        else
                            txt.Visible = false
                        end
                    end
                else
                    if ActiveDrawings.Names[player] then
                        pcall(function() ActiveDrawings.Names[player].Visible = false ActiveDrawings.Names[player]:Remove() end)
                        ActiveDrawings.Names[player] = nil
                    end
                end

                if boxEspEnabled and pRoot and pHum and pHum.Health > 0 then
                    if not ActiveDrawings.Boxes[player] then
                        pcall(function()
                            local box = Drawing.new("Square")
                            box.Visible = false
                            box.Color = Color3.fromRGB(255, 255, 255)
                            box.Thickness = 1
                            box.Filled = false
                            ActiveDrawings.Boxes[player] = box
                        end)
                    end
                    local box = ActiveDrawings.Boxes[player]
                    if box then
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
                    if ActiveDrawings.Boxes[player] then
                        pcall(function() ActiveDrawings.Boxes[player].Visible = false ActiveDrawings.Boxes[player]:Remove() end)
                        ActiveDrawings.Boxes[player] = nil
                    end
                end

                if skeletonEnabled and pHum and pHum.Health > 0 then
                    local torso = pChar:FindFirstChild("Torso") or pChar:FindFirstChild("UpperTorso")
                    local leftArm = pChar:FindFirstChild("Left Arm") or pChar:FindFirstChild("LeftUpperArm")
                    local rightArm = pChar:FindFirstChild("Right Arm") or pChar:FindFirstChild("RightUpperArm")
                    local leftLeg = pChar:FindFirstChild("Left Leg") or pChar:FindFirstChild("LeftUpperLeg")
                    local rightLeg = pChar:FindFirstChild("Right Leg") or pChar:FindFirstChild("RightUpperLeg")

                    if pHead and torso then
                        if not ActiveDrawings.Skeletons[player] then
                            pcall(function()
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
                            end)
                        end

                        local skel = ActiveDrawings.Skeletons[player]
                        if skel then
                            local headPos, headOn = Camera:WorldToViewportPoint(pHead.Position)
                            local torsoPos, torsoOn = Camera:WorldToViewportPoint(torso.Position)

                            if headOn and torsoOn and skel.HeadToTorso then
                                skel.HeadToTorso.From = Vector2.new(headPos.X, headPos.Y)
                                skel.HeadToTorso.To = Vector2.new(torsoPos.X, torsoPos.Y)
                                skel.HeadToTorso.Visible = true
                            elseif skel.HeadToTorso then
                                skel.HeadToTorso.Visible = false
                            end

                            if leftArm and torso and skel.TorsoToLeftArm then
                                local lArmPos, lArmOn = Camera:WorldToViewportPoint(leftArm.Position)
                                if torsoOn and lArmOn then
                                    skel.TorsoToLeftArm.From = Vector2.new(torsoPos.X, torsoPos.Y)
                                    skel.TorsoToLeftArm.To = Vector2.new(lArmPos.X, lArmPos.Y)
                                    skel.TorsoToLeftArm.Visible = true
                                else
                                    skel.TorsoToLeftArm.Visible = false
                                end
                            end

                            if rightArm and torso and skel.TorsoToRightArm then
                                local rArmPos, rArmOn = Camera:WorldToViewportPoint(rightArm.Position)
                                if torsoOn and rArmOn then
                                    skel.TorsoToRightArm.From = Vector2.new(torsoPos.X, torsoPos.Y)
                                    skel.TorsoToRightArm.To = Vector2.new(rArmPos.X, rArmPos.Y)
                                    skel.TorsoToRightArm.Visible = true
                                else
                                    skel.TorsoToRightArm.Visible = false
                                end
                            end

                            if leftLeg and torso and skel.TorsoToLeftLeg then
                                local lLegPos, lLegOn = Camera:WorldToViewportPoint(leftLeg.Position)
                                if torsoOn and lLegOn then
                                    skel.TorsoToLeftLeg.From = Vector2.new(torsoPos.X, torsoPos.Y)
                                    skel.TorsoToLeftLeg.To = Vector2.new(lLegPos.X, lLegPos.Y)
                                    skel.TorsoToLeftLeg.Visible = true
                                else
                                    skel.TorsoToLeftLeg.Visible = false
                                end
                            end

                            if rightLeg and torso and skel.TorsoToRightLeg then
                                local rLegPos, rLegOn = Camera:WorldToViewportPoint(rightLeg.Position)
                                if torsoOn and rLegOn then
                                    skel.TorsoToRightLeg.From = Vector2.new(torsoPos.X, torsoPos.Y)
                                    skel.TorsoToRightLeg.To = Vector2.new(rLegPos.X, rLegPos.Y)
                                    skel.TorsoToRightLeg.Visible = true
                                else
                                    skel.TorsoToRightLeg.Visible = false
                                end
                            end
                        end
                    else
                        if ActiveDrawings.Skeletons[player] then
                            for _, line in pairs(ActiveDrawings.Skeletons[player]) do
                                pcall(function() line.Visible = false line:Remove() end)
                            end
                            ActiveDrawings.Skeletons[player] = nil
                        end
                    end
                else
                    if ActiveDrawings.Skeletons[player] then
                        for _, line in pairs(ActiveDrawings.Skeletons[player]) do
                            pcall(function() line.Visible = false line:Remove() end)
                        end
                        ActiveDrawings.Skeletons[player] = nil
                    end
                end
            end
        end
    end)
end)
