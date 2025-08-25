-- VIBE CODED SLOP

-- Clientside "Bank Top" UI
-- Architecture mirrors cl_tauntmenu: command-owned window, single-instance holder, DesktopWindows just triggers the command.

local panelName = "HIGHEST BANK BALANCES"
local bankTop = {}

-- Central config: derive layout from item size (1080p baseline)
local CFG = {
	itemSize1080p = 120,         -- square tile size baseline (W/H)
	tilesPerRowEstimate = 7,      -- used to compute default frame width
	tileGapRatio = 0.2,           -- gap between tiles as fraction of item width
	headerPadRatio = 0.2,         -- header vertical padding as fraction of item height
	innerPadRatio = 0.08,         -- image padding inside a tile as fraction of item width
	outerMarginRatio = 0.5,       -- outer screen margin as fraction of item width
	awardSizeRatio = 22 / 120,    -- star icon size relative to item width
	hoverScale = 1.18,            -- target scale on hover
	wheelImpulseItems = 10,       -- wheel impulse in units of item widths
	-- Slide sound response
	slideFullSpeedItems = 30,     -- speed where volume hits 1.0 (in item widths/sec)
	slideVolumeScale = 0.5,       -- multiply final volume
	slidePitchBase = 85,          -- base pitch
	slidePitchSpan = 25,          -- pitch increases by this across full volume
}

-- Sliding sound (loop) while dragging/gliding
local SLIDE_SOUND_PATH = "physics/concrete/concrete_scrape_smooth_loop1.wav"

local function computeFrameSize1080p()
	local item = CFG.itemSize1080p
	local tiles = math.max( 1, math.floor( CFG.tilesPerRowEstimate ) )
	local gap = math.floor( item * CFG.tileGapRatio )
	local outer = math.floor( item * CFG.outerMarginRatio )
	local headerPad = math.floor( item * CFG.headerPadRatio )
	-- Height: header pads + one row of tiles + a small bottom pad (same as headerPad)
	local width1080 = tiles * item + math.max( tiles - 1, 0 ) * gap + 2 * outer
	local height1080 = item + headerPad * 7
	return width1080, height1080
end

-- 1080p baseline sizes (auto-scaled via glee_sizeScaled + shop scale)
-- (legacy constants removed; sizes now derive from CFG)

-- Use noclamp to avoid edge clipping/bleed on some GPUs
local skullMat = Material( "vgui/hud/deadshopicon.png", "smooth noclamp" )
local awardGold   = Material( "icon16/award_star_gold_1.png",   "smooth" )
local awardSilver = Material( "icon16/award_star_silver_1.png", "smooth" )
local awardBronze = Material( "icon16/award_star_bronze_3.png", "smooth" )

local function canOpenBankTop()
	-- Check if player has a bank account
	local ply = LocalPlayer()
	if not ply:BankHasAccount() then
		return false, "You need to open a bank account."
	end

	local roundActive = GAMEMODE.RoundState and GAMEMODE:RoundState() == GAMEMODE.ROUND_ACTIVE
	local alive = LocalPlayer():Alive()
	-- Only while round is starting (i.e., not active) or the user is dead
	if roundActive and alive then
		return false, "Wait. You need to be dead to view the leaderboard."

	end
	return true
end

-- Format funds nicely with thousands separators
local function formatFunds( n )
	n = tonumber( n ) or 0
	local s = tostring( math.floor( n + 0.5 ) )
	local k
	repeat
		s, k = s:gsub( "^(-?%d+)(%d%d%d)", "%1,%2" )
	until k == 0
	return s
end

