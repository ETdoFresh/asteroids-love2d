-- Asteroids Game
-- A classic Asteroids game built with Love2D
-- Run directly: love .
-- Supports hot-reload via getState() and reload() functions

-- Game module
local game = {}

-- Constants
local SHIP_ACCEL = 300
local SHIP_FRICTION = 0.98
local SHIP_ROTATE_SPEED = 5
local SHIP_SIZE = 12
local BULLET_SPEED = 500
local BULLET_LIFETIME = 1.5
local FIRE_RATE = 0.15
local MAX_BULLETS = 20
local ASTEROID_SPEED_MIN = 30
local ASTEROID_SPEED_MAX = 80
local ASTEROID_SIZES = {large = 40, medium = 20, small = 10}
local ASTEROID_SCORES = {large = 20, medium = 50, small = 100}
local ASTEROID_CHILDREN = {large = "medium", medium = "small", small = nil}
local INITIAL_ASTEROIDS = 4
local INVULN_TIME = 3
local RESPAWN_DELAY = 1.5
local HYPERSPACE_COOLDOWN = 3
local THRUST_PARTICLE_RATE = 30

local COLORS = {
    background = {0.02, 0.02, 0.06, 1},
    ship = {0.9, 0.9, 0.95, 1},
    ship_thrust = {1.0, 0.5, 0.2, 1},
    bullet = {1, 1, 0.8, 1},
    asteroid = {0.7, 0.65, 0.6, 1},
    text = {1, 1, 1, 1},
    menu_bg = {0, 0, 0, 0.7},
    menu_selected = {0.4, 0.8, 0.4, 1},
    hud = {0.8, 0.8, 0.85, 1},
}

-- Game state
local state = nil

-- Helper: check if a gamepad button is held on any connected gamepad
local function isGamepadDown(button)
    local joysticks = love.joystick.getJoysticks()
    for _, js in ipairs(joysticks) do
        if js:isGamepad() and js:isGamepadDown(button) then
            return true
        end
    end
    return false
end

-- Helper: check if a gamepad trigger axis is pressed (triggers are axes, not buttons)
local function isGamepadTriggerDown(trigger)
    local joysticks = love.joystick.getJoysticks()
    for _, js in ipairs(joysticks) do
        if js:isGamepad() and js:getGamepadAxis(trigger) > 0.5 then
            return true
        end
    end
    return false
end

-- Helper: deep copy
local function deepCopy(orig)
    if type(orig) ~= 'table' then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = deepCopy(v)
    end
    return copy
end

-- Helper: wrap position around screen
local function wrap(x, y, w, h)
    if x < 0 then x = x + w end
    if x > w then x = x - w end
    if y < 0 then y = y + h end
    if y > h then y = y - h end
    return x, y
end

-- Helper: distance between two points
local function dist(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

-- Helper: distance with wrapping
local function wrapDist(x1, y1, x2, y2, w, h)
    local dx = math.abs(x1 - x2)
    local dy = math.abs(y1 - y2)
    if dx > w / 2 then dx = w - dx end
    if dy > h / 2 then dy = h - dy end
    return math.sqrt(dx * dx + dy * dy)
end

-- Generate a random jagged asteroid shape
local function generateAsteroidShape(size)
    local verts = {}
    local numVerts = love.math.random(8, 12)
    for i = 1, numVerts do
        local angle = (i - 1) / numVerts * math.pi * 2
        local r = size * (0.7 + love.math.random() * 0.3)
        table.insert(verts, {angle = angle, r = r})
    end
    return verts
end

-- Create an asteroid
local function createAsteroid(x, y, sizeType, w, h)
    local speed = love.math.random() * (ASTEROID_SPEED_MAX - ASTEROID_SPEED_MIN) + ASTEROID_SPEED_MIN
    local angle = love.math.random() * math.pi * 2
    return {
        x = x,
        y = y,
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed,
        size = sizeType,
        radius = ASTEROID_SIZES[sizeType],
        shape = generateAsteroidShape(ASTEROID_SIZES[sizeType]),
        rotAngle = love.math.random() * math.pi * 2,
        rotSpeed = (love.math.random() - 0.5) * 2,
    }
end

-- Spawn initial asteroids away from center
local function spawnAsteroids(count, w, h)
    local asteroids = {}
    for i = 1, count do
        local x, y
        repeat
            x = love.math.random() * w
            y = love.math.random() * h
        until dist(x, y, w / 2, h / 2) > 150
        table.insert(asteroids, createAsteroid(x, y, "large", w, h))
    end
    return asteroids
end

-- Create particles for explosion
local function createExplosion(x, y, count, speed, lifetime)
    local particles = {}
    for i = 1, count do
        local angle = love.math.random() * math.pi * 2
        local spd = love.math.random() * speed
        table.insert(particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * spd,
            vy = math.sin(angle) * spd,
            life = lifetime * (0.5 + love.math.random() * 0.5),
            maxLife = lifetime,
            size = love.math.random() * 2 + 1,
        })
    end
    return particles
