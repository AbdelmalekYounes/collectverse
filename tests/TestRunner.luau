-- Mini framework de tests, sans dépendance externe.
--
-- Une spec est un ModuleScript qui renvoie function(test, expect) :
--   return function(test, expect)
--       test("additionne", function()
--           expect.equal(1 + 1, 2)
--       end)
--   end

local TestRunner = {}

local function describe(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local expect = {}

function expect.equal(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(
			string.format("%s : attendu %s, obtenu %s", label or "égalité", describe(expected), describe(actual)),
			2
		)
	end
end

function expect.near(actual: number, expected: number, epsilon: number?, label: string?)
	if type(actual) ~= "number" or math.abs(actual - expected) > (epsilon or 1e-9) then
		error(
			string.format("%s : attendu ≈ %s, obtenu %s", label or "proximité", describe(expected), describe(actual)),
			2
		)
	end
end

function expect.truthy(value: any, label: string?)
	if not value then
		error((label or "valeur") .. " : attendu vrai, obtenu " .. describe(value), 2)
	end
end

function expect.falsy(value: any, label: string?)
	if value then
		error((label or "valeur") .. " : attendu faux, obtenu " .. describe(value), 2)
	end
end

function expect.fails(callback: () -> (), label: string?)
	local ok = pcall(callback)
	if ok then
		error((label or "appel") .. " : une erreur était attendue", 2)
	end
end

function expect.contains(text: string, fragment: string, label: string?)
	if type(text) ~= "string" or not string.find(text, fragment, 1, true) then
		error(string.format("%s : %s ne contient pas %s", label or "texte", describe(text), describe(fragment)), 2)
	end
end

export type Results = { passed: number, failed: number, failures: { string } }

function TestRunner.run(specFolder: Instance): Results
	local results: Results = { passed = 0, failed = 0, failures = {} }

	local modules = {}
	for _, child in specFolder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(modules, child)
		end
	end
	table.sort(modules, function(a, b)
		return a.Name < b.Name
	end)

	for _, module in modules do
		local loaded, spec = pcall(require, module)
		if not loaded or type(spec) ~= "function" then
			results.failed += 1
			table.insert(results.failures, module.Name .. " : chargement impossible : " .. tostring(spec))
			continue
		end

		local cases = {}
		local collected, collectError = pcall(spec, function(name: string, callback: () -> ())
			table.insert(cases, { name = name, callback = callback })
		end, expect)
		if not collected then
			results.failed += 1
			table.insert(results.failures, module.Name .. " : " .. tostring(collectError))
			continue
		end

		for _, case in cases do
			local passed, caseError = pcall(case.callback)
			if passed then
				results.passed += 1
			else
				results.failed += 1
				table.insert(
					results.failures,
					string.format("%s › %s : %s", module.Name, case.name, tostring(caseError))
				)
			end
		end
	end

	print(string.format("[Tests] %d réussi(s), %d échec(s)", results.passed, results.failed))
	for _, failure in results.failures do
		warn("[Tests] ÉCHEC " .. failure)
	end
	return results
end

return TestRunner
