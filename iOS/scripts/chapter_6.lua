-- dofile("chapter_6.lua")

-- exercise 0 (works!)
function derivative (f, delta)
	delta = delta or 1e-4
	return function (x)
		return (f(x + delta) - f(x)) / delta
	end
end

-- exercise 1 (works!)
function integral (f, delta)
	delta = delta or 1e-4
	return function (x1, x2)
		local sum = 0
		local x = x1
		while (x + delta < x2) do
			sum = sum + ( f(x) * delta )
			x = x + delta
		end
		return sum + ( f(x) * (x2 - x))
	end
end

-- incrementor test (using closures) works!
function inc ()
	local val = 0
	return function()
		local result = val
		val = val + 1
		return result
	end
end


-- exercise 2 (works!)
function newpoly (coeffs)
	return function (x)
		local sum = 0
		for k, v in pairs(coeffs) do
			sum = sum + v*(x^(#coeffs - k))
		end
		return sum
	end
end

