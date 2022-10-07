local vector = {};
local matrix = {};
local physics = {};
local hud = {};
local objLoader = {};

local sceneOrigin = { 0, 6, 0 };
local scenes = {};
local scene = {
    time = 0
}
local renderer = {
    shader = nil,
    light = {
        lightDirection = { -.54978538074163039916787208350194, .2732183031115653209570042419656, .79863551004729284628400080406894 },
        lightColor = { 186 / 255, 185 / 255, 140 / 255 },
        ambientColor = { 59 / 255, 106 / 255, 110 / 255 }
    },
    sky = {
        shader = nil,
        mesh = nil,
        texture = nil
    },
    camera = {
        fieldOfView = 90,
        aspect = 1,
        position = sceneOrigin,
        forward = { 0, 0, -1 },
        right = { 1, 0, 0 },
        up = { 0, 1, 0 },
        projectionMatrix = nil,
        viewMatrix = nil
    }
}
local client = {
    allowInput = false,
    yaw = 0,
    pitch = 0,
    deltaYaw = 0,
    deltaPitch = 0,
    sensitivity = .1,
    speed = 16,
    inputs = { 0, 0, 0 }
}

-- ==================== SCENES ====================
scenes.mainMenu = {
    logoSprite = nil,
    load = function()
        love.mouse.setRelativeMode(false);

        scene.logoSprite = love.graphics.newImage("Assets/Textures/HUD/Logo.png");

        client.allowInput = false;
        renderer.camera.fieldOfView = 110;
    end,
    update = function()
        client.yaw = scene.time % 360;
        client.pitch = -20;

        local width, height = love.graphics.getDimensions();

        if (hud.buttonCentered("Jouer", width / 2, height / 2, 512, 128)) then
            scenes.loadScene("loadingScreen");
        end
        if (hud.buttonCentered("Quitter", width / 2, height / 2 + 152, 512, 128)) then
            love.event.quit();
        end
    end,
    draw = function()
        love.graphics.setShader();
        love.graphics.setDepthMode("always", true);

        local width, height = love.graphics.getDimensions();
        local logoWidth, logoHeight = scene.logoSprite:getDimensions();
        love.graphics.draw(scene.logoSprite, width / 2, height / 2 - logoHeight / 2 - 48, 0, 1, 1, logoWidth / 2, logoHeight / 2);
    end
}
scenes.loadingScreen = {
    firstFrame = true,
    helpSprite = nil,
    load = function()
        love.window.maximize();

        scene.helpSprite = love.graphics.newImage("Assets/Textures/HUD/Keybind.png");

        scene.firstFrame = true;
    end,
    update = function()
        if (scene.firstFrame) then
            scene.firstFrame = false;
        else
            scenes.loadScene("inGame");
        end
    end,
    draw = function()
        love.graphics.setShader();
        love.graphics.setDepthMode("always", true);

        local width, height = love.graphics.getDimensions();
        local font = love.graphics.getFont();
        local fontHeight = font:getHeight();
        local fontWidth = font:getWidth("CHARGEMENT");

        love.graphics.setColor(0, 0, 0, 1);
        love.graphics.rectangle("fill", 0, 0, width, height);
        love.graphics.setColor(1, 1, 1, 1);
        love.graphics.print("CHARGEMENT", width / 2, height / 2 - 64, 0, 1, 1, fontWidth / 2, fontHeight / 2);
        love.graphics.draw(scene.helpSprite, width / 2, height / 2 + 64, 0, 1, 1, scene.helpSprite:getWidth() / 2, 0);
    end
}
scenes.inGame = {
    meshes = {
        ground = nil,
        rocks = nil,
        bubble = nil
    },
    sounds = {
        burst = nil
    },
    sprites = {
        damageOverlay = nil
    },
    bubble = {
        duration = 1.5,
        speed = 24,
        range = 32,
        radius = .5
    },
    enemy = {
        spawnTime = 0,
        spawnDelay = 1,
        speed = 4,
        radius = 1,
        target = { 0, 5, 0 }
    },
    health = {
        point = 0,
        sinceLastDamage = math.huge
    },
    bubbles = {},
    enemies = {},
    easterEgg = nil,
    load = function()
        love.mouse.setRelativeMode(true);
        love.audio.setVolume(.4);

        client.allowInput = true;
        renderer.camera.fieldOfView = 90;

        scene.meshes.ground = renderer.loadMesh("Ground");
        scene.meshes.rocks = renderer.loadMesh("Rocks");
        scene.meshes.bubble = renderer.loadMesh("Bubble");
        scene.meshes.enemy = renderer.loadMesh("Enemy");
        scene.meshes.target = renderer.loadMesh("Target");

        scene.sounds.burst = love.audio.newSource("Assets/Sounds/Burst.ogg", "static");

        scene.sprites.damageOverlay = love.graphics.newImage("Assets/Textures/DamageOverlay.png");
        scene.sprites.hearth = love.graphics.newImage("Assets/Textures/HUD/Health.png");

        scene.health.point = 3;
        scene.health.sinceLastDamage = math.huge;
        scene.enemy.spawnDelay = 1;
        scene.enemy.target = { 0, 5, 0 };
        scene.bubbles = {};
        scene.enemies = {};
        scene.easterEgg = nil;
    end,
    unload = function()
        if (scene.easterEgg) then
            renderer.sky.mesh:setTexture(renderer.sky.texture);
            scene.easterEgg.video:pause();
        end
    end,
    update = function(deltaTime)
        scene.updateBubbles(deltaTime);
        scene.updateEnemies(deltaTime)

        scene.enemy.spawnTime = scene.enemy.spawnTime + deltaTime;
        if (scene.enemy.spawnTime > scene.enemy.spawnDelay) then
            scene.enemy.spawnTime = 0;
            local angle = math.random(0, 2 * math.pi);
            local offset = math.random(-1, 1);
            local spawnDirection = vector.normalize({
                math.cos(angle),
                0,
                math.sin(angle)
            });
            local spawnPosition = vector.subtract(
                    vector.add(sceneOrigin, { 0, offset, 0 }),
                    vector.scale(spawnDirection, 20)
            )
            scene.spawnEnemy(spawnPosition, -angle + math.pi / 2);
        end ;

        scene.health.sinceLastDamage = scene.health.sinceLastDamage + deltaTime;
        if (scene.health.point <= 0) then
            scenes.loadScene("mainMenu");
        end

        if(scene.easterEgg) then
            scene.easterEgg.time = scene.easterEgg.time + deltaTime;
        end
    end,
    draw = function()

        if(scene.easterEgg) then
            math.randomseed(math.floor(scene.easterEgg.time / (60 / 113))); -- second in a minute / bpm
            renderer.shader:send("lightColor", {
                math.random(),
                math.random(),
                math.random()
            });
        end

        renderer.shader:send("model", "column", matrix.identity());
        love.graphics.draw(scene.meshes.ground);
        love.graphics.draw(scene.meshes.rocks);

        for _, enemy in pairs(scene.enemies) do
            renderer.shader:send("model", "column", matrix.mul(
                    matrix.translate(
                            enemy.position[1], enemy.position[2], enemy.position[3]
                    ),
                    matrix.rotate(enemy.angle + math.cos(scene.time * 4) * (math.pi / 16), { 0, 1, 0 })
            ));
            love.graphics.draw(scene.meshes.enemy);
        end

        for _, bubble in pairs(scene.bubbles) do
            renderer.shader:send("model", "column", matrix.mul(
                    matrix.translate(
                            bubble.position[1], bubble.position[2], bubble.position[3]
                    ),
                    matrix.scale(
                            1 - bubble.time / scene.bubble.duration, 1 - bubble.time / scene.bubble.duration, 1 - bubble.time / scene.bubble.duration
                    )
            ));
            love.graphics.draw(scene.meshes.bubble);
        end

        if (scene.easterEgg) then
            love.graphics.setShader();
            love.graphics.setCanvas(scene.easterEgg.canvas);
            love.graphics.draw(scene.easterEgg.video, 0, 0);
            love.graphics.setCanvas();
        else
            renderer.shader:send("model", "column", matrix.translate(6, 0, 34));
            love.graphics.draw(scene.meshes.target);
        end

        love.graphics.setShader();
        love.graphics.setDepthMode("always", false);
        local width, height = love.graphics.getDimensions();

        local alpha = 1 - scene.health.sinceLastDamage;
        if (alpha > 0) then
            local damageOverlayWidth, damageOverlayHeight = scene.sprites.damageOverlay:getDimensions();
            love.graphics.setColor(1, 1, 1, alpha);
            love.graphics.draw(scene.sprites.damageOverlay, 0, 0, 0, width / damageOverlayWidth, height / damageOverlayHeight);
        end

        love.graphics.setColor(1, 1, 1, 1);
        local hearthWidth = scene.sprites.hearth:getWidth();
        for i = 0, scene.health.point - 1 do
            love.graphics.draw(scene.sprites.hearth, 20 + i * hearthWidth, 20);
        end

        love.graphics.circle("line", width / 2, height / 2, 10);
    end,
    mousePressed = function(_, _, button)
        if (button == 1) then
            local spawnPosition = vector.subtract(renderer.camera.position, vector.scale(renderer.camera.up, .5));
            scene.spawnBubble(spawnPosition, renderer.camera.forward);
        end
    end,
    keypressed = function(key)
        if (key == "escape") then
            scenes.loadScene("mainMenu");
        end
    end,
    updateBubbles = function(deltaTime)
        for i = #scene.bubbles, 1, -1 do
            local bubble = scene.bubbles[i];
            bubble.position = vector.add(bubble.position, vector.scale(bubble.velocity, deltaTime));
            bubble.time = bubble.time + deltaTime;

            if (not scene.easterEgg and physics.testSphereSphere(bubble.position, scene.bubble.radius, { 6, 4.5, 34 }, 1)) then
                scene.easterEgg = {
                    time = 0,
                    canvas = love.graphics.newCanvas(1280, 720),
                    video = love.graphics.newVideo("Assets/NGGYU.ogg", {
                        audio = true
                    })
                };
                renderer.sky.mesh:setTexture(scene.easterEgg.canvas);
                scene.easterEgg.video:play();

                scene.enemy.spawnDelay = .2;
                scene.enemy.target = { 0, 10000, 0 };
                for _, v in pairs(scene.enemies) do
                    v.velocity = { 0, 1, 0 };
                end
            end

            for j = #scene.enemies, 1, -1 do
                local enemy = scene.enemies[j];
                if (physics.testSphereSphere(enemy.position, scene.enemy.radius, bubble.position, scene.bubble.radius)) then
                    bubble.time = math.huge;
                    table.remove(scene.enemies, j);
                end
            end

            -- Checks if y < 0 to fake collision with the ground
            if (bubble.time > scene.bubble.duration or bubble.position[2] < 0) then
                table.remove(scene.bubbles, i);
            end
        end
    end,
    updateEnemies = function(deltaTime)
        local reached = false;
        for i = #scene.enemies, 1, -1 do
            local enemy = scene.enemies[i];
            enemy.position, reached = vector.moveTowards(enemy.position, scene.enemy.target, scene.enemy.speed * deltaTime);
            if (reached) then
                scene.health.sinceLastDamage = 0;
                scene.health.point = scene.health.point - 1;
                table.remove(scene.enemies, i);
            end
        end
    end,
    spawnBubble = function(position, direction)
        if (scene.sounds.burst:isPlaying()) then
            scene.sounds.burst:stop();
        end
        scene.sounds.burst:play();
        table.insert(scene.bubbles, {
            position = position,
            direction = direction,
            velocity = vector.scale(direction, scene.bubble.speed),
            time = 0
        });
    end,
    spawnEnemy = function(position, angle)
        table.insert(scene.enemies, {
            position = position,
            angle = angle
        });
    end
}

