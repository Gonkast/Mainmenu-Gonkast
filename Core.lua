--[[
	Mainmenu - Gonkast
	A cosmetic skin for the retail Game Menu (the Escape / "Game Menu" panel).

	It hides Blizzard's default frame art and the buttons' 3-slice atlas art and
	replaces them with the TGA assets bundled in the Assets\ folder:
		Background border  -> frame background + border
		Header Menu        -> banner on top (title text + player portrait drawn by us)
		button wood large  -> normal menu buttons
		button red2 large  -> Log Out / Exit Game / Return to Game

	Only textures/regions are touched, never secure attributes, so this is
	taint-safe: the protected Logout / Quit buttons keep working.
--]]

local ADDON = ...

-- Base path to the bundled art. Extensions are omitted on purpose so WoW
-- resolves .tga automatically.
local ASSETS = [[Interface\AddOns\Mainmenu-Gonkast\Assets\]]

local TEX = {
	BG      = ASSETS .. "Background border",
	HEADER  = ASSETS .. "Header Menu",
	WHITE   = ASSETS .. "button wood large",
	RED     = ASSETS .. "button red2 large",
	RED_BIG = ASSETS .. "button red2 large",
}

-- ---------------------------------------------------------------------------
-- Tunables (tweak here if you want to re-position things)
-- ---------------------------------------------------------------------------
local CFG = {
	-- How far the background/border extends past the frame edges.
	bgPadLeft   = 40,
	bgPadRight  = 40,
	bgPadTop    = 40,
	bgPadBottom = 40,

	-- Header banner. Width is a multiple of the frame width; height keeps the
	-- asset's native aspect ratio (736 x 374).
	showHeader       = false, -- true = muestra el banner decorativo; false = lo oculta
	headerWidthScale = 1.0,
	headerAspect     = 374 / 736,
	headerYOffset    = 24,  -- how far the banner rises above the frame top

	-- Title text drawn on the banner (or standalone).
	headerTextYOffset = -0,   -- vertical nudge from the banner center (usado si showHeader es true)
	titleX            = 0,     -- ajuste horizontal si NO hay banner
	titleY            = 10,   -- ajuste vertical si NO hay banner

	-- Character portrait shown inside the header orb.
	showPortrait      = false, -- true = crea y muestra el retrato; false = lo desactiva completamente
	portrait3D        = true, -- true = modelo 3D vivo; false = retrato 2D plano
	portraitZoom      = 0.9, -- (solo 3D) zoom del retrato; 0.7 lejos .. 1.2 cerca
	portraitSize      = 47,   -- diameter (px) del modelo. Este es el tamaño del retrato
	portraitX         = 2,    -- ajuste horizontal desde el centro del orb
	portraitY         = -40,  -- desde el borde superior del banner, baja hacia el orb
	portraitBGPadding = 20,   -- el disco de clase = portraitSize + esto. Debe cubrir las
	                          -- esquinas del modelo (mín. ~40% de portraitSize) pero no más

	-- Buttons. El tamaño VISIBLE del botón = altura base + buttonExtraHeight +
	-- texExtraHeight. La caja física (que usa el layout) es ese tamaño visible
	-- + buttonSpacing, así que buttonSpacing es hueco puro entre botones.
	buttonExtraHeight = 10,   -- botones más altos
	buttonFontDelta   = 1,    -- tamaño de fuente del texto
	texExtraWidth     = 80,   -- cuánto más ancha se dibuja la textura vs el botón
	texExtraHeight    = 10,    -- cuánto más alta se dibuja la textura vs el botón
	buttonSpacing     = 1,    -- separación entre botones (no cambia su tamaño)

	-- Text (buttons + title). FFE19B.
	textColor = { 1.0, 0.882, 0.608 },
}

-- ---------------------------------------------------------------------------
-- Saved settings (persisted via the SavedVariables in the .toc)
-- ---------------------------------------------------------------------------
local DEFAULT_BG_ALPHA = 1.0

local function InitDB()
	MainmenuGonkastDB = MainmenuGonkastDB or {}
	if type(MainmenuGonkastDB.bgAlpha) ~= "number" then
		MainmenuGonkastDB.bgAlpha = DEFAULT_BG_ALPHA
	end
end

-- Push the saved opacity onto the background/border texture (if it exists yet).
local function ApplyBGAlpha()
	if GameMenuFrame and GameMenuFrame.__gonkBG and MainmenuGonkastDB then
		GameMenuFrame.__gonkBG:SetAlpha(MainmenuGonkastDB.bgAlpha or DEFAULT_BG_ALPHA)
	end
