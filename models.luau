local Gltf = require("gltf")

config = config or {}

type Placed = {
    mesh: LuauMesh,
    name: string,
    euler: Vec3, 
    baseRotation: Quat?,
    rotationReference: Quat?,
    isGif: boolean?,
    isFolderGif: boolean?,
    frames: { any }?,
    isPlaying: boolean?,
    currentFrame: number?,
    frameTimer: number?,
    texture: any?,
    isLooping: boolean?,
    playbackSpeed: number?,
    trackHand: boolean?,
    trackedPlayerId: number?,
    trackLeftHand: boolean?,
    trackRightHand: boolean?,
    handOffsetPos: Vec3?,
    handOffsetRot: Vec3?,
    targetSearchText: string?,
}

type CharacterMesh = {
    mesh: LuauMesh,
    charIndex: number,
}

type PlacedText = {
    name: string,
    text: string,
    position: Vec3,
    euler: Vec3,
    baseRotation: Quat?,
    rotationReference: Quat?,
    scale: Vec3,
    color: any?,
    visible: boolean,
    meshes: { CharacterMesh },
    brightness: number?,
    is3D: boolean?,
    isRainbow: boolean?,
    rainbowSpeed: number?,
}

type Light = {
    position: Vec3,
    intensity: number,
    color: Vec3,
    radius: number,
    lightType: string, -- "Area" or "Player"
    isPlayerLight: boolean?,
    trackedPlayerId: number?,
    name: string,
}

local modelFiles: { string } = {}
local imageFiles: { string } = {}
local placedModels: { Placed } = {}
local placedImages: { Placed } = {}
local placedTexts: { PlacedText } = {}
local lights: { any } = {}
local modelSpawnCount = 0
local imageSpawnCount = 0
local textSpawnCount = 0
local lightSpawnCount = 0
local status = " "
local lightTabOpen = false
local lightIndex = 1

if config.hudSpeedEnabled == nil then config.hudSpeedEnabled = false end
config.hudSpeedPlayerId = config.hudSpeedPlayerId or nil
config.hudSpeedOffset = config.hudSpeedOffset or Vec3.new(0, 0, 400)
config.hudSpeedFontSize = config.hudSpeedFontSize or 1
local savedHudSpeedColor = config.hudSpeedColor
if savedHudSpeedColor and savedHudSpeedColor.r and savedHudSpeedColor.g and savedHudSpeedColor.b then
    config.hudSpeedColor = LinearColor.new(
        savedHudSpeedColor.r,
        savedHudSpeedColor.g,
        savedHudSpeedColor.b,
        savedHudSpeedColor.a or 1
    )
else
    config.hudSpeedColor = LinearColor.new(1, 1, 1, 1)
end
local hudSpeedText: PlacedText? = nil
local hudSpeedPreviousPosition: Vec3? = nil
local hudSpeedPreviousPlayerId: any? = nil
local hudSpeed = 0

local function copyPosition(position: Vec3): Vec3
    return Vec3.new(position.x, position.y, position.z)
end

local pendingSpawnModelFile: string? = nil
local pendingSpawnModelDelay: number = 0
local pendingSpawnModelScale: number? = nil

local pendingSpawnImageFile: string? = nil
local pendingSpawnImageDelay: number = 0

local fontCache: { [string]: { vertices: any, triangles: any, normals: any, uVs: any } } = {}

local function drawCircle(position: Vec3, radius: number, direction: Vec3, colour: Vec3, lineWidth: number, lifetime: number)
    local arbritaryVector = if direction ~= Vec3.upVector then Vec3.upVector else Vec3.rightVector
    local upDirection = direction:cross(arbritaryVector):normalize()
    local rightDirection = direction:cross(upDirection):normalize()
    local previousPoint = nil
    for theta = 0, math.pi * 2, math.pi / 64 do
        local pointPos = upDirection * math.sin(theta) + rightDirection * math.cos(theta)
        if previousPoint then
            WorldDraw.drawLine(
                position + (previousPoint * radius),
                position + (pointPos * radius),
                colour.x,
                colour.y,
                colour.z,
                lineWidth,
                lifetime
            )
        end
        previousPoint = pointPos
    end
end

local function fillCircle(
    position: Vec3,
    radius: number,
    direction: Vec3 | nil,
    colour: Vec3,
    lineWidth: number,
    lifetime: number
)
    if not direction then
        direction = camera:getSmoothedRotation():getForwardVector()
    end
    assert(direction, "Direction should not be nil")
    local arbritaryVector = if direction ~= Vec3.upVector then Vec3.upVector else Vec3.rightVector
    local upDirection = direction:cross(arbritaryVector):normalize()
    local rightDirection = direction:cross(upDirection):normalize()
    for theta = 0, math.pi, math.pi / 64 do
        local pointPos = upDirection * math.sin(theta) + rightDirection * math.cos(theta)
        WorldDraw.drawLine(
            position - (pointPos * radius),
            position + (pointPos * radius),
            colour.x,
            colour.y,
            colour.z,
            lineWidth,
            lifetime
        )
    end
end

local function HSVToRGB(h: number, s: number, v: number)
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end
    return {r = r, g = g, b = b}
end

config.savedOffsets = config.savedOffsets or { }

local defaultModelOffsets = {
    ["micrpohone/model.gltf"] = {
        leftPos = Vec3.new(1.6, -2.8, -0.9), leftRot = Vec3.new(0, 0, 0),
        rightPos = Vec3.new(3, -4.5, -1.8), rightRot = Vec3.new(0, 0, 0)
    },
    ["sword.glb"] = {
        leftPos = Vec3.new(0, 0, 0), leftRot = Vec3.new(0, 180, 0),
        rightPos = Vec3.new(0, 0, 0), rightRot = Vec3.new(0, 180, 0)
    }
}

local function loadOffsetsForEntry(entry: Placed)
    if entry.leftOffsetPos then return end 
    local fname = entry.fileName or ""
    
    local saved = config.savedOffsets[fname]
    local def = defaultModelOffsets[fname]
    
    entry.leftOffsetPos = (saved and saved.leftPos) or (def and def.leftPos) or Vec3.new(0, 0, 0)
    entry.leftOffsetRot = (saved and saved.leftRot) or (def and def.leftRot) or Vec3.new(0, 0, 0)
    entry.rightOffsetPos = (saved and saved.rightPos) or (def and def.rightPos) or Vec3.new(0, 0, 0)
    entry.rightOffsetRot = (saved and saved.rightRot) or (def and def.rightRot) or Vec3.new(0, 0, 0)
end

local function saveOffsetsForEntry(entry: Placed)
    local fname = entry.fileName or ""
    config.savedOffsets[fname] = {
        leftPos = entry.leftOffsetPos,
        leftRot = entry.leftOffsetRot,
        rightPos = entry.rightOffsetPos,
        rightRot = entry.rightOffsetRot
    }
end

local function ensureSecondaryMesh(entry: Placed)
    if not entry.leftMesh then
        local m = WorldDraw.spawnMesh()
        if m then
            m.vertices = entry.mesh.vertices
            m.triangles = entry.mesh.triangles
            m.normals = entry.mesh.normals
            m.uVs = entry.mesh.uVs
            m.texture = entry.mesh.texture
            m.normalTexture = entry.mesh.normalTexture
            m.color = entry.mesh.color
            m.scale = entry.mesh.scale
            m:draw()
            entry.leftMesh = m
        end
    end
end