function love.load()
    math.randomseed(os.time());
    renderer.initialize();

    local font = love.graphics.newFont("Assets/OpenDyslexic.otf", 24);
    love.graphics.setFont(font);

    hud.style.button.textColor = { 0.87058824, 0.7921569, 0.64705884, 1 };
    hud.style.button.sprites.normal = love.graphics.newImage("Assets/Textures/HUD/Button.png");
    hud.style.button.sprites.hovered = love.graphics.newImage("Assets/Textures/HUD/Button_Hover.png");
    hud.style.button.sprites.clicked = love.graphics.newImage("Assets/Textures/HUD/Button_Clicked.png");

    scenes.loadScene("mainMenu");
end

function love.update(deltaTime)
    scene.time = scene.time + deltaTime;
    if (scene.update) then
        scene.update(deltaTime);
    end

    -- update matrices
    renderer.camera.setYawPitch(client.yaw, client.pitch);
    renderer.camera.projectionMatrix = matrix.perspectiveProjection(renderer.camera.fieldOfView, renderer.camera.aspect, .1, 1000);
    renderer.camera.viewMatrix = matrix.lookAt(renderer.camera.position, vector.add(renderer.camera.position, renderer.camera.forward), renderer.camera.up);

    -- update camera
    if (client.allowInput) then
        client.yaw = (client.yaw + client.deltaYaw) % 360;
        client.pitch = math.clamp(client.pitch - client.deltaPitch, -90, 90);
    end
    client.deltaYaw = 0;
    client.deltaPitch = 0;