end

-- A parked, hidden frame. Reparenting Blizzard regions onto it stops them from
-- ever rendering again, even if Blizzard re-shows them on a later OnShow.
local UIHider = CreateFrame("Frame")
UIHider:Hide()

-- Hide Blizzard's default frame chrome. Called on every show (not just once)
-- so the original border can't peek through when our own border is faded out.
local function HideBlizzardChrome()
	local f = GameMenuFrame
	if not f then
		return
	end
	if f.NineSlice then
		f.NineSlice:SetAlpha(0)
		f.NineSlice:Hide()
		if f.NineSlice.SetParent and f.NineSlice:GetParent() ~= UIHider then
			f.NineSlice:SetParent(UIHider)
		end
	end
	for _, key in ipairs({ "Border", "Background", "Bg", "BorderFrame" }) do
		local region = f[key]
		if region and region.SetAlpha then
			region:SetAlpha(0)
			if region.Hide then region:Hide() end
		end
	end
	-- Hide any Blizzard texture drawn straight on the frame, but keep ours
	-- (tagged with __gonk). Runs every show so a re-shown border can't peek out.
	for _, region in ipairs({ f:GetRegions() }) do
		if region.GetObjectType and region:GetObjectType() == "Texture" and not region.__gonk then
			region:SetAlpha(0)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Which buttons get which texture, matched by their (localized) label.
-- Built at load time from the global strings so it works in every locale.
-- ---------------------------------------------------------------------------
local RED_LABELS, RED_BIG_LABELS = {}, {}
do
	if LOG_OUT   then RED_LABELS[LOG_OUT]   = true end
	if EXIT_GAME then RED_LABELS[EXIT_GAME] = true end
	-- MAINMENU_BUTTON = "Return to Game"
	if MAINMENU_BUTTON then RED_BIG_LABELS[MAINMENU_BUTTON] = true end
end

local function TextureForLabel(label)
	if label then
		if RED_BIG_LABELS[label] then return TEX.RED_BIG end
		if RED_LABELS[label]     then return TEX.RED end
	end
	return TEX.WHITE
end

-- ---------------------------------------------------------------------------
-- Button skinning
-- ---------------------------------------------------------------------------
-- The retail Game Menu buttons use ThreeSliceButtonTemplate: their art lives in
-- the .Left / .Center / .Right atlas textures (older ones used .Middle) plus the
-- button's own normal/pushed/disabled textures.
local SLICE_KEYS   = { "Left", "Center", "Middle", "Right" }
-- Includes GetHighlightTexture so the atlas button's native (red) mouseover
-- glow is hidden; our own per-button highlight replaces it.
local STATE_GETTERS = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }

local function HideButtonArt(button)
	for _, key in ipairs(SLICE_KEYS) do
		local region = button[key]
		if region and region.SetAlpha then
			region:SetAlpha(0)
		end
	end
	for _, getter in ipairs(STATE_GETTERS) do
		if button[getter] then
			local tex = button[getter](button)
			if tex then tex:SetAlpha(0) end
		end
	end
end

local function IsGameMenuButton(button)
	if not button or button:GetParent() ~= GameMenuFrame then
		return false
	end
	if button.GetObjectType and button:GetObjectType() ~= "Button" then
		return false
	end
	return (button.GetText and button:GetText() ~= nil) and true or false
end

-- Recolor / outline the label. Uses the stored base font size so repeated
-- passes stay idempotent (never keeps growing the font).
local function StyleButtonText(button)
	local fs = button:GetFontString() or button.Text
	local base = button.__gonkFont
	if not fs or not base then
		return
	end
	fs:SetDrawLayer("OVERLAY")
	if base[1] then
		fs:SetFont(base[1], base[2] + CFG.buttonFontDelta, "OUTLINE")
	end
	fs:SetTextColor(unpack(CFG.textColor))
	fs:SetShadowColor(0, 0, 0, 0)
end

