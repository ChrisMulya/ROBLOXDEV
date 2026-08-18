-- Instant, dependency-free match loading curtain. Runs from ReplicatedFirst,
-- Roblox's earliest possible LocalScript execution point -- specifically so
-- the curtain is up before ReplicatedStorage.Modules has even replicated.
-- Cannot require anything under ReplicatedStorage.Modules for that reason --
-- LoadingHud/LoadingController (required later, from ClientBootstrap) adopt
-- this exact ScreenGui by name once Modules exists, rather than building a
-- second one. See LoadingHud's own header for the adoption mechanics; the
-- instance names below ("Backdrop", "StatusLabel") are load-bearing -- they
-- must match what LoadingHud.ensureGui() looks for.
--
-- Both places ship this script so ReplicatedFirst stays non-empty
-- identically on both trees; the Lobby's LoadingController hands its
-- adopted curtain straight to LoadingHud.HideInstant() the moment it can.

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoadingCurtainGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 2000
-- Exempts the curtain from CameraSession.hideOtherGuis before it could ever
-- be disabled by it -- see ScreenFlashRenderer's documented bug for what
-- happens without this on a lazily-adopted GUI.
screenGui:SetAttribute("KeepDuringCamera", true)
screenGui.Parent = playerGui

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0
backdrop.BorderSizePixel = 0
backdrop.ZIndex = 0
backdrop.Parent = screenGui

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.AnchorPoint = Vector2.new(0.5, 0.5)
statusLabel.Position = UDim2.new(0.5, 0, 0.5, -24)
statusLabel.Size = UDim2.fromOffset(480, 32)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 22
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.Text = "Loading..."
statusLabel.ZIndex = 2
statusLabel.Parent = backdrop

screenGui.Enabled = true