end

function love.draw()
    love.graphics.setColor(1, 1, 1, 1);

    renderer.renderSky();
    renderer.renderScene();
    renderer.renderHUD();
end

function love.resize(width, height)
    renderer.camera.aspect = width / height;
end

function love.mousemoved(_, _, dx, dy)
    if client.allowInput then
        client.deltaYaw = client.deltaYaw + dx * client.sensitivity;
        client.deltaPitch = client.deltaPitch + dy * client.sensitivity;
    end
end

function love.mousepressed(x, y, button, isTouch, presses)
    if (scene.mousePressed) then
        scene.mousePressed(x, y, button, isTouch, presses);
    end
end

function love.keypressed(key)
    if (scene.keypressed) then
        scene.keypressed(key);
    end
    if (key == "f") then
        scenes.inGame.enemy.spawnDelay = 2;
        scenes.inGame.health.point = 10;
    end
end

function scenes.loadScene(name)
    if (scene.unload) then
        scene.unload();
    end
    scene = scenes[name];
    scene.time = 0;
    if (scene.load) then
        scene.load();
    end
end

function renderer.initialize()
    local w, h = love.graphics.getDimensions();
    renderer.camera.aspect = w / h;

    love.graphics.setFrontFaceWinding("ccw");
    love.graphics.setMeshCullMode("back");
    love.graphics.setBackgroundColor(0.019607844, 0.3254902, 0.47843137, 1);

    renderer.shader = love.graphics.newShader("Assets/Shaders/Standard.frag", "Assets/Shaders/Standard.vert");

    renderer.sky.mesh = renderer.loadMesh("Skybox");
    renderer.sky.shader = love.graphics.newShader("Assets/Shaders/Skybox.frag", "Assets/Shaders/Skybox.vert");
    renderer.sky.texture = renderer.sky.mesh:getTexture();