function bankTop:Create( container )
	local scale = GAMEMODE.shopStandards.shpScale
	local switchSound = GAMEMODE.shopStandards.switchSound

	-- Derive all sizes from the item size
	local itemW   = glee_sizeScaled( CFG.itemSize1080p * scale )
	local itemH   = glee_sizeScaled( nil, CFG.itemSize1080p * scale )
	local itemGap = math.floor( itemW * CFG.tileGapRatio )
	local headerPad = math.floor( itemH * CFG.headerPadRatio )
	local innerPad = math.floor( itemW * CFG.innerPadRatio )
	local awardSizePx = math.floor( itemW * CFG.awardSizeRatio )
	local hudPadding = terminator_Extras.defaultHudPaddingFromEdge or 0
	local outerMargin = math.max( hudPadding, math.floor( itemW * CFG.outerMarginRatio ) )

	container:DockPadding( 0, 0, 0, 0 )
	container:DockMargin( outerMargin, outerMargin, outerMargin, outerMargin )
	container:SetTitle( "" )
	container:ShowCloseButton( false )
	container:SetDraggable( false )
	function container:Paint() end

	local listPanel = vgui.Create( "DPanel", container )
	listPanel:Dock( FILL )
	listPanel:DockMargin( 0, headerPad, 0, headerPad )
	listPanel:SetMouseInputEnabled( true )

	-- State
	listPanel.entries = {}
	listPanel.scrollX = 0
	listPanel.velX = 0
	listPanel.isDragging = false
	listPanel.dragLastX = 0
	listPanel.dragLastT = 0
	listPanel.hoverIndex = nil
	listPanel.contentW = 0
	listPanel.scales = {}
	listPanel.initialPositioned = false
	listPanel.lastHoverIndex = nil
	listPanel.playerIndex = nil

	-- Sliding sound state
	listPanel.slideSound = nil -- CSoundPatch
	listPanel.slideVol = 0
	listPanel.slidePlaying = false
	listPanel._lastScrollX = 0

	function listPanel:OnRemove()
		if self.slideSound then
			self.slideSound:Stop()
			self.slideSound = nil
			self.slidePlaying = false
		end
	end

	local HOVER_SCALE_TARGET = CFG.hoverScale
	local HOVER_LERP_SPEED = 10 -- higher = snappier

	function listPanel:GetScrollBounds( viewW )
		-- viewW is the current visible width of the list panel
		local contentW = self.contentW or 0 -- total width of all skull tiles
		if contentW <= viewW or contentW <= 0 then
			-- Centered; no scrolling
			return 0, 0
		end
		local centerX = viewW * 0.5
		local halfContentW = contentW * 0.5
		-- baseX = centerX - halfContentW + scrollX must be in [viewW - contentW, 0]
		local minScroll = ( viewW - contentW ) - ( centerX - halfContentW )
		local maxScroll = 0 - ( centerX - halfContentW )
		return minScroll, maxScroll
	end

	-- Request accounts, then sort by funds desc (top rich first)
	local function applyAccounts( accounts )
		local arr = {}
		for steamID, data in pairs( accounts or {} ) do
			arr[#arr + 1] = {
				steamID = steamID,
				ownersName = data.ownersName or "Unknown",
				funds = tonumber( data.funds ) or 0,
			}
		end
		table.sort( arr, function( a, b ) return a.funds > b.funds end )
		listPanel.entries = arr

		-- Find local player's index by SteamID64 or SteamID
		local me = LocalPlayer()
		local my32 = IsValid( me ) and me:SteamID() or nil
		listPanel.playerIndex = nil
		for i = 1, #arr do
			local id = tostring( arr[i].steamID )
			if my32 and id == tostring( my32 ) then
				listPanel.playerIndex = i
				break
			end
		end
		-- compute content width
		local count = #arr
		listPanel.contentW = count > 0 and (count * itemW + math.max( count - 1, 0 ) * itemGap) or 0
		-- position will be set on next Think once panel has width
		listPanel.initialPositioned = false
		listPanel.velX = 0
	end

	local function requestNow()
		local ok = GAMEMODE:RequestAllBankAccounts( function( accounts )
			if not IsValid( listPanel ) then return end
			applyAccounts( accounts )
		end )
		if not ok then
			-- Try again shortly (respecting the 1s throttle in the API)
			timer.Simple( 1.05, function()
				if not IsValid( listPanel ) then return end
				requestNow()
			end )
		end
	end
	requestNow()

	-- Dragging + inertia
	function listPanel:OnMousePressed( mc )
		if mc ~= MOUSE_LEFT then return end
		self:MouseCapture( true )
		self.isDragging = true
		self.velX = 0
		self.dragLastX = gui.MouseX() -- last mouse X position during drag
		self.dragLastT = SysTime()    -- last timestamp during drag
		if IsValid( LocalPlayer() ) and switchSound then
			LocalPlayer():EmitSound( switchSound, 60, 60, 0.18 )
		end
	end
	function listPanel:OnMouseReleased( mc )
		if mc ~= MOUSE_LEFT then return end
		self:MouseCapture( false )
		self.isDragging = false
		if IsValid( LocalPlayer() ) and switchSound then
			LocalPlayer():EmitSound( switchSound, 60, 80, 0.14 )
		end
	end
	function listPanel:OnCursorMoved()
		if not self.isDragging then return end

		local nowTime = SysTime()
		local cursorX = gui.MouseX()
		local deltaX = cursorX - self.dragLastX

		self.scrollX = self.scrollX + deltaX
		local deltaTime = math.max( nowTime - self.dragLastT, 0.0001 )

		self.velX = deltaX / deltaTime
		self.dragLastX = cursorX
		self.dragLastT = nowTime

	end

	-- Mouse wheel propels the horizontal scroller with inertia
	function listPanel:OnMouseWheeled( delta )
		-- Ignore while dragging
		if self.isDragging then return true end

		-- Positive delta (wheel up) moves content right (towards earlier entries),
		-- negative delta (wheel down) moves content left (towards later entries).
		local impulse = itemW * CFG.wheelImpulseItems -- tuned for a snappy flick per notch
		self.velX = ( self.velX or 0 ) + delta * impulse
		return true

	end

	-- Scroll physics
	local scrollFriction = 8   -- larger = faster slowdown
	local overscrollSpringK = 28 -- pull-back strength when overscrolled
	local overshootPx = 50       -- soft cap overscroll distance in px

	function listPanel:Think()
		-- Round/death gate: auto-close if no longer allowed
		local ok = canOpenBankTop()
		if not ok and IsValid( GAMEMODE.glee_BankTop_Holder ) then
			GAMEMODE.glee_BankTop_Holder:Remove()
			return

		end

		-- slide sound updater driven by measured speed (px/sec)
		local function updateSlideSound( speed )
			local fullSpeed = itemW * CFG.slideFullSpeedItems
			local volNorm = math.Clamp( speed / fullSpeed, 0, 1 )
			self.slideVol = volNorm
			if volNorm > 0 then
				if not self.slideSound and IsValid( LocalPlayer() ) then
					self.slideSound = CreateSound( LocalPlayer(), SLIDE_SOUND_PATH )
				end
				if self.slideSound then
					local pitch = math.floor( CFG.slidePitchBase + CFG.slidePitchSpan * volNorm )
					if not self.slidePlaying then
						self.slideSound:PlayEx( volNorm * CFG.slideVolumeScale, pitch )
						self.slidePlaying = true
					else
						self.slideSound:ChangeVolume( volNorm * CFG.slideVolumeScale, 0 )
						self.slideSound:ChangePitch( pitch, 0 )
					end
				end
			elseif self.slidePlaying and self.slideSound then
				self.slideSound:ChangeVolume( 0, 0 )
				self.slideSound:Stop()
				self.slidePlaying = false
			end
		end

		local deltaTime = FrameTime()
		local prevX = self._lastScrollX or self.scrollX

		-- While dragging, measure actual movement and update sound, then return
		if self.isDragging then
			local moved = math.abs( ( self.scrollX or 0 ) - ( prevX or 0 ) )
			local speed = moved / math.max( deltaTime, 0.0001 )
			updateSlideSound( speed )
			self._lastScrollX = self.scrollX
			return

		end

		if math.abs( self.velX ) > 0 then
			-- integrate velocity
			self.scrollX = self.scrollX + self.velX * deltaTime
			-- apply friction
			local velocitySign = self.velX > 0 and 1 or -1
			local decelAmount = scrollFriction * 1000 * deltaTime
			local newVel = self.velX - velocitySign * decelAmount
			if velocitySign ~= ( newVel > 0 and 1 or -1 ) then newVel = 0 end
			self.velX = newVel

		else
			self.velX = 0

		end

		-- Slingshot back if overscrolled
		local panelWidth = self:GetWide()
		local minScroll, maxScroll = self:GetScrollBounds( panelWidth )

		-- On first layout after data, snap to left bound to show richest first
		if not self.initialPositioned and panelWidth > 0 and #self.entries > 0 then
			self.scrollX = maxScroll
			self.velX = 0
			self.initialPositioned = true
		end
		if self.scrollX < minScroll or self.scrollX > maxScroll then
			-- Acceleration towards the nearest bound
			local clampedTarget = math.Clamp( self.scrollX, minScroll, maxScroll )
			local distToTarget = clampedTarget - self.scrollX
			-- Soft-limit overshoot to avoid flying off forever
			if self.scrollX < minScroll then
				self.scrollX = math.max( self.scrollX, minScroll - overshootPx )
			elseif self.scrollX > maxScroll then
				self.scrollX = math.min( self.scrollX, maxScroll + overshootPx )
			end
			-- Spring towards target
			self.velX = ( self.velX or 0 ) + distToTarget * overscrollSpringK * deltaTime
			-- Extra damping when outside
			self.velX = self.velX * ( 1 - math.min( 0.9, 3 * deltaTime ) )

		end

		-- Measure actual movement and update slide sound precisely from position change
		local moved = math.abs( ( self.scrollX or 0 ) - ( prevX or 0 ) )
		local speed = moved / math.max( deltaTime, 0.0001 )
		updateSlideSound( speed )
		self._lastScrollX = self.scrollX
	end

	function listPanel:Paint( w, h )
		-- w,h are the size of this panel, provided by VGUI
		-- Background (square corners to match repo style)
		surface.SetDrawColor( GAMEMODE.shopStandards.backgroundColor )
		surface.DrawRect( 0, 0, w, h )

		local entries = self.entries
		local count = #entries

		-- Header: left title, right hover info (prevents clipping and reduces negative space)
		local padding = headerPad
		surface.SetFont( "termhuntShopItemFontShadowed" )
		local _, titleH = surface.GetTextSize( panelName )
		-- Measure detail line height to reserve consistent space even when nothing hovered
		surface.SetFont( "termhuntShopItemFont" )
		local _, detailH = surface.GetTextSize( "Loses 000,000 every 2 days" )
		local detailGap = math.floor( padding * 0.25 )
		-- Draw title on the left
		surface.SetFont( "termhuntShopItemFontShadowed" )
		draw.SimpleText( panelName, "termhuntShopItemFontShadowed", padding, padding, GAMEMODE.shopStandards.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )

		-- Precompute mouse position
		self.hoverIndex = nil
		local mouseX, mouseY = self:CursorPos()

		if count == 0 then
			draw.SimpleText( "Fetching accounts...", "termhuntShopItemFont", w * 0.5, padding + titleH + padding, GAMEMODE.shopStandards.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
			return

		end

		-- Layout skull row below header + detail line reservation
		local rowY = padding + titleH + detailGap + detailH + padding
		local centerX = w * 0.5
		local contentW = self.contentW
		local halfContentW = contentW * 0.5
		-- Center the content around centerX; scrollX shifts it
		local baseX = centerX - halfContentW + self.scrollX

		for i = 1, count do
			local x = baseX + ( i - 1 ) * ( itemW + itemGap )
			local rect = { x = x, y = rowY, w = itemW, h = itemH }

			-- Hover check first so scale uses current frame's hover state
			local isHover = mouseX >= rect.x and mouseX <= rect.x + rect.w and mouseY >= rect.y and mouseY <= rect.y + rect.h
			if isHover then self.hoverIndex = i end

			-- icon: aspect-fit inside tile, avoid cutoff; hovered entries scale up smoothly
			surface.SetDrawColor( 255, 255, 255, 255 )
			surface.SetMaterial( skullMat ) -- rebind each iteration to avoid previous icon materials

			local texW = skullMat.Width and skullMat:Width() or 0
			local texH = skullMat.Height and skullMat:Height() or 0
			if ( texW or 0 ) <= 0 or ( texH or 0 ) <= 0 then
				texW, texH = rect.w, rect.h

			end

			local innerW, innerH = rect.w - innerPad * 2, rect.h - innerPad * 2
			local baseScale = math.min( innerW / texW, innerH / texH )

			-- smooth scale per entry
			local currentScale = self.scales[i] or 1
			local targetScale = isHover and HOVER_SCALE_TARGET or 1
			currentScale = Lerp( math.min( FrameTime() * HOVER_LERP_SPEED, 1 ), currentScale, targetScale )
			self.scales[i] = currentScale

			-- clamp to not exceed tile bounds
			local maxScale = math.min( rect.w / ( texW * baseScale ), rect.h / ( texH * baseScale ) )
			local finalScale = baseScale * math.min( currentScale, maxScale )
			local iconW, iconH = texW * finalScale, texH * finalScale
			local iconX = rect.x + ( rect.w - iconW ) * 0.5
			local iconY = rect.y + ( rect.h - iconH ) * 0.5
			surface.DrawTexturedRect( iconX, iconY, iconW, iconH )

			-- rank number overlay
			draw.SimpleText( "#" .. tostring( i ), "termhuntShopItemFontShadowed", rect.x + rect.w - 12, rect.y + rect.h - 10, GAMEMODE.shopStandards.white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM )

			-- Award icons for top 3
			if i <= 3 then
				local iconMat = ( i == 1 and awardGold ) or ( i == 2 and awardSilver ) or awardBronze
				surface.SetMaterial( iconMat )
				surface.SetDrawColor( 255, 255, 255, 255 )
				local baseSize = awardSizePx
				local size = ( i == 1 ) and math.floor( baseSize * 1.25 ) or baseSize
				local starCenterX = rect.x + size * 0.6
				local starCenterY = rect.y + rect.h - size * 0.6
				local starRotation = -18
				surface.DrawTexturedRectRotated( starCenterX, starCenterY, size, size, starRotation )
			end

			-- Simple splash text over your own skull inside the scroller
			if self.playerIndex and i == self.playerIndex then
				local splash = "You!"
				local bounce = math.sin( CurTime() * 5 ) * 2
				draw.SimpleTextOutlined( splash, "termhuntShopItemFontShadowed", rect.x + rect.w * 0.75, rect.y * 1.5 + bounce - glee_sizeScaled( nil, 6 * scale ) + bounce, GAMEMODE.shopStandards.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0,0,0,220) )
			end
		end

		-- Hover info in header (right-aligned) + hover enter/leave tick
		local idx = self.hoverIndex
		if idx ~= self.lastHoverIndex and IsValid( LocalPlayer() ) and switchSound then
			-- Different pitch for enter vs leave
			local pitch = idx and 90 or 80
			LocalPlayer():EmitSound( switchSound, 60, pitch, 0.12 )
			self.lastHoverIndex = idx

		end
		-- Always draw the top hover line if available; second line shows 2-day loss
		if idx then
			local data = entries[idx]
			local tipText = string.format( "%s - %s SCORE", data.ownersName or "Unknown", formatFunds( data.funds ) )
			-- First line (same as before), right-aligned in header top area
			draw.SimpleText( tipText, "termhuntShopItemFontShadowed", w - padding, padding + ( titleH - select(2, surface.GetTextSize( tipText )) ) * 0.5, GAMEMODE.shopStandards.white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP )

			-- Second line: projected loss every 2 days
			local percent = ( gleefunc_BankChargePerPeriod and gleefunc_BankChargePerPeriod() ) or 10
			local loss = math.floor( ( tonumber( data.funds ) or 0 ) * ( tonumber( percent ) or 0 ) / 100 + 0.5 )
			local lossText = string.format( "Losing %s score every 2 days!", formatFunds( loss ) )
			draw.SimpleText( lossText, "termhuntShopItemSmallerFont", w - padding, padding + titleH + detailGap, GAMEMODE.shopStandards.white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP )
		end
	end