local function refreshFiles()
    modelFiles = {}
    imageFiles = {}
    local foundGifFolders = {}

    for _, f in ipairs(LuauFile.listFiles("")) do
        local lower = f:lower()
        
        if lower:sub(1, 7) == "assets/" then
            if lower:sub(1, 12) ~= "assets/font/" then
                if lower:match("%.glb$") or lower:match("%.gltf$") then
                    if lower ~= "assets/plane-for-images_dont-delete.glb" then
                        table.insert(modelFiles, f)
                    end
                elseif lower:match("%.png$") or lower:match("%.jpe?g$") or lower:match("%.bmp$") or lower:match("%.gif$") then
                    local folderMatch = f:match("^(.*gifs/[^/]+)/%d+%.[a-z0-9]+$")
                    if folderMatch then
                        if not foundGifFolders[folderMatch] then
                            foundGifFolders[folderMatch] = true
                            table.insert(imageFiles, folderMatch)
                        end
                    else
                        table.insert(imageFiles, f)
                    end
                end
            end
        end
    end
end

function onTransitionBegin()
    refreshFiles()
end

local function inFrontOfCamera(): Vec3
    return camera.position + camera.rotation:getForwardVector() * 400
end

local function getWorldRotation(baseRotation: Quat?, rotationReference: Quat?, euler: Vec3): Quat
    local base = baseRotation or Quat.identity
    local reference = rotationReference or Quat.identity
    return base * reference:inverse() * Quat.fromEuler(euler.x, euler.y, euler.z)
end

local function getCharFileName(char: string): string?
    if char >= "A" and char <= "Z" then
        return "upper_" .. char .. ".glb"
    elseif char >= "a" and char <= "z" then
        return "lower_" .. char .. ".glb"
    elseif char >= "0" and char <= "9" then
        return char .. ".glb"
    end
    
    local symbols: { [string]: string } = {
    ["!"] = "exclamation.glb",
    ["\""] = "quote.glb",
    ["#"] = "hash.glb",
    ["$"] = "dollar.glb",
    ["%"] = "percent.glb",
    ["&"] = "ampersand.glb",
    ["'"] = "apostrophe.glb",
    ["("] = "left_parenthesis.glb",
    [")"] = "right_parenthesis.glb",
    ["*"] = "asterisk.glb",
    ["+"] = "plus.glb",
    [","] = "comma.glb",
    ["-"] = "hyphen.glb",
    ["."] = "period.glb",
    ["/"] = "slash.glb",
    [":"] = "colon.glb",
    [";"] = "semicolon.glb",
    ["<"] = "less_than.glb",
    ["="] = "equals.glb",
    [">"] = "greater_than.glb",
    ["?"] = "question.glb",
    ["@"] = "at.glb",
    ["["] = "left_bracket.glb",
    ["\\"] = "backslash.glb",
    ["]"] = "right_bracket.glb",
    ["^"] = "caret.glb",
    ["_"] = "underscore.glb",
    ["`"] = "backtick.glb",
    ["{"] = "left_brace.glb",
    ["|"] = "pipe.glb",
    ["}"] = "right_brace.glb",
    ["~"] = "tilde.glb",
}
    return symbols[char]
end

local function getFontCharData(fileName: string, is2D: boolean?)
    local cacheKey = (is2D and "2D_" or "") .. fileName
    if fontCache[cacheKey] then
        return fontCache[cacheKey]
    end
    
    local folderPath = is2D and "assets/font/2D/" or "assets/font/"
    local filePath = folderPath .. fileName
    
    local bytes = LuauFile.loadBytes(filePath)
    if #bytes == 0 then return nil end
    local ok, vertices, triangles, normals, uvs = pcall(Gltf.parseGlb, bytes, "")
    if not ok then return nil end
    
    fontCache[cacheKey] = {
        vertices = vertices,
        triangles = triangles,
        normals = normals,
        uVs = uvs,
    }
    return fontCache[cacheKey]
end

local ADVANCE_WIDTHS: { [string]: number } = {
    ["A"] = 0.6720, ["B"] = 0.5830, ["C"] = 0.5500, ["D"] = 0.6600, ["E"] = 0.6170, ["F"] = 0.5080,
    ["G"] = 0.6950, ["H"] = 0.6070, ["I"] = 0.2900, ["J"] = 0.4500, ["K"] = 0.7050, ["L"] = 0.5980,
    ["M"] = 0.8250, ["N"] = 0.6900, ["O"] = 0.6520, ["P"] = 0.6800, ["Q"] = 0.6500, ["R"] = 0.6400,
    ["S"] = 0.6450, ["T"] = 0.5950, ["U"] = 0.6000, ["V"] = 0.6950, ["W"] = 0.8710, ["X"] = 0.6720,
    ["Y"] = 0.6820, ["Z"] = 0.6200,
    ["a"] = 0.5170, ["b"] = 0.5460, ["c"] = 0.5050, ["d"] = 0.5450, ["e"] = 0.5650, ["f"] = 0.3760,
    ["g"] = 0.5490, ["h"] = 0.5200, ["i"] = 0.2500, ["j"] = 0.3120, ["k"] = 0.5550, ["l"] = 0.2480,
    ["m"] = 0.7650, ["n"] = 0.5080,["o"] = 0.5820, ["p"] = 0.5500, ["q"] = 0.5550, ["r"] = 0.3880,
    ["s"] = 0.5130, ["t"] = 0.3780, ["u"] = 0.5090, ["v"] = 0.5090, ["w"] = 0.7900, ["x"] = 0.5300,
    ["y"] = 0.5020, ["z"] = 0.4800,
    ["0"] = 0.6440, ["1"] = 0.3500, ["2"] = 0.6310, ["3"] = 0.6340, ["4"] = 0.6850, ["5"] = 0.6300,
    ["6"] = 0.6400, ["7"] = 0.5300, ["8"] = 0.6440, ["9"] = 0.6400,
    [" "] = 0.2330, ["!"] = 0.2930, ["\""] = 0.4560, ["#"] = 0.8680, ["$"] = 0.6700, ["%"] = 0.8020,
    ["&"] = 0.7640, ["'"] = 0.2590, ["("] = 0.3910, [")"] = 0.3910, ["*"] = 0.5010, ["+"] = 0.6430,
    [","] = 0.3170, ["-"] = 0.4620, ["."] = 0.2700, ["/"] = 0.5120, [":"] = 0.2700, [";"] = 0.3170,
    ["<"] = 0.6450, ["="] = 0.6440, [">"] = 0.6450, ["?"] = 0.4820, ["@"] = 1.0000, ["["] = 0.3920,
    ["\\"] = 0.5120, ["]"] = 0.3920, ["^"] = 0.6020, ["_"] = 0.5620, ["`"] = 0.3200, ["{"] = 0.3240,
    ["|"] = 0.1950, ["}"] = 0.3240, ["~"] = 0.6280,
}

