local BLACK  = {0, 0, 0, 1}
local WHITE  = {1, 1, 1, 1}
local RED    = {1, 0, 0, 1}
local YELLOW = {1, 1, 0, 1}

love.graphics.setDefaultFilter("nearest", "nearest")

local font = love.graphics.newImageFont("assets/font.png",
    " abcdefghijklmnopqrstuvwxyz" ..
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ0" ..
    "123456789.,!?-+/():;%&`'*#=[]\"")
love.graphics.setFont(font)

local hand = love.mouse.newCursor("assets/hand.png")
local handdown = love.mouse.newCursor("assets/handdown.png")
love.mouse.setCursor(hand)

-- possible values for screen are: "menu", "game", "over"
-- and "credits"
local screen = "menu"

local dt = 0

local dbg = false
local dbgcolor = RED

local camx = 0
-- calling gameover() change screen to "over", but we want
-- to render a last frame before changing screens, so we use
-- this variable to delay the screen change in the game loop
local isover = false

local score = 0
local highscore = 0

-- since we using immediate ui for drawing text/buttons
-- this became necessary for simulating a single mouse
-- button press, otherwise click callbacks would be
-- fired in every frame
local allowclick = true

local gamevel = 75
local gamescale = 2

-- used to hide the top score in the "over" screen
local showtopscore = false

local gravity = 300
local world = love.physics.newWorld(0, gravity)

local birdsize = 16
local jumpforce = -gravity*0.5

local birdbody = love.physics.newBody(world, 0, 0, "dynamic")
birdbody:setFixedRotation(true)

local birdshape = love.physics.newCircleShape(birdsize*0.8)

local birdfixture = love.physics.newFixture(birdbody, birdshape)
birdfixture:setCategory(1)

local birdrotation = 0.0
local birdrotationt = 0.0

local birdimg = love.graphics.newImage("assets/bird.png")

local birdsprites = {
    love.graphics.newQuad(0, 0,
        birdsize, birdsize, birdimg:getDimensions()),
    love.graphics.newQuad(16, 0,
        birdsize, birdsize, birdimg:getDimensions()),
    love.graphics.newQuad(32, 0,
        birdsize, birdsize, birdimg:getDimensions()),
    love.graphics.newQuad(48, 0,
        birdsize, birdsize, birdimg:getDimensions()),
}

local birdspritet = 0.0

local bgmorning = love.graphics.newImage(
    "assets/morning.png")
local bgnoon = love.graphics.newImage(
    "assets/noon.png")
local bgevening = love.graphics.newImage(
    "assets/evening.png")
local bgnight = love.graphics.newImage(
    "assets/night.png")
local bgmidnight = love.graphics.newImage(
    "assets/midnight.png")

function getbackground()
    local hour = os.date("%H")
    hour = tonumber(hour)
    if hour < 6 then
        return bgmidnight
    end
    if hour < 14 then
        return bgmorning
    end
    if hour < 18 then
        return bgnoon
    end
    if hour < 25 then
        return bgnight
    end
    error("invalid background")
end

local bg = getbackground()

local bgupdate = 300
local bgupdatet = 0

local bgscale = love.graphics.getHeight() / bg:getHeight()
local bgscaled = bg:getWidth() * bgscale

local tiles = love.graphics.newImage("assets/tiles.png")

local tubes = {}

-- tubes are glued together to make them bigger,
-- this variable tells how many tiles we glue together
local tubetiles = 12
local tubetileh = 20 -- tube tile height in pixels

local tubewidth = 32
local tubeheight = tubetileh*tubetiles

local tubedist = 128 -- distance/space between spawned tubes

local tubeshape = love.physics.newRectangleShape(
    tubewidth*gamescale, tubeheight*gamescale)

local toptubeq = love.graphics.newQuad(0,  0, 32, tubetileh,
    tiles:getDimensions())
local midtubeq = love.graphics.newQuad(0, 20, 32, tubetileh,
    tiles:getDimensions())
local bottubeq = love.graphics.newQuad(0, 60, 32, tubetileh,
    tiles:getDimensions())

