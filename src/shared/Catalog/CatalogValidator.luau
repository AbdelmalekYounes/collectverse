-- Vérifie la cohérence du catalogue et de la configuration.
-- Appelé au démarrage du serveur (échec immédiat si invalide) et par les tests.
-- Chaque fonction ajoute des messages lisibles dans la liste `errors`.

local Catalog = script.Parent
local GameConfig = require(Catalog.Parent.Config.GameConfig)
local CardCatalog = require(Catalog.CardCatalog)
local Elements = require(Catalog.Elements)
local Roles = require(Catalog.Roles)
local Rarities = require(Catalog.Rarities)
local Statuses = require(Catalog.Statuses)
local Targets = require(Catalog.Targets)
local Boosters = require(Catalog.Boosters)

local EFFECT_TYPES = { Damage = true, Heal = true, Shield = true, Status = true }
local SCALINGS = { attack = true, defense = true, maxHp = true }
local STAT_KEYS = { "maxHp", "attack", "defense", "speed" }

local CatalogValidator = {}

local function isPositiveNumber(value: any): boolean
	return type(value) == "number" and value > 0 and value == value
end

local function isPositiveInteger(value: any): boolean
	return isPositiveNumber(value) and math.floor(value) == value
end

local function isNonEmptyString(value: any): boolean
	return type(value) == "string" and #value > 0
end

local function validateEffect(errors, where: string, rule, effect)
	if type(effect) ~= "table" or not EFFECT_TYPES[effect.type] then
		table.insert(errors, where .. " : type d'effet inconnu")
		return
	end
	if effect.target ~= nil and effect.target ~= "Self" and effect.target ~= "Targets" then
		table.insert(errors, where .. " : target d'effet invalide (Self ou Targets)")
	end

	local hitsSelf = effect.target == "Self"
	local side = if hitsSelf then "Self" else (rule and rule.side)

	if effect.type == "Status" then
		local status = Statuses.Info[effect.status]
		if not status then
			table.insert(errors, where .. " : statut inconnu " .. tostring(effect.status))
			return
		end
		if not isPositiveInteger(effect.duration) then
			table.insert(errors, where .. " : duration doit être un entier >= 1")
		end
		if status.needsPower and not isPositiveNumber(effect.power) then
			table.insert(errors, where .. " : le statut " .. effect.status .. " exige power > 0")
		end
		return
	end

	if not isPositiveNumber(effect.power) then
		table.insert(errors, where .. " : power doit être > 0")
	end
	if effect.scaling ~= nil and not SCALINGS[effect.scaling] then
		table.insert(errors, where .. " : scaling invalide " .. tostring(effect.scaling))
	end
	if effect.type == "Damage" and side ~= "Enemy" then
		table.insert(errors, where .. " : des dégâts ne peuvent viser que des ennemis")
	end
	if (effect.type == "Heal" or effect.type == "Shield") and side == "Enemy" then
		table.insert(errors, where .. " : soins et boucliers ne peuvent pas viser un ennemi")
	end
end

local function validateAction(errors, fighterId: string, slot: string, action)
	local where = fighterId .. "." .. slot
	if type(action) ~= "table" then
		table.insert(errors, where .. " : action manquante")
		return
	end
	if not isNonEmptyString(action.name) then
		table.insert(errors, where .. " : nom manquant")
	end
	local cost = action.cost
	if type(cost) ~= "number" or cost < 0 or math.floor(cost) ~= cost then
		table.insert(errors, where .. " : coût invalide")
	elseif cost > GameConfig.Battle.MaxEnergy then
		table.insert(errors, where .. " : coût supérieur à l'énergie maximale")
	elseif (slot == "basic" or slot == "defend") and cost ~= 0 then
		table.insert(errors, where .. " : l'attaque normale et la défense doivent être gratuites")
	end

	local rule = Targets.Rules[action.target]
	if not rule then
		table.insert(errors, where .. " : règle de ciblage inconnue " .. tostring(action.target))
	elseif slot == "defend" and rule.side == "Enemy" then
		table.insert(errors, where .. " : une action défensive ne peut pas viser un ennemi")
	end

	if type(action.effects) ~= "table" or #action.effects == 0 then
		table.insert(errors, where .. " : aucun effet")
		return
	end
	for index, effect in action.effects do
		validateEffect(errors, string.format("%s.effects[%d]", where, index), rule, effect)
	end
end

