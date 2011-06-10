local function ident (...)
	return ...
end

local function dsp ( effects )
	return function(sample,...)
		for i=1 , #effects do
			sample=effects[i](sample,...)
		end
		return sample
	end
end

local function channel ( chan , func )
	return function(sample,channel,...)
		if channel == chan then
			return func(sample,channel,...)
		else
			return sample,channel,...
		end
	end
end

local function multiply ( m )
	return function(sample,...)
			return m*sample
		end
end

-- Convert on logarithmic scale.
local function attenuate ( v )
	v = tonumber(v)
	assert(v and v>=0 and v<=1,"Invalid volume")
	local base=2
	local m=(base^(v)-1)/(base-1)

	return multiply ( m )
end

local function balance ( b )
	b = tonumber(b)
	assert(b and b>=0 and b<=1,"Invalid balance")
	local left
	local right 
	if b == .5 then return ident
	elseif b < .5 then -- Attenuate right
		return channel(1,attenuate(b*2))
	elseif b > .5 then -- Attenuate left
		return channel(0,attenuate((1-b)*2))
	end
end
local function delay(d)
	local p = { }
	for i=0,d-1 do
		p[i]=0
	end
	local i = 0
	return function(sample,...)
		local old = p[i]
		p[i]=sample
		i=(i+1)%d
		return old,...
	end
end

return setmetatable({
	dsp = dsp ;
	channel = channel ;
	
	multiply = multiply ;
	attenuate = attenuate ;
	balance = balance ;

	delay = delay ;
},{__call = function(t,...) return dsp(...) end })