local tubecanvas = love.graphics.newCanvas(tubewidth, tubeheight)
tubecanvas:renderTo(function()
    local y = 0
    love.graphics.draw(tiles, toptubeq, 0, y)
    for i = 1, tubetiles - 2 do
        y = y + tubetileh
        love.graphics.draw(tiles, midtubeq, 0, y)
    end
    y = y + tubetileh
    love.graphics.draw(tiles, bottubeq, 0, y)
end)

local spawnt = 0.0
local spawntime = 4 -- time in seconds between tube spawn

local hitsound = love.audio.newSource("assets/hit.ogg", "static")
hitsound:setVolume(0.1)

local wingsound = love.audio.newSource("assets/wing.ogg", "static")
wingsound:setVolume(0.3)

function easyincubic(x)
    return x*x*x
end

function clamp(value, min, max)
    return math.max(math.min(value, max), min)
end

-- checks wheter x, y are inside an rectangle
-- represented by rx, ry, rw, rh
function inside(x, y, rx, ry, rw, rh)
    return
        x >= rx and x <= rx + rw and
        y >= ry and y <= ry + rh
end

function startgame()
    screen = "game"
    birdbody:setPosition(
        love.graphics.getWidth()*0.5,
        love.graphics.getHeight()*0.5)
    birdbody:setLinearVelocity(0, gravity)
    birdfixture:setCategory(1) -- make bird collides with tubes
    -- destroy all tubes
    for key, tube in pairs(tubes) do
        tube:destroy()
        tubes[key] = nil
    end
    camx = 0.0
    score = 0.0
    spawnt = 4.0
    showtopscore = true
    birdjump()
end

function backmenu()
    camx = 0.0
    screen = "menu"
    birdrotation = 0.0
    allowclick = false
end

function showcredits()
    screen = "credits"
end

function updatebackground(dt)
    bgupdatet = bgupdatet + dt
    if bgupdatet > bgupdate then
        bgupdatet = 0
        bg = getbackground()
    end
end

function spawntube()
    local x = love.graphics.getWidth()*0.5 + camx
    local y = 0

    local minp = love.graphics.getHeight()*0.2
    local maxp = love.graphics.getHeight()*0.8
    local ypoint = love.math.random(minp, maxp)

    x = x + love.graphics.getWidth()/2 * 1.25
    y = ypoint + tubeheight + tubedist/2
    local downtube = love.physics.newBody(world, x, y, "static")
    local tfixture = love.physics.newFixture(downtube, tubeshape)
    tfixture:setMask(2)
    table.insert(tubes, downtube)

    y = ypoint - tubeheight - tubedist/2
    local toptube = love.physics.newBody(world, x, y, "static")
    local tfixture = love.physics.newFixture(toptube, tubeshape)
    tfixture:setMask(2)
    table.insert(tubes, toptube)

    -- clean tubes that are out the screen, not
    -- actually necessary, I doubt someone would
    -- play this game for soo long that the tubes
    -- would be a problem for today computer's memory
    for key, tube in pairs(tubes) do
        if tube:getX() + tubewidth*0.5 < -camx then
            tube:destroy()
            tubes[key] = nil
        end
    end
end

function birdjump()
    birdspritet = 0.0
    birdrotation = 1.7*math.pi
    birdrotationt = 0.0
    birdbody:setLinearVelocity(0, jumpforce)
    wingsound:play()
end

function gameover()
    screen = "over"
    birdbody:applyLinearImpulse(0, jumpforce*0.5)
    birdfixture:setCategory(2) -- make bird NOT collide with tubes
    if score > highscore then
        highscore = score
    end
    hitsound:play()
end