function CatalogValidator.validateFighter(def, errors)
	local id = tostring(def.id)
	if type(def.id) ~= "string" or not string.match(def.id, "^F%d%d%d$") then
		table.insert(errors, id .. " : id de combattant invalide (format F000)")
	end
	if not isNonEmptyString(def.name) then
		table.insert(errors, id .. " : nom manquant")
	end
	if not Rarities.isValid(def.rarity) then
		table.insert(errors, id .. " : rareté invalide")
	end
	if not Elements.isValid(def.element) then
		table.insert(errors, id .. " : élément invalide")
	end
	if not Roles.isValid(def.role) then
		table.insert(errors, id .. " : rôle invalide")
	end
	if Roles.Rows[def.preferredRow] == nil then
		table.insert(errors, id .. " : preferredRow invalide")
	end
	if type(def.stats) ~= "table" then
		table.insert(errors, id .. " : statistiques manquantes")
	else
		for _, key in STAT_KEYS do
			if not isPositiveNumber(def.stats[key]) then
				table.insert(errors, id .. " : statistique " .. key .. " invalide")
			end
		end
	end
	if type(def.actions) ~= "table" then
		table.insert(errors, id .. " : actions manquantes")
		return
	end
	for _, slot in CardCatalog.ActionSlots do
		validateAction(errors, id, slot, def.actions[slot])
	end
end

function CatalogValidator.validateItem(def, errors)
	local id = tostring(def.id)
	if type(def.id) ~= "string" or not string.match(def.id, "^I%d%d%d$") then
		table.insert(errors, id .. " : id d'objet invalide (format I000)")
	end
	if not isNonEmptyString(def.name) then
		table.insert(errors, id .. " : nom manquant")
	end
	if not Rarities.isValid(def.rarity) then
		table.insert(errors, id .. " : rareté invalide")
	end
end

-- getPool(rarity) -> liste d'ids ; injectable pour tester des pools vides.
function CatalogValidator.validateBooster(def, errors, getPool)
	local where = "Booster " .. tostring(def.id)
	getPool = getPool or CardCatalog.getBoosterPool

	if not isPositiveInteger(def.cardCount) then
		table.insert(errors, where .. " : cardCount invalide")
		return
	end
	local guaranteed = def.guaranteedSlots or 0
	if type(guaranteed) ~= "number" or guaranteed < 0 or guaranteed > def.cardCount then
		table.insert(errors, where .. " : guaranteedSlots invalide")
	end

	local function checkWeights(label: string, weights, minimumRank: number)
		if type(weights) ~= "table" then
			table.insert(errors, where .. " : " .. label .. " manquant")
			return
		end
		local total = 0
		for rarity, weight in weights do
			if not Rarities.isValid(rarity) then
				table.insert(errors, where .. " : rareté inconnue " .. tostring(rarity))
				continue
			end
			if type(weight) ~= "number" or weight < 0 or math.floor(weight) ~= weight then
				table.insert(errors, where .. " : poids invalide pour " .. rarity)
				continue
			end
			if weight > 0 then
				if Rarities.Info[rarity].rank < minimumRank then
					table.insert(errors, where .. " : " .. label .. " ne peut pas contenir " .. rarity)
				end
				if #getPool(rarity) == 0 then
					table.insert(errors, where .. " : aucune carte " .. rarity .. " dans le pool")
				end
			end
			total += weight
		end
		if total <= 0 then
			table.insert(errors, where .. " : " .. label .. " a un poids total nul")
		end
	end

	if def.cardCount - guaranteed > 0 then
		checkWeights("standardWeights", def.standardWeights, 1)
	end
	if guaranteed > 0 then
		checkWeights("guaranteedWeights", def.guaranteedWeights, Rarities.Info.Rare.rank)
	end
end

function CatalogValidator.validateAll(): { string }
	local errors = {}

	for _, id in CardCatalog.getDuplicateIds() do
		table.insert(errors, "Id dupliqué : " .. id)
	end
	for _, def in CardCatalog.getFighters() do
		CatalogValidator.validateFighter(def, errors)
	end
	for _, def in CardCatalog.getItems() do
		CatalogValidator.validateItem(def, errors)
	end
	for _, def in Boosters do
		CatalogValidator.validateBooster(def, errors)
	end

	local team = GameConfig.Team
	if team.FrontSlots + team.BackSlots ~= team.Size then
		table.insert(errors, "GameConfig.Team : FrontSlots + BackSlots doit valoir Size")
	end

	local starters = GameConfig.Progression.StarterFighters
	local seen = {}
	for _, id in starters do
		if not CardCatalog.getFighter(id) then
			table.insert(errors, "Combattant de départ inconnu : " .. tostring(id))
		elseif seen[id] then
			table.insert(errors, "Combattant de départ en double : " .. id)
		end
		seen[id] = true
	end
	if #starters < team.Size then
		table.insert(errors, "Pas assez de combattants de départ pour une équipe complète")
	end

	for boosterId in GameConfig.Progression.FirstLaunchBoosters do
		if not Boosters[boosterId] then
			table.insert(errors, "Booster de premier lancement inconnu : " .. tostring(boosterId))
		end
	end
	for boosterId in GameConfig.Progression.VictoryBoosters do
		if not Boosters[boosterId] then
			table.insert(errors, "Booster de victoire inconnu : " .. tostring(boosterId))
		end
	end

	return errors
end

return CatalogValidator
