include("shared.lua")

SOUND_PANEL_SCINT = Sound "moonpanel/panel_scint.ogg"
SOUND_PANEL_FAILURE = Sound "moonpanel/panel_failure.ogg"
SOUND_PANEL_POTENTIAL_FAILURE = Sound "moonpanel/panel_potential_failure.ogg"
SOUND_PANEL_SUCCESS = Sound "moonpanel/panel_success.ogg"
SOUND_PANEL_START = Sound "moonpanel/panel_start_tracing.ogg"
SOUND_PANEL_ERASER = Sound "moonpanel/eraser_apply.ogg"
SOUND_PANEL_ABORT = Sound "moonpanel/panel_abort_tracing.ogg"

ENT.RenderGroup = RENDERGROUP_BOTH

ENT.GetTimerName = (subname) =>
	index = tostring @EntIndex!
	return "TheMP_Panel#{index}_#{subname}"

ENT.Initialize = () =>
	@BaseClass.Initialize @

	info = @Monitor_Offsets[@GetModel!]
	if not info
		mins = @OBBMins!
		maxs = @OBBMaxs!
		size = maxs-mins
		info = {
            Name: ""
            RS: (size.y-1) / @ScreenSize
            RatioX: size.y / size.x
            offset: @OBBCenter! + Vector 0, 0, maxs.z - 0.24
            rot: Angle 0, 0, 180
            x1: 0
            x2: 0
            y1: 0
            y2: 0
            z: 0
        }

	rotation, translation, translation2, scale = Matrix!, Matrix!, Matrix!, Matrix!

	rotation\SetAngles          info.rot
	translation\SetTranslation  info.offset
	translation2\SetTranslation Vector -512 / info.RatioX,  -512,       0
	scale\SetScale              Vector info.RS / 2, info.RS / 2, info.RS / 2

	@ScreenMatrix = translation * rotation * scale * translation2
	@ScreenInfo = info
	@Aspect = info.RatioX
	@Scale = info.RS / 2
	@Origin = info.offset

	w, h = @ScreenSize / @Aspect, @ScreenSize
	@ScreenQuad = {
        Vector(0,0,0)
        Vector(w,0,0)
        Vector(w,h,0)
        Vector(0,h,0)
        Color(0, 0, 0, 255)
    }

	@SetBackgroundColor 80, 77, 255, 255

	index = tostring @EntIndex!
	@rendertargets = {
		foreground: {
			always: true
			rt: GetRenderTarget "TheMPFG#{index}", @ScreenSize, @ScreenSize
			render: @DrawForeground
		}
		background: {
			rt: GetRenderTarget "TheMPBG#{index}", @ScreenSize, @ScreenSize
			render: @DrawBackground
		}
		trace: {
			rt: GetRenderTarget "TheMPTrace#{index}", @ScreenSize, @ScreenSize
			render: @DrawTrace
		}
		ripple: {
			always: true
			rt: GetRenderTarget "TheMPRipple#{index}", @ScreenSize, @ScreenSize
			render: @DrawRipple
		}
	}

ENT.Draw = () =>
	@DrawModel!

ENT.SetBackgroundColor = (r, g, b, a) =>
	@ScreenQuad[5] = Color r, g, b, (math.max a, 1)

writez = Material("engine/writez")

fn = (self) ->
	self\RenderPanel!