local function updateTextMeshTransforms(entry: PlacedText)
    if not entry.visible or #entry.meshes == 0 then return end

    local rotQuat = getWorldRotation(entry.baseRotation, entry.rotationReference, entry.euler)
    local rightVec: Vec3
    if (rotQuat :: any).getRightVector then
        rightVec = (rotQuat :: any):getRightVector()
    else
        local ry = math.rad(entry.euler.y)
        local rz = math.rad(entry.euler.z)
        rightVec = Vec3.new(math.cos(ry) * math.cos(rz), math.sin(rz), -math.sin(ry) * math.cos(rz))
    end

    local charPositions: { number } = {}
    local currentCursorX = 0
    local scaleMultiplier = 100 * entry.scale.x

    for i = 1, #entry.text do
        charPositions[i] = currentCursorX
        local char = entry.text:sub(i, i)
        local defaultWidth = (char == " ") and 0.3 or 0.5
        local charWidth = ADVANCE_WIDTHS[char] or defaultWidth
        currentCursorX += charWidth * scaleMultiplier
    end

    local totalWidth = currentCursorX
    local startOffset = -totalWidth / 2

    for _, item in ipairs(entry.meshes) do
        local m = item.mesh
        local exactX = charPositions[item.charIndex] + startOffset
        
        m.position = entry.position + Vec3.new(
            rightVec.x * exactX, 
            rightVec.y * exactX, 
            rightVec.z * exactX
        )
        m.rotation = rotQuat
        m.scale = Vec3.new(100 * entry.scale.x, 100 * entry.scale.y, 100 * entry.scale.z)
        
        if entry.color then
            m.color = entry.color
        end
        m:draw()
    end
end

local function rebuildTextMeshes(entry: PlacedText)
    for _, item in ipairs(entry.meshes) do
        item.mesh:destroy()
    end
    entry.meshes = {}

    if not entry.visible then return end

    for i = 1, #entry.text do
        local char = entry.text:sub(i, i)
        if char ~= " " then
            local fileName = getCharFileName(char)
            if fileName then
                local charData = getFontCharData(fileName, not entry.is3D) 
                if charData then
                    local mesh = WorldDraw.spawnMesh()
                    if mesh then
                        mesh.vertices = charData.vertices
                        mesh.triangles = charData.triangles
                        mesh.normals = charData.normals
                        mesh.uVs = charData.uVs
                        if entry.color and mesh.color then
                            mesh.color = entry.color
                        elseif mesh.color then
                            entry.color = mesh.color
                        end
                        table.insert(entry.meshes, { mesh = mesh, charIndex = i })
                    end
                end
            end
        end
    end

    updateTextMeshTransforms(entry)
end

local function spawnTextObject(initialText: string)
    textSpawnCount += 1
    local entry: PlacedText = {
        name = "Text #" .. textSpawnCount,
        text = initialText,
        position = inFrontOfCamera(),
        euler = Vec3.zeroVector,
        baseRotation = camera.rotation,
        rotationReference = Quat.identity,
        scale = Vec3.new(1, 1, 1),
        brightness = 1,
        color = nil,
        visible = true,
        is3D = true,
        meshes = {},
        isRainbow = false,
        rainbowSpeed = 1.0,
    }
    table.insert(placedTexts, entry)
    rebuildTextMeshes(entry)
    status = "Created " .. entry.name
end

local function destroyHudSpeedText()
    if not hudSpeedText then return end
    for _, item in ipairs(hudSpeedText.meshes) do
        item.mesh:destroy()
    end
    hudSpeedText = nil
end

local function ensureHudSpeedText()
    if hudSpeedText then return end
    hudSpeedText = {
        name = "HUD Speed",
        text = "0.00 m/s",
        position = inFrontOfCamera(),
        euler = Vec3.zeroVector,
        baseRotation = camera.rotation,
        rotationReference = Quat.identity,
        scale = Vec3.new(1, 1, 1),
        brightness = 1,
        color = config.hudSpeedColor,
        visible = true,
        is3D = false,
        meshes = {},
        isRainbow = false,
        rainbowSpeed = 1.0,
    }
    rebuildTextMeshes(hudSpeedText)
end

local function getHudSpeedPlayer()
    if not config.hudSpeedPlayerId then return nil end
    local sessions = getAllGameData and getAllGameData() or (getGameData and { getGameData() } or {})
    for i = 1, #sessions do
        local session = sessions[i]
        if session and session.getPlayerById then
            local player = session:getPlayerById(config.hudSpeedPlayerId)
            if player then return player end
        end
    end
    return nil
end

local function updateHudSpeedText(dt: number)
    if not config.hudSpeedEnabled then
        destroyHudSpeedText()
        hudSpeedPreviousPosition = nil
        hudSpeedPreviousPlayerId = nil
        return
    end

    ensureHudSpeedText()
    local player = getHudSpeedPlayer()
    if not player or not player.root or not player.root.position then
        hudSpeed = 0
        hudSpeedPreviousPosition = nil
    elseif hudSpeedPreviousPlayerId ~= config.hudSpeedPlayerId then
        hudSpeed = 0
        hudSpeedPreviousPosition = copyPosition(player.root.position)
        hudSpeedPreviousPlayerId = config.hudSpeedPlayerId
    elseif hudSpeedPreviousPosition and dt > 0 then
        hudSpeed = player.root.position:distance(hudSpeedPreviousPosition) / 100 / dt
        hudSpeedPreviousPosition = copyPosition(player.root.position)
    else
        hudSpeedPreviousPosition = copyPosition(player.root.position)
    end

    local newText = string.format("%.2f m/s", hudSpeed)
    if hudSpeedText.text ~= newText then
        hudSpeedText.text = newText
        rebuildTextMeshes(hudSpeedText)
    end

    hudSpeedText.scale = Vec3.new(config.hudSpeedFontSize, config.hudSpeedFontSize, config.hudSpeedFontSize)
    hudSpeedText.color = config.hudSpeedColor
    hudSpeedText.position = camera.position + camera.rotation:rotateVector(config.hudSpeedOffset)
    hudSpeedText.baseRotation = camera.rotation
    hudSpeedText.rotationReference = Quat.identity
    hudSpeedText.euler = Vec3.zeroVector
    updateTextMeshTransforms(hudSpeedText)
end

local function spawnModel(file: string, customScale: number?)
    local baseDir = file:match("^(.*)/[^/]+$") or ""

    local ok, vertices, triangles, normals, uvs, textures
    if file:lower():match("%.glb$") then
        local bytes = LuauFile.loadBytes(file)
        if #bytes == 0 then
            status = "Failed to read " .. file
            return
        end
        ok, vertices, triangles, normals, uvs, textures = pcall(Gltf.parseGlb, bytes, baseDir)
    else
        local text = LuauFile.loadText(file)
        if text == "" then
            status = "Failed to read " .. file
            return
        end
        ok, vertices, triangles, normals, uvs, textures = pcall(Gltf.parse, text, baseDir)
    end
    if not ok then
        status = "Failed to parse " .. file .. ": " .. tostring(vertices)
        return
    end

    local mesh = WorldDraw.spawnMesh()
    if mesh == nil then
        status = "Failed to spawn a mesh"
        return
    end
    mesh.position = inFrontOfCamera()
    mesh.rotation = camera.rotation
    local scale = customScale or 100
    mesh.scale = Vec3.new(scale, scale, scale)
    mesh.vertices = vertices
    mesh.triangles = triangles
    mesh.normals = normals
    mesh.uVs = uvs
    if textures then
        if textures.baseColor then
            mesh.texture = LuauTexture.fromBytes(textures.baseColor)
        end
        if textures.normal then
            mesh.normalTexture = LuauTexture.fromBytes(textures.normal)
        end
    end
    mesh:draw()

    modelSpawnCount += 1
    local cleanName = file:gsub("^assets/", "")
    table.insert(placedModels, {
        mesh = mesh,
        name = cleanName .. " #" .. modelSpawnCount,
        fileName = cleanName,
        euler = Vec3.zeroVector,
        baseRotation = camera.rotation,
        rotationReference = Quat.identity,
    })
    status = "Spawned " .. cleanName .. " (" .. #vertices .. " vertices)"