end

-- Initialize game state
local function initGame()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    state = {
        ship = {
            x = w / 2,
            y = h / 2,
            vx = 0,
            vy = 0,
            angle = -math.pi / 2,
            alive = true,
            invulnerable = true,
            invulnTimer = INVULN_TIME,
            respawnTimer = 0,
            thrusting = false,
        },
        bullets = {},
        asteroids = spawnAsteroids(INITIAL_ASTEROIDS, w, h),
        particles = {},
        thrustParticles = {},
        score = 0,
        highScore = 0,
        lives = 3,
        level = 1,
        fireTimer = 0,
        hyperspaceTimer = 0,
        screen = "menu",
        menuSelection = 1,
        pauseSelection = 1,
        gameOver = false,
        levelClearTimer = 0,
        leftTriggerWasDown = false,
        stars = {},
    }
    -- Generate background stars
    for i = 1, 100 do
        table.insert(state.stars, {
            x = love.math.random() * w,
            y = love.math.random() * h,
            brightness = love.math.random() * 0.5 + 0.1,
            size = love.math.random() < 0.3 and 2 or 1,
        })
    end
end

local function restartGame()
    local highScore = state.highScore
    local stars = state.stars
    initGame()
    state.highScore = highScore
    state.stars = stars
    state.screen = "playing"
end

local function startNextLevel()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    state.level = state.level + 1
    state.asteroids = spawnAsteroids(INITIAL_ASTEROIDS + state.level - 1, w, h)
    state.bullets = {}
    state.ship.x = w / 2
    state.ship.y = h / 2
    state.ship.vx = 0
    state.ship.vy = 0
    state.ship.angle = -math.pi / 2
    state.ship.invulnerable = true
    state.ship.invulnTimer = INVULN_TIME
    state.levelClearTimer = 0
end

-- Respawn ship
local function respawnShip()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    state.ship.x = w / 2
    state.ship.y = h / 2
    state.ship.vx = 0
    state.ship.vy = 0
    state.ship.angle = -math.pi / 2
    state.ship.alive = true
    state.ship.invulnerable = true
    state.ship.invulnTimer = INVULN_TIME
end

-- Fire a bullet
local function fireBullet()
    if #state.bullets >= MAX_BULLETS then return end
    if state.fireTimer > 0 then return end
    state.fireTimer = FIRE_RATE
    local s = state.ship
    local tipX = s.x + math.cos(s.angle) * SHIP_SIZE
    local tipY = s.y + math.sin(s.angle) * SHIP_SIZE
    table.insert(state.bullets, {
        x = tipX,
        y = tipY,
        vx = math.cos(s.angle) * BULLET_SPEED + s.vx * 0.5,
        vy = math.sin(s.angle) * BULLET_SPEED + s.vy * 0.5,
        life = BULLET_LIFETIME,
    })
end