ENT.DrawTranslucent = () =>
ENT.Draw = () =>
	@DrawModel()

	if not @ScreenMatrix or halo.RenderedEntity() == @
        return
	-- Draw screen here
	transform = @GetBoneMatrix(0) * @ScreenMatrix
	@Transform = transform
	cam.PushModelMatrix(transform)

    render.ClearStencil!
    render.SetStencilEnable true
    render.SetStencilFailOperation STENCILOPERATION_KEEP
    render.SetStencilZFailOperation STENCILOPERATION_KEEP
    render.SetStencilPassOperation STENCILOPERATION_REPLACE
    render.SetStencilCompareFunction STENCILCOMPARISONFUNCTION_ALWAYS
    render.SetStencilWriteMask 1
    render.SetStencilReferenceValue 1

    --First draw a quad that defines the visible area
    render.SetColorMaterial!
    render.DrawQuad unpack @ScreenQuad

    render.SetStencilCompareFunction STENCILCOMPARISONFUNCTION_EQUAL
    render.SetStencilTestMask 1

    --Clear it to the clear color and clear depth as well
    color = @ScreenQuad[5]
    if color.a == 255
        render.ClearBuffersObeyStencil color.r, color.g, color.b, color.a, true

    --Render the starfall stuff
    --render.PushFilterMag TEXFILTER.ANISOTROPIC
    --render.PushFilterMin TEXFILTER.ANISOTROPIC

    xpcall fn, print, @

    --render.PopFilterMag!
    --render.PopFilterMin!

    render.SetStencilEnable false

    --Give the screen back its depth
    render.SetMaterial writez
    render.DrawQuad unpack @ScreenQuad

	cam.PopModelMatrix!

ENT.GetCursorPos = () =>
	ply = LocalPlayer()
	screen = @

	local Normal, Pos
	-- Get monitor screen pos & size

	Pos = screen\LocalToWorld screen.Origin

	Normal = -screen.Transform\GetUp!\GetNormalized!

	Start = ply\GetShootPos!
	Dir = ply\GetAimVector!

	A = Normal\Dot Dir

	-- If ray is parallel or behind the screen
	if A == 0 or A > 0
		return nil

	B = Normal\Dot(Pos-Start) / A
	if (B >= 0)
		w = @ScreenSize / screen.Aspect
		HitPos = screen.Transform\GetInverseTR! * (Start + Dir * B)
		x = HitPos.x / screen.Scale^2
		y = HitPos.y / screen.Scale^2
		if x < 0 or x > w or y < 0 or y > @ScreenSize
			return nil
		return x, y

	return nil

ENT.GetResolution = () =>
	return @ScreenSize / @Aspect, @ScreenSize

ENT.ClientThink = () =>
	if @shouldRepaintTrace and CurTime! >= (@nextTraceRepaint or 0)
		@shouldRepaintTrace = false
		@nextTraceRepaint = CurTime! + 0.01

		@rendertargets.trace.dirty = true

ENT.ClientTickrateThink = () =>
	activeUser = @GetNW2Entity "ActiveUser"
	if IsValid activeUser
		if @__scintPower and @__scintPower >= 0.15 and CurTime! >= @__nextscint
			@EmitSound SOUND_PANEL_SCINT, 75, 100, @__scintPower
			@__nextscint = CurTime! + 2
			@__scintPower *= 0.75
			@__firstscint = false

import SetDrawColor, DrawRect from surface
import Clear, ClearDepth, OverrideAlphaWriteEnable from render

RT_Material = CreateMaterial "TheMP_RT", "UnlitGeneric", {
	["$nolod"]: 1,
	["$ignorez"]: 1,
	["$vertexcolor"]: 1,
	["$vertexalpha"]: 1
}

ENT.PuzzleStart = (nodeA, nodeB) =>
	tr = @colors.traced
	@pen = Color tr.r, tr.g, tr.b, 255

	@EmitSound SOUND_PANEL_START

	@pathFinder\restart nodeA, nodeB
    @shouldRepaintTrace = true

	@__nextscint = CurTime! + 0.5
	@__firstscint = true
	@__scintPower = 1
	@redOut = nil
	@grayOut = nil
	@grayOutStart = nil

	timer.Remove @GetTimerName "redOut"
	timer.Remove @GetTimerName "grayOut"
	timer.Remove @GetTimerName "penFade"