function drawtext(t)
    local x = t.x or 0
    local y = t.y or 0
    local text = t.text or ""
    local scale = t.scale or 1
    local width = font:getWidth(text) * scale
    local height = font:getHeight() * scale
    local origin = t.origin or "topleft"
    local onclick = t.onclick or nil
    local color = t.color or WHITE
    local onhovercolor = t.onhovercolor or WHITE

    if origin == "center" then
        x = x - width*0.5
        y = y - height*0.5
    elseif origin == "botright" then
        x = x - width
        y = y - height
    end

    local mx, my = love.mouse.getPosition()
    if inside(mx, my, x, y, width, height) then
        color = onhovercolor
        if love.mouse.isDown(1) and onclick ~= nil and allowclick then
            onclick()
            allowclick = false
        end
    end

    love.graphics.setColor(color)
    love.graphics.print(text, x, y, 0, scale)
end

function drawmenu()
    love.graphics.translate(camx, 0)

    drawtext {
        text = "LUA BIRD",
        scale = 4,
        x = love.graphics.getWidth()*0.5,
        y = love.graphics.getHeight()*0.25,
        origin = "center",
    }

    drawtext {
        text = string.format("high score: %dm", highscore),
        scale = 2,
        x = love.graphics.getWidth()*0.5,
        y = love.graphics.getHeight()*0.35,
        origin = "center",
    }

    drawtext {
        text = "PLAY",
        scale = 3,
        x = love.graphics.getWidth()*0.5,
        y = love.graphics.getHeight()*0.65,
        origin = "center",
        onclick = startgame,
        onhovercolor = YELLOW,
    }

    drawtext {
        text = "CREDITS",
        scale = 3,
        x = love.graphics.getWidth()*0.5,
        y = love.graphics.getHeight()*0.75,
        origin = "center",
        onclick = showcredits,
        onhovercolor = YELLOW,
    }

    drawtext {
        text = "QUIT",
        scale = 3,
        x = love.graphics.getWidth()*0.5,
        y = love.graphics.getHeight()*0.85,
        origin = "center",
        onclick = love.event.quit,
        onhovercolor = YELLOW,
    }

    -- keep the bird at the same place, going
    -- against the world's gravity
    birdbody:setPosition(
        love.graphics.getWidth()*0.5,
        love.graphics.getHeight()*0.5)

    drawbird()
end

