-- Scénario du test privé de performance (branche test/kael-af-perf uniquement).
--
-- Lu dans ReplicatedStorage.PerfTest, présent seulement dans les places construites
-- par perf/<A|B|C>.project.json : Scenario (perf/scenarios/<X>.luau), AnimationIds
-- (perf/af_animation_ids.json) et TestPlace (perf/test_place.json). Partout ailleurs
-- (Studio synchronisé par default.project.json, tests Lune), get() renvoie nil et le
-- jeu se comporte normalement.

local PerfScenario = {}

local KINDS = { "Idle", "Attack", "Skill", "Ultimate", "Defend", "Hit", "Defeat" }
local ASSET_PATTERN = "^rbxassetid://%d+$"

export type Scenario = {
	name: string,
	label: string,
	forceModelDetail: string?,
	afAnimations: boolean,
	animations: { [string]: string }?, -- 7 identifiants Anime Fantasy valides, sinon nil
	testPlaceIds: { number },
}

local loaded = false
local current: Scenario? = nil

local function requireChild(folder: Instance, name: string): any
	local module = folder:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		return require(module)
	end
	return nil
end

-- Les 7 identifiants, seulement s'ils sont tous valides et distincts.
function PerfScenario.validAnimations(ids: any): { [string]: string }?
	if type(ids) ~= "table" then
		return nil
	end
	local result, seen = {}, {}
	for _, kind in KINDS do
		local id = ids[kind]
		if type(id) ~= "string" or not string.match(id, ASSET_PATTERN) or seen[id] then
			return nil
		end
		seen[id] = true
		result[kind] = id
	end
	return result
end

function PerfScenario.get(): Scenario?
	if loaded then
		return current
	end
	loaded = true
	local ok, folder = pcall(function()
		return game:GetService("ReplicatedStorage"):FindFirstChild("PerfTest")
	end)
	if not ok or not folder then
		return nil
	end
	local scenario = requireChild(folder, "Scenario")
	if type(scenario) ~= "table" then
		return nil
	end
	local place = requireChild(folder, "TestPlace")
	current = {
		name = tostring(scenario.name),
		label = tostring(scenario.label),
		forceModelDetail = scenario.forceModelDetail,
		afAnimations = scenario.afAnimations == true,
		animations = if scenario.afAnimations == true
			then PerfScenario.validAnimations(requireChild(folder, "AnimationIds"))
			else nil,
		testPlaceIds = if type(place) == "table" and type(place.placeIds) == "table" then place.placeIds else {},
	}
	return current
end

return PerfScenario