end

function renderer.loadMesh(name, noTexture)
    local obj = objLoader.load("Assets/Models/" .. name .. ".obj");

    local format = {
        { "VertexPosition", "float", 3 },
        { "VertexNormal", "float", 3 },
        { "VertexTexCoord", "float", 2 }
    };

    local vertices = {};
    local indices = {};

    for _, face in pairs(obj.f) do
        for _, vertex in pairs(face) do
            local pos = obj.v[vertex.v];
            local normal = obj.vn[vertex.vn];
            local texCoord = obj.vt[vertex.vt];
            table.insert(vertices, {
                pos.x, pos.y, pos.z,
                normal.x, normal.y, normal.z,
                texCoord.u, 1 - texCoord.v
            });
            table.insert(indices, #vertices);
        end
    end

    local mesh = love.graphics.newMesh(format, vertices, "triangles");
    mesh:setVertexMap(indices);

    if (not noTexture) then
        local diffuseTexture = love.graphics.newImage("Assets/Textures/" .. name .. ".png");
        mesh:setTexture(diffuseTexture);
    end

    return mesh
end

function renderer.renderSky()
    love.graphics.setDepthMode("lequal", false)
    love.graphics.setShader(renderer.sky.shader);

    -- send camera data
    renderer.sky.shader:send("projection", "column", renderer.camera.projectionMatrix);
    renderer.sky.shader:send("view", "column", renderer.camera.viewMatrix);

    love.graphics.draw(renderer.sky.mesh);
end

function renderer.renderScene()
    love.graphics.setDepthMode("less", true)
    love.graphics.setShader(renderer.shader);

    -- send camera data
    renderer.shader:send("projection", "column", renderer.camera.projectionMatrix);
    renderer.shader:send("view", "column", renderer.camera.viewMatrix);

    -- send light data
    renderer.shader:send("lightDirection", renderer.light.lightDirection);
    renderer.shader:send("lightColor", renderer.light.lightColor);
    renderer.shader:send("ambientColor", renderer.light.ambientColor);

    if (scene.draw) then
        scene.draw();
    end
end

function renderer.renderHUD()
    love.graphics.setDepthMode("always", false)
    love.graphics.setShader()
    hud.draw();
end

function renderer.camera.setYawPitch(yaw, pitch)
    local radYaw = math.rad(yaw);
    local radPitch = math.rad(pitch);
    renderer.camera.forward = vector.normalize({
        math.cos(radPitch) * math.cos(radYaw),
        math.sin(radPitch),
        math.cos(radPitch) * math.sin(radYaw)
    });
    renderer.camera.right = vector.normalize(vector.cross(renderer.camera.forward, vector.up));
    renderer.camera.up = vector.normalize(vector.cross(renderer.camera.right, renderer.camera.forward));
end

-- ==================== MATH LIB ====================
function math.clamp(x, min, max)
    return math.min(math.max(x, min), max);
end

-- ==================== VECTOR LIB ====================
vector.up = { 0, 1, 0 };
vector.forward = { 0, 0, 1 };
vector.right = { -1, 0, 0 };
function vector.add(a, b)
    return {
        a[1] + b[1],
        a[2] + b[2],
        a[3] + b[3]
    }
end
function vector.subtract(a, b)
    return {
        a[1] - b[1],
        a[2] - b[2],
        a[3] - b[3]
    }
end
function vector.scale(a, b)
    return {
        a[1] * b,
        a[2] * b,
        a[3] * b
    }
end
function vector.normalize(vec3)
    local magnitude = math.sqrt(vec3[1] * vec3[1] + vec3[2] * vec3[2] + vec3[3] * vec3[3]);
    if (magnitude > 0) then
        return { vec3[1] / magnitude, vec3[2] / magnitude, vec3[3] / magnitude };
    else
        return { 0, 0, 0 }
    end
end
function vector.cross(a, b)
    return {
        a[2] * b[3] - a[3] * b[2],
        a[3] * b[1] - a[1] * b[3],
        a[1] * b[2] - a[2] * b[1]
    }
end
function vector.dot(a, b)
    return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end
function vector.lengthSqr(a)
    return a[1] * a[1] + a[2] * a[2] + a[3] * a[3];
end
function vector.length(a)
    return math.sqrt(vector.lengthSqr(a));
end
function vector.moveTowards(current, target, maxSpeed)
    local delta = vector.subtract(target, current);
    local d = vector.lengthSqr(delta);
    if (d == 0 or maxSpeed >= 0 and d <= maxSpeed * maxSpeed) then
        return target, true;
    end

    local distance = math.sqrt(d);
    return vector.add(current, vector.scale(delta, 1 / distance * maxSpeed)), false;
end

-- ==================== MATRIX LIB ====================
function matrix.new()
    return {
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0
    };
end
function matrix.identity()
    return {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    }
end
function matrix.mul(a, b)
    local out = {};
    out[1] = b[1] * a[1] + b[2] * a[5] + b[3] * a[9] + b[4] * a[13]
    out[2] = b[1] * a[2] + b[2] * a[6] + b[3] * a[10] + b[4] * a[14]
    out[3] = b[1] * a[3] + b[2] * a[7] + b[3] * a[11] + b[4] * a[15]
    out[4] = b[1] * a[4] + b[2] * a[8] + b[3] * a[12] + b[4] * a[16]
    out[5] = b[5] * a[1] + b[6] * a[5] + b[7] * a[9] + b[8] * a[13]
    out[6] = b[5] * a[2] + b[6] * a[6] + b[7] * a[10] + b[8] * a[14]
    out[7] = b[5] * a[3] + b[6] * a[7] + b[7] * a[11] + b[8] * a[15]
    out[8] = b[5] * a[4] + b[6] * a[8] + b[7] * a[12] + b[8] * a[16]
    out[9] = b[9] * a[1] + b[10] * a[5] + b[11] * a[9] + b[12] * a[13]
    out[10] = b[9] * a[2] + b[10] * a[6] + b[11] * a[10] + b[12] * a[14]
    out[11] = b[9] * a[3] + b[10] * a[7] + b[11] * a[11] + b[12] * a[15]
    out[12] = b[9] * a[4] + b[10] * a[8] + b[11] * a[12] + b[12] * a[16]
    out[13] = b[13] * a[1] + b[14] * a[5] + b[15] * a[9] + b[16] * a[13]
    out[14] = b[13] * a[2] + b[14] * a[6] + b[15] * a[10] + b[16] * a[14]
    out[15] = b[13] * a[3] + b[14] * a[7] + b[15] * a[11] + b[16] * a[15]
    out[16] = b[13] * a[4] + b[14] * a[8] + b[15] * a[12] + b[16] * a[16]
    return out
end
function matrix.transformVector(a, b)
    return {
        b[1] * a[1] + b[2] * a[5] + b[3] * a[9] + (b[4] or 1) * a[13],
        b[1] * a[2] + b[2] * a[6] + b[3] * a[10] + (b[4] or 1) * a[14],
        b[1] * a[3] + b[2] * a[7] + b[3] * a[11] + (b[4] or 1) * a[15],
        b[1] * a[4] + b[2] * a[8] + b[3] * a[12] + (b[4] or 1) * a[16]
    };
end
function matrix.translate(x, y, z)
    return {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        x, y, z, 1
    }
end
function matrix.rotate(angle, axis)
    local l = vector.length(axis);
    local x, y, z = axis[1] / l, axis[2] / l, axis[3] / l;
    local c = math.cos(angle);
    local s = math.sin(angle);
    return {
        x * x * (1 - c) + c, y * x * (1 - c) + z * s, x * z * (1 - c) - y * s, 0,
        x * y * (1 - c) - z * s, y * y * (1 - c) + c, y * z * (1 - c) + x * s, 0,
        x * z * (1 - c) + y * s, y * z * (1 - c) - x * s, z * z * (1 - c) + c, 0,
        0, 0, 0, 1
    };
end
function matrix.scale(x, y, z)
    return {
        x, 0, 0, 0,
        0, y, 0, 0,
        0, 0, z, 0,
        0, 0, 0, 1
    }
end
function matrix.perspectiveProjection(fov, aspect, near, far)
    local t = math.tan(math.rad(fov) / 2)
    local out = matrix.new();
    out[1] = 1 / (t * aspect)
    out[6] = 1 / t
    out[11] = -(far + near) / (far - near)
    out[12] = -1
    out[15] = -(2 * far * near) / (far - near)
    out[16] = 0
    return out
end
function matrix.lookAt(eye, target, up)
    local zAxis = vector.normalize(vector.subtract(eye, target));
    local xAxis = vector.normalize(vector.cross(up, zAxis));
    local yAxis = vector.cross(zAxis, xAxis);
    local out = {};
    out[1] = xAxis[1]
    out[2] = yAxis[1]
    out[3] = zAxis[1]
    out[4] = 0
    out[5] = xAxis[2]
    out[6] = yAxis[2]
    out[7] = zAxis[2]
    out[8] = 0
    out[9] = xAxis[3]
    out[10] = yAxis[3]
    out[11] = zAxis[3]
    out[12] = 0
    out[13] = -out[1] * eye[1] - out[4 + 1] * eye[2] - out[8 + 1] * eye[3]
    out[14] = -out[2] * eye[1] - out[4 + 2] * eye[2] - out[8 + 2] * eye[3]
    out[15] = -out[3] * eye[1] - out[4 + 3] * eye[2] - out[8 + 3] * eye[3]
    out[16] = -out[4] * eye[1] - out[4 + 4] * eye[2] - out[8 + 4] * eye[3] + 1
    return out;
end


-- ==================== HUD LIB ====================
hud.style = {
    button = {
        color = { 1, 1, 1, 1 },
        textColor = { 1, 1, 1, 1 },
        sprites = {
            normal = nil,
            hovered = nil,
            clicked = nil
        }
    }
};
hud.buttons = {};
function hud.applyColor(color)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1);
end
function hud.draw()
    local mx, my = love.mouse.getPosition();
    local down = love.mouse.isDown(1);
    for _, button in pairs(hud.buttons) do
        local sprite = hud.style.button.sprites.normal;
        if (physics.testPointRectangle(mx, my, button.x, button.y, button.width, button.height)) then
            if (down) then
                sprite = hud.style.button.sprites.clicked;
            else
                sprite = hud.style.button.sprites.hovered;
            end
        end
        local spriteWidth, spriteHeight = sprite:getDimensions();

        hud.applyColor(hud.style.button.color);
        love.graphics.draw(sprite, button.x, button.y, 0, button.width / spriteWidth, button.height / spriteHeight);

        local font = love.graphics.getFont();
        local fontHeight = font:getHeight();
        local fontWidth = font:getWidth(button.text);

        hud.applyColor(hud.style.button.textColor);
        love.graphics.print(button.text, button.x + button.width / 2, button.y + button.height / 2, 0, 1, 1, fontWidth / 2, fontHeight / 2);
    end
    hud.buttons = {};