function drawbird()
    local x = birdbody:getX()
    local y = birdbody:getY()

    if screen == "game" then
        local t = easyincubic(birdrotationt)
        birdrotation = ((2.4 - 1.7)*t + 1.7)*math.pi
    elseif screen == "over" then
        birdrotation = birdrotation + 10 * dt
    end

    local sprite = math.floor((#birdsprites - 1)*birdspritet) + 1

    love.graphics.setColor(WHITE)
    love.graphics.draw(birdimg,
        birdsprites[sprite],
        x, y, birdrotation,
        gamescale, gamescale,
        birdsize/2, birdsize/2)
end

function drawtube(tube)
    love.graphics.setColor(WHITE)

    local x = tube:getX()
    local y = tube:getY()

    love.graphics.draw(
        tubecanvas, x, y, 0,
        gamescale, gamescale,
        tubewidth*0.5, tubeheight*0.5)

    if dbg then
        love.graphics.setColor(dbgcolor)
        love.graphics.polygon("line",
            tube:getWorldPoints(tubeshape:getPoints()))
    end
end

function updategame()
    camx = camx + gamevel * dt

    local _, birdyv = birdbody:getLinearVelocity()
    birdbody:setLinearVelocity(gamevel, birdyv)

    spawnt = spawnt + dt
    if spawnt > spawntime then
        spawntube()
        spawnt = 0.0
    end

    birdspritet = clamp(birdspritet + 3 * dt, 0.0, 1.0)
    birdrotationt = clamp(birdrotationt + dt, 0.0, 1.0)

    score = (birdbody:getX() - love.graphics.getWidth()*0.5)
    score = score/love.physics.getMeter()

    local contacts = world:getContacts()
    for _, contact in ipairs(contacts) do
        if contact:isTouching() then
            isover = true
        end
    end

    local _, birdy = birdbody:getPosition()
    if birdy >= love.graphics.getHeight() then
        isover = true
    end
end

function drawgame()
    for _, tube in ipairs(tubes) do
        drawtube(tube)
    end

    drawbird()

    if dbg then
        love.graphics.setColor(dbgcolor)
        love.graphics.circle("line",
            birdbody:getX(),
            birdbody:getY(),
            birdshape:getRadius())
    end

    love.graphics.translate(camx, 0)

    if showtopscore == true then
        drawtext {
            scale = 3,
            text = string.format("%dm", score),
            x = love.graphics.getWidth()*0.5,
            y = love.graphics.getHeight()*0.1,
            origin = "center",
        }
    end
end

function updateover()
    camx = camx + gamevel * dt

    spawnt = spawnt + dt
    if spawnt > spawntime then
        spawntube()
        spawnt = 0.0
    end

    local _, birdyv = birdbody:getLinearVelocity()
    birdbody:setLinearVelocity(gamevel, birdyv)
end

function drawover()
    showtopscore = false

    drawgame()

    drawtext {
        x = love.graphics.getWidth()*0.5,
        y = love.graphics.getHeight()*0.5,
        text = string.format("score: %dm", score),
        scale = 3,
        origin = "center",
    }
end

function drawcredits()
    drawtext {
        scale = 2,
        text = "Art by:\n* MegaCrash",
        x = love.graphics.getWidth()*0.2,
        y = love.graphics.getHeight()*0.15,
    }

    drawtext {
        scale = 2,
        text = "Cursor by:\n* AspecsGaming",
        x = love.graphics.getWidth()*0.2,
        y = love.graphics.getHeight()*0.30,
    }

    drawtext {
        scale = 2,
        text = "Sounds by:\n* SamuelCust",
        x = love.graphics.getWidth()*0.2,
        y = love.graphics.getHeight()*0.45,
    }

    drawtext {
        scale = 2,
        text = "Game by:\n* Johnathan",
        x = love.graphics.getWidth()*0.2,
        y = love.graphics.getHeight()*0.60,
    }

    drawtext {
        text = "MENU",
        scale = 3,
        x = love.graphics.getWidth()*0.5,
        y = love.graphics.getHeight()*0.85,
        origin = "center",
        onclick = backmenu,
        onhovercolor = YELLOW,
    }
end

function love.run()
    for _, a in ipairs(arg) do
        if a == "debug" then
            dbg = true
        end
    end
    return function()
        dt = love.timer.step()

        love.event.pump()
        for event, a, b, c, d, e, f in love.event.poll() do
            if event == "quit" then
                return 0
            elseif event == "keypressed" then
                if a == "escape" then
                    return 0
                end
                if a == "space" then
                    if screen == "menu" then
                        startgame()
                    elseif screen == "game" then
                        birdjump()
                    elseif screen == "over" then
                        backmenu()
                    end
                end
            elseif event == "mousepressed" then
                if screen == "game" and c == 1 then
                    birdjump()
                end
                if screen == "over" and c == 1 then
                    backmenu()
                end
                love.mouse.setCursor(handdown)
            elseif event == "mousereleased" then
                if c == 1 then
                    allowclick = true
                end
                love.mouse.setCursor(hand)
            end
        end

        if screen == "game" then
            updategame()
        elseif screen == "over" then
            updateover()
        end
        world:update(dt)

        love.graphics.push("all")
        love.graphics.clear(BLACK)
        -- translate used here to allow background
        -- move as well
        love.graphics.translate(-camx, 0)

        -- draw infinite background, basically draw
        -- two images in a row, and position them
        -- in a way that seems like endless
        for i = 0, 1 do
            local o = math.floor(camx / bgscaled)
            local x = bgscaled * o + bgscaled * i

            love.graphics.setColor(WHITE)
            love.graphics.draw(bg, x, 0, 0, bgscale)
        end

        updatebackground(dt)

        if screen == "menu" then
            drawmenu()
        elseif screen == "game" then
            drawgame()
        elseif screen == "over" then
            drawover()
        elseif screen == "credits" then
            drawcredits()
        else
            assert(false, "draw screen missing")
        end

        love.graphics.present()
        love.graphics.pop("all")

        if isover then
            gameover()
            isover = false
        end
    end
end
