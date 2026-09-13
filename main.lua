-- ════════════════════════════════════════════════════════════════════
--  BLACKWARE UI LIBRARY (inline)
-- ════════════════════════════════════════════════════════════════════

local BWU = {}
BWU.__index = BWU

local Players  = game:GetService("Players")
local UIS      = game:GetService("UserInputService")
local TS       = game:GetService("TweenService")
local RunSvc   = game:GetService("RunService")

local lp       = Players.LocalPlayer
local pg       = lp:WaitForChild("PlayerGui")
local MOBILE   = UIS.TouchEnabled and not UIS.KeyboardEnabled

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
local SIDEBAR_ICON = 72
local SIDEBAR_TEXT = 110

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
	handle.InputBegan:Connect(function(inp)
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
	end)
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

local function getScale()
	local vp = workspace.CurrentCamera
		and workspace.CurrentCamera.ViewportSize
		or Vector2.new(1920, 1080)
	local s = math.min(vp.X / 1280, vp.Y / 720)
	return math.clamp(s, MOBILE and 0.7 or 0.75, 1.2)
end

-- icon helper: loads a rainylib LucideIcon module and creates an ImageLabel from it
local function applyIcon(iconData, parent, size)
	if not iconData then return end
	size = size or 18

	local il = Instance.new("ImageLabel")
	il.BackgroundTransparency = 1
	il.Size       = UDim2.fromOffset(size, size)
	il.AnchorPoint = Vector2.new(0.5, 0.5)
	il.Position   = UDim2.new(0.5, 0, 0.5, 0)
	il.ImageColor3 = T.subtext
	il.ScaleType  = Enum.ScaleType.Fit

	if typeof(iconData) == "Instance" and iconData:IsA("ImageLabel") then
		il.Image           = iconData.Image
		il.ImageRectOffset = iconData.ImageRectOffset
		il.ImageRectSize   = iconData.ImageRectSize
	elseif type(iconData) == "table" then
		il.Image           = iconData.Image or ""
		il.ImageRectOffset = iconData.ImageRectOffset or Vector2.zero
		il.ImageRectSize   = iconData.ImageRectSize   or Vector2.zero
	elseif type(iconData) == "string" then
		il.Image = iconData
	end

	il.Parent = parent
	return il
end