-- Hyperspace jump
local function hyperspace()
    if state.hyperspaceTimer > 0 then return end
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    -- Add disappear particles
    local p = createExplosion(state.ship.x, state.ship.y, 10, 100, 0.5)
    for _, part in ipairs(p) do table.insert(state.particles, part) end
    state.ship.x = love.math.random() * w
    state.ship.y = love.math.random() * h
    state.ship.vx = 0
    state.ship.vy = 0
    state.hyperspaceTimer = HYPERSPACE_COOLDOWN
    -- Add reappear particles
    p = createExplosion(state.ship.x, state.ship.y, 10, 100, 0.5)
    for _, part in ipairs(p) do table.insert(state.particles, part) end
end

-- Split or destroy asteroid
local function destroyAsteroid(index)
    local ast = state.asteroids[index]
    state.score = state.score + (ASTEROID_SCORES[ast.size] or 0)
    if state.score > state.highScore then state.highScore = state.score end

    -- Explosion particles
    local count = ast.size == "large" and 15 or (ast.size == "medium" and 10 or 6)
    local p = createExplosion(ast.x, ast.y, count, ast.radius * 2, 0.8)
    for _, part in ipairs(p) do table.insert(state.particles, part) end

    -- Spawn children
    local childSize = ASTEROID_CHILDREN[ast.size]
    if childSize then
        local w = love.graphics.getWidth()
        local h = love.graphics.getHeight()
        for i = 1, 2 do
            local child = createAsteroid(ast.x, ast.y, childSize, w, h)
            table.insert(state.asteroids, child)
        end
    end

    table.remove(state.asteroids, index)
end

-- Ship-asteroid collision
local function checkShipCollision()
    if not state.ship.alive or state.ship.invulnerable then return end
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    for _, ast in ipairs(state.asteroids) do
        if wrapDist(state.ship.x, state.ship.y, ast.x, ast.y, w, h) < ast.radius + SHIP_SIZE * 0.7 then
            -- Ship destroyed
            state.ship.alive = false
            state.ship.thrusting = false
            local p = createExplosion(state.ship.x, state.ship.y, 20, 150, 1.0)
            for _, part in ipairs(p) do table.insert(state.particles, part) end
            state.lives = state.lives - 1
            if state.lives <= 0 then
                state.gameOver = true
                state.screen = "gameover"
            else
                state.ship.respawnTimer = RESPAWN_DELAY
            end
            return
        end
    end
end

-- Bullet-asteroid collision
local function checkBulletCollisions()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local i = 1
    while i <= #state.bullets do
        local bullet = state.bullets[i]
        local hit = false
        local j = #state.asteroids
        while j >= 1 do
            local ast = state.asteroids[j]
            if wrapDist(bullet.x, bullet.y, ast.x, ast.y, w, h) < ast.radius then
                destroyAsteroid(j)
                table.remove(state.bullets, i)
                hit = true
                break
            end
            j = j - 1
        end
        if not hit then i = i + 1 end
    end
end

-- Draw the ship
local function drawShip()
    if not state.ship.alive then return end
    local s = state.ship

    -- Blinking when invulnerable
    if s.invulnerable then
        local blink = math.floor(s.invulnTimer * 10) % 2
        if blink == 0 then return end
    end

    love.graphics.push()
    love.graphics.translate(s.x, s.y)
    love.graphics.rotate(s.angle)

    -- Draw thrust flame
    if s.thrusting then
        local flicker = 0.7 + love.math.random() * 0.3
        love.graphics.setColor(COLORS.ship_thrust[1], COLORS.ship_thrust[2], COLORS.ship_thrust[3], flicker)
        love.graphics.polygon("fill",
            -SHIP_SIZE * 0.5, -SHIP_SIZE * 0.35 * flicker,
            -SHIP_SIZE * (0.8 + love.math.random() * 0.4), 0,
            -SHIP_SIZE * 0.5, SHIP_SIZE * 0.35 * flicker
        )
    end

    -- Draw ship body
    love.graphics.setColor(COLORS.ship)
    love.graphics.polygon("line",
        SHIP_SIZE, 0,
        -SHIP_SIZE * 0.7, -SHIP_SIZE * 0.6,
        -SHIP_SIZE * 0.4, 0,
        -SHIP_SIZE * 0.7, SHIP_SIZE * 0.6
    )

    love.graphics.pop()
