local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------
local FOLDER       = "SkibidiHub"
local BASE         = "https://raw.githubusercontent.com/DatboyAa78/SkibidiHub-assets/main/"
local SOUND_VOLUME = 5
local RAIN_COUNT   = 30   -- how many falling pngs (lower = less lag)

-- file names are case sensitive and must match the repo exactly
-- accent = main color, accent2 = second color
local THEMES = {
    {
        name    = "Skibidi",
        image   = "skibidi.png",
        sound   = "skibidi.mp3",
        accent  = Color3.fromRGB(0, 230, 255),
        accent2 = Color3.fromRGB(170, 245, 255),
        top     = "@datboyaa",
        title   = 'Skibidi Duels <font color="rgb(0,230,255)">ON TOP</font>',
    },
    {
        name    = "Garama",
        image   = "Garama.png",
        sound   = "Garama.mp3",
        accent  = Color3.fromRGB(139, 90, 43),    -- brown
        accent2 = Color3.fromRGB(214, 178, 130),  -- light brown
        top     = "Skibidi Duels • garama theme",
        title   = "Garama and Madundung Duels",
    },
    {
        name    = "Dragon",
        image   = "Dragon.png",
        sound   = "Dragon.mp3",
        accent  = Color3.fromRGB(255, 150, 30),
        accent2 = Color3.fromRGB(255, 210, 120),
        top     = "Skibidi Duels • dragon theme",
        title   = "Dragon Duels",
    },
}

