-- Pure Shop UI: builds the panel + item rows from ShopCatalog and renders
-- whatever state the caller feeds it via Refresh(). No remotes, no Player
-- lookups -- PlayerShop.local.luau owns those and calls in, same seam as
-- MatchReceipt/MatchReceiptController.
--
-- Panel chrome comes from UIBuilder so this matches DeathScreen/MatchReceipt.
-- The panel gets its own UIScaleController.Attach -- the persistent HUD's
-- convention, reused here because a fixed-pixel shop panel is exactly the
-- "excessively large on mobile" failure this refinement was asked to fix.

local UIBuilder = require(script.Parent.Parent.UI.UIBuilder)
local UITheme = require(script.Parent.Parent.UI.UITheme)
local UIScaleController = require(script.Parent.Parent.UI.UIScaleController)
local ShopCatalog = require(script.Parent.ShopCatalog)

local ShopGui = {}

local PANEL_SIZE = UDim2.fromOffset(460, 430)
local HEADER_HEIGHT = 64
local ROW_HEIGHT = 76
local ROW_PADDING = 6

local screenGui: ScreenGui? = nil
local panel: Frame? = nil
local cashLabel: TextLabel? = nil
local slotsLabel: TextLabel? = nil
local scrollFrame: ScrollingFrame? = nil

-- itemId -> { Row: Frame, Button: TextButton, PriceLabel: TextLabel }
local rows: { [string]: any } = {}

local onBuy: ((itemId: string) -> ())? = nil
local onCloseRequested: (() -> ())? = nil
local pendingIds: { [string]: boolean } = {}

function ShopGui.SetOnBuy(fn: (itemId: string) -> ())
	onBuy = fn
end

-- Fired when the panel's own X button is pressed. The controller (not this
-- module) decides what closing means -- it owns isShopOpen and the
-- Heartbeat/render-step cleanup, so the X must route through it rather than
-- calling ShopGui.Hide() directly, or that cleanup would leak exactly the
-- way the isShopOpen invariant comment in PlayerShop.local.luau warns about.
function ShopGui.SetOnCloseRequested(fn: () -> ())
	onCloseRequested = fn
end

function ShopGui.SetPending(itemId: string, isPending: boolean)
	pendingIds[itemId] = isPending or nil
end

local function buildHeader(parent: Frame)
	local pad = UITheme.Layout.PanelPadding

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -(pad * 2) - 34, 0, 26)
	title.Position = UDim2.fromOffset(pad, 16)
	title.BackgroundTransparency = 1
	title.Font = UITheme.Fonts.Bold
	title.TextColor3 = UITheme.Colors.Text
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 2
	title.Text = "SHOP"
	title.Parent = parent

	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MinTextSize = 16
	textConstraint.MaxTextSize = 22
	textConstraint.Parent = title

	cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "Cash"
	cashLabel.Size = UDim2.new(0.5, -pad, 0, 18)
	cashLabel.Position = UDim2.fromOffset(pad, 42)
	cashLabel.BackgroundTransparency = 1
	cashLabel.Font = UITheme.Fonts.Medium
	cashLabel.TextColor3 = UITheme.Colors.Accent
	cashLabel.TextSize = 14
	cashLabel.TextXAlignment = Enum.TextXAlignment.Left
	cashLabel.ZIndex = 2
	cashLabel.Text = "$0"
	cashLabel.Parent = parent

	slotsLabel = Instance.new("TextLabel")
	slotsLabel.Name = "Slots"
	slotsLabel.Size = UDim2.new(0.5, -pad, 0, 18)
	slotsLabel.Position = UDim2.new(0.5, 0, 0, 42)
	slotsLabel.BackgroundTransparency = 1
	slotsLabel.Font = UITheme.Fonts.Medium
	slotsLabel.TextColor3 = UITheme.Colors.TextMuted
	slotsLabel.TextSize = 14
	slotsLabel.TextXAlignment = Enum.TextXAlignment.Right
	slotsLabel.ZIndex = 2
	slotsLabel.Text = "Slots 0/2"
	slotsLabel.Parent = parent