end

-- Command-owned window creation (mirrors taunt menu pattern)
local function createBankTopSafely()
	local allowed, reason = canOpenBankTop()
	if not allowed then return nil, reason end

	local frame = vgui.Create( "DFrame" )
	terminator_Extras.easyClosePanel( frame )
	local w1080, h1080 = computeFrameSize1080p()
	local w, h = glee_sizeScaled( w1080 * GAMEMODE.shopStandards.shpScale, h1080 * GAMEMODE.shopStandards.shpScale )
	frame:SetSize( w, h )
	frame:Center()
	frame:MakePopup()
	frame:SetSizable( true )
	bankTop:Create( frame )
	LocalPlayer():EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 200, 0.45 )
	return frame

end

concommand.Add( "glee_banktop_open", function()
	local newFrame, err = createBankTopSafely()
	if not IsValid( newFrame ) then
		if err then print( "[Hunters Glee] Failed to open bank top:", err ) end
		return
	end

	if IsValid( GAMEMODE.glee_BankTop_Holder ) then
		GAMEMODE.glee_BankTop_Holder:Remove()
	end

	GAMEMODE.glee_BankTop_Holder = newFrame
	function newFrame:OnRemove()
		if GAMEMODE.glee_BankTop_Holder == self then
			GAMEMODE.glee_BankTop_Holder = nil
		end
	end
end )

-- Desktop Windows launcher mirrors taunt menu
local dskW1080, dskH1080 = computeFrameSize1080p()
local width, height = glee_sizeScaled( dskW1080, dskH1080 )
list.Set( "DesktopWindows", "HuntersGlee_BankTop", {
	title = "Bank Leaderboard",
	icon = "icon16/coins.png",
	width = width,
	height = height,
	onewindow = true,
	init = function( _, window )
		if IsValid( window ) then window:Remove() end
		local ok, reason = canOpenBankTop()
		if not ok then
			LocalPlayer():PrintMessage( HUD_PRINTTALK, reason )
			return

		end
		RunConsoleCommand( "glee_banktop_open" )
	end
} )