function BWU.new(opts)
	opts = opts or {}
	local self     = setmetatable({}, BWU)
	self._tabs     = {}
	self._curTab   = nil
	self._visible  = true
	self._key      = opts.Key or Enum.KeyCode.RightShift
	self._icons    = opts.Icons  -- { crosshair = <data>, menu = <data> }
	self._iconMode = self._icons ~= nil

	local SIDEBAR_W = self._iconMode and SIDEBAR_ICON or SIDEBAR_TEXT
	local sc = getScale()

	local sg = Instance.new("ScreenGui")
	sg.Name           = "BlackwareUI"
	sg.ResetOnSpawn   = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.IgnoreGuiInset = true
	sg.Parent         = pg
	self._sg          = sg

	local usc = Instance.new("UIScale")
	usc.Scale  = sc
	usc.Parent = sg

	local shadow = frame({
		Name                   = "Shadow",
		Size                   = UDim2.fromOffset(W + 16, H + 16),
		Position               = UDim2.new(0.5, -(W+16)/2, 0.5, -(H+16)/2),
		BackgroundColor3       = T.shadow,
		BackgroundTransparency = 0.55,
		BorderSizePixel        = 0,
	})
	corner(RAD + 4, shadow)
	shadow.Parent = sg

	local win = frame({
		Name             = "Window",
		Size             = UDim2.fromOffset(W, H),
		Position         = UDim2.new(0.5, -W/2, 0.5, -H/2),
		BackgroundColor3 = T.bg,
		BorderSizePixel  = 0,
		ClipsDescendants = true,
	})
	corner(RAD, win)
	stroke(T.border, 1, win)
	win.Parent = sg
	self._win  = win

	win:GetPropertyChangedSignal("Position"):Connect(function()
		shadow.Position = UDim2.new(
			win.Position.X.Scale, win.Position.X.Offset - 8,
			win.Position.Y.Scale, win.Position.Y.Offset - 8
		)
	end)

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

	label({
		Size       = UDim2.new(1, -120, 1, 0),
		Position   = UDim2.fromOffset(20, 0),
		Text       = opts.Title or "BlackwareUI",
		Font       = FONTB,
		TextSize   = 15,
		TextColor3 = T.text,
		Parent     = bar,
	})

	label({
		Size           = UDim2.new(0, 150, 1, 0),
		Position       = UDim2.fromOffset(20, 0),
		Text           = opts.Subtitle or "",
		Font           = FONT,
		TextSize       = 11,
		TextColor3     = T.subtext,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent         = bar,
	})

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size             = UDim2.fromOffset(28, 28)
	closeBtn.Position         = UDim2.new(1, -36, 0.5, -14)
	closeBtn.BackgroundColor3 = T.border
	closeBtn.Font             = FONTB
	closeBtn.Text             = "✕"
	closeBtn.TextColor3       = T.subtext
	closeBtn.TextSize         = 13
	closeBtn.BorderSizePixel  = 0
	corner(6, closeBtn)
	closeBtn.Parent = bar
	closeBtn.MouseButton1Click:Connect(function() self:Toggle(false) end)

	makeDraggable(win, bar)

	local sidebar = frame({
		Name             = "Sidebar",
		Size             = UDim2.new(0, SIDEBAR_W, 1, -44),
		Position         = UDim2.new(0, 0, 0, 44),
		BackgroundColor3 = T.panel,
		BorderSizePixel  = 0,
	})
	sidebar.Parent = win
	self._sidebar  = sidebar
	self._sidebarW = SIDEBAR_W

	local tabList = Instance.new("UIListLayout")
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.Padding   = UDim.new(0, 4)
	tabList.Parent    = sidebar

	local tabPad = Instance.new("UIPadding")
	tabPad.PaddingTop   = UDim.new(0, 8)
	tabPad.PaddingLeft  = UDim.new(0, 6)
	tabPad.PaddingRight = UDim.new(0, 6)
	tabPad.Parent       = sidebar

	frame({
		Size             = UDim2.new(0, 1, 1, -44),
		Position         = UDim2.new(0, SIDEBAR_W, 0, 44),
		BackgroundColor3 = T.border,
		BorderSizePixel  = 0,
		Parent           = win,
	})

	local content = frame({
		Name             = "Content",
		Size             = UDim2.new(1, -SIDEBAR_W, 1, -44),
		Position         = UDim2.new(0, SIDEBAR_W, 0, 44),
		BackgroundColor3 = T.bg,
		BorderSizePixel  = 0,
	})
	content.Parent = win
	self._content  = content

	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Name             = "ToggleBtn"
	toggleBtn.Size             = UDim2.fromOffset(44, 44)
	toggleBtn.Position         = MOBILE
		and UDim2.new(1, -54, 1, -64)
		or  UDim2.new(0, 10, 0.5, -22)
	toggleBtn.BackgroundColor3 = T.accent
	toggleBtn.Font             = FONTB
	toggleBtn.Text             = "BW"
	toggleBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
	toggleBtn.TextSize         = 12
	toggleBtn.BorderSizePixel  = 0
	toggleBtn.ZIndex           = 10
	corner(12, toggleBtn)
	toggleBtn.Parent = sg
	makeDraggable(toggleBtn, toggleBtn)
	toggleBtn.MouseButton1Click:Connect(function() self:Toggle() end)

	UIS.InputBegan:Connect(function(inp, gp)
		if gp then return end
		if inp.KeyCode == self._key then self:Toggle() end
	end)

	RunSvc.RenderStepped:Connect(function()
		local ns = getScale()
		if math.abs(usc.Scale - ns) > 0.01 then usc.Scale = ns end
	end)

	self._tabList = tabList
	return self
end

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

function BWU:Tab(name, iconData)
	local self2    = { _elements = {} }
	local iconMode = self._iconMode and iconData ~= nil

	local btn = Instance.new("TextButton")
	btn.Size             = UDim2.new(1, 0, 0, iconMode and 52 or 32)
	btn.BackgroundColor3 = T.tab
	btn.BorderSizePixel  = 0
	btn.LayoutOrder      = #self._tabs + 1
	btn.Text             = iconMode and "" or name
	btn.Font             = FONT
	btn.TextColor3       = T.subtext
	btn.TextSize         = 12
	corner(6, btn)
	btn.Parent = self._sidebar

	if iconMode then
		local iconHolder = frame({
			Size                   = UDim2.new(1, 0, 0, 32),
			Position               = UDim2.new(0, 0, 0, 4),
			BackgroundTransparency = 1,
			BorderSizePixel        = 0,
		})
		iconHolder.Parent = btn

		self2._iconLabel = applyIcon(iconData, iconHolder, 18)

		local iconText = label({
			Size           = UDim2.new(1, 0, 0, 14),
			Position       = UDim2.new(0, 0, 1, -16),
			Text           = name,
			TextSize       = 9,
			TextColor3     = T.subtext,
			TextXAlignment = Enum.TextXAlignment.Center,
			Font           = FONT,
		})
		iconText.Parent = btn
		self2._iconText = iconText
	else
		btn.TextXAlignment = Enum.TextXAlignment.Left
		local textPad = Instance.new("UIPadding")
		textPad.PaddingLeft = UDim.new(0, 10)
		textPad.Parent      = btn
	end

	local selBar = frame({
		Size                   = UDim2.new(0, 2, 0.6, 0),
		Position               = UDim2.new(0, 0, 0.2, 0),
		BackgroundColor3       = T.accent,
		BorderSizePixel        = 0,
		BackgroundTransparency = 1,
	})
	corner(1, selBar)
	selBar.Parent = btn
	self2._selBar = selBar

	local sf = Instance.new("ScrollingFrame")
	sf.Name                 = name
	sf.Size                 = UDim2.fromScale(1, 1)
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel      = 0
	sf.ScrollBarThickness   = 3
	sf.ScrollBarImageColor3 = T.accent
	sf.CanvasSize           = UDim2.fromOffset(0, 0)
	sf.AutomaticCanvasSize  = Enum.AutomaticSize.Y
	sf.Visible              = false
	sf.Parent               = self._content

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

	local function deselect(t)
		t.sf.Visible = false
		tween(t.btn, 0.12, { BackgroundColor3 = T.tab })
		if t.self2._iconLabel then
			tween(t.self2._iconLabel, 0.12, { ImageColor3 = T.subtext })
		end
		if t.self2._iconText then
			tween(t.self2._iconText, 0.12, { TextColor3 = T.subtext })
		end
		if not t.self2._iconLabel then
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
		if not self2._iconLabel then
			tween(btn, 0.12, { TextColor3 = T.text })
		end
		self._curTab = self2
	end

	btn.MouseButton1Click:Connect(select)
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

	function self2:Toggle(ltext, default, cb)
		local state = default or false
		local row   = makeRow(46)
		label({ Size = UDim2.new(1,-60,1,0), Position = UDim2.fromOffset(12,0), Text = ltext, TextSize = 13, Parent = row })
		local track = frame({ Size = UDim2.fromOffset(36,20), Position = UDim2.new(1,-48,0.5,-10), BackgroundColor3 = state and T.toggle1 or T.toggle0, BorderSizePixel = 0 })
		corner(10, track)
		track.Parent = row
		local knob = frame({ Size = UDim2.fromOffset(14,14), Position = state and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7), BackgroundColor3 = Color3.fromRGB(255,255,255), BorderSizePixel = 0 })
		corner(7, knob)
		knob.Parent = track
		local function flip()
			state = not state
			tween(track, 0.15, { BackgroundColor3 = state and T.toggle1 or T.toggle0 })
			tween(knob,  0.15, { Position = state and UDim2.new(1,-17,0.5,-7) or UDim2.new(0,3,0.5,-7) })
			if cb then cb(state) end
		end
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromScale(1,1) b.BackgroundTransparency = 1 b.Text = "" b.Parent = row
		b.MouseButton1Click:Connect(flip)
		return self2
	end

	function self2:Slider(ltext, min, max, default, cb)
		local val = math.clamp(default or min, min, max)
		local row = makeRow(60)
		label({ Size = UDim2.new(1,-60,0,20), Position = UDim2.new(0,12,0,8), Text = ltext, TextSize = 13, Parent = row })
		local numLbl = label({ Size = UDim2.new(0,50,0,20), Position = UDim2.new(1,-58,0,8), Text = tostring(val), TextSize = 12, TextColor3 = T.accent, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		local track = frame({ Size = UDim2.new(1,-24,0,6), Position = UDim2.new(0,12,0,38), BackgroundColor3 = T.slider, BorderSizePixel = 0 })
		corner(3, track) track.Parent = row
		local fill = frame({ Size = UDim2.new((val-min)/(max-min),0,1,0), BackgroundColor3 = T.accent, BorderSizePixel = 0 })
		corner(3, fill) fill.Parent = track
		local handle = frame({ Size = UDim2.fromOffset(14,14), Position = UDim2.new((val-min)/(max-min),-7,0.5,-7), BackgroundColor3 = Color3.fromRGB(255,255,255), BorderSizePixel = 0 })
		corner(7, handle) handle.Parent = track
		local sliding = false
		local function update(inp)
			local pct = math.clamp((inp.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
			val = math.floor(min + (max-min)*pct)
			fill.Size = UDim2.new(pct,0,1,0)
			handle.Position = UDim2.new(pct,-7,0.5,-7)
			numLbl.Text = tostring(val)
			if cb then cb(val) end
		end
		track.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
				sliding = true update(inp)
			end
		end)
		UIS.InputChanged:Connect(function(inp)
			if sliding and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then update(inp) end
		end)
		UIS.InputEnded:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then sliding = false end
		end)
		return self2
	end

	function self2:Dropdown(ltext, values, default, cb)
		local selected = default or values[1]
		local open = false
		local row = makeRow(46)
		label({ Size = UDim2.new(0.45,0,1,0), Position = UDim2.fromOffset(12,0), Text = ltext, TextSize = 13, Parent = row })
		local box = frame({ Size = UDim2.new(0.5,-8,0,28), Position = UDim2.new(0.5,0,0.5,-14), BackgroundColor3 = T.slider, BorderSizePixel = 0 })
		corner(6, box) box.Parent = row
		local cur2 = label({ Size = UDim2.new(1,-28,1,0), Position = UDim2.fromOffset(8,0), Text = selected, TextSize = 12, TextColor3 = T.text, Parent = box })
		local arr  = label({ Size = UDim2.fromOffset(20,28), Position = UDim2.new(1,-22,0,0), Text = "▾", TextSize = 14, TextColor3 = T.subtext, TextXAlignment = Enum.TextXAlignment.Center, Parent = box })
		local list2 = frame({ Size = UDim2.new(0.5,-8,0,#values*30), Position = UDim2.new(0.5,0,1,2), BackgroundColor3 = T.tab, BorderSizePixel = 0, ZIndex = 5, Visible = false })
		corner(6, list2) stroke(T.border, 1, list2) list2.Parent = row
		local ll = Instance.new("UIListLayout") ll.SortOrder = Enum.SortOrder.LayoutOrder ll.Parent = list2
		for i, v in ipairs(values) do
			local opt = Instance.new("TextButton")
			opt.Size = UDim2.new(1,0,0,30) opt.BackgroundTransparency = 1
			opt.Font = FONT opt.Text = v opt.TextColor3 = T.subtext opt.TextSize = 12 opt.LayoutOrder = i opt.Parent = list2
			opt.MouseButton1Click:Connect(function() selected = v cur2.Text = v list2.Visible = false open = false if cb then cb(v) end end)
			opt.MouseEnter:Connect(function() tween(opt,0.08,{TextColor3=T.text}) end)
			opt.MouseLeave:Connect(function() tween(opt,0.08,{TextColor3=T.subtext}) end)
		end
		local boxBtn = Instance.new("TextButton")
		boxBtn.Size = UDim2.fromScale(1,1) boxBtn.BackgroundTransparency = 1 boxBtn.Text = "" boxBtn.ZIndex = 2 boxBtn.Parent = box
		boxBtn.MouseButton1Click:Connect(function() open = not open list2.Visible = open tween(arr,0.12,{Rotation=open and 180 or 0}) end)
		return self2
	end

	function self2:Button(ltext, cb)
		local row = makeRow(40)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1,-24,0,28) b.Position = UDim2.new(0,12,0.5,-14)
		b.BackgroundColor3 = T.accentD b.Font = FONTB b.Text = ltext
		b.TextColor3 = Color3.fromRGB(255,255,255) b.TextSize = 13 b.BorderSizePixel = 0
		corner(6, b) b.Parent = row
		b.MouseButton1Click:Connect(function()
			tween(b,0.08,{BackgroundColor3=T.accent})
			task.delay(0.15,function() tween(b,0.1,{BackgroundColor3=T.accentD}) end)
			if cb then cb() end
		end)
		b.MouseEnter:Connect(function() tween(b,0.1,{BackgroundColor3=T.accent}) end)
		b.MouseLeave:Connect(function() tween(b,0.1,{BackgroundColor3=T.accentD}) end)
		return self2
	end

	function self2:Label(ltext)
		local row = makeRow(28)
		row.BackgroundTransparency = 1
		label({ Size = UDim2.new(1,-12,1,0), Position = UDim2.fromOffset(12,0), Text = "<b>"..ltext.."</b>", TextSize = 11, TextColor3 = T.subtext, Parent = row })
		return self2
	end

	table.insert(self._tabs, { btn = btn, sf = sf, self2 = self2 })

	if #self._tabs == 1 then
		sf.Visible = true
		tween(btn, 0, { BackgroundColor3 = T.tabSel })
		tween(selBar, 0, { BackgroundTransparency = 0 })
		if self2._iconLabel then self2._iconLabel.ImageColor3 = T.accent end
		if self2._iconText  then self2._iconText.TextColor3  = T.text   end
		if not self2._iconLabel then btn.TextColor3 = T.text end
		self._curTab = self2
	end

	return self2
end

-- ════════════════════════════════════════════════════════════════════
--  ICON LOADING
--  Loads PNG icons from the LucideIcons folder in the GitHub repo.
-- ════════════════════════════════════════════════════════════════════

local ICON_BASE =
	"https://raw.githubusercontent.com/blacknoirs/rainylib/refs/heads/main/LucideIcons/"

local function loadIcon(name)
	local fileName = "BlackwareIcon_" .. name .. ".png"

	local ok, result = pcall(function()
		if not isfile(fileName) then
			local data = game:HttpGet(ICON_BASE .. name .. ".png")
			writefile(fileName, data)
		end

		return getcustomasset(fileName)
	end)

	if ok then
		return result
	end

	warn("BlackwareUI: failed to load icon '" .. name .. "': " .. tostring(result))
	return nil
end

local crosshairIcon = loadIcon("crosshair")
local menuIcon      = loadIcon("menu")


-- ════════════════════════════════════════════════════════════════════
--  GAME SCRIPT
-- ════════════════════════════════════════════════════════════════════

local P   = game:GetService("Players")
local R   = game:GetService("RunService")
local W   = game:GetService("Workspace")

local cfg = {
	aim     = false,
	esp     = false,
	fov     = 250,
	showFov = true,
	bone    = "Head",
	teamck  = true,
	minD    = 2,
	maxD    = 5000,
}

local ring            = Drawing.new("Circle")
ring.Thickness        = 2
ring.Filled           = false
ring.Color            = Color3.fromRGB(180, 130, 255)
ring.Transparency     = 0.5
ring.Visible          = false

local esps = {}
local cur  = nil

local function wipeESP(p)
	if not esps[p] then return end
	pcall(function()
		if esps[p].hl then esps[p].hl:Destroy() end
		if esps[p].bb then esps[p].bb:Destroy() end
	end)
	esps[p] = nil
end

local function makeESP(p)
	wipeESP(p)
	if not cfg.esp then return end
	local char = p.Character
	if not char then return end
	local hum  = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	if not head then return end
	pcall(function()
		local hl                   = Instance.new("Highlight")
		hl.Adornee                 = char
		hl.FillColor               = Color3.fromRGB(140, 80, 255)
		hl.OutlineColor            = Color3.fromRGB(200, 170, 255)
		hl.FillTransparency        = 0.55
		hl.OutlineTransparency     = 0
		hl.DepthMode               = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent                  = char
		local bb                   = Instance.new("BillboardGui")
		bb.Adornee                 = head
		bb.Size                    = UDim2.fromOffset(160, 26)
		bb.StudsOffset             = Vector3.new(0, 3, 0)
		bb.AlwaysOnTop             = true
		bb.Parent                  = head
		local lbl2                 = Instance.new("TextLabel")
		lbl2.Size                  = UDim2.fromScale(1, 1)
		lbl2.BackgroundTransparency = 1
		lbl2.Text                  = p.DisplayName
		lbl2.TextColor3            = Color3.fromRGB(200, 160, 255)
		lbl2.TextStrokeTransparency = 0
		lbl2.Font                  = Enum.Font.GothamBold
		lbl2.TextSize              = 13
		lbl2.Parent                = bb
		esps[p] = { hl = hl, bb = bb }
	end)
end

local function rebuildESP()
	for p in pairs(esps) do wipeESP(p) end
	if not cfg.esp then return end
	for _, p in ipairs(P:GetPlayers()) do
		if p ~= lp then makeESP(p) end
	end
end

R.RenderStepped:Connect(function()
	local cam = W.CurrentCamera
	if not cam then return end
	local vp     = cam.ViewportSize
	local cx, cy = vp.X / 2, vp.Y / 2

	ring.Position = Vector2.new(cx, cy)
	ring.Radius   = cfg.fov
	ring.Visible  = cfg.aim and cfg.showFov

	if not cfg.aim then cur = nil return end

	local lchar = lp.Character
	local lroot = lchar and lchar:FindFirstChild("HumanoidRootPart")
	if not lroot then return end

	cur = nil
	local bestD = math.huge

	for _, p in ipairs(P:GetPlayers()) do
		if p == lp then continue end
		local char = p.Character
		if not char then continue end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then continue end
		if cfg.teamck and p.Team and p.Team == lp.Team then continue end
		local bn
		if cfg.bone == "Head" then
			bn = char:FindFirstChild("HeadHB") or char:FindFirstChild("Head")
		elseif cfg.bone == "Torso" then
			bn = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
		else
			bn = char:FindFirstChild("HumanoidRootPart")
		end
		if not bn then continue end
		local wd = (bn.Position - lroot.Position).Magnitude
		if wd < cfg.minD or wd > cfg.maxD then continue end
		local sv, onscreen = cam:WorldToViewportPoint(bn.Position)
		if not onscreen then continue end
		local sd = Vector2.new(sv.X - cx, sv.Y - cy).Magnitude
		if sd > cfg.fov then continue end
		if sd < bestD then bestD = sd cur = { player = p, bone = bn } end
	end

	if not cur then return end
	local bn = cur.bone
	if not bn or not bn.Parent then cur = nil return end
	local sv, onscreen = cam:WorldToViewportPoint(bn.Position)
	if not onscreen then return end
	mousemoverel(sv.X - cx, sv.Y - cy)
end)

local et = 0
R.Heartbeat:Connect(function(dt)
	if not cfg.esp then
		for p in pairs(esps) do wipeESP(p) end
		return
	end
	et += dt
	if et < 0.3 then return end
	et = 0
	for _, p in ipairs(P:GetPlayers()) do
		if p == lp then continue end
		local char  = p.Character
		local hum   = char and char:FindFirstChildOfClass("Humanoid")
		local alive = hum and hum.Health > 0
		if alive and not esps[p] then makeESP(p)
		elseif not alive and esps[p] then wipeESP(p) end
	end
end)

P.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(function() task.wait(0.1) makeESP(p) end)
end)
P.PlayerRemoving:Connect(function(p)
	wipeESP(p)
	if cur and cur.player == p then cur = nil end
end)
for _, p in ipairs(P:GetPlayers()) do
	if p ~= lp then
		p.CharacterAdded:Connect(function() task.wait(0.1) makeESP(p) end)
	end
end

-- ════════════════════════════════════════════════════════════════════
--  UI SETUP
--  Icon data is passed directly into Tab() — no Icons table needed.
-- ════════════════════════════════════════════════════════════════════

local win = BWU.new({
	Title    = "Blackware",
	Subtitle = "v3",
	Key      = Enum.KeyCode.RightShift,
	-- only enable icon mode if we actually got icon data
	Icons    = (crosshairIcon or menuIcon) and { _dummy = true } or nil,
})

local main = win:Tab("Aim",    crosshairIcon)
local vizt = win:Tab("Visual", menuIcon)

main:Toggle("Aim Assist",   cfg.aim,     function(v) cfg.aim     = v  if not v then cur = nil end end)
main:Toggle("Show FOV",     cfg.showFov, function(v) cfg.showFov = v  end)
main:Slider("FOV Radius",   50,  800,   cfg.fov,   function(v) cfg.fov  = v  end)
main:Slider("Min Distance", 0,   30,    cfg.minD,  function(v) cfg.minD = v  end)
main:Slider("Max Distance", 50,  10000, cfg.maxD,  function(v) cfg.maxD = v  end)
main:Dropdown("Target Bone", {"Head","Torso","HumanoidRootPart"}, cfg.bone, function(v) cfg.bone = v cur = nil end)
main:Toggle("Team Check",   cfg.teamck,  function(v) cfg.teamck  = v  end)

vizt:Toggle("ESP",         cfg.esp, function(v) cfg.esp = v rebuildESP() end)
vizt:Button("Refresh ESP", function() rebuildESP() end)
