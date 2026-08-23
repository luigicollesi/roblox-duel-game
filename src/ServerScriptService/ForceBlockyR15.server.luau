local Players = game:GetService("Players")

local function makeBlocky(character: Model)
	local humanoid = character:WaitForChild("Humanoid")

	-- Confirmação adicional.
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		warn(
			("[Avatar] %s não nasceu como R15")
				:format(character.Name)
		)

		return
	end

	------------------------------------------------------------
	-- PEGAR A APARÊNCIA QUE O JOGADOR JÁ ESTÁ USANDO
	--
	-- Assim preservamos:
	-- camisa
	-- calça
	-- cabelo
	-- acessórios
	-- face
	-- layered clothing
	------------------------------------------------------------

	local description =
		humanoid:GetAppliedDescription()

	------------------------------------------------------------
	-- REMOVER BODY PACKAGES
	--
	-- 0 = parte padrão/blocky do Roblox.
	------------------------------------------------------------

	description.Head = 0
	description.Torso = 0

	description.LeftArm = 0
	description.RightArm = 0

	description.LeftLeg = 0
	description.RightLeg = 0

	------------------------------------------------------------
	-- PROPORÇÕES BLOCKY
	------------------------------------------------------------

	description.BodyTypeScale = 0
	description.ProportionScale = 0

	------------------------------------------------------------
	-- TAMANHO PADRONIZADO
	------------------------------------------------------------

	description.HeightScale = 1
	description.WidthScale = 1
	description.DepthScale = 1
	description.HeadScale = 1

	------------------------------------------------------------
	-- APLICAR
	------------------------------------------------------------

	local success, err = pcall(function()
		humanoid:ApplyDescriptionAsync(
			description
		)
	end)

	if not success then
		warn(
			"[Avatar] Falha ao aplicar corpo blocky:",
			err
		)

		return
	end

	print(
		("[Avatar] %s convertido para R15 Blocky")
			:format(character.Name)
	)
end


local function setupPlayer(player: Player)

	player.CharacterAdded:Connect(function(character)

		--------------------------------------------------------
		-- Esperar a aparência padrão do Roblox carregar.
		--
		-- CharacterAppearanceLoaded é melhor do que simplesmente
		-- task.wait(), pois esperamos efetivamente o avatar.
		--------------------------------------------------------

		if not player:HasAppearanceLoaded() then
			player.CharacterAppearanceLoaded:Wait()
		end

		if player.Character ~= character then
			return
		end

		makeBlocky(character)

	end)

end


Players.PlayerAdded:Connect(setupPlayer)

for _, player in Players:GetPlayers() do
	setupPlayer(player)
end