ENT.PuzzleFinish = (success, aborted, @redOut, _grayOut) =>
	@__scintPower = nil

	if success
		if _grayOut.grayedOut
			@EmitSound SOUND_PANEL_POTENTIAL_FAILURE

			_oldPen = ColorAlpha @pen, 255
			err = @colors.errored
			@pen = Color err.r, err.g, err.b, 255

			timer.Create @GetTimerName("penFade"), 0.05, 0, () ->
				if not IsValid @
					return

				if @pen.a <= 0
					@pen.a = 0
					timer.Remove @GetTimerName "penFade"
					return

				@pen.a -= 5
				@shouldRepaintTrace = true

			timer.Create @GetTimerName("grayOut"), 0.75, 1, () ->
				timer.Remove @GetTimerName "penFade"
				@redOut = nil
				@grayOut = _grayOut
				@grayOutStart = CurTime!
				@pen = _oldPen
				@EmitSound SOUND_PANEL_ERASER

		else
			@EmitSound SOUND_PANEL_SUCCESS
	elseif not aborted
		@grayOut = _grayOut
		@grayOutStart = CurTime!

		@EmitSound SOUND_PANEL_FAILURE
		if @pen
			err = @colors.errored
			@pen = Color err.r, err.g, err.b, 255

			timer.Create @GetTimerName("penFade"), 0.05, 0, () ->
				if not IsValid @
					return

				if @pen.a <= 0
					@pen.a = 0
					timer.Remove @GetTimerName "penFade"
					return

				@pen.a -= 5
				@shouldRepaintTrace = true
	else
		@EmitSound SOUND_PANEL_ABORT

		if @pen
			@pen = Color @pen.r, @pen.g, @pen.b, 255

			timer.Create @GetTimerName("penFade"), 0.05, 0, () ->
				if not IsValid @
					return

				if @pen.a <= 0
					@pen.a = 0
					timer.Remove @GetTimerName "penFade"
					return

				@pen.a -= 5
				@shouldRepaintTrace = true

