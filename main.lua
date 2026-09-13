--[[
	BlackwareUI — with Lucide tab icon support
	─────────────────────────────────────────────────────────────────────────────
	SETUP (two options):

	Option A — rainylib LucideIcons (your repo):
		local Icons = loadstring(game:HttpGet(
			"https://raw.githubusercontent.com/blacknoirs/rainylib/icons/LucideIcons/init.lua"
		))()
		local UI = loadstring(...)()
		local win = UI.new({ Title = "My Script", Key = Enum.KeyCode.RightShift, Icons = Icons })

	Option B — latte-soft/lucide-roblox (popular alternative):
		local Icons = require(game:GetService("ReplicatedStorage").Lucide)
		local win = UI.new({ ..., Icons = Icons })

	Option C — no icons at all (original behaviour):
		local win = UI.new({ Title = "My Script" })

	USAGE:
		local tab = win:Tab("Main",   "house")       -- Lucide icon name
		local tab = win:Tab("Combat", "crosshair")
		local tab = win:Tab("Visuals","eye")
		local tab = win:Tab("Misc")                  -- no icon, text only

		tab:Toggle("Aim Assist", false, function(v) end)
		tab:Slider("FOV", 50, 800, 250, function(v) end)
		tab:Dropdown("Bone", {"Head","Torso"}, "Head", function(v) end)
		tab:Button("Refresh", function() end)
		tab:Label("Section Title")
	─────────────────────────────────────────────────────────────────────────────
]]

local BWU = {}
BWU.__index = BWU

local Players  = game:GetService("Players")
local UIS      = game:GetService("UserInputService")
local TS       = game:GetService("TweenService")
local RunSvc   = game:GetService("RunService")

local lp       = Players.LocalPlayer
local pg       = lp:WaitForChild("PlayerGui")
local MOBILE   = UIS.TouchEnabled and not UIS.KeyboardEnabled

-- ─── theme ───────────────────────────────────────────────────────────────────
local T = {
	bg       = Color3.fromRGB(12, 12, 16),
	panel    = Color3.fromRGB(20, 20, 27),
	accent   = Color3.fromRGB(120, 80, 255),
	accentD  = Color3.fromRGB(80, 50, 200),
	tab      = Color3.fromRGB(28, 28, 38),
	tabSel   = Color3.fromRGB(38, 38, 55),
	text     = Color3.fromRGB(230, 230, 240),
	subtext  = Color3.fromRGB(130, 130, 150),
	toggle0  = Color3.fromRGB(45, 45, 60),
	toggle1  = Color3.fromRGB(120, 80, 255),
	slider   = Color3.fromRGB(35, 35, 50),
	border   = Color3.fromRGB(40, 40, 58),
	shadow   = Color3.fromRGB(0, 0, 0),
}

local FONT  = Enum.Font.GothamMedium
local FONTB = Enum.Font.GothamBold
local RAD   = 10
local W, H  = 420, 480

-- sidebar is wider when icons are shown
local SIDEBAR_ICON = 72   -- icon-only width
local SIDEBAR_TEXT = 110  -- text-only width (original)

-- ─── helpers ─────────────────────────────────────────────────────────────────
local function corner(r, p)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
	return c
end

local function stroke(clr, t, p)
	local s = Instance.new("UIStroke")
	s.Color = clr
	s.Thickness = t
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

local function frame(props)
	local f = Instance.new("Frame")
	for k, v in pairs(props) do f[k] = v end
	return f
end