local function SkinButton(button)
	if not IsGameMenuButton(button) then
		return
	end

	-- Guard on the texture itself, not a flag, so a half-initialized button
	-- (e.g. after an error on a previous version) still gets finished.
	if not button.__gonkTex then
		HideButtonArt(button)

		-- Remember the untouched size / font before we change anything.
		button.__gonkBaseH = button:GetHeight()
		local fs = button:GetFontString() or button.Text
		if fs then
			local f, h = fs:GetFont()
			button.__gonkFont = { f or STANDARD_TEXT_FONT, h or 14 }
		end

		-- Our replacement art. ARTWORK sublevel 7 sits above the atlas slices
		-- but below the OVERLAY font string, so the label stays readable even
		-- if the button's controller re-shows its slices on mouseover.
		local tex = button:CreateTexture(nil, "ARTWORK", nil, 7)
		tex:SetPoint("CENTER", button, "CENTER", 0, 0)
		button.__gonkTex = tex

		local hl = button:CreateTexture(nil, "HIGHLIGHT")
		hl:SetPoint("CENTER", button, "CENTER", 0, 0)
		hl:SetBlendMode("ADD")
		hl:SetVertexColor(1, 1, 1, 0.18)
		button.__gonkHL = hl
	end

	if not button.__gonkBaseH then
		return
	end

	-- The button pool can reuse a button for a different entry, so refresh
	-- everything every pass (all idempotent). Highlight uses the same art as
	-- the button so red buttons glow red, etc.
	local art = TextureForLabel(button:GetText())
	button.__gonkTex:SetTexture(art)
	if button.__gonkHL then
		button.__gonkHL:SetTexture(art)
	end

	-- Visible size of the art. This is the size the player sees and clicks.
	local visW = button:GetWidth() + (CFG.texExtraWidth or 0)
	local visH = button.__gonkBaseH + (CFG.buttonExtraHeight or 0) + (CFG.texExtraHeight or 0)

	button.__gonkTex:SetSize(visW, visH)
	if button.__gonkHL then
		button.__gonkHL:SetSize(visW, visH)
	end

	-- Physical box = visible art + the gap we want between buttons. The layout
	-- stacks these boxes, so the extra height becomes clean spacing without
	-- changing how big the buttons look.
	local gap = CFG.buttonSpacing or 0
	button:SetHeight(visH + gap)

	-- Clickable area = the visible art: wider than the box (expand sideways),
	-- and centered so the gap above/below is not clickable (shrink vertically).
	button:SetHitRectInsets(
		-(CFG.texExtraWidth or 0) / 2,
		-(CFG.texExtraWidth or 0) / 2,
		gap / 2,
		gap / 2
	)

	StyleButtonText(button)
	HideButtonArt(button)
end

-- ---------------------------------------------------------------------------
-- Frame skinning
-- ---------------------------------------------------------------------------
local function GetMenuTitle()
	local header = GameMenuFrame.Header or _G.GameMenuFrameHeader
	if header then
		if header.Text and header.Text.GetText then
			local t = header.Text:GetText()
			if t and t ~= "" then return t end
		end
		for _, region in ipairs({ header:GetRegions() }) do
			if region.GetObjectType and region:GetObjectType() == "FontString" then
				local t = region:GetText()
				if t and t ~= "" then return t end
			end
		end
	end
	return "Game Menu"
end