end

local function spawnImage(imageFile: string)
    local planeFile = "assets/plane-for-images_dont-delete.glb"
    
    local bytes = LuauFile.loadBytes(planeFile)
    if #bytes == 0 then
        status = "Failed to read " .. planeFile
        return
    end
    
    local ok, vertices, triangles, normals, uvs, textures = pcall(Gltf.parseGlb, bytes, "")
    if not ok then
        status = "Failed to parse " .. planeFile
        return
    end

    local mesh = WorldDraw.spawnMesh()
    if mesh == nil then
        status = "Failed to spawn a mesh"
        return
    end
    
    mesh.position = inFrontOfCamera()
    local imageRotation = Quat.fromEuler(180, 0, 180)
    mesh.rotation = camera.rotation * imageRotation
    mesh.scale = Vec3.new(100, 100, 100)
    mesh.vertices = vertices
    mesh.triangles = triangles
    mesh.normals = normals
    mesh.uVs = uvs
    
    local isFolderGif = not imageFile:lower():match("%.[a-z0-9]+$")
    local isNativeGif = imageFile:lower():match("%.gif$") ~= nil
    local isGif = isFolderGif or isNativeGif

    local tex = nil
    local loadedFrames = nil

    if isFolderGif then
        loadedFrames = {}
        local i = 1
        while true do
            local frameTex = LuauFile.loadTexture(imageFile .. "/" .. i .. ".jpg") 
                          or LuauFile.loadTexture(imageFile .. "/" .. i .. ".png")
            if not frameTex then 
                break 
            end
            table.insert(loadedFrames, frameTex)
            i += 1
        end

        if #loadedFrames > 0 then
            tex = loadedFrames[1]
        else
            status = "Failed to find any frames in folder: " .. imageFile
            mesh:destroy()
            return
        end
    else
        tex = LuauFile.loadTexture(imageFile)
        if tex and isNativeGif then
            tex.currentFrame = 1
        end
    end
    
    if tex then
        mesh.texture = tex
    else
        status = "Failed to load texture data for: " .. imageFile
        mesh:destroy()
        return
    end
    
    mesh:draw()

    imageSpawnCount += 1
    local cleanName = imageFile:gsub("^assets/", "")
    table.insert(placedImages, {
        mesh = mesh,
        name = cleanName .. " #" .. imageSpawnCount,
        euler = Vec3.new(180, 0, 0),
        baseRotation = camera.rotation,
        rotationReference = Quat.fromEuler(180, 0, 0),
        isGif = isGif,
        isFolderGif = isFolderGif,
        frames = loadedFrames,
        isPlaying = false,
        currentFrame = 1,
        frameTimer = 0,
        texture = tex,
        isLooping = true,
        playbackSpeed = 15,
    })
    status = "Spawned image " .. cleanName
end

local function renderTextureTree(node: any, entry: Placed)
    local folderNames = {}
    for name in pairs(node.folders) do
        table.insert(folderNames, name)
    end
    table.sort(folderNames)

    for _, folderName in ipairs(folderNames) do
        local subNode = node.folders[folderName]
        if Gui.treeNode(folderName) then
            Gui.indent()
            renderTextureTree(subNode, entry)
            Gui.unindent()
            Gui.treePop()
        end
    end

    table.sort(node.files, function(a, b) return a.name:lower() < b.name:lower() end)

    for _, fileData in ipairs(node.files) do
        Gui.pushId("tex_" .. fileData.fullPath)
        
        if Gui.selectable(fileData.name, false) then
            local isFolderGif = not fileData.fullPath:lower():match("%.[a-z0-9]+$")
            local isNativeGif = fileData.fullPath:lower():match("%.gif$") ~= nil
            local isGif = isFolderGif or isNativeGif

            local tex = nil
            local loadedFrames = nil

            if isFolderGif then
                loadedFrames = {}
                local i = 1
                while true do
                    local frameTex = LuauFile.loadTexture(fileData.fullPath .. "/" .. i .. ".jpg") 
                                  or LuauFile.loadTexture(fileData.fullPath .. "/" .. i .. ".png")
                    if not frameTex then break end
                    table.insert(loadedFrames, frameTex)
                    i += 1
                end

                if #loadedFrames > 0 then
                    tex = loadedFrames[1]
                end
            else
                tex = LuauFile.loadTexture(fileData.fullPath)
                if tex and isNativeGif then
                    tex.currentFrame = 1
                end
            end
            
            local cleanEntryName = entry.name:gsub("^assets/", "")
            if tex then
                entry.mesh.texture = tex
                entry.mesh:draw()
                
                entry.isGif = isGif
                entry.isFolderGif = isFolderGif
                entry.frames = loadedFrames
                entry.texture = tex
                if isGif then
                    entry.isPlaying = true
                    entry.currentFrame = 1
                    entry.frameTimer = 0
                    entry.isLooping = true
                    entry.playbackSpeed = 15
                end
                
                status = "Applied " .. fileData.cleanPath .. " to " .. cleanEntryName
            else
                status = "Failed to load " .. fileData.cleanPath
            end
        end

        Gui.popId()
    end
end

local function spawnLight(lightType: string)
    lightSpawnCount += 1
    local light = WorldDraw.spawnPointLight(
        inFrontOfCamera(),
        10000,
        Vec3.new(1, 1, 1),
        1000
    )
    if light then
        table.insert(lights, {
            position = light.position,
            intensity = light.intensity,
            color = Vec3.new(1, 1, 1),
            radius = light.radius,
            lightType = lightType,
            isPlayerLight = false,
            trackedPlayerId = nil,
            name = lightType .. " Light #" .. lightSpawnCount,
            __internalLight = light,
        })
        lightIndex = #lights
        status = "Spawned " .. lightType .. " Light"
    else
        status = "Failed to spawn light"
    end
end

local function spawnPlayerLight(playerId: number)
    lightSpawnCount += 1
    local light = WorldDraw.spawnPointLight(
        inFrontOfCamera(),
        10000,
        Vec3.new(1, 1, 1),
        1000
    )
    if light then
        table.insert(lights, {
            position = light.position,
            intensity = light.intensity,
            color = Vec3.new(1, 1, 1),
            radius = light.radius,
            lightType = "Player",
            isPlayerLight = true,
            trackedPlayerId = playerId,
            name = "Player Light #" .. lightSpawnCount,
            __internalLight = light,
        })
        lightIndex = #lights
        status = "Spawned Player Light"
    else
        status = "Failed to spawn light"
    end
end

local function updateLightObjects()
    for i, entry in ipairs(lights) do
        if entry.__internalLight then
            -- Update position for player lights
            if entry.isPlayerLight and entry.trackedPlayerId then
                local sessions = getAllGameData and getAllGameData() or (getGameData and { getGameData() } or {})
                local targetPlayer = nil
                for j = 1, #sessions do
                    local session = sessions[j]
                    if session and session.getPlayerById then
                        targetPlayer = session:getPlayerById(entry.trackedPlayerId)
                        if targetPlayer then break end
                    end
                end
                
                if targetPlayer and targetPlayer.root and targetPlayer.root.position then
                    -- Position light between player and camera
                    local playerPos = targetPlayer.root.position
                    local camPos = camera.position
                    entry.position = playerPos + (camPos - playerPos) * 0.3
                end
            end
            
            entry.__internalLight.position = entry.position
            entry.__internalLight.intensity = entry.intensity
            entry.__internalLight.color = entry.color
            entry.__internalLight.radius = entry.radius
        end
    end
end