end

-- Draw asteroid
local function drawAsteroid(ast)
    love.graphics.push()
    love.graphics.translate(ast.x, ast.y)
    love.graphics.rotate(ast.rotAngle)

    love.graphics.setColor(COLORS.asteroid)
    local points = {}
    for _, v in ipairs(ast.shape) do
        table.insert(points, math.cos(v.angle) * v.r)
        table.insert(points, math.sin(v.angle) * v.r)
    end
    if #points >= 6 then
        love.graphics.polygon("line", points)
    end

    love.graphics.pop()
end

-- Draw functions
local function drawStars()
    for _, star in ipairs(state.stars) do
        love.graphics.setColor(star.brightness, star.brightness, star.brightness + 0.1, 1)
        if star.size == 2 then
            love.graphics.rectangle("fill", star.x, star.y, 2, 2)
        else
            love.graphics.points(star.x, star.y)
        end
    end
end

local function drawBullets()
    love.graphics.setColor(COLORS.bullet)
    for _, b in ipairs(state.bullets) do
        love.graphics.circle("fill", b.x, b.y, 2)
    end
end

local function drawParticles()
    for _, p in ipairs(state.particles) do
        local alpha = p.life / p.maxLife
        love.graphics.setColor(1, 0.8 * alpha, 0.3 * alpha, alpha)
        love.graphics.circle("fill", p.x, p.y, p.size * alpha)
    end
    for _, p in ipairs(state.thrustParticles) do
        local alpha = p.life / p.maxLife
        love.graphics.setColor(COLORS.ship_thrust[1], COLORS.ship_thrust[2] * alpha, COLORS.ship_thrust[3] * alpha * 0.5, alpha * 0.8)
        love.graphics.circle("fill", p.x, p.y, p.size * alpha)
    end
end

local function drawHUD()
    local w = love.graphics.getWidth()
    love.graphics.setColor(COLORS.hud)

    -- Score
    love.graphics.print("SCORE: " .. state.score, 15, 10)

    -- High score
    local hsText = "HIGH: " .. state.highScore
    love.graphics.print(hsText, w - love.graphics.getFont():getWidth(hsText) - 15, 10)

    -- Level
    local lvlText = "LEVEL " .. state.level
    love.graphics.print(lvlText, (w - love.graphics.getFont():getWidth(lvlText)) / 2, 10)

    -- Lives (draw small ships)
    for i = 1, state.lives do
        local lx = 15 + (i - 1) * 22
        local ly = 35
        love.graphics.push()
        love.graphics.translate(lx, ly)
        love.graphics.rotate(-math.pi / 2)
        love.graphics.polygon("line",
            SHIP_SIZE * 0.6, 0,
            -SHIP_SIZE * 0.4, -SHIP_SIZE * 0.35,
            -SHIP_SIZE * 0.25, 0,
            -SHIP_SIZE * 0.4, SHIP_SIZE * 0.35
        )
        love.graphics.pop()
    end

    -- Hyperspace cooldown indicator
    if state.hyperspaceTimer > 0 then
        love.graphics.setColor(0.5, 0.5, 0.5, 0.6)
        local cdText = string.format("HYPERSPACE: %.1fs", state.hyperspaceTimer)
        love.graphics.print(cdText, 15, 55)
    end
end

local function drawMenu()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(COLORS.menu_bg)
    love.graphics.rectangle("fill", 0, 0, w, h)

    drawStars()

    local defaultFont = love.graphics.getFont()
    local font = love.graphics.newFont(48)
    love.graphics.setFont(font)

    local title = "ASTEROIDS"
    local titleY = h / 3
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.printf(title, 3, titleY + 3, w, "center")
    love.graphics.setColor(0.9, 0.9, 0.95, 1)
    love.graphics.printf(title, 0, titleY, w, "center")
    love.graphics.printf(title, 1, titleY, w, "center")
    love.graphics.printf(title, 0, titleY + 1, w, "center")
    love.graphics.printf(title, 1, titleY + 1, w, "center")
    love.graphics.setFont(defaultFont)

    local options = {"Start Game", "Quit"}
    for i, opt in ipairs(options) do
        if i == state.menuSelection then
            love.graphics.setColor(COLORS.menu_selected)
            opt = "> " .. opt .. " <"
        else
            love.graphics.setColor(COLORS.text)
        end
        love.graphics.printf(opt, 0, h / 2 + (i - 1) * 30, w, "center")
    end

    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.printf("WASD/Arrows: Move  |  Space: Shoot  |  Shift: Hyperspace", 0, h - 50, w, "center")