local function BuildFrameArt()
	if GameMenuFrame.__gonkFrameSkinned then
		return
	end
	GameMenuFrame.__gonkFrameSkinned = true

	-- Grab the localized title BEFORE we hide the header.
	local titleText = GetMenuTitle()

	-- Hide the default frame chrome (also re-applied every show in SkinFrame).
	HideBlizzardChrome()

	-- Hide the default header/title (our banner + our own title replace it).
	local header = GameMenuFrame.Header or _G.GameMenuFrameHeader
	if header then
		header:SetAlpha(0)
		header:Hide()
	end

	-- Strip any stray textures parented straight to the frame.
	for _, region in ipairs({ GameMenuFrame:GetRegions() }) do
		if region.GetObjectType and region:GetObjectType() == "Texture" then
			region:SetAlpha(0)
		end
	end

	-- Background + border (a texture on the frame sits behind the buttons,
	-- which are child frames).
	local bg = GameMenuFrame:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(TEX.BG)
	bg:SetPoint("TOPLEFT",     GameMenuFrame, "TOPLEFT",     -CFG.bgPadLeft,   CFG.bgPadTop)
	bg:SetPoint("BOTTOMRIGHT", GameMenuFrame, "BOTTOMRIGHT",  CFG.bgPadRight, -CFG.bgPadBottom)
	GameMenuFrame.__gonkBG = bg

	-- Header art (banner + title) lives on its own child frame with a high frame
	-- level. This lets it render ABOVE the portrait -- essential for the 3D
	-- model, which is a child frame and would otherwise cover the orb rim.
	local headerFrame = CreateFrame("Frame", nil, GameMenuFrame)
	headerFrame:SetAllPoints(GameMenuFrame)
	headerFrame:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 10)
	GameMenuFrame.__gonkHeaderFrame = headerFrame

	-- Header banner, straddling the top edge. Only created if enabled in CFG.
	local banner
	if CFG.showHeader then
		banner = headerFrame:CreateTexture(nil, "OVERLAY")
		banner:SetTexture(TEX.HEADER)
		banner:SetPoint("BOTTOM", GameMenuFrame, "TOP", 0, -CFG.headerYOffset)
		GameMenuFrame.__gonkHeader = banner
	end

	-- Title text.
	local title = headerFrame:CreateFontString(nil, "OVERLAY")
	title:SetFontObject("GameFontNormalHuge")
	local tf, th = title:GetFont()
	if tf then
		title:SetFont(tf, th, "OUTLINE")
	end
	title:SetText(titleText)
	title:SetTextColor(unpack(CFG.textColor))
	title:SetShadowColor(0, 0, 0, 0)
	
	-- Posicionamiento del texto según si existe el banner o no.
	if CFG.showHeader and banner then
		title:SetPoint("CENTER", banner, "CENTER", 0, CFG.headerTextYOffset)
	else
		title:SetPoint("TOP", GameMenuFrame, "TOP", CFG.titleX, CFG.titleY)
	end
	GameMenuFrame.__gonkTitle = title

	-- Solo crear los objetos del retrato si están activados en CFG.
	if CFG.showPortrait then
		-- Class-colored circle behind the portrait, filling the orb hole. Solid
		-- white tinted to the class color, clipped to a circle.
		local portraitBG = GameMenuFrame:CreateTexture(nil, "ARTWORK", nil, 0)
		portraitBG:SetColorTexture(1, 1, 1, 1)
		portraitBG:SetSize(CFG.portraitSize + CFG.portraitBGPadding, CFG.portraitSize + CFG.portraitBGPadding)
		-- Ajuste de posición: referenciado a banner si existe, sino al GameMenuFrame
		if banner then
			portraitBG:SetPoint("CENTER", banner, "TOP", CFG.portraitX, CFG.portraitY)
		else
			portraitBG:SetPoint("CENTER", GameMenuFrame, "TOP", CFG.portraitX, CFG.portraitY)
		end

		local bgMask = GameMenuFrame:CreateMaskTexture()
		bgMask:SetAllPoints(portraitBG)
		bgMask:SetTexture([[Interface\Masks\CircleMaskScalable]], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		portraitBG:AddMaskTexture(bgMask)
		GameMenuFrame.__gonkPortraitBG = portraitBG

		-- The portrait itself sits BELOW the header frame, so the orb rim frames it.
		if CFG.portrait3D then
			-- Live 3D model. It's a child frame (renders above the class circle) and
			-- its rectangle corners are hidden by the orb art on the header frame.
			local model = CreateFrame("PlayerModel", nil, GameMenuFrame)
			model:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 5)
			model:SetSize(CFG.portraitSize, CFG.portraitSize)
			if banner then
				model:SetPoint("CENTER", banner, "TOP", CFG.portraitX, CFG.portraitY)
			else
				model:SetPoint("CENTER", GameMenuFrame, "TOP", CFG.portraitX, CFG.portraitY)
			end
			GameMenuFrame.__gonkPortraitModel = model
		else
			-- Flat 2D portrait, clipped to a circle.
			local portrait = GameMenuFrame:CreateTexture(nil, "ARTWORK", nil, 1)
			portrait:SetSize(CFG.portraitSize, CFG.portraitSize)
			if banner then
				portrait:SetPoint("CENTER", banner, "TOP", CFG.portraitX, CFG.portraitY)
			else
				portrait:SetPoint("CENTER", GameMenuFrame, "TOP", CFG.portraitX, CFG.portraitY)
			end

			local mask = GameMenuFrame:CreateMaskTexture()
			mask:SetAllPoints(portrait)
			mask:SetTexture([[Interface\Masks\CircleMaskScalable]], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			portrait:AddMaskTexture(mask)

			GameMenuFrame.__gonkPortrait = portrait
			GameMenuFrame.__gonkPortraitMask = mask
		end
	end
end

-- Refresh the portrait (2D texture or 3D model) and the class-colored circle
-- behind it.
local function UpdatePortrait()
	if not GameMenuFrame or not CFG.showPortrait then
		return
	end

	-- Tint the circle behind the portrait with the class color.
	local bg = GameMenuFrame.__gonkPortraitBG
	if bg then
		local _, class = UnitClass("player")
		local c = class and C_ClassColor and C_ClassColor.GetClassColor(class)
		if not c and class and RAID_CLASS_COLORS then
			c = RAID_CLASS_COLORS[class]
		end
		if c then
			bg:SetVertexColor(c.r, c.g, c.b)
		end
	end

	-- 3D model portrait.
	local model = GameMenuFrame.__gonkPortraitModel
	if model then
		model:SetUnit("player")
		model:SetPortraitZoom(CFG.portraitZoom or 1)
		return
	end

	-- 2D texture portrait.
	if GameMenuFrame.__gonkPortrait then
		SetPortraitTexture(GameMenuFrame.__gonkPortrait, "player")
	end
end

local function SkinFrame()
	if not GameMenuFrame or GameMenuFrame:IsForbidden() then
		return
	end

	BuildFrameArt()
	HideBlizzardChrome()
	ApplyBGAlpha()
	UpdatePortrait()

	-- Size the banner relative to the (now-laid-out) frame width.
	local banner = GameMenuFrame.__gonkHeader
	if banner then
		local w = (GameMenuFrame:GetWidth() or 200) * CFG.headerWidthScale
		banner:SetSize(w, w * CFG.headerAspect)
	end

	-- Skin every currently visible button.
	for _, child in ipairs({ GameMenuFrame:GetChildren() }) do
		if child.IsShown and child:IsShown() then
			SkinButton(child)
		end
	end

	-- We changed button heights after Blizzard's own layout ran, so re-run the
	-- layout to re-space everything without overlap.
	if GameMenuFrame.Layout then
		GameMenuFrame:Layout()
	end
end

-- ---------------------------------------------------------------------------
-- Options panel (Escape -> Options -> AddOns -> "Mainmenu - Gonkast")
-- ---------------------------------------------------------------------------
local optionsCategory

local function BuildOptions()
	if optionsCategory then
		return
	end
	if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then
		return
	end

	local category = Settings.RegisterVerticalLayoutCategory("Mainmenu - Gonkast")
	optionsCategory = category

	local variable = "MainmenuGonkast_BGAlpha"
	local setting = Settings.RegisterAddOnSetting(
		category,
		variable,
		"bgAlpha",
		MainmenuGonkastDB,
		Settings.VarType.Number,
		"Opacidad del fondo",
		DEFAULT_BG_ALPHA
	)

	-- 0% .. 100% in 5% steps, shown as a percentage.
	local options = Settings.CreateSliderOptions(0, 1, 0.05)
	options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
		return string.format("%d%%", math.floor(value * 100 + 0.5))
	end)

	Settings.CreateSlider(category, setting, options, "Ajusta la opacidad del fondo y borde del menu.")

	-- Apply changes live (harmless while the menu is hidden; kicks in on reopen).
	Settings.SetOnValueChangedCallback(variable, function(_, _, value)
		MainmenuGonkastDB.bgAlpha = value
		ApplyBGAlpha()
	end)

	Settings.RegisterAddOnCategory(category)
end

-- ---------------------------------------------------------------------------
-- Hook-up
-- ---------------------------------------------------------------------------
local function TryHook()
	if not GameMenuFrame then
		return false
	end
	if GameMenuFrame.__gonkHooked then
		return true
	end
	GameMenuFrame.__gonkHooked = true

	GameMenuFrame:HookScript("OnShow", SkinFrame)

	-- Blizzard rebuilds the visible-button list here; re-skin afterwards.
	if type(GameMenuFrame_UpdateVisibleButtons) == "function" then
		hooksecurefunc("GameMenuFrame_UpdateVisibleButtons", SkinFrame)
	end

	if GameMenuFrame:IsShown() then
		SkinFrame()
	end
	return true
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" then
		if name == ADDON then
			InitDB()
		elseif name == "Blizzard_GameMenu" then
			TryHook()
		end
		return
	end

	-- PLAYER_LOGIN
	InitDB()
	TryHook()
	BuildOptions()
	self:UnregisterEvent("ADDON_LOADED")
end)

-- /gonkmenu opens the options panel directly.
SLASH_MAINMENUGONKAST1 = "/gonkmenu"
SlashCmdList["MAINMENUGONKAST"] = function()
	if optionsCategory and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(optionsCategory:GetID())
	end
end