local function label(props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = T.text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.RichText = true
	for k, v in pairs(props) do l[k] = v end
	return l
end

local function tween(obj, t, props)
	TS:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function makeDraggable(gui, handle)
	local dragging, dragStart, startPos = false, nil, nil
	local function input(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
			or inp.UserInputType == Enum.UserInputType.Touch then
			dragging  = true
			dragStart = inp.Position
			startPos  = gui.Position
			inp.Changed:Connect(function()
				if inp.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end
	handle.InputBegan:Connect(input)
	UIS.InputChanged:Connect(function(inp)
		if dragging and (
			inp.UserInputType == Enum.UserInputType.MouseMovement or
			inp.UserInputType == Enum.UserInputType.Touch
		) then
			local d = inp.Position - dragStart
			gui.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y
			)
		end
	end)
end

-- ─── scale ───────────────────────────────────────────────────────────────────
local function getScale()
	local vp = workspace.CurrentCamera
		and workspace.CurrentCamera.ViewportSize
		or Vector2.new(1920, 1080)
	local s = math.min(vp.X / 1280, vp.Y / 720)
	return math.clamp(s, MOBILE and 0.7 or 0.75, 1.2)
end

-- ─── icon helpers ─────────────────────────────────────────────────────────────
--[[
	We support two icon-library APIs:

	  rainylib / latte-soft style:
	    Icons["crosshair"]  → an ImageLabel or a table with .Image + .ImageRectOffset + .ImageRectSize

	  Function style (some libs return a function):
	    Icons("crosshair")  → same result

	In both cases we clone/copy the image data onto a fresh ImageLabel
	and parent it to the given container.
]]
local function applyIcon(Icons, iconName, parent, size)
	if not Icons or not iconName then return end
	size = size or 18

	-- resolve the icon data
	local iconData
	local t = type(Icons)
	if t == "function" then
		iconData = Icons(iconName)
	elseif t == "table" then
		-- could be Icons[name] or Icons:Get(name)
		iconData = Icons[iconName]
		if iconData == nil and type(Icons.Get) == "function" then
			iconData = Icons:Get(iconName)
		end
	end

	if not iconData then
		warn("BlackwareUI: icon '" .. tostring(iconName) .. "' not found in Icons library")
		return
	end

	local il = Instance.new("ImageLabel")
	il.BackgroundTransparency = 1
	il.Size = UDim2.fromOffset(size, size)
	il.AnchorPoint = Vector2.new(0.5, 0.5)
	il.Position = UDim2.new(0.5, 0, 0.5, 0)
	il.ImageColor3 = T.subtext
	il.ScaleType = Enum.ScaleType.Fit

	-- copy properties from returned data
	if typeof(iconData) == "Instance" and iconData:IsA("ImageLabel") then
		il.Image               = iconData.Image
		il.ImageRectOffset     = iconData.ImageRectOffset
		il.ImageRectSize       = iconData.ImageRectSize
	elseif type(iconData) == "table" then
		il.Image               = iconData.Image or ""
		il.ImageRectOffset     = iconData.ImageRectOffset or Vector2.zero
		il.ImageRectSize       = iconData.ImageRectSize   or Vector2.zero
	elseif type(iconData) == "string" then
		-- plain asset id
		il.Image = iconData
	end

	il.Parent = parent
	return il
end

-- ─── constructor ─────────────────────────────────────────────────────────────
function BWU.new(opts)
	opts = opts or {}
	local self      = setmetatable({}, BWU)
	self._tabs      = {}
	self._curTab    = nil
	self._visible   = true
	self._key       = opts.Key   or Enum.KeyCode.RightShift
	self._icons     = opts.Icons -- optional icon library
	self._iconMode  = self._icons ~= nil

	-- sidebar width depends on whether icons are available
	local SIDEBAR_W = self._iconMode and SIDEBAR_ICON or SIDEBAR_TEXT

	local sc = getScale()

	-- ScreenGui
	local sg = Instance.new("ScreenGui")
	sg.Name            = "BlackwareUI"
	sg.ResetOnSpawn    = false
	sg.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
	sg.IgnoreGuiInset  = true
	sg.Parent          = pg
	self._sg           = sg

	-- Scale
	local usc = Instance.new("UIScale")
	usc.Scale  = sc
	usc.Parent = sg

	-- Shadow (fake)
	local shadow = frame({
		Name                 = "Shadow",
		Size                 = UDim2.fromOffset(W + 16, H + 16),
		Position             = UDim2.new(0.5, -(W+16)/2, 0.5, -(H+16)/2),
		BackgroundColor3     = T.shadow,
		BackgroundTransparency = 0.55,
		BorderSizePixel      = 0,
	})
	corner(RAD + 4, shadow)
	shadow.Parent = sg

	-- Main window
	local win = frame({
		Name                = "Window",
		Size                = UDim2.fromOffset(W, H),
		Position            = UDim2.new(0.5, -W/2, 0.5, -H/2),
		BackgroundColor3    = T.bg,
		BorderSizePixel     = 0,
		ClipsDescendants    = true,
	})
	corner(RAD, win)
	stroke(T.border, 1, win)
	win.Parent = sg
	self._win  = win

	-- sync shadow
	win:GetPropertyChangedSignal("Position"):Connect(function()
		shadow.Position = UDim2.new(
			win.Position.X.Scale, win.Position.X.Offset - 8,
			win.Position.Y.Scale, win.Position.Y.Offset - 8
		)
	end)

	-- Titlebar
	local bar = frame({
		Name             = "Bar",
		Size             = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = T.panel,
		BorderSizePixel  = 0,
	})
	bar.Parent = win

	local accent_line = frame({
		Size             = UDim2.new(0, 3, 1, -12),
		Position         = UDim2.new(0, 10, 0, 6),
		BackgroundColor3 = T.accent,
		BorderSizePixel  = 0,
	})
	corner(2, accent_line)
	accent_line.Parent = bar

	local title = label({
		Size              = UDim2.new(1, -120, 1, 0),
		Position          = UDim2.fromOffset(20, 0),
		Text              = opts.Title or "BlackwareUI",
		Font              = FONTB,
		TextSize          = 15,
		TextColor3        = T.text,
	})
	title.Parent = bar

	local sub = label({
		Size              = UDim2.new(0, 150, 1, 0),
		Position          = UDim2.fromOffset(20, 0),
		Text              = opts.Subtitle or "",
		Font              = FONT,
		TextSize          = 11,
		TextColor3        = T.subtext,
		TextXAlignment    = Enum.TextXAlignment.Right,
	})
	sub.Parent = bar

	-- Close button
	local closeBtn     = Instance.new("TextButton")
	closeBtn.Size      = UDim2.fromOffset(28, 28)
	closeBtn.Position  = UDim2.new(1, -36, 0.5, -14)
	closeBtn.BackgroundColor3 = T.border
	closeBtn.Font      = FONTB
	closeBtn.Text      = "✕"
	closeBtn.TextColor3 = T.subtext
	closeBtn.TextSize  = 13
	closeBtn.BorderSizePixel = 0
	corner(6, closeBtn)
	closeBtn.Parent    = bar
	closeBtn.MouseButton1Click:Connect(function() self:Toggle(false) end)

	makeDraggable(win, bar)

	-- Tab sidebar
	local sidebar = frame({
		Name             = "Sidebar",
		Size             = UDim2.new(0, SIDEBAR_W, 1, -44),
		Position         = UDim2.new(0, 0, 0, 44),
		BackgroundColor3 = T.panel,
		BorderSizePixel  = 0,
	})
	sidebar.Parent   = win
	self._sidebar    = sidebar
	self._sidebarW   = SIDEBAR_W

	local tabList = Instance.new("UIListLayout")
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.Padding   = UDim.new(0, 4)
	tabList.Parent    = sidebar

	local tabPad = Instance.new("UIPadding")
	tabPad.PaddingTop   = UDim.new(0, 8)
	tabPad.PaddingLeft  = UDim.new(0, 6)
	tabPad.PaddingRight = UDim.new(0, 6)
	tabPad.Parent       = sidebar

	-- Thin vertical separator between sidebar and content
	local sep = frame({
		Size             = UDim2.new(0, 1, 1, -44),
		Position         = UDim2.new(0, SIDEBAR_W, 0, 44),
		BackgroundColor3 = T.border,
		BorderSizePixel  = 0,
	})
	sep.Parent = win

	-- Content area
	local content = frame({
		Name             = "Content",
		Size             = UDim2.new(1, -SIDEBAR_W, 1, -44),
		Position         = UDim2.new(0, SIDEBAR_W, 0, 44),
		BackgroundColor3 = T.bg,
		BorderSizePixel  = 0,
	})
	content.Parent  = win
	self._content   = content

	-- Floating toggle button
	local toggleBtn           = Instance.new("TextButton")
	toggleBtn.Name            = "ToggleBtn"
	toggleBtn.Size            = UDim2.fromOffset(44, 44)
	toggleBtn.Position        = MOBILE
		and UDim2.new(1, -54, 1, -64)
		or  UDim2.new(0, 10, 0.5, -22)
	toggleBtn.BackgroundColor3 = T.accent
	toggleBtn.Font            = FONTB
	toggleBtn.Text            = "BW"
	toggleBtn.TextColor3      = Color3.fromRGB(255, 255, 255)
	toggleBtn.TextSize        = 12
	toggleBtn.BorderSizePixel = 0
	toggleBtn.ZIndex          = 10
	corner(12, toggleBtn)
	toggleBtn.Parent = sg
	makeDraggable(toggleBtn, toggleBtn)

	toggleBtn.MouseButton1Click:Connect(function() self:Toggle() end)

	-- Keyboard toggle
	UIS.InputBegan:Connect(function(inp, gp)
		if gp then return end
		if inp.KeyCode == self._key then self:Toggle() end
	end)

	-- Auto-rescale
	RunSvc.RenderStepped:Connect(function()
		local ns = getScale()
		if math.abs(usc.Scale - ns) > 0.01 then usc.Scale = ns end
	end)

	self._tabList = tabList
	return self
end

-- ─── toggle visibility ────────────────────────────────────────────────────────
function BWU:Toggle(force)
	self._visible = force ~= nil and force or not self._visible
	local win = self._win
	if self._visible then
		win.Visible = true
		tween(win, 0.2, { BackgroundTransparency = 0 })
	else
		tween(win, 0.15, { BackgroundTransparency = 1 })
		task.delay(0.16, function()
			if not self._visible then win.Visible = false end
		end)
	end
end

-- ─── Tab ─────────────────────────────────────────────────────────────────────
--   win:Tab("Name")             — text label only
--   win:Tab("Name", "iconName") — Lucide icon name (requires Icons in BWU.new opts)
function BWU:Tab(name, iconName)
	local self2      = { _elements = {} }
	local iconMode   = self._iconMode and iconName ~= nil
	local SIDEBAR_W  = self._sidebarW

	-- ── sidebar button ──────────────────────────────────────────────────────
	local btn = Instance.new("TextButton")
	btn.Size             = UDim2.new(1, 0, 0, iconMode and 52 or 32)
	btn.BackgroundColor3 = T.tab
	btn.BorderSizePixel  = 0
	btn.LayoutOrder      = #self._tabs + 1
	-- Text is shown differently depending on mode
	btn.Text             = iconMode and "" or name
	btn.Font             = FONT
	btn.TextColor3       = T.subtext
	btn.TextSize         = 12
	corner(6, btn)
	btn.Parent = self._sidebar

	if iconMode then
		-- Icon image (centred, upper portion of button)
		local iconHolder = frame({
			Size             = UDim2.new(1, 0, 0, 32),
			Position         = UDim2.new(0, 0, 0, 4),
			BackgroundTransparency = 1,
			BorderSizePixel  = 0,
		})
		iconHolder.Parent = btn

		local il = applyIcon(self._icons, iconName, iconHolder, 18)
		self2._iconLabel = il  -- stored so we can tint on select

		-- Small text label beneath icon
		local iconText = label({
			Size              = UDim2.new(1, 0, 0, 14),
			Position          = UDim2.new(0, 0, 1, -16),
			Text              = name,
			TextSize          = 9,
			TextColor3        = T.subtext,
			TextXAlignment    = Enum.TextXAlignment.Center,
			Font              = FONT,
		})
		iconText.Parent    = btn
		self2._iconText    = iconText
	else
		-- plain text mode: left-align with small padding
		btn.TextXAlignment = Enum.TextXAlignment.Left
		local textPad = Instance.new("UIPadding")
		textPad.PaddingLeft = UDim.new(0, 10)
		textPad.Parent      = btn
	end

	-- Accent left-edge indicator (hidden when not selected)
	local selBar = frame({
		Size             = UDim2.new(0, 2, 0.6, 0),
		Position         = UDim2.new(0, 0, 0.2, 0),
		BackgroundColor3 = T.accent,
		BorderSizePixel  = 0,
		BackgroundTransparency = 1,
	})
	corner(1, selBar)
	selBar.Parent = btn
	self2._selBar = selBar

	-- ── scroll frame for elements ───────────────────────────────────────────
	local sf = Instance.new("ScrollingFrame")
	sf.Name                  = name
	sf.Size                  = UDim2.fromScale(1, 1)
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel        = 0
	sf.ScrollBarThickness     = 3
	sf.ScrollBarImageColor3   = T.accent
	sf.CanvasSize             = UDim2.fromOffset(0, 0)
	sf.AutomaticCanvasSize    = Enum.AutomaticSize.Y
	sf.Visible                = false
	sf.Parent                 = self._content

	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding   = UDim.new(0, 6)
	list.Parent    = sf

	local pad = Instance.new("UIPadding")
	pad.PaddingTop    = UDim.new(0, 10)
	pad.PaddingLeft   = UDim.new(0, 10)
	pad.PaddingRight  = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent        = sf

	-- ── tab selection ───────────────────────────────────────────────────────
	local function deselect(t)
		t.sf.Visible = false
		tween(t.btn, 0.12, { BackgroundColor3 = T.tab })
		if t.self2._iconLabel then
			tween(t.self2._iconLabel, 0.12, { ImageColor3 = T.subtext })
		end
		if t.self2._iconText then
			tween(t.self2._iconText, 0.12, { TextColor3 = T.subtext })
		end
		if not t.self2._iconLabel then  -- text mode
			tween(t.btn, 0.12, { TextColor3 = T.subtext })
		end
		tween(t.self2._selBar, 0.12, { BackgroundTransparency = 1 })
	end

	local function select()
		for _, t in ipairs(self._tabs) do deselect(t) end
		sf.Visible = true
		tween(btn, 0.12, { BackgroundColor3 = T.tabSel })
		tween(selBar, 0.12, { BackgroundTransparency = 0 })
		if self2._iconLabel then
			tween(self2._iconLabel, 0.12, { ImageColor3 = T.accent })
		end
		if self2._iconText then
			tween(self2._iconText, 0.12, { TextColor3 = T.text })
		end
		if not self2._iconLabel then  -- text mode
			tween(btn, 0.12, { TextColor3 = T.text })
		end
		self._curTab = self2
	end

	btn.MouseButton1Click:Connect(select)

	-- hover glow
	btn.MouseEnter:Connect(function()
		if self._curTab ~= self2 then
			tween(btn, 0.08, { BackgroundColor3 = Color3.fromRGB(32, 32, 44) })
		end
	end)
	btn.MouseLeave:Connect(function()
		if self._curTab ~= self2 then
			tween(btn, 0.08, { BackgroundColor3 = T.tab })
		end
	end)

	-- ── row helper ──────────────────────────────────────────────────────────
	local rowCount = 0
	local function makeRow(h)
		rowCount += 1
		local r = frame({
			Size             = UDim2.new(1, 0, 0, h),
			BackgroundColor3 = T.panel,
			BorderSizePixel  = 0,
			LayoutOrder      = rowCount,
		})
		corner(8, r)
		r.Parent = sf
		return r
	end

	-- ── Toggle ──────────────────────────────────────────────────────────────
	function self2:Toggle(ltext, default, cb)
		local state = default or false
		local row   = makeRow(46)

		local lbl = label({
			Size     = UDim2.new(1, -60, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			Text     = ltext,
			TextSize = 13,
		})
		lbl.Parent = row

		local track = frame({
			Size             = UDim2.fromOffset(36, 20),
			Position         = UDim2.new(1, -48, 0.5, -10),
			BackgroundColor3 = state and T.toggle1 or T.toggle0,
			BorderSizePixel  = 0,
		})
		corner(10, track)
		track.Parent = row

		local knob = frame({
			Size             = UDim2.fromOffset(14, 14),
			Position         = state
				and UDim2.new(1, -17, 0.5, -7)
				or  UDim2.new(0, 3, 0.5, -7),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel  = 0,
		})
		corner(7, knob)
		knob.Parent = track

		local function flip()
			state = not state
			tween(track, 0.15, { BackgroundColor3 = state and T.toggle1 or T.toggle0 })
			tween(knob,  0.15, { Position = state
				and UDim2.new(1, -17, 0.5, -7)
				or  UDim2.new(0, 3, 0.5, -7) })
			if cb then cb(state) end
		end

		local btn2                 = Instance.new("TextButton")
		btn2.Size                  = UDim2.fromScale(1, 1)
		btn2.BackgroundTransparency = 1
		btn2.Text                  = ""
		btn2.Parent                = row
		btn2.MouseButton1Click:Connect(flip)

		return self2
	end

	-- ── Slider ──────────────────────────────────────────────────────────────
	function self2:Slider(ltext, min, max, default, cb)
		local val = math.clamp(default or min, min, max)
		local row = makeRow(60)

		local lbl = label({
			Size     = UDim2.new(1, -60, 0, 20),
			Position = UDim2.new(0, 12, 0, 8),
			Text     = ltext,
			TextSize = 13,
		})
		lbl.Parent = row

		local numLbl = label({
			Size           = UDim2.new(0, 50, 0, 20),
			Position       = UDim2.new(1, -58, 0, 8),
			Text           = tostring(val),
			TextSize       = 12,
			TextColor3     = T.accent,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		numLbl.Parent = row

		local track = frame({
			Size             = UDim2.new(1, -24, 0, 6),
			Position         = UDim2.new(0, 12, 0, 38),
			BackgroundColor3 = T.slider,
			BorderSizePixel  = 0,
		})
		corner(3, track)
		track.Parent = row

		local fill = frame({
			Size             = UDim2.new((val - min) / (max - min), 0, 1, 0),
			BackgroundColor3 = T.accent,
			BorderSizePixel  = 0,
		})
		corner(3, fill)
		fill.Parent = track

		local handle = frame({
			Size             = UDim2.fromOffset(14, 14),
			Position         = UDim2.new((val - min) / (max - min), -7, 0.5, -7),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel  = 0,
		})
		corner(7, handle)
		handle.Parent = track

		local sliding = false

		local function update(inp)
			local abs = track.AbsolutePosition
			local sz  = track.AbsoluteSize
			local pct = math.clamp((inp.Position.X - abs.X) / sz.X, 0, 1)
			local nv  = math.floor(min + (max - min) * pct)
			val               = nv
			fill.Size         = UDim2.new(pct, 0, 1, 0)
			handle.Position   = UDim2.new(pct, -7, 0.5, -7)
			numLbl.Text       = tostring(nv)
			if cb then cb(nv) end
		end

		track.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1
				or inp.UserInputType == Enum.UserInputType.Touch then
				sliding = true
				update(inp)
			end
		end)

		UIS.InputChanged:Connect(function(inp)
			if sliding and (
				inp.UserInputType == Enum.UserInputType.MouseMovement or
				inp.UserInputType == Enum.UserInputType.Touch
			) then
				update(inp)
			end
		end)

		UIS.InputEnded:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1
				or inp.UserInputType == Enum.UserInputType.Touch then
				sliding = false
			end
		end)

		return self2
	end

	-- ── Dropdown ─────────────────────────────────────────────────────────────
	function self2:Dropdown(ltext, values, default, cb)
		local selected = default or values[1]
		local open     = false
		local row      = makeRow(46)

		local lbl = label({
			Size     = UDim2.new(0.45, 0, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			Text     = ltext,
			TextSize = 13,
		})
		lbl.Parent = row

		local box = frame({
			Size             = UDim2.new(0.5, -8, 0, 28),
			Position         = UDim2.new(0.5, 0, 0.5, -14),
			BackgroundColor3 = T.slider,
			BorderSizePixel  = 0,
		})
		corner(6, box)
		box.Parent = row

		local cur2 = label({
			Size       = UDim2.new(1, -28, 1, 0),
			Position   = UDim2.fromOffset(8, 0),
			Text       = selected,
			TextSize   = 12,
			TextColor3 = T.text,
		})
		cur2.Parent = box

		local arr = label({
			Size           = UDim2.fromOffset(20, 28),
			Position       = UDim2.new(1, -22, 0, 0),
			Text           = "▾",
			TextSize       = 14,
			TextColor3     = T.subtext,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		arr.Parent = box

		local list2 = frame({
			Size             = UDim2.new(0.5, -8, 0, #values * 30),
			Position         = UDim2.new(0.5, 0, 1, 2),
			BackgroundColor3 = T.tab,
			BorderSizePixel  = 0,
			ZIndex           = 5,
			Visible          = false,
		})
		corner(6, list2)
		stroke(T.border, 1, list2)
		list2.Parent = row

		local ll = Instance.new("UIListLayout")
		ll.SortOrder = Enum.SortOrder.LayoutOrder
		ll.Parent    = list2

		for i, v in ipairs(values) do
			local opt                   = Instance.new("TextButton")
			opt.Size                    = UDim2.new(1, 0, 0, 30)
			opt.BackgroundTransparency  = 1
			opt.Font                    = FONT
			opt.Text                    = v
			opt.TextColor3              = T.subtext
			opt.TextSize                = 12
			opt.LayoutOrder             = i
			opt.Parent                  = list2
			opt.MouseButton1Click:Connect(function()
				selected      = v
				cur2.Text     = v
				list2.Visible = false
				open          = false
				if cb then cb(v) end
			end)
			opt.MouseEnter:Connect(function()  tween(opt, 0.08, { TextColor3 = T.text    }) end)
			opt.MouseLeave:Connect(function()  tween(opt, 0.08, { TextColor3 = T.subtext }) end)
		end

		local boxBtn                   = Instance.new("TextButton")
		boxBtn.Size                    = UDim2.fromScale(1, 1)
		boxBtn.BackgroundTransparency  = 1
		boxBtn.Text                    = ""
		boxBtn.ZIndex                  = 2
		boxBtn.Parent                  = box
		boxBtn.MouseButton1Click:Connect(function()
			open          = not open
			list2.Visible = open
			tween(arr, 0.12, { Rotation = open and 180 or 0 })
		end)

		return self2
	end

	-- ── Button ───────────────────────────────────────────────────────────────
	function self2:Button(ltext, cb)
		local row = makeRow(40)

		local btn2                  = Instance.new("TextButton")
		btn2.Size                   = UDim2.new(1, -24, 0, 28)
		btn2.Position               = UDim2.new(0, 12, 0.5, -14)
		btn2.BackgroundColor3       = T.accentD
		btn2.Font                   = FONTB
		btn2.Text                   = ltext
		btn2.TextColor3             = Color3.fromRGB(255, 255, 255)
		btn2.TextSize               = 13
		btn2.BorderSizePixel        = 0
		corner(6, btn2)
		btn2.Parent = row

		btn2.MouseButton1Click:Connect(function()
			tween(btn2, 0.08, { BackgroundColor3 = T.accent })
			task.delay(0.15, function()
				tween(btn2, 0.1, { BackgroundColor3 = T.accentD })
			end)
			if cb then cb() end
		end)
		btn2.MouseEnter:Connect(function() tween(btn2, 0.1, { BackgroundColor3 = T.accent  }) end)
		btn2.MouseLeave:Connect(function() tween(btn2, 0.1, { BackgroundColor3 = T.accentD }) end)

		return self2
	end

	-- ── Label / Section ──────────────────────────────────────────────────────
	function self2:Label(ltext)
		local row = makeRow(28)
		row.BackgroundTransparency = 1
		local lbl = label({
			Size       = UDim2.new(1, -12, 1, 0),
			Position   = UDim2.fromOffset(12, 0),
			Text       = "<b>" .. ltext .. "</b>",
			TextSize   = 11,
			TextColor3 = T.subtext,
		})
		lbl.Parent = row
		return self2
	end

	-- ── Keybind ──────────────────────────────────────────────────────────────
	function self2:Keybind(ltext, default, cb)
		local key      = default or Enum.KeyCode.Unknown
		local binding  = false
		local row      = makeRow(46)

		local lbl = label({
			Size     = UDim2.new(1, -80, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			Text     = ltext,
			TextSize = 13,
		})
		lbl.Parent = row

		local keyBtn                  = Instance.new("TextButton")
		keyBtn.Size                   = UDim2.fromOffset(64, 26)
		keyBtn.Position               = UDim2.new(1, -76, 0.5, -13)
		keyBtn.BackgroundColor3       = T.slider
		keyBtn.Font                   = FONT
		keyBtn.Text                   = key.Name
		keyBtn.TextColor3             = T.text
		keyBtn.TextSize               = 11
		keyBtn.BorderSizePixel        = 0
		corner(5, keyBtn)
		keyBtn.Parent = row

		keyBtn.MouseButton1Click:Connect(function()
			binding         = true
			keyBtn.Text     = "..."
			keyBtn.TextColor3 = T.accent
		end)

		UIS.InputBegan:Connect(function(inp, gp)
			if gp or not binding then return end
			if inp.UserInputType == Enum.UserInputType.Keyboard then
				key             = inp.KeyCode
				binding         = false
				keyBtn.Text     = key.Name
				keyBtn.TextColor3 = T.text
				if cb then cb(key) end
			end
		end)

		return self2
	end

	-- register + auto-select first tab
	table.insert(self._tabs, { btn = btn, sf = sf, self2 = self2 })

	if #self._tabs == 1 then
		sf.Visible = true
		tween(btn, 0, { BackgroundColor3 = T.tabSel })
		tween(selBar, 0, { BackgroundTransparency = 0 })
		if self2._iconLabel then
			self2._iconLabel.ImageColor3 = T.accent
		end
		if self2._iconText then
			self2._iconText.TextColor3 = T.text
		end
		if not self2._iconLabel then
			btn.TextColor3 = T.text
		end
		self._curTab = self2
	end

	return self2
end

return BWU