---------------------------------------------------------------------
-- DOWNLOAD + CACHE
---------------------------------------------------------------------
local function fetch(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" and #body > 0 then return body end
    local req = (syn and syn.request) or http_request or request
    if req then
        local ok2, res = pcall(req, { Url = url, Method = "GET" })
        if ok2 and res and res.StatusCode == 200 then return res.Body end
    end
end

local function looksValid(name, data)
    if name:sub(-4) == ".png" then return data:sub(2, 4) == "PNG" end
    if name:sub(-4) == ".mp3" then return data:sub(1, 3) == "ID3" or data:byte(1) == 0xFF end
    return true
end

local function ensureFile(name)
    if not (writefile and isfile) then return end
    if makefolder and isfolder and not isfolder(FOLDER) then makefolder(FOLDER) end
    local path = FOLDER .. "/" .. name
    if isfile(path) then return end
    local data = fetch(BASE .. name)
    if data and looksValid(name, data) then
        pcall(writefile, path, data)
    else
        warn("Intro: could not download a valid file for " .. name)
    end
end

local function asset(name)
    local getAsset = getcustomasset or getsynasset
    local path = FOLDER .. "/" .. name
    if getAsset and isfile and isfile(path) then
        local ok, id = pcall(getAsset, path)
        if ok then return id end
    end
end

---------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------
local root = (gethui and gethui()) or game:GetService("CoreGui")
local playing = false

local function tw(obj, t, props, style, dir)
    local tween = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    tween:Play()
    return tween
end

local function corner(obj, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = obj
end

-- visible letter count (ignores rich text tags)
local function visibleLength(text)
    local plain = text:gsub("<[^>]+>", "")
    return utf8.len(plain) or #plain
end

---------------------------------------------------------------------
-- INTRO
---------------------------------------------------------------------
local function playIntro(theme, onDone)
    if playing then return end
    playing = true

    ensureFile(theme.image)
    ensureFile(theme.sound)
    local imageId, soundId = asset(theme.image), asset(theme.sound)

    local old = root:FindFirstChild("ThemeIntro")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "ThemeIntro"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 1000
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = root

    local ACCENT  = theme.accent
    local ACCENT2 = theme.accent2

    -- animated gradient backdrop
    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.new(1, 1, 1)
    bg.BackgroundTransparency = 1
    bg.BorderSizePixel = 0
    bg.ZIndex = 1
    bg.Parent = gui
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new(Color3.fromRGB(8, 8, 10), ACCENT:Lerp(Color3.new(0, 0, 0), 0.7))
    grad.Rotation = 45
    grad.Parent = bg
    tw(bg, 0.35, { BackgroundTransparency = 0.08 })

    ---------------------------------------------------------------
    -- RAIN LAYER (falling pngs, behind everything else)
    ---------------------------------------------------------------
    local rain = Instance.new("CanvasGroup") -- CanvasGroup so the whole rain fades at once
    rain.Size = UDim2.fromScale(1, 1)
    rain.BackgroundTransparency = 1
    rain.BorderSizePixel = 0
    rain.ZIndex = 2
    rain.GroupTransparency = 1
    rain.Parent = gui

    local drops = {}
    local rainSpeedMul = 1

    local function resetDrop(d, initial)
        local screen = rain.AbsoluteSize
        local depth = 0.3 + math.random() * 0.7           -- 0.3 far, 1 close
        d.depth = depth
        d.size  = 22 + depth * 52
        d.speed = 90 + depth * 270
        d.spin  = math.random(-60, 60)
        d.sway  = math.random(8, 28)
        d.phase = math.random() * 6.28
        d.x     = math.random() * screen.X
        d.y     = initial and (math.random() * screen.Y) or (-d.size - math.random(0, 120))
        d.rot   = math.random(0, 360)
        d.label.Size = UDim2.fromOffset(d.size, d.size)
        d.label.ImageTransparency = 0.82 - depth * 0.42   -- far = faint, close = brighter
        d.label.ZIndex = 1 + math.floor(depth * 3)
    end

    if imageId then
        for i = 1, RAIN_COUNT do
            local l = Instance.new("ImageLabel")
            l.AnchorPoint = Vector2.new(0.5, 0.5)
            l.BackgroundTransparency = 1
            l.ScaleType = Enum.ScaleType.Fit
            l.Image = imageId
            l.Parent = rain
            local d = { label = l }
            resetDrop(d, true)
            drops[i] = d
        end
        tw(rain, 0.6, { GroupTransparency = 0 })
    end

    local rainConn = RunService.RenderStepped:Connect(function(dt)
        dt = math.min(dt, 0.05)
        local screenY = rain.AbsoluteSize.Y
        local now = os.clock()
        for _, d in ipairs(drops) do
            d.y += d.speed * rainSpeedMul * dt
            d.rot += d.spin * dt
            if d.y - d.size > screenY then resetDrop(d, false) end
            d.label.Position = UDim2.fromOffset(d.x + math.sin(now * 1.5 + d.phase) * d.sway, d.y)
            d.label.Rotation = d.rot
        end
    end)

    -- effects layer (rings + particles), above the rain, behind the stage
    local fx = Instance.new("Frame")
    fx.Size = UDim2.fromScale(1, 1)
    fx.BackgroundTransparency = 1
    fx.BorderSizePixel = 0
    fx.ZIndex = 3
    fx.Parent = gui

    -- flash layer (top)
    local flash = Instance.new("Frame")
    flash.Size = UDim2.fromScale(1, 1)
    flash.BackgroundColor3 = ACCENT2:Lerp(Color3.new(1, 1, 1), 0.6)
    flash.BackgroundTransparency = 1
    flash.BorderSizePixel = 0
    flash.ZIndex = 20
    flash.Parent = gui

    local W, H = 240, 240
    local LOGO_Y = 40 + H / 2
    local CENTER_Y = -15 -- logo center relative to screen center (stage is 350 tall)

    local stage = Instance.new("CanvasGroup")
    stage.AnchorPoint = Vector2.new(0.5, 0.5)
    stage.Position = UDim2.new(-0.3, 0, 0.5, 0)
    stage.Size = UDim2.fromOffset(380, 350)
    stage.BackgroundTransparency = 1
    stage.BorderSizePixel = 0
    stage.ZIndex = 5
    stage.Parent = gui
    local stageScale = Instance.new("UIScale")
    stageScale.Parent = stage

    -- glow circle behind the image
    local glow = Instance.new("Frame")
    glow.AnchorPoint = Vector2.new(0.5, 0.5)
    glow.Position = UDim2.new(0.5, 0, 0, LOGO_Y)
    glow.Size = UDim2.fromOffset(300, 300)
    glow.BackgroundColor3 = ACCENT2
    glow.BackgroundTransparency = 0.85
    glow.BorderSizePixel = 0
    glow.ZIndex = 1
    glow.Parent = stage
    local glowCorner = Instance.new("UICorner")
    glowCorner.CornerRadius = UDim.new(0.5, 0)
    glowCorner.Parent = glow

    -- top text (types out), uses the light color so it reads on dark
    local top = Instance.new("TextLabel")
    top.Size = UDim2.new(1, 0, 0, 30)
    top.BackgroundTransparency = 1
    top.RichText = true
    top.Text = theme.top
    top.MaxVisibleGraphemes = 0
    top.Font = Enum.Font.GothamBold
    top.TextSize = 22
    top.TextColor3 = ACCENT2
    top.ZIndex = 4
    top.Parent = stage

    -- image + RGB-split ghosts (theme colors)
    local function makeLogo(color, transp, z)
        local l = Instance.new("ImageLabel")
        l.AnchorPoint = Vector2.new(0.5, 0.5)
        l.Position = UDim2.new(0.5, 0, 0, LOGO_Y)
        l.Size = UDim2.fromOffset(W, H)
        l.BackgroundTransparency = 1
        l.ScaleType = Enum.ScaleType.Fit
        l.Image = imageId or ""
        l.ImageColor3 = color
        l.ImageTransparency = transp
        l.ZIndex = z
        l.Parent = stage
        return l
    end
    local ghostR = makeLogo(ACCENT,  1, 2)
    local ghostC = makeLogo(ACCENT2, 1, 2)
    local logo   = makeLogo(Color3.new(1, 1, 1), 0, 3)
    local logoScale = Instance.new("UIScale") -- used for the talking bounce
    logoScale.Parent = logo

    -- bottom text (types out)
    local title = Instance.new("TextLabel")
    title.Position = UDim2.fromOffset(0, 40 + H + 10)
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.RichText = true
    title.Text = theme.title
    title.MaxVisibleGraphemes = 0
    title.Font = Enum.Font.GothamBold
    title.TextSize = 22
    title.TextColor3 = Color3.new(1, 1, 1)
    title.ZIndex = 4
    title.Parent = stage

    -- loading bar (main color -> second color)
    local barBg = Instance.new("Frame")
    barBg.AnchorPoint = Vector2.new(0.5, 0)
    barBg.Position = UDim2.new(0.5, 0, 0, 40 + H + 52)
    barBg.Size = UDim2.fromOffset(240, 8)
    barBg.BackgroundColor3 = Color3.fromRGB(40, 36, 34)
    barBg.BorderSizePixel = 0
    barBg.ZIndex = 4
    barBg.Parent = stage
    corner(barBg, 4)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.new(1, 1, 1)
    fill.BorderSizePixel = 0
    fill.ZIndex = 5
    fill.Parent = barBg
    corner(fill, 4)
    local fillGrad = Instance.new("UIGradient")
    fillGrad.Color = ColorSequence.new(ACCENT, ACCENT2)
    fillGrad.Parent = fill

    ---------------------------------------------------------------
    -- EFFECT SPAWNERS
    ---------------------------------------------------------------
    local function spawnRing(startSize, endSize, thick, dur)
        local ring = Instance.new("Frame")
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.Position = UDim2.new(0.5, 0, 0.5, CENTER_Y)
        ring.Size = UDim2.fromOffset(startSize, startSize)
        ring.BackgroundTransparency = 1
        ring.BorderSizePixel = 0
        ring.Parent = fx
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0.5, 0)
        rc.Parent = ring
        local st = Instance.new("UIStroke")
        st.Color = (math.random() < 0.5) and ACCENT or ACCENT2
        st.Thickness = thick
        st.Parent = ring
        tw(ring, dur, { Size = UDim2.fromOffset(endSize, endSize) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        tw(st, dur, { Transparency = 1, Thickness = 0 })
        task.delay(dur + 0.05, function() ring:Destroy() end)
    end

    local function spawnBurst(count, minDist, maxDist)
        for _ = 1, count do
            local p = Instance.new("Frame")
            local s = math.random(5, 11)
            local r = math.random()
            p.AnchorPoint = Vector2.new(0.5, 0.5)
            p.Position = UDim2.new(0.5, 0, 0.5, CENTER_Y)
            p.Size = UDim2.fromOffset(s, s)
            p.BackgroundColor3 = (r < 0.4) and ACCENT or ((r < 0.8) and ACCENT2 or Color3.new(1, 1, 1))
            p.BorderSizePixel = 0
            p.Rotation = math.random(0, 360)
            p.Parent = fx
            local ang  = math.random() * math.pi * 2
            local dist = minDist + math.random() * (maxDist - minDist)
            local dur  = 0.6 + math.random() * 0.5
            tw(p, dur, {
                Position = UDim2.new(0.5, math.cos(ang) * dist, 0.5, CENTER_Y + math.sin(ang) * dist),
                Size = UDim2.fromOffset(0, 0),
                BackgroundTransparency = 1,
                Rotation = p.Rotation + math.random(-240, 240),
            }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            task.delay(dur + 0.05, function() p:Destroy() end)
        end
    end

    ---------------------------------------------------------------
    -- 1) SLIDE IN
    ---------------------------------------------------------------
    tw(stage, 0.7, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out).Completed:Wait()
    spawnRing(80, 420, 4, 0.6)

    ---------------------------------------------------------------
    -- 2) SOUND + REACTIVE SHAKE (stops when the mp3 ends)
    ---------------------------------------------------------------
    local len = 2.5
    local sound
    local ended = false
    if soundId then
        sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = SOUND_VOLUME
        sound.Looped = false
        sound.Parent = gui
        local waited = 0
        while not sound.IsLoaded and waited < 2 do
            task.wait(0.05)
            waited += 0.05
        end
        if sound.TimeLength > 0 then len = math.clamp(sound.TimeLength, 1.5, 12) end
        sound.Ended:Connect(function() ended = true end)
        sound:Play()
    else
        task.delay(len, function() ended = true end)
    end

    tw(fill, len, { Size = UDim2.new(1, 0, 1, 0) }, Enum.EasingStyle.Linear)
    tw(ghostR, 0.25, { ImageTransparency = 0.55 })
    tw(ghostC, 0.25, { ImageTransparency = 0.55 })

    -- talking: type each letter and bounce the image on every letter
    local typing = true
    task.spawn(function()
        local total = visibleLength(theme.top) + visibleLength(theme.title)
        local delay = math.clamp((len * 0.85) / total, 0.03, 0.12)
        for _, label in ipairs({ top, title }) do
            local n = visibleLength(label.Text)
            for i = 1, n do
                if not typing then return end
                label.MaxVisibleGraphemes = i
                logoScale.Scale = 1.07
                tw(logoScale, delay * 0.9, { Scale = 1 })
                task.wait(delay)
            end
            label.MaxVisibleGraphemes = -1
            task.wait(0.1)
        end
    end)

    local function place(dx, dy, rot, s, sep)
        local sz = UDim2.fromOffset(W * s, H * s)
        logo.Position   = UDim2.new(0.5, dx, 0, LOGO_Y + dy)
        ghostR.Position = UDim2.new(0.5, dx - sep, 0, LOGO_Y + dy)
        ghostC.Position = UDim2.new(0.5, dx + sep, 0, LOGO_Y + dy)
        logo.Size, ghostR.Size, ghostC.Size = sz, sz, sz
        logo.Rotation, ghostR.Rotation, ghostC.Rotation = rot, rot, rot
    end

    local state = "shake"
    local t0 = os.clock()
    local slamStart = 0
    local peak, norm, lastBeat = 1, 0, 0

    local conn = RunService.RenderStepped:Connect(function()
        local now = os.clock()
        local t = now - t0

        if state == "shake" then
            if sound and sound.IsPlaying then
                local l = sound.PlaybackLoudness
                peak = math.max(peak * 0.998, l, 1)
                norm = math.clamp(l / peak, 0, 1)
            else
                norm = 0.35 + 0.3 * math.abs(math.sin(t * 18))
            end
            local intensity = 2 + 13 * norm
            place(
                (math.random() * 2 - 1) * intensity,
                (math.random() * 2 - 1) * intensity,
                (math.random() * 2 - 1) * intensity * 0.5,
                1 + 0.09 * norm,
                intensity * 0.9
            )
            local g = 290 + 80 * norm
            glow.Size = UDim2.fromOffset(g, g)
            glow.BackgroundTransparency = 0.88 - 0.2 * norm

            -- rain speeds up on loud hits
            rainSpeedMul = 1 + 1.8 * norm

            -- beat: rings + a few sparks
            if norm > 0.78 and t - lastBeat > 0.22 then
                lastBeat = t
                spawnRing(120, 360, 3, 0.45)
                spawnBurst(5, 90, 200)
            end

        elseif state == "slam" then
            local p = math.clamp((now - slamStart) / 0.45, 0, 1)
            local s = 1 + 0.35 * (1 - p) ^ 3
            place(0, 0, 0, s, 0)
            rainSpeedMul = 1 + 3 * (1 - p)   -- rain surges on the slam then calms
            if p >= 1 then state = "float" end

        elseif state == "float" then
            place(0, math.sin(t * 3) * 4, math.sin(t * 2) * 1.5, 1, 0)
            local g = 300 + math.sin(t * 4) * 18
            glow.Size = UDim2.fromOffset(g, g)
            rainSpeedMul = 1
        end

        grad.Rotation = 45 + t * 35
    end)

    -- wait until the mp3 is actually finished
    repeat
        task.wait()
        if sound and sound.TimeLength > 0 and sound.TimePosition >= sound.TimeLength - 0.05 then
            ended = true
        end
    until ended or (os.clock() - t0) > len + 1.5

    ---------------------------------------------------------------
    -- 3) FINALE: freeze + slam + flash + shockwave
    ---------------------------------------------------------------
    typing = false
    top.MaxVisibleGraphemes, title.MaxVisibleGraphemes = -1, -1
    tw(fill, 0.15, { Size = UDim2.new(1, 0, 1, 0) })
    tw(ghostR, 0.3, { ImageTransparency = 1 })
    tw(ghostC, 0.3, { ImageTransparency = 1 })
    tw(glow, 0.4, { BackgroundTransparency = 0.8 })

    slamStart = os.clock()
    state = "slam"

    flash.BackgroundTransparency = 0.15
    tw(flash, 0.45, { BackgroundTransparency = 1 })
    spawnRing(100, 900, 7, 0.8)
    spawnRing(60, 560, 4, 0.65)
    spawnBurst(40, 160, 460)

    task.wait(1.1) -- hold on the finished pose (floating)

    ---------------------------------------------------------------
    -- 4) ZOOM OUT + FADE
    ---------------------------------------------------------------
    tw(stageScale, 0.7, { Scale = 3.2 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    tw(stage, 0.7, { GroupTransparency = 1 })
    tw(rain, 0.7, { GroupTransparency = 1 })
    tw(bg, 0.7, { BackgroundTransparency = 1 }).Completed:Wait()

    conn:Disconnect()
    rainConn:Disconnect()
    if sound then sound:Destroy() end
    gui:Destroy()
    playing = false
    if onDone then onDone() end
end

---------------------------------------------------------------------
-- PUBLIC API  (your main script calls SkibidiIntro.Play("Garama"))
---------------------------------------------------------------------
local env = (getgenv and getgenv()) or _G
env.SkibidiIntro = {
    Play = function(name)
        if playing then return end
        for _, theme in ipairs(THEMES) do
            if theme.name:lower() == tostring(name):lower() then
                task.spawn(playIntro, theme)
                return
            end
        end
        warn("SkibidiIntro: no theme named " .. tostring(name))
    end,
}