local function destroyLight(index: number)
    if lights[index] and lights[index].__internalLight then
        lights[index].__internalLight:destroy()
    end
    table.remove(lights, index)
    if lightIndex > #lights and lightIndex > 1 then
        lightIndex -= 1
    end
end

local function getPlayersList()
    local players = {}
    local sessions = getAllGameData and getAllGameData() or (getGameData and { getGameData() } or {})
    for i = 1, #sessions do
        local session = sessions[i]
        if session and session.players then
            for j = 1, #session.players do
                local pInfo = session.players[j]
                if pInfo and pInfo.playerId then
                    local p = session.getPlayerById and session:getPlayerById(pInfo.playerId) or pInfo
                    if p and p.playerName then
                        table.insert(players, { id = pInfo.playerId, name = p.playerName })
                    end
                end
            end
        end
    end
    return players
end

local function onLightsGui()
    if status ~= "" then Gui.textDisabled(status) end

    lightTabOpen = Gui.checkbox("Show Light Visualizations", lightTabOpen)

    if Gui.button(Icon.Lightbulb .. "  Spawn Light") then
        spawnLight("Area")
    end
    Gui.sameLine()
    if Gui.buttonColored(LinearColor.new(1,0,0,1), Icon.Trash .. "  Remove All") then
        for i = #lights, 1, -1 do
            destroyLight(i)
        end
        status = "Cleared all lights"
    end

    Gui.separatorText("Spawn Player Light")
    Gui.textDisabled("Spawn lights that track a player")
    local players = getPlayersList() or {}
    if #players == 0 then
        Gui.textDisabled("No players available")
    else
        if Gui.beginListBox("##PlayerListForLight") then
            for _, p in ipairs(players) do
                if Gui.selectable(p.name, false) then
                    spawnPlayerLight(p.id)
                end
            end
        end
        Gui.endListBox()
    end

    Gui.separatorText("Lights (" .. #lights .. ")")

    if Gui.beginListBox("##LightsList") then
        for i = 1, #lights do
            if Gui.selectable(lights[i].name, lightIndex == i) then
                lightIndex = i
            end
        end
    end
    Gui.endListBox()

    if lightIndex >= 1 and lightIndex <= #lights then
        local light = lights[lightIndex]
        Gui.newLine()
        Gui.separatorText("Edit")

        light.name = Gui.inputText("Light Name", light.name)
        
        if not light.isPlayerLight then
            Gui.separatorText("Transform")
            light.position = Gui.dragFloat3("Position", light.position, 1, -1000000, 1000000)
            Gui.sameLine()
            if Gui.smallButton("To Camera") then
                light.position = inFrontOfCamera()
            end
        else
            Gui.separatorText("Player")
            local selectedPlayer = nil
            for _, p in ipairs(players) do
                if p.id == light.trackedPlayerId then
                    selectedPlayer = p
                    break
                end
            end
            if selectedPlayer then
                Gui.text(selectedPlayer.name)
            else
                Gui.textDisabled("Player not found")
            end
        end

        Gui.separatorText("Properties")
        light.intensity = Gui.dragFloat("Intensity", light.intensity, 100, 0, 1000000)
        light.radius = Gui.dragFloat("Radius", light.radius, 10, 0, 50000)
        
        local newColor = Gui.colorEdit("Color##light_" .. lightIndex, LinearColor.new(light.color.x, light.color.y, light.color.z, 1))
        light.color = Vec3.new(newColor.r, newColor.g, newColor.b)

        Gui.separatorText("Actions")
        if Gui.button(Icon.Copy .. "  Duplicate") then
            lightSpawnCount += 1
            local newLight = WorldDraw.spawnPointLight(
                light.position,
                light.intensity,
                light.color,
                light.radius
            )
            if newLight then
                table.insert(lights, {
                    position = newLight.position,
                    intensity = newLight.intensity,
                    color = light.color,
                    radius = newLight.radius,
                    lightType = light.lightType,
                    isPlayerLight = light.isPlayerLight,
                    trackedPlayerId = light.trackedPlayerId,
                    name = light.name .. " (copy)",
                    __internalLight = newLight,
                })
                lightIndex = #lights
            end
        end

        Gui.sameLine()
        if Gui.buttonColored(LinearColor.new(1,0,0,1), Icon.Trash .. "  Delete") then
            destroyLight(lightIndex)
        end
    end
end

local function onHudGui()
    local newEnabled = Gui.checkbox("Show Player Speed", config.hudSpeedEnabled)
    if newEnabled ~= config.hudSpeedEnabled then
        config.hudSpeedEnabled = newEnabled
        hudSpeedPreviousPosition = nil
        hudSpeedPreviousPlayerId = nil
        if saveConfig then saveConfig() end
    end

    Gui.separatorText("Player")
    local players = getPlayersList()
    if Gui.beginListBox("##HudSpeedPlayers") then
        for _, player in ipairs(players) do
            local isSelected = config.hudSpeedPlayerId == player.id
            if Gui.selectable(player.name, isSelected) then
                config.hudSpeedPlayerId = player.id
                hudSpeedPreviousPosition = nil
                hudSpeedPreviousPlayerId = nil
                if saveConfig then saveConfig() end
            end
        end
        Gui.endListBox()
    end

    if not config.hudSpeedPlayerId then
        Gui.textDisabled("Select a player to measure")
    end

    local newOffset = Gui.dragFloat3("HUD Offset", config.hudSpeedOffset, 1, -1000, 1000)
    if newOffset ~= config.hudSpeedOffset then
        config.hudSpeedOffset = newOffset
        if saveConfig then saveConfig() end
    end

    local newFontSize = Gui.sliderFloat("Font Size", config.hudSpeedFontSize, 0.1, 10)
    if newFontSize ~= config.hudSpeedFontSize then
        config.hudSpeedFontSize = newFontSize
        if saveConfig then saveConfig() end
    end

    local newColor = Gui.colorEdit("Font Color", config.hudSpeedColor)
    if newColor ~= config.hudSpeedColor then
        config.hudSpeedColor = newColor
        if saveConfig then saveConfig() end
    end
    Gui.text(string.format("Current speed: %.2f m/s", hudSpeed))
end

local function renderPlacedItems(placedList: {Placed})
    local removeIndex: number? = nil
    for i, entry in ipairs(placedList) do
        Gui.pushId("placed_" .. entry.name .. "_" .. i)
        
        local isExpanded, keepOpen = Gui.collapsingHeader(entry.name, true)
        if keepOpen == false then
            removeIndex = i
        end

       if isExpanded then
            Gui.indent()
            local m = entry.mesh

            entry.trackHand = Gui.checkbox("Track hand", entry.trackHand == true)

            if entry.trackHand then
                if Gui.collapsingHeader("Tracking") then

                    loadOffsetsForEntry(entry)
                    
                    if entry.trackLeftHand == nil then entry.trackLeftHand = false end
                    if entry.trackRightHand == nil then entry.trackRightHand = true end

                    Gui.separatorText("Select Target to Track")
                    entry.targetSearchText = Gui.inputText(Icon.Search .. "  Search Target", entry.targetSearchText or "")
                    
                    local players = getPlayersList()
                    local searchText = string.lower(entry.targetSearchText or "")
                    if Gui.beginListBox("##TargetList_" .. tostring(i)) then
                        for _, p in ipairs(players) do
                            local lowerName = string.lower(p.name)
                            if searchText == "" or string.find(lowerName, searchText, 1, true) then
                                local isSelected = (entry.trackedPlayerId == p.id)
                                if Gui.selectable(p.name, isSelected) then
                                    entry.trackedPlayerId = p.id
                                end
                            end
                        end
                        Gui.endListBox()
                    end

                    local changed = false
                    
                    Gui.separatorText("Left Hand")
                        entry.trackLeftHand = Gui.checkbox("Enable Left Hand##" .. tostring(i), entry.trackLeftHand)
                        local nlPos = Gui.dragFloat3("Pos Offset##L_" .. tostring(i), entry.leftOffsetPos, 0.1, -1000, 1000)
                        local nlRot = Gui.dragFloat3("Rot Offset##L_" .. tostring(i), entry.leftOffsetRot, 1, -360, 360)
                        if nlPos ~= entry.leftOffsetPos or nlRot ~= entry.leftOffsetRot then
                            entry.leftOffsetPos = nlPos
                            entry.leftOffsetRot = nlRot
                            changed = true
                        end
                    
                    Gui.separatorText("Right Hand")
                        entry.trackRightHand = Gui.checkbox("Enable Right Hand##" .. tostring(i), entry.trackRightHand)
                        local nrPos = Gui.dragFloat3("Pos Offset##R_" .. tostring(i), entry.rightOffsetPos, 0.1, -1000, 1000)
                        local nrRot = Gui.dragFloat3("Rot Offset##R_" .. tostring(i), entry.rightOffsetRot, 1, -360, 360)
                        if nrPos ~= entry.rightOffsetPos or nrRot ~= entry.rightOffsetRot then
                            entry.rightOffsetPos = nrPos
                            entry.rightOffsetRot = nrRot
                            changed = true
                        end
                    
                    if changed then
                        saveOffsetsForEntry(entry)
                    end

                end
                Gui.newLine()
                Gui.separator()
            else
                m.position = Gui.dragFloat3("Position", m.position, 1, -1000000, 1000000)
                
                Gui.sameLine()
                if Gui.smallButton("Bring To Camera") then
                    m.position = inFrontOfCamera()
                end

                local newEuler = Gui.dragFloat3("Rotation", entry.euler, 1, -360, 360)
                if newEuler ~= entry.euler then
                    entry.euler = newEuler
                    m.rotation = getWorldRotation(entry.baseRotation, entry.rotationReference, newEuler)
                end
            end

            local scale = Gui.dragFloat("Scale", m.scale.x, 1, 0.001, 1000000)
            local newScale = Vec3.new(scale, scale, scale)
            if m.scale ~= newScale then
                m.scale = newScale
                if entry.leftMesh then entry.leftMesh.scale = newScale end
            end

            local newColor = Gui.colorEdit("Color", m.color)
            if newColor ~= m.color then
                m.color = newColor
                m:draw()
                if entry.leftMesh then 
                    entry.leftMesh.color = newColor
                    entry.leftMesh:draw()
                end
            end

            if Gui.buttonColored(LinearColor.new(1,0,0,1), Icon.Times .. "  Remove") then
                removeIndex = i
            end

            if entry.isGif then
                local totalFrames = 1
                if entry.isFolderGif and entry.frames then
                    totalFrames = #entry.frames
                elseif entry.texture and entry.texture.frameCount then
                    totalFrames = entry.texture.frameCount
                end

                Gui.separatorText("Playback")

                if Gui.button(Icon.ChevronLeft) then
                    entry.currentFrame = (entry.currentFrame or 1) - 1
                    if entry.currentFrame < 1 then entry.currentFrame = totalFrames end
                    
                    if entry.isFolderGif and entry.frames then
                        m.texture = entry.frames[entry.currentFrame]
                        m:draw()
                    elseif entry.texture then 
                        entry.texture.currentFrame = entry.currentFrame 
                    end
                end
                
                Gui.sameLine()
                if Gui.button(entry.isPlaying and Icon.Pause or Icon.Play) then
                    if not entry.isPlaying and entry.isLooping == false and (entry.currentFrame or 1) >= totalFrames then
                        entry.currentFrame = 1
                        if entry.isFolderGif and entry.frames then
                            m.texture = entry.frames[1]
                            m:draw()
                        elseif entry.texture then 
                            entry.texture.currentFrame = 1 
                        end
                    end
                    entry.isPlaying = not entry.isPlaying
                end
                
                Gui.sameLine()
                if Gui.button(Icon.ChevronRight) then
                    entry.currentFrame = (entry.currentFrame or 1) + 1
                    if entry.currentFrame > totalFrames then entry.currentFrame = 1 end
                    
                    if entry.isFolderGif and entry.frames then
                        m.texture = entry.frames[entry.currentFrame]
                        m:draw()
                    elseif entry.texture then 
                        entry.texture.currentFrame = entry.currentFrame 
                    end
                end
                
                Gui.sameLine()
                local newFrame = Gui.sliderInt("Frame", entry.currentFrame or 1, 1, totalFrames)
                if newFrame ~= entry.currentFrame then
                    entry.currentFrame = newFrame
                    if entry.isFolderGif and entry.frames then
                        m.texture = entry.frames[entry.currentFrame]
                        m:draw()
                    elseif entry.texture then 
                        entry.texture.currentFrame = entry.currentFrame 
                    end
                end
                
                entry.isLooping = Gui.checkbox("Loop", entry.isLooping ~= false)
                Gui.sameLine()
                entry.playbackSpeed = Gui.sliderInt("FPS", entry.playbackSpeed or 15, 1, 60)        
            end

            if #imageFiles > 0 and placedList == placedModels then
                if Gui.collapsingHeader("Apply texture##" .. tostring(i)) then
                    local rootNode = { folders = {}, files = {} }
                    
                    for _, fullPath in ipairs(imageFiles) do
                        local cleanPath = fullPath:gsub("^assets/", "")
                        local parts = {}
                        for part in cleanPath:gmatch("[^/]+") do
                            table.insert(parts, part)
                        end
                        
                        local current = rootNode
                        for j = 1, #parts - 1 do
                            local folderName = parts[j]
                            if not current.folders[folderName] then
                                current.folders[folderName] = { folders = {}, files = {} }
                            end
                            current = current.folders[folderName]
                        end
                        
                        local fileName = parts[#parts] or cleanPath
                        table.insert(current.files, {
                            name = fileName,
                            fullPath = fullPath,
                            cleanPath = cleanPath
                        })
                    end

                    if Gui.beginListBox("##TextureTree_" .. tostring(i)) then
                        renderTextureTree(rootNode, entry)
                        Gui.endListBox()
                    end
                end
            end

            Gui.unindent()
        end
        Gui.popId()
    end
    
    if removeIndex ~= nil then
                if placedList[removeIndex].leftMesh then
                    placedList[removeIndex].leftMesh:destroy()
                end
                placedList[removeIndex].mesh:destroy()
                table.remove(placedList, removeIndex)
            end
end

local function renderPlacedTexts(placedList: {PlacedText})
    local removeIndex: number? = nil
    for i, entry in ipairs(placedList) do
        Gui.pushId("placed_text_" .. entry.name .. "_" .. i)
        
        local isExpanded, keepOpen = Gui.collapsingHeader(entry.name, true)
        if keepOpen == false then
            removeIndex = i
        end

        if isExpanded then
            Gui.indent()
            
            local newText = Gui.inputText("Input Text", entry.text)
            if newText ~= entry.text then
                entry.text = newText
                rebuildTextMeshes(entry)
            end

            local newIs3D = Gui.checkbox("3D text", entry.is3D ~= false)
            if newIs3D ~= entry.is3D then
                entry.is3D = newIs3D
                rebuildTextMeshes(entry)
            end

            local newVisible = Gui.checkbox("Show text", entry.visible)
            if newVisible ~= entry.visible then
                entry.visible = newVisible
                rebuildTextMeshes(entry)
            end

            local newPos = Gui.dragFloat3("Position", entry.position, 1, -1000000, 1000000)
            if newPos ~= entry.position then
                entry.position = newPos
                updateTextMeshTransforms(entry)
            end

            Gui.sameLine()
            if Gui.smallButton("Bring To Camera") then
                entry.position = inFrontOfCamera()
                updateTextMeshTransforms(entry)
            end

            local newEuler = Gui.dragFloat3("Rotation", entry.euler, 1, -360, 360)
            if newEuler ~= entry.euler then
                entry.euler = newEuler
                updateTextMeshTransforms(entry)
            end

            local newScale = Gui.dragFloat3("Scale", entry.scale, 0.05, 0.001, 1000000)
            if newScale ~= entry.scale then
                entry.scale = newScale
                updateTextMeshTransforms(entry)
            end

            if entry.color then
                local newColor = Gui.colorEdit("Color", entry.color)
                if newColor ~= entry.color then
                    entry.color = newColor
                    for _, item in ipairs(entry.meshes) do
                        item.mesh.color = newColor
                        item.mesh:draw()
                    end
                end
                
                local currentBrightness = entry.brightness or 1
                local newBrightness = Gui.dragFloat("Brightness", currentBrightness, 0.1, 0, 100)
                
                if newBrightness ~= currentBrightness then
                    entry.brightness = newBrightness
                    
                    local r = entry.color.r * newBrightness
                    local g = entry.color.g * newBrightness
                    local b = entry.color.b * newBrightness
                    local a = entry.color.a
                    
                    local brightColor = LinearColor.new(r, g, b, a)
                    
                    for _, item in ipairs(entry.meshes) do
                        item.mesh.color = brightColor
                        item.mesh:draw()
                    end
                end

                local currentRainbow = entry.isRainbow or false
                local newRainbow = Gui.checkbox("Rainbow Color", currentRainbow)
                
                local currentSpeed = entry.rainbowSpeed or 1.0
                local newSpeed = currentSpeed
                if newRainbow then
                    Gui.sameLine()
                    newSpeed = Gui.sliderFloat("Speed", currentSpeed, 0.1, 10.0)
                end

                if newRainbow ~= currentRainbow or newSpeed ~= currentSpeed then
                    entry.isRainbow = newRainbow
                    entry.rainbowSpeed = newSpeed
                    
                    if not newRainbow and entry.color then
                        local mult = entry.brightness or 1
                        local r = entry.color.r * mult
                        local g = entry.color.g * mult
                        local b = entry.color.b * mult
                        local a = entry.color.a
                        
                        local brightColor = LinearColor.new(r, g, b, a)
                        for _, item in ipairs(entry.meshes) do
                            if item.mesh and item.mesh.color then
                                item.mesh.color = brightColor
                                item.mesh:draw()
                            end
                        end
                    end
                end

            end

            if Gui.buttonColored(LinearColor.new(1,0,0,1), Icon.Times .. "  Remove") then
                removeIndex = i
            end

            Gui.unindent()
        end
        Gui.popId()
    end
    
    if removeIndex ~= nil then
        for _, item in ipairs(placedList[removeIndex].meshes) do
            item.mesh:destroy()
        end
        table.remove(placedList, removeIndex)
    end
end

function onModelsGui()
    if status ~= "" then Gui.textDisabled(status) end

    if Gui.button(Icon.Sync .. "  Refresh Files") then refreshFiles() end
    Gui.sameLine()
    if Gui.buttonColored(LinearColor.new(1,0,0,1), Icon.Trash .. "  Remove All") then
        for _, entry in ipairs(placedModels) do entry.mesh:destroy() end
        placedModels = {}
        status = "Cleared all"
        WorldDraw.clearAll()
    end

    Gui.separatorText("Load models")
    if #modelFiles == 0 then
        Gui.textDisabled("no .glb / .gltf files found")
    else
        if Gui.beginListBox("##AvailableModelsList") then
            for i, file in ipairs(modelFiles) do
                Gui.pushId("model_" .. tostring(i))
                local cleanName = file:gsub("^assets/", "")
                if Gui.selectable(cleanName, false) then
                    status = "Loading..."
                    pendingSpawnModelFile = file
                    pendingSpawnModelScale = nil
                    pendingSpawnModelDelay = 0.1
                end
                Gui.popId()
            end
            Gui.endListBox()
        end
    end

    Gui.separatorText("Placed models (" .. #placedModels .. ")")
    renderPlacedItems(placedModels)
end

local function renderImageSelectListTree(node: any)
    local folderNames = {}
    for name in pairs(node.folders) do
        table.insert(folderNames, name)
    end
    table.sort(folderNames)

    for _, folderName in ipairs(folderNames) do
        local subNode = node.folders[folderName]
        if Gui.treeNode(folderName) then
            Gui.indent()
            renderImageSelectListTree(subNode)
            Gui.unindent()
            Gui.treePop()
        end
    end

    table.sort(node.files, function(a, b) return a.name:lower() < b.name:lower() end)

    for _, fileData in ipairs(node.files) do
        Gui.pushId("img_select_" .. fileData.fullPath)
        
        if Gui.selectable(fileData.name, false) then
            status = "Loading media..."
            pendingSpawnImageFile = fileData.fullPath
            pendingSpawnImageDelay = 0.1
        end

        Gui.popId()
    end
end

function onImagesGui()
    if status ~= "" then Gui.textDisabled(status) end

    if Gui.button(Icon.Sync .. "  Refresh Files") then refreshFiles() end
    Gui.sameLine()
    if Gui.buttonColored(LinearColor.new(1,0,0,1), Icon.Trash .. "  Remove All") then
        for _, entry in ipairs(placedImages) do entry.mesh:destroy() end
        placedImages = {}
        pendingSpawnImageFile = nil
        status = "Cleared all"
        WorldDraw.clearAll()
    end

    Gui.separatorText("Load images & GIFs")
    Gui.textDisabled("Use august-image.vercel.app for GIF creation")
    if #imageFiles == 0 then
        Gui.textDisabled("no image files found")
    else
        local rootNode = { folders = {}, files = {} }
        
        for _, fullPath in ipairs(imageFiles) do
            local cleanPath = fullPath:gsub("^assets/", "")
            
            local parts = {}
            for part in cleanPath:gmatch("[^/]+") do
                table.insert(parts, part)
            end
            
            local current = rootNode
            for j = 1, #parts - 1 do
                local folderName = parts[j]
                if not current.folders[folderName] then
                    current.folders[folderName] = { folders = {}, files = {} }
                end
                current = current.folders[folderName]
            end
            
            local fileName = parts[#parts] or cleanPath
            table.insert(current.files, {
                name = fileName,
                fullPath = fullPath
            })
        end

        if Gui.beginListBox("##AvailableImagesTree") then
            renderImageSelectListTree(rootNode)
            Gui.endListBox()
        end
    end

    Gui.separatorText("Placed media (" .. #placedImages .. ")")
    renderPlacedItems(placedImages)
end

function onTextGui()
    if status ~= "" then Gui.textDisabled(status) end

    if Gui.button(Icon.Plus .. "  Create Text Object") then
        spawnTextObject("THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG")
    end
    Gui.sameLine()
    if Gui.buttonColored(LinearColor.new(1,0,0,1), Icon.Trash .. "  Remove All") then
        for _, entry in ipairs(placedTexts) do
            for _, item in ipairs(entry.meshes) do item.mesh:destroy() end
        end
        placedTexts = {}
        status = "Cleared all"
        WorldDraw.clearAll()
    end

    Gui.separatorText("Placed text (" .. #placedTexts .. ")")
    renderPlacedTexts(placedTexts)
end

function tick(dt: number)

    local function getDistance(pointA, pointB)
        local delta = pointB - pointA :: Vec3
        return math.abs(math.sqrt(delta.x ^ 2 + delta.y ^ 2 + delta.z ^ 2))
    end

    local function resizeNameFromDistance(distance)
        local size = distance / 150 + 10
        return math.clamp(size, 1, 60)
    end

    -- Update and render lights
    updateLightObjects()
    WorldDraw.clear()
    
    if lightTabOpen then
        local gravityUp = gravity.upDirection ~= Vec3.zeroVector and gravity.upDirection or Vec3.upVector
        local gravityUpRotation = gravity.upRotation or Vec3.forwardVector
        
        for i = 1, #lights do
            local light = lights[i]
            fillCircle(
                light.position,
                2 * (Vec3.distance(light.position, camera.position) / 100),
                nil,
                light.color,
                0.3 * (Vec3.distance(light.position, camera.position) / 100),
                0
            )
            if lightIndex == i then
                fillCircle(
                    light.position + (camera.position - light.position):normalize(),
                    1 * (Vec3.distance(light.position, camera.position) / 100),
                    nil,
                    Vec3.zeroVector,
                    0.15 * (Vec3.distance(light.position, camera.position) / 100),
                    0
                )
            end
            drawCircle(light.position, light.radius, gravityUp, light.color, 1, 0)
            drawCircle(light.position, light.radius, gravityUpRotation ~= Vec3.forwardVector and gravityUpRotation:getForwardVector() or Vec3.upVector, light.color, 1, 0)
            drawCircle(light.position, light.radius, Vec3.rightVector, light.color, 1, 0)
        end
    end

    for _, entry in ipairs(placedTexts) do
        if entry.isRainbow and entry.visible and #entry.meshes > 0 then
            local speed = entry.rainbowSpeed or 1.0
            local timeFactor = os.clock() * speed
            local hue = timeFactor - math.floor(timeFactor)
            local rgb = HSVToRGB(hue, 1, 1)
            local mult = entry.brightness or 1
            
            local c = LinearColor.new(rgb.r * mult, rgb.g * mult, rgb.b * mult, 1)
            
            for _, item in ipairs(entry.meshes) do
                if item.mesh then
                    item.mesh.color = c
                    item.mesh:draw()
                end
            end
        end
    end

    if pendingSpawnModelFile ~= nil then
        pendingSpawnModelDelay -= dt
        if pendingSpawnModelDelay <= 0 then
            local fileToSpawn = pendingSpawnModelFile
            local scaleToSpawn = pendingSpawnModelScale
            pendingSpawnModelFile = nil
            pendingSpawnModelScale = nil
            spawnModel(fileToSpawn, scaleToSpawn)
        end
    end
    
    if pendingSpawnImageFile ~= nil then
        pendingSpawnImageDelay -= dt
        if pendingSpawnImageDelay <= 0 then
            local fileToSpawn = pendingSpawnImageFile
            pendingSpawnImageFile = nil
            spawnImage(fileToSpawn)
        end
    end

    local animatedLists = { placedImages, placedModels }
    
    for _, placedList in ipairs(animatedLists) do
        for _, entry in ipairs(placedList) do
            if entry.isGif and entry.isPlaying then
                entry.frameTimer = (entry.frameTimer or 0) + dt
                
                local fps = entry.playbackSpeed or 15
                local frameDuration = 1 / math.max(fps, 1)
                
                if entry.frameTimer > frameDuration then
                    entry.frameTimer = 0
                    entry.currentFrame = (entry.currentFrame or 1) + 1
                    
                    local totalFrames = 1
                    if entry.isFolderGif and entry.frames then
                        totalFrames = #entry.frames
                    elseif entry.texture and entry.texture.frameCount then
                        totalFrames = entry.texture.frameCount
                    end
                    
                    if entry.currentFrame > totalFrames then
                        if entry.isLooping == false then
                            entry.currentFrame = totalFrames
                            entry.isPlaying = false
                        else
                            entry.currentFrame = 1
                        end
                    end
                    
                    if entry.isFolderGif and entry.frames then
                        entry.mesh.texture = entry.frames[entry.currentFrame]
                        entry.mesh:draw()
                    elseif entry.texture then
                        entry.texture.currentFrame = entry.currentFrame
                    end
                end
            end

            if entry.trackHand and entry.trackedPlayerId then
                local sessions = getAllGameData and getAllGameData() or (getGameData and { getGameData() } or {})
                local targetPlayer = nil
                for i = 1, #sessions do
                    local session = sessions[i]
                    if session and session.getPlayerById then
                        targetPlayer = session:getPlayerById(entry.trackedPlayerId)
                        if targetPlayer then break end
                    end
                end

                if targetPlayer and targetPlayer.root then
                    local rightActive = entry.trackRightHand and targetPlayer.rightHand and targetPlayer.rightHand.position
                    local leftActive = entry.trackLeftHand and targetPlayer.leftHand and targetPlayer.leftHand.position
                    
                    if rightActive and leftActive then
                        ensureSecondaryMesh(entry)
                    elseif entry.leftMesh then
                        entry.leftMesh:destroy()
                        entry.leftMesh = nil
                    end
                    
                    if rightActive then
                        local worldRot = targetPlayer.root.rotation * targetPlayer.rightHand.rotation
                        local worldPos = targetPlayer.root.position + targetPlayer.root.rotation:rotateVector(targetPlayer.rightHand.position)
                        
                        local finalRot = worldRot * Quat.fromEuler(entry.rightOffsetRot.x, entry.rightOffsetRot.y, entry.rightOffsetRot.z)
                        local finalPos = worldPos + worldRot:rotateVector(entry.rightOffsetPos)
                        
                        entry.mesh.position = finalPos
                        entry.mesh.rotation = finalRot
                    end
                    
                    if leftActive then
                        local targetMesh = (rightActive and entry.leftMesh) or entry.mesh
                        
                        local worldRot = targetPlayer.root.rotation * targetPlayer.leftHand.rotation
                        local worldPos = targetPlayer.root.position + targetPlayer.root.rotation:rotateVector(targetPlayer.leftHand.position)
                        
                        local finalRot = worldRot * Quat.fromEuler(entry.leftOffsetRot.x, entry.leftOffsetRot.y, entry.leftOffsetRot.z)
                        local finalPos = worldPos + worldRot:rotateVector(entry.leftOffsetPos)
                        
                        targetMesh.position = finalPos
                        targetMesh.rotation = finalRot
                    end
                end
            else
                if entry.leftMesh then
                    entry.leftMesh:destroy()
                    entry.leftMesh = nil
                end
            end
        end
    end
end

function updateHud(dt: number)
    updateHudSpeedText(dt)
end

return {
    onModelsGui = onModelsGui,
    onImagesGui = onImagesGui,
    onTextGui = onTextGui,
    onHudGui = onHudGui,
    onLightsGui = onLightsGui,
    onTransitionBegin = onTransitionBegin,
    updateHud = updateHud,
    tick = tick,
}