end

local function drawPaused()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local defaultFont = love.graphics.getFont()
    local font = love.graphics.newFont(48)
    love.graphics.setFont(font)

    local titleText = "GAME PAUSED"
    local titleY = h / 4
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.printf(titleText, 3, titleY + 3, w, "center")
    love.graphics.setColor(1, 0.2, 0.2, 1)
    love.graphics.printf(titleText, 0, titleY, w, "center")
    love.graphics.printf(titleText, 1, titleY, w, "center")
    love.graphics.printf(titleText, 0, titleY + 1, w, "center")
    love.graphics.printf(titleText, 1, titleY + 1, w, "center")
    love.graphics.setFont(defaultFont)

    love.graphics.setColor(COLORS.text)
    local statsY = h / 3 + 20
    love.graphics.printf("Score: " .. state.score, 0, statsY, w, "center")
    love.graphics.printf("Level: " .. state.level, 0, statsY + 25, w, "center")
    love.graphics.printf("Lives: " .. state.lives, 0, statsY + 50, w, "center")

    local options = {"Resume", "Restart", "Main Menu"}
    local menuStartY = h / 2 + 40
    for i, opt in ipairs(options) do
        if i == state.pauseSelection then
            love.graphics.setColor(COLORS.menu_selected)
            opt = "> " .. opt .. " <"
        else
            love.graphics.setColor(COLORS.text)
        end
        love.graphics.printf(opt, 0, menuStartY + (i - 1) * 35, w, "center")
    end
end

local function drawGameOver()
    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(COLORS.menu_bg)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local defaultFont = love.graphics.getFont()
    local font = love.graphics.newFont(72)
    love.graphics.setFont(font)

    local titleText = "GAME OVER"
    local titleY = h / 3
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.printf(titleText, 4, titleY + 4, w, "center")
    love.graphics.setColor(0.9, 0.3, 0.3, 1)
    for dx = 0, 2 do
        for dy = 0, 2 do
            love.graphics.printf(titleText, dx, titleY + dy, w, "center")
        end
    end
    love.graphics.setFont(defaultFont)

    love.graphics.setColor(COLORS.text)
    love.graphics.printf("Score: " .. state.score, 0, h / 2, w, "center")
    love.graphics.printf("High Score: " .. state.highScore, 0, h / 2 + 30, w, "center")
    love.graphics.printf("Level Reached: " .. state.level, 0, h / 2 + 60, w, "center")
    love.graphics.printf("Press ENTER to restart", 0, h / 2 + 110, w, "center")
    love.graphics.printf("Press ESC for menu", 0, h / 2 + 140, w, "center")
end

-- Module functions

function game.init()
    love.keyboard.setKeyRepeat(false)
    initGame()
end