end
function hud.button(text, x, y, width, height)
    local button = {
        x = x,
        y = y,
        width = width or love.graphics.getWidth(),
        height = height or love.graphics.getHeight(),
        text = text
    };
    table.insert(hud.buttons, button);

    local mx, my = love.mouse.getPosition();
    return physics.testPointRectangle(mx, my, button.x, button.y, button.width, button.height) and love.mouse.isDown(1);
end
function hud.buttonCentered(text, x, y, width, height)
    return hud.button(text, x - width / 2, y - height / 2, width, height);
end

-- ==================== OBJ LOADER LIB ====================
function objLoader.load(file)
    local lines = {}
    for line in love.filesystem.lines(file) do
        table.insert(lines, line)
    end
    return objLoader.parse(lines)
end
function objLoader.parse(object)
    local obj = {
        v	= {}, -- List of vertices - x, y, z, [w]=1.0
        vt	= {}, -- Texture coordinates - u, v, [w]=0
        vn	= {}, -- Normals - x, y, z
        vp	= {}, -- Parameter space vertices - u, [v], [w]
        f	= {}, -- Faces
    }

    for _, line in ipairs(object) do
        local l = objLoader.string_split(line, "%s+")

        if l[1] == "v" then
            local v = {
                x = tonumber(l[2]),
                y = tonumber(l[3]),
                z = tonumber(l[4]),
                w = tonumber(l[5]) or 1.0
            }
            table.insert(obj.v, v)
        elseif l[1] == "vt" then
            local vt = {
                u = tonumber(l[2]),
                v = tonumber(l[3]),
                w = tonumber(l[4]) or 0
            }
            table.insert(obj.vt, vt)
        elseif l[1] == "vn" then
            local vn = {
                x = tonumber(l[2]),
                y = tonumber(l[3]),
                z = tonumber(l[4]),
            }
            table.insert(obj.vn, vn)
        elseif l[1] == "vp" then
            local vp = {
                u = tonumber(l[2]),
                v = tonumber(l[3]),
                w = tonumber(l[4]),
            }
            table.insert(obj.vp, vp)
        elseif l[1] == "f" then
            local f = {}

            for i=2, #l do
                local split = objLoader.string_split(l[i], "/")
                local v = {}

                v.v = tonumber(split[1])
                v.vt = tonumber(split[2])
                v.vn = tonumber(split[3])

                table.insert(f, v)
            end

            table.insert(obj.f, f)
        end
    end

    return obj
end

-- http://wiki.interfaceware.com/534.html
function objLoader.string_split(s, d)
    local t = {}
    local i = 0
    local f
    local match = '(.-)' .. d .. '()'

    if string.find(s, d) == nil then
        return {s}
    end

    for sub, j in string.gmatch(s, match) do
        i = i + 1
        t[i] = sub
        f = j
    end

    if i ~= 0 then
        t[i+1] = string.sub(s, f)
    end

    return t
end

-- ==================== PHYSICS LIB ====================
function physics.testPointRectangle(x1, y1, x2, y2, w2, h2)
    return x1 <= x2 + w2 and x1 >= x2 and y1 <= y2 + h2 and y1 >= y2;
end
function physics.testSphereSphere(positionA, radiusA, positionB, radiusB)
    local delta = vector.subtract(positionA, positionB);
    local lengthSqr = vector.lengthSqr(delta);
    return lengthSqr <= radiusA * radiusA + radiusB * radiusB;
end