ENT.SetupDataClient = () =>
	defs = Moonpanel.DefaultColors
	
	@colors            or= {}
	@colors.background or= defs.Background
	@colors.untraced   or= defs.Untraced
	@colors.traced     or= defs.Traced
	@colors.vignette   or= defs.Vignette
	@colors.errored    or= defs.Errored

	tr = @colors.traced
	@pen = Color tr.r, tr.g, tr.b, 255

    cellsW = @tileData.Tile.Width
    cellsH = @tileData.Tile.Height

	@startRipples = {}
	@endRipples = {}
	for j = 1, cellsH + 1
		for i = 1, cellsW + 1
			int = @elements.intersections[i][j]
			if int and int.entity
				if int.entity.type == MOONPANEL_ENTITY_TYPES.START
					@startRipples[#@startRipples + 1] = int.entity.ripple
				if int.entity.type == MOONPANEL_ENTITY_TYPES.END
					@endRipples[#@endRipples + 1] = int.entity.ripple

ENT.DrawBackground = () =>
	Clear 0, 0, 0, 0
	ClearDepth!

    cellsW = @tileData.Tile.Width
    cellsH = @tileData.Tile.Height

	for j = 1, cellsH + 1
		for i = 1, cellsW + 1
			toRender = {}
			if i <= cellsW and j <= cellsH
				toRender[#toRender + 1] = @elements.cells[i][j]

			if i <= cellsW and j <= cellsH + 1
				toRender[#toRender + 1] = @elements.hpaths[i][j]

			if i <= cellsW + 1 and j <= cellsH
				toRender[#toRender + 1] = @elements.vpaths[i][j]

			toRender[#toRender + 1] = @elements.intersections[i][j]
			
			for _, obj in pairs toRender
				if obj and not (obj.entity and obj.entity.overridesRender)
					obj\render!
				if obj and obj.entity and obj.entity.background
					obj\renderEntity!

gradient = (startColor, endColor, percentFade) ->
	diffRed = endColor.r - startColor.r
	diffGreen = endColor.g - startColor.g
	diffBlue = endColor.b - startColor.b
	diffAlpha = endColor.a - startColor.a

	return Color (diffRed * percentFade) + startColor.r,
		(diffGreen * percentFade) + startColor.g,
		(diffBlue * percentFade) + startColor.b,
		(diffAlpha * percentFade) + startColor.a

_err = Color 255, 0, 0, 255
_errAlt = Color 0, 0, 0, 255
ENT.ErrorifyColor = (color, alternate) =>
	clr = _err
	if color.r > 200 and color.b < 30 and color.g < 30
		clr = _errAlt

	time = CurTime!

	pct = ((math.cos math.rad time * 500) + 1) / 2

	if alternate
		pct = 1 - pct

	return gradient clr, color, pct	

ENT.DrawForeground = () =>
	Clear 0, 0, 0, 0
	ClearDepth!

    cellsW = @tileData.Tile.Width
    cellsH = @tileData.Tile.Height

	for j = 1, cellsH + 1
		for i = 1, cellsW + 1
			toRender = {}
			if i <= cellsW and j <= cellsH
				toRender[#toRender + 1] = @elements.cells[i][j]

			if i <= cellsW and j <= cellsH + 1
				toRender[#toRender + 1] = @elements.hpaths[i][j]

			if i <= cellsW + 1 and j <= cellsH
				toRender[#toRender + 1] = @elements.vpaths[i][j]

			toRender[#toRender + 1] = @elements.intersections[i][j]
			
			for _, obj in pairs toRender
				if obj and obj.entity and not obj.entity.background
					clr = Moonpanel.Colors[(obj.entity.attributes and obj.entity.attributes.color) or 1]

					if @grayOut and @grayOut[obj.type] and @grayOut[obj.type][j] and @grayOut[obj.type][j][i]
						pct = math.Clamp (CurTime!- @grayOutStart) / 2, 0, 0.6
						pct = 1 - pct

						clr = ColorAlpha clr, 255 * math.EaseInOut pct, 0.1, 0.1

					elseif @redOut and @redOut[obj.type] and @redOut[obj.type][j] and @redOut[obj.type][j][i]
						alternate = ((i + j) % 2 == 0) and true or false
						clr = @ErrorifyColor clr, alternate

					surface.SetDrawColor clr
					obj\renderEntity!

circ = Material "moonpanel/circ128.png"
ENT.DrawTrace = () =>
	Clear 0, 0, 0, 0
	ClearDepth!

	if false
		for _, node in pairs @pathMap
			w, h = 32, 32
			x, y = node.screenX - w/2, node.screenY - w/2
			render.SetMaterial circ
			Moonpanel.render.drawTexturedRect x, y, w, h, (Color 255, 0, 0)
			render.SetColorMaterial!

			for _, neighbor in pairs node.neighbors
				draw.NoTexture!
				surface.SetDrawColor (Color 255, 0, 0, 255)
				surface.DrawLine node.screenX, node.screenY, neighbor.screenX, neighbor.screenY

	nodeStacks = nil
	cursors = {}
	--if LocalPlayer! == @GetNW2Entity "ActiveUser"
	nodeStacks = @pathFinder.nodeStacks
	cursors = @pathFinder.cursors

	surface.SetDrawColor Color 255, 255, 255, 255
	if nodeStacks
		barWidth = @calculatedDimensions.barWidth
		barLength = @calculatedDimensions.barLength
		symmVector = nil

		for stackId, stack in pairs nodeStacks 
			for k, v in pairs stack
				Moonpanel.render.drawCircle v.screenX, v.screenY, (k == 1) and barWidth * 1.25 or barWidth / 2

				if k > 1
					prev = stack[k - 1]
					Moonpanel.render.drawThickLine prev.screenX, prev.screenY, v.screenX, v.screenY, barWidth

		if cursors and #cursors > 0
			for stackid, cur in pairs cursors
				stack = nodeStacks[stackid]
				last = stack[#stack]
				Moonpanel.render.drawCircle cur.x, cur.y, barWidth / 2  
				Moonpanel.render.drawThickLine cur.x, cur.y, last.screenX, last.screenY, barWidth

setRTTexture = (rt) ->
	RT_Material\SetTexture "$basetexture", rt
	surface.SetMaterial RT_Material
	render.SetMaterial RT_Material

ENT.DrawRipple = () =>
	Clear 0, 0, 0, 0
	ClearDepth!

	activeUser = @GetNW2Entity "ActiveUser"
	if @endRipples and @__nextscint and not @__firstscint and IsValid activeUser
		buf = 1 - ((@__nextscint - CurTime!) / 2)
		for _, ripple in pairs @endRipples
			Moonpanel.render.drawRipple ripple, buf, (Color 255, 255, 255)

ENT.RenderPanel = () =>
	if not @rendertargets or not @calculatedDimensions
		return

	oldw, oldh = ScrW!, ScrH!
	for k, v in pairs @rendertargets
		if (v.always or v.dirty ~= false) and v.render
			v.dirty = false

			render.SetStencilEnable false
			render.SetViewPort 0, 0, @ScreenSize, @ScreenSize
			cam.Start2D!

			draw.NoTexture!
			render.SetColorMaterial!

			render.PushRenderTarget v.rt
			v.render @
			render.PopRenderTarget!

			cam.End2D!
			render.SetViewPort 0, 0, oldw, oldh
			render.SetStencilEnable true

	render.SetColorModulation(1, 0.5, 0)
	draw.NoTexture!
	render.SetColorMaterial!

	SetDrawColor 255, 255, 255, 255
	setRTTexture @rendertargets.background.rt
	surface.DrawTexturedRect 0, 0, @ScreenSize, @ScreenSize

	setRTTexture @rendertargets.foreground.rt
	surface.DrawTexturedRect 0, 0, @ScreenSize, @ScreenSize

	setRTTexture @rendertargets.ripple.rt
	surface.DrawTexturedRect 0, 0, @ScreenSize, @ScreenSize

	surface.SetDrawColor @pen
	setRTTexture @rendertargets.trace.rt
	surface.DrawTexturedRect 0, 0, @ScreenSize, @ScreenSize

ENT.Monitor_Offsets = {
	["models//cheeze/pcb/pcb4.mdl"]: {
		Name:	"pcb4.mdl",
		RS:	0.0625,
		RatioX:	1,
		offset:	Vector(0, 0, 0.5),
		rot:	Angle(0, 0, 180),
		x1:	-16,
		x2:	16,
		y1:	-16,
		y2:	16,
		z:	0.5,
	},
	["models//cheeze/pcb/pcb5.mdl"]: {
		Name:	"pcb5.mdl",
		RS:	0.0625,
		RatioX:	0.508,
		offset:	Vector(-0.5, 0, 0.5),
		rot:	Angle(0, 0, 180),
		x1:	-31.5,
		x2:	31.5,
		y1:	-16,
		y2:	16,
		z:	0.5,
	},
	["models//cheeze/pcb/pcb6.mdl"]: {
		Name:	"pcb6.mdl",
		RS:	0.09375,
		RatioX:	0.762,
		offset:	Vector(-0.5, -8, 0.5),
		rot:	Angle(0, 0, 180),
		x1:	-31.5,
		x2:	31.5,
		y1:	-24,
		y2:	24,
		z:	0.5,
	},
	["models//cheeze/pcb/pcb7.mdl"]: {
		Name:	"pcb7.mdl",
		RS:	0.125,
		RatioX:	1,
		offset:	Vector(0, 0, 0.5),
		rot:	Angle(0, 0, 180),
		x1:	-32,
		x2:	32,
		y1:	-32,
		y2:	32,
		z:	0.5,
	},
	["models//cheeze/pcb/pcb8.mdl"]: {
		Name:	"pcb8.mdl",
		RS:	0.125,
		RatioX:	0.668,
		offset:	Vector(15.885, 0, 0.5),
		rot:	Angle(0, 0, 180),
		x1:	-47.885,
		x2:	47.885,
		y1:	-32,
		y2:	32,
		z:	0.5,
	},
	["models/cheeze/pcb2/pcb8.mdl"]: {
		Name:	"pcb8.mdl",
		RS:	0.2475,
		RatioX:	0.99,
		offset:	Vector(0, 0, 0.3),
		rot:	Angle(0, 0, 180),
		x1:	-64,
		x2:	64,
		y1:	-63.36,
		y2:	63.36,
		z:	0.3,
	},
	["models/blacknecro/tv_plasma_4_3.mdl"]: {
		Name:	"Plasma TV (4:3)",
		RS:	0.082,
		RatioX:	0.751,
		offset:	Vector(0, -0.1, 0),
		rot:	Angle(0, 0, -90),
		x1:	-27.87,
		x2:	27.87,
		y1:	-20.93,
		y2:	20.93,
		z:	0.1,
	},
	["models/hunter/blocks/cube1x1x1.mdl"]: {
		Name:	"Cube 1x1x1",
		RS:	0.09,
		RatioX:	1,
		offset:	Vector(24, 0, 0),
		rot:	Angle(0, 90, -90),
		x1:	-48,
		x2:	48,
		y1:	-48,
		y2:	48,
		z:	24,
	},
	["models/hunter/plates/plate05x05.mdl"]: {
		Name:	"Panel 0.5x0.5",
		RS:	0.045,
		RatioX:	1,
		offset:	Vector(0, 0, 1.7),
		rot:	Angle(0, 90, 180),
		x1:	-48,
		x2:	48,
		y1:	-48,
		y2:	48,
		z:	0,
	},
	["models/hunter/plates/plate1x1.mdl"]: {
		Name:	"Panel 1x1",
		RS:	0.09,
		RatioX:	1,
		offset:	Vector(0, 0, 2),
		rot:	Angle(0, 90, 180),
		x1:	-48,
		x2:	48,
		y1:	-48,
		y2:	48,
		z:	0,
	},
	["models/hunter/plates/plate2x2.mdl"]: {
		Name:	"Panel 2x2",
		RS:	0.182,
		RatioX:	1,
		offset:	Vector(0, 0, 2),
		rot:	Angle(0, 90, 180),
		x1:	-48,
		x2:	48,
		y1:	-48,
		y2:	48,
		z:	0,
	},
	["models/hunter/plates/plate4x4.mdl"]: {
		Name:	"plate4x4.mdl",
		RS:	0.3707,
		RatioX:	1,
		offset:	Vector(0, 0, 2),
		rot:	Angle(0, 90, 180),
		x1:	-94.9,
		x2:	94.9,
		y1:	-94.9,
		y2:	94.9,
		z:	1.7,
	},
	["models/hunter/plates/plate8x8.mdl"]: {
		Name:	"plate8x8.mdl",
		RS:	0.741,
		RatioX:	1,
		offset:	Vector(0, 0, 2),
		rot:	Angle(0, 90, 180),
		x1:	-189.8,
		x2:	189.8,
		y1:	-189.8,
		y2:	189.8,
		z:	1.7,
	},
	["models/hunter/plates/plate16x16.mdl"]: {
		Name:	"plate16x16.mdl",
		RS:	1.482,
		RatioX:	1,
		offset:	Vector(0, 0, 2),
		rot:	Angle(0, 90, 180),
		x1:	-379.6,
		x2:	379.6,
		y1:	-379.6,
		y2:	379.6,
		z:	1.7,
	},
	["models/hunter/plates/plate24x24.mdl"]: {
		Name:	"plate24x24.mdl",
		RS:	2.223,
		RatioX:	1,
		offset:	Vector(0, 0, 2),
		rot:	Angle(0, 90, 180),
		x1:	-569.4,
		x2:	569.4,
		y1:	-569.4,
		y2:	569.4,
		z:	1.7,
	},
	["models/hunter/plates/plate32x32.mdl"]: {
		Name:	"plate32x32.mdl",
		RS:	2.964,
		RatioX:	1,
		offset:	Vector(0, 0, 2),
		rot:	Angle(0, 90, 180),
		x1:	-759.2,
		x2:	759.2,
		y1:	-759.2,
		y2:	759.2,
		z:	1.7,
	},
	["models/kobilica/wiremonitorbig.mdl"]: {
		Name:	"Monitor Big",
		RS:	0.045,
		RatioX:	0.991,
		offset:	Vector(0.2, -0.4, 13),
		rot:	Angle(0, 0, -90),
		x1:	-11.5,
		x2:	11.6,
		y1:	1.6,
		y2:	24.5,
		z:	0.2,
	},
	["models/kobilica/wiremonitorsmall.mdl"]: {
		Name:	"Monitor Small",
		RS:	0.0175,
		RatioX:	1,
		offset:	Vector(0, -0.4, 5),
		rot:	Angle(0, 0, -90),
		x1:	-4.4,
		x2:	4.5,
		y1:	0.6,
		y2:	9.5,
		z:	0.3,
	},
	["models/props/cs_assault/billboard.mdl"]: {
		Name:	"Billboard",
		RS:	0.23,
		RatioX:	0.522,
		offset:	Vector(2, 0, 0),
		rot:	Angle(0, 90, -90),
		x1:	-110.512,
		x2:	110.512,
		y1:	-57.647,
		y2:	57.647,
		z:	1,
	},
	["models/props/cs_militia/reload_bullet_tray.mdl"]: {
		Name:	"Tray",
		RS:	0,
		RatioX:	0.6,
		offset:	Vector(0, 0, 0.8),
		rot:	Angle(0, 90, 180),
		x1:	0,
		x2:	100,
		y1:	0,
		y2:	60,
		z:	0,
	},
	["models/props/cs_office/computer_monitor.mdl"]: {
		Name:	"LCD Monitor (4:3)",
		RS:	0.031,
		RatioX:	0.767,
		offset:	Vector(3.3, 0, 16.7),
		rot:	Angle(0, 90, -90),
		x1:	-10.5,
		x2:	10.5,
		y1:	8.6,
		y2:	24.7,
		z:	3.3,
	},
	["models/props/cs_office/tv_plasma.mdl"]: {
		Name:	"Plasma TV (16:10)",
		RS:	0.065,
		RatioX:	0.5965,
		offset:	Vector(6.1, 0, 18.93),
		rot:	Angle(0, 90, -90),
		x1:	-28.5,
		x2:	28.5,
		y1:	2,
		y2:	36,
		z:	6.1,
	},
	["models/props_lab/monitor01b.mdl"]: {
		Name:	"Small TV",
		RS:	0.0185,
		RatioX:	1.0173,
		offset:	Vector(6.53, -1, 0.45),
		rot:	Angle(0, 90, -90),
		x1:	-5.535,
		x2:	3.5,
		y1:	-4.1,
		y2:	5.091,
		z:	6.53,
	},
	["models/props_lab/workspace002.mdl"]: {
		Name:	"Workspace 002",
		RS:	0.06836,
		RatioX:	0.9669,
		offset:	Vector(-42.133224, -42.372322, 42.110897),
		rot:	Angle(0, 133.340, -120.317),
		x1:	-18.1,
		x2:	18.1,
		y1:	-17.5,
		y2:	17.5,
		z:	42.1109,
	},
	["models/props_mining/billboard001.mdl"]: {
		Name:	"TF2 Red billboard",
		RS:	0.375,
		RatioX:	0.5714,
		offset:	Vector(3.5, 0, 96),
		rot:	Angle(0, 90, -90),
		x1:	-168,
		x2:	168,
		y1:	-96,
		y2:	96,
		z:	96,
	},
	["models/props_mining/billboard002.mdl"]: {
		Name:	"TF2 Red vs Blue billboard",
		RS:	0.375,
		RatioX:	0.3137,
		offset:	Vector(3.5, 0, 192),
		rot:	Angle(0, 90, -90),
		x1:	-306,
		x2:	306,
		y1:	-96,
		y2:	96,
		z:	192,
	}
}