function game.update(dt)
    if state.screen ~= "playing" then return end

    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    -- Timers
    if state.fireTimer > 0 then state.fireTimer = state.fireTimer - dt end
    if state.hyperspaceTimer > 0 then state.hyperspaceTimer = state.hyperspaceTimer - dt end

    -- Left trigger hyperspace (detect press transition since triggers are axes)
    local leftTriggerDown = isGamepadTriggerDown("triggerleft")
    if leftTriggerDown and not state.leftTriggerWasDown and state.ship.alive then
        hyperspace()
    end
    state.leftTriggerWasDown = leftTriggerDown

    -- Ship controls (continuous input)
    if state.ship.alive then
        state.ship.thrusting = false
        if love.keyboard.isDown("up") or love.keyboard.isDown("w") or isGamepadDown("dpup") then
            state.ship.vx = state.ship.vx + math.cos(state.ship.angle) * SHIP_ACCEL * dt
            state.ship.vy = state.ship.vy + math.sin(state.ship.angle) * SHIP_ACCEL * dt
            state.ship.thrusting = true
        end
        if love.keyboard.isDown("left") or love.keyboard.isDown("a") or isGamepadDown("dpleft") then
            state.ship.angle = state.ship.angle - SHIP_ROTATE_SPEED * dt
        end
        if love.keyboard.isDown("right") or love.keyboard.isDown("d") or isGamepadDown("dpright") then
            state.ship.angle = state.ship.angle + SHIP_ROTATE_SPEED * dt
        end
        if love.keyboard.isDown("space") or isGamepadDown("a") or isGamepadDown("rightshoulder") or isGamepadTriggerDown("triggerright") then
            fireBullet()
        end

        -- Apply friction
        state.ship.vx = state.ship.vx * SHIP_FRICTION
        state.ship.vy = state.ship.vy * SHIP_FRICTION

        -- Cap speed
        local speed = math.sqrt(state.ship.vx ^ 2 + state.ship.vy ^ 2)
        local maxSpeed = 400
        if speed > maxSpeed then
            state.ship.vx = state.ship.vx / speed * maxSpeed
            state.ship.vy = state.ship.vy / speed * maxSpeed
        end

        -- Move ship
        state.ship.x = state.ship.x + state.ship.vx * dt
        state.ship.y = state.ship.y + state.ship.vy * dt
        state.ship.x, state.ship.y = wrap(state.ship.x, state.ship.y, w, h)

        -- Invulnerability timer
        if state.ship.invulnerable then
            state.ship.invulnTimer = state.ship.invulnTimer - dt
            if state.ship.invulnTimer <= 0 then
                state.ship.invulnerable = false
            end
        end

        -- Thrust particles
        if state.ship.thrusting then
            local backX = state.ship.x - math.cos(state.ship.angle) * SHIP_SIZE * 0.5
            local backY = state.ship.y - math.sin(state.ship.angle) * SHIP_SIZE * 0.5
            local spread = 0.5
            local angle = state.ship.angle + math.pi + (love.math.random() - 0.5) * spread
            local spd = 50 + love.math.random() * 50
            table.insert(state.thrustParticles, {
                x = backX,
                y = backY,
                vx = math.cos(angle) * spd,
                vy = math.sin(angle) * spd,
                life = 0.3 + love.math.random() * 0.2,
                maxLife = 0.5,
                size = 1 + love.math.random() * 2,
            })
        end
    else
        -- Respawn timer
        if not state.gameOver then
            state.ship.respawnTimer = state.ship.respawnTimer - dt
            if state.ship.respawnTimer <= 0 then
                respawnShip()
            end
        end
    end

    -- Update bullets
    local i = 1
    while i <= #state.bullets do
        local b = state.bullets[i]
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.x, b.y = wrap(b.x, b.y, w, h)
        b.life = b.life - dt
        if b.life <= 0 then
            table.remove(state.bullets, i)
        else
            i = i + 1
        end
    end

    -- Update asteroids
    for _, ast in ipairs(state.asteroids) do
        ast.x = ast.x + ast.vx * dt
        ast.y = ast.y + ast.vy * dt
        ast.x, ast.y = wrap(ast.x, ast.y, w, h)
        ast.rotAngle = ast.rotAngle + ast.rotSpeed * dt
    end

    -- Update particles
    i = 1
    while i <= #state.particles do
        local p = state.particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(state.particles, i)
        else
            i = i + 1
        end
    end
    i = 1
    while i <= #state.thrustParticles do
        local p = state.thrustParticles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(state.thrustParticles, i)
        else
            i = i + 1
        end
    end

    -- Collisions
    checkBulletCollisions()
    checkShipCollision()

    -- Level clear
    if #state.asteroids == 0 and state.ship.alive then
        state.levelClearTimer = state.levelClearTimer + dt
        if state.levelClearTimer >= 2 then
            startNextLevel()
        end
    end
