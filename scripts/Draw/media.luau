--!strict
-- Gifs and images and textures and frames
-- Yeah

local Media = {}

type TextureSource = {
	texture: any?,
	frames: { any }?,
	isGif: boolean,
	isFolderGif: boolean,
}

function Media.loadTextureSource(path: string): TextureSource
	-- folders are fake gifs made from numbered images btw say btw again
	local isFolderGif = not path:lower():match("%.[a-z0-9]+$")
	local isNativeGif = path:lower():match("%.gif$") ~= nil
	local frames = nil
	local texture = nil

	if isFolderGif then
		frames = {}
		local index = 1
		while true do
			local frameTexture = LuauFile.loadTexture(path .. "/" .. index .. ".jpg")
				or LuauFile.loadTexture(path .. "/" .. index .. ".png")
			if not frameTexture then
				break
			end
			table.insert(frames, frameTexture)
			index += 1
		end
		texture = #frames > 0 and frames[1] or nil
	else
		texture = LuauFile.loadTexture(path)
		if texture and isNativeGif then
			texture.currentFrame = 1
		end
	end

	return {
		texture = texture,
		frames = frames,
		isGif = isFolderGif or isNativeGif,
		isFolderGif = isFolderGif,
	}
end

function Media.getFrameCount(entry): number
	if entry.isFolderGif and entry.frames then
		return #entry.frames
	end
	if entry.texture and entry.texture.frameCount then
		return entry.texture.frameCount
	end
	return 1
end

function Media.setFrame(entry, frame: number)
	-- meshes need a redraw aftre folder frames swap
	entry.currentFrame = frame
	if entry.isFolderGif and entry.frames then
		entry.mesh.texture = entry.frames[frame]
		entry.mesh:draw()
	elseif entry.texture then
		entry.texture.currentFrame = frame
	end
end

function Media.advanceFrame(entry)
	-- stop on the last frame cause i hate loop
	local totalFrames = Media.getFrameCount(entry)
	local nextFrame = (entry.currentFrame or 1) + 1
	if nextFrame > totalFrames then
		if entry.isLooping == false then
			entry.currentFrame = totalFrames
			entry.isPlaying = false
		else
			nextFrame = 1
		end
	end

	if entry.isPlaying then
		Media.setFrame(entry, nextFrame)
	elseif entry.currentFrame == totalFrames then
		Media.setFrame(entry, totalFrames)
	end
end

return Media