end

local function buildScrollFrame(parent: Frame)
	local pad = UITheme.Layout.PanelPadding

	scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "Items"
	scrollFrame.Size = UDim2.new(1, -(pad * 2), 1, -HEADER_HEIGHT - pad)
	scrollFrame.Position = UDim2.fromOffset(pad, HEADER_HEIGHT)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 3
	scrollFrame.ScrollBarImageColor3 = UITheme.Colors.Divider
	scrollFrame.CanvasSize = UDim2.new()
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.ZIndex = 2

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, ROW_PADDING)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scrollFrame

	scrollFrame.Parent = parent
end

local function buildRow(item: ShopCatalog.ShopItem): { [string]: any }
	local row = Instance.new("Frame")
	row.Name = item.Id
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.LayoutOrder = item.Order
	row.BackgroundColor3 = UITheme.Colors.PanelRow
	row.BorderSizePixel = 0
	row.ZIndex = 2

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UITheme.Layout.RowCornerRadius
	corner.Parent = row

	local stroke = Instance.new("UIStroke")
	stroke.Name = "SelectedStroke"
	stroke.Color = UITheme.Colors.Accent
	stroke.Thickness = 1
	stroke.Transparency = 1 -- shown only for the "owned" state
	stroke.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, -120, 0, 20)
	nameLabel.Position = UDim2.fromOffset(10, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = UITheme.Fonts.Bold
	nameLabel.TextColor3 = UITheme.Colors.Text
	nameLabel.TextSize = 15
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex = 3
	nameLabel.Text = item.DisplayName
	nameLabel.Parent = row

	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "Price"
	priceLabel.Size = UDim2.fromOffset(60, 20)
	priceLabel.Position = UDim2.new(1, -70, 0, 8)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Font = UITheme.Fonts.Bold
	priceLabel.TextColor3 = UITheme.Colors.Accent
	priceLabel.TextSize = 14
	priceLabel.TextXAlignment = Enum.TextXAlignment.Right
	priceLabel.ZIndex = 3
	priceLabel.Text = "$" .. tostring(item.Price)
	priceLabel.Parent = row

	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "Description"
	descLabel.Size = UDim2.new(1, -100, 0, 34)
	descLabel.Position = UDim2.fromOffset(10, 30)
	descLabel.BackgroundTransparency = 1
	descLabel.Font = UITheme.Fonts.Regular
	descLabel.TextColor3 = UITheme.Colors.TextMuted
	descLabel.TextSize = 12
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.TextWrapped = true
	descLabel.ZIndex = 3
	descLabel.Text = item.Description
	descLabel.Parent = row

	local buyButton = Instance.new("TextButton")
	buyButton.Name = "Buy"
	buyButton.Size = UDim2.fromOffset(80, 30)
	buyButton.Position = UDim2.new(1, -90, 1, -38)
	buyButton.BackgroundColor3 = UITheme.Colors.Accent
	buyButton.BorderSizePixel = 0
	buyButton.AutoButtonColor = false
	buyButton.Font = UITheme.Fonts.Bold
	buyButton.TextColor3 = UITheme.Colors.PanelBackground
	buyButton.TextSize = 14
	buyButton.Text = "BUY"
	buyButton.ZIndex = 3
	buyButton.Parent = row

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UITheme.Layout.RowCornerRadius
	buttonCorner.Parent = buyButton

	buyButton.MouseEnter:Connect(function()
		if buyButton.Active then
			buyButton.BackgroundTransparency = 0.15
		end
	end)
	buyButton.MouseLeave:Connect(function()
		buyButton.BackgroundTransparency = 0
	end)

	buyButton.Activated:Connect(function()
		if buyButton.Active and onBuy then
			onBuy(item.Id)
		end
	end)

	row.Parent = scrollFrame

	return { Row = row, Button = buyButton, PriceLabel = priceLabel, Stroke = stroke }
end

local function ensureBuilt()
	if screenGui then
		return
	end

	-- DisplayOrder 35 -- registered in UIBuilder.CreateScreenGui's comment:
	-- beats MobileSprintGui(30), loses to DeathScreenGui(40)/MatchReceiptGui(50).
	screenGui = UIBuilder.CreateScreenGui("ShopGui", UIBuilder.GetPlayerGui(), 35)
	UIBuilder.CreateBackdrop(screenGui)

	panel = UIBuilder.CreatePanel(screenGui, PANEL_SIZE)
	UIScaleController.Attach(panel)
	UIBuilder.CreateCloseButton(panel, function()
		if onCloseRequested then
			onCloseRequested()
		end
	end)

	buildHeader(panel)
	buildScrollFrame(panel)

	for _, item in ipairs(ShopCatalog.GetOrdered()) do
		rows[item.Id] = buildRow(item)
	end
end

-- Applies live state to already-built rows. Server remains authoritative on
-- every one of these outcomes -- this only decides what the row LOOKS like.
--
-- cash: current Cash balance.
-- ownedIds: set of item ids currently held in a slot.
-- freeSlotCount: how many of the 2 slots are empty right now.
function ShopGui.Refresh(cash: number, ownedIds: { [string]: boolean }, freeSlotCount: number)
	if not screenGui then
		return
	end

	if cashLabel then
		cashLabel.Text = "$" .. tostring(cash)
	end
	if slotsLabel then
		slotsLabel.Text = string.format("Slots %d/2", 2 - freeSlotCount)
	end

	for _, item in ipairs(ShopCatalog.GetOrdered()) do
		local rowData = rows[item.Id]
		if rowData then
			local button = rowData.Button
			local owned = ownedIds[item.Id] == true
			local pending = pendingIds[item.Id] == true
			local affordable = cash >= item.Price

			rowData.Stroke.Transparency = owned and 0.5 or 1

			if pending then
				button.Text = "..."
				button.Active = false
				button.BackgroundColor3 = UITheme.Colors.PanelElevated
				button.TextColor3 = UITheme.Colors.TextMuted
				button.BackgroundTransparency = 0
			elseif owned then
				button.Text = "OWNED"
				button.Active = false
				button.BackgroundColor3 = UITheme.Colors.PanelElevated
				button.TextColor3 = UITheme.Colors.TextMuted
				button.BackgroundTransparency = 0
			-- Instant items grant no Tool, so a full backpack is no obstacle --
			-- see ShopItem.Instant. Without this they'd read FULL alongside
			-- everything else, which the server would have happily sold.
			elseif freeSlotCount <= 0 and not item.Instant then
				button.Text = "FULL"
				button.Active = false
				button.BackgroundColor3 = UITheme.Colors.PanelElevated
				button.TextColor3 = UITheme.Colors.TextMuted
				button.BackgroundTransparency = 0
			elseif not affordable then
				button.Text = "BUY"
				button.Active = false
				button.BackgroundColor3 = UITheme.Colors.PanelRow
				button.TextColor3 = UITheme.Colors.TextMuted
				button.BackgroundTransparency = 0
			else
				button.Text = "BUY"
				button.Active = true
				button.BackgroundColor3 = UITheme.Colors.Accent
				button.TextColor3 = UITheme.Colors.PanelBackground
				button.BackgroundTransparency = 0
			end

			rowData.PriceLabel.TextColor3 = affordable and UITheme.Colors.Accent or UITheme.Colors.Danger
		end
	end
end

function ShopGui.Show()
	ensureBuilt()
	screenGui.Enabled = true
end

function ShopGui.Hide()
	if screenGui then
		screenGui.Enabled = false
	end
end

function ShopGui.IsBuilt(): boolean
	return screenGui ~= nil
end

return ShopGui