end

function game.draw()
    love.graphics.setColor(COLORS.background)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    if state.screen == "menu" then
        drawMenu()
    else
        drawStars()
        drawParticles()
        drawBullets()
        for _, ast in ipairs(state.asteroids) do
            drawAsteroid(ast)
        end
        drawShip()
        drawHUD()

        -- Level clear message
        if #state.asteroids == 0 and state.ship.alive then
            local w = love.graphics.getWidth()
            local h = love.graphics.getHeight()
            love.graphics.setColor(COLORS.menu_selected)
            love.graphics.printf("LEVEL CLEAR!", 0, h / 2 - 15, w, "center")
        end

        if state.screen == "paused" then
            drawPaused()
        elseif state.screen == "gameover" then
            drawGameOver()
        end
    end
end

function game.keypressed(key, scancode, isrepeat)
    if state.screen == "menu" then
        if key == "up" then
            state.menuSelection = state.menuSelection - 1
            if state.menuSelection < 1 then state.menuSelection = 2 end
        elseif key == "down" then
            state.menuSelection = state.menuSelection + 1
            if state.menuSelection > 2 then state.menuSelection = 1 end
        elseif key == "return" or key == "space" then
            if state.menuSelection == 1 then
                state.screen = "playing"
            else
                love.event.quit()
            end
        end
    elseif state.screen == "playing" then
        if key == "escape" then
            state.screen = "paused"
            state.pauseSelection = 1
        elseif key == "lshift" or key == "rshift" then
            if state.ship.alive then
                hyperspace()
            end
        end
    elseif state.screen == "paused" then
        if key == "up" then
            state.pauseSelection = state.pauseSelection - 1
            if state.pauseSelection < 1 then state.pauseSelection = 3 end
        elseif key == "down" then
            state.pauseSelection = state.pauseSelection + 1
            if state.pauseSelection > 3 then state.pauseSelection = 1 end
        elseif key == "return" or key == "space" then
            if state.pauseSelection == 1 then
                state.screen = "playing"
            elseif state.pauseSelection == 2 then
                restartGame()
            else
                state.screen = "menu"
                initGame()
            end
        elseif key == "escape" then
            state.screen = "playing"
        end
    elseif state.screen == "gameover" then
        if key == "return" or key == "space" then
            restartGame()
        elseif key == "escape" then
            state.screen = "menu"
            initGame()
        end
    end
end

function game.getState()
    if not state then return nil end
    return deepCopy(state)
end

function game.reload(savedState)
    love.keyboard.setKeyRepeat(false)
    if savedState then
        state = deepCopy(savedState)
    else
        initGame()
    end
end

-- Input deduplication
local DEDUP_WINDOW = 0.08
local lastPressTime = {}

local function dedup(key)
    local now = love.timer.getTime()
    if lastPressTime[key] and (now - lastPressTime[key]) < DEDUP_WINDOW then
        return true
    end
    lastPressTime[key] = now
    return false
end

-- Love2D callbacks
function love.load()
    game.init()
end

function love.update(dt)
    game.update(dt)
end

function love.draw()
    game.draw()
end

function love.keypressed(key, scancode, isrepeat)
    if isrepeat then return end
    if dedup(key) then return end
    game.keypressed(key, scancode, isrepeat)
end

function love.gamepadpressed(joystick, button)
    local map = {
        dpup = "up", dpdown = "down", dpleft = "left", dpright = "right",
        a = "space", b = "escape", x = "lshift", y = "return",
        start = "escape", back = "backspace",
        leftshoulder = "lshift", rightshoulder = "space",
    }
    local key = map[button]
    if key then
        if dedup(key) then return end
        game.keypressed(key)
    end
end

function love.mousepressed(x, y, button)
    if button == 1 and state and state.screen == "menu" then
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
        local options = {"Start Game", "Quit"}
        for i = 1, #options do
            local itemY = h / 2 + (i - 1) * 30
            if y >= itemY and y <= itemY + 20 then
                state.menuSelection = i
                game.keypressed("return")
                return
            end
        end
    end
end

return game
