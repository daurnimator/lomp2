local dt = { }

local function doc ( ... )
	local args = {...}
	return function ( v )
			if type(v) == "function" then
				local t = dt [ v ]
				if t then
					local tn = #t
					for i,doctbl in ipairs(args) do
						t[tn+1]=doctbl
					end
				else
					dt [ v ] = args
				end
				return v
			else
				error()
			end
		end
end

local value = {}
value.type = "table";
value.elements = {}
value.elements.type = {
	type = { "string", "table" };
	desc = [[Type of the value or list of types]];
	string = { "string", "table", "number", "cdata" };
	table = {
		list = { type="string" , desc=[[type]] };
	};
}
value.elements.string = {
	desc = [[]];
	type = "table";
	table = {
		elements = {
			patterns = {
				type = { "string", "table" };
				desc = [[Pattern or list of patterns the string must match]];
				table = {
					list = { type="string" , desc=[[pattern]] };
				};
			};
		};
		list = { type="string", desc=[[If present, allowed values]] };
	};
}
value.elements.number = {
	desc = [[
Condition or space seperated string of conditions for the number; or table of the former.

int:	number is an integer (x%1 == 0)
>x:		number is larger than x
<x: 	number is smaller than x
>=x:	number is larger than or equal to x
<=x:	number is smaller than or equal to x
==x:	number is equal to x

eg. "int >=0" for a positive integer
]];
	type = { "string" , "table" };
	table = {
		list = { type="string",	desc=[[condition(s) for number]] };
	};
}
value.elements.table = {
	desc = [[]];
	type = "table";
	table = {
		elements = {
			elements = {	type="table" ,	desc = [[Key/value in the table]] ;
				table = {
					elements = {
						{ type="table" , table=value, 	desc=[[Value]] };
					};
					list = { type="table",	table=value,	desc=[[Allowed value types for elements not in element table]] };
				};
			};
			list = {	type="table",	table=value,	desc=[[Contents of list part of table]] };
		};
	};
}
value.elements.cdata = {
	desc = [[cdata type or list of cdata types]];
	type = { "string", "table" };
	table = {
		list= { type="string",	desc=[[cdata type]] };
	};
};

local doctbl = {
	elements = {
		desc = {	type={ "string", nil },	desc=[[Description]] };
		method = {	desc=[[Specify the class this function is a method of; the class does not need to be specified in params.]] };
		params = {	type="table", 			desc=[[Parameters]], 	table={
				elements = {
					vararg={ type="number", number={"int",">0"}, desc=[[From which parameter does the variable length argument list start]] }
				};
				list = value;
			} };
		returns = { type="table", 			desc=[[Return values]],	table={
				elements = {
					multi= { type="number", number={"int",">0"}, desc=[[From which return value does the multiple return start]]; };
				};
				list=value
			} };
	};
}

doc{
	desc = [[Adds documentation for a function, call with any number of documentation tables]] ;
	params = {
		vararg = 1;
		{ type="table",		table=doctbl,	desc=[[Documentation table(s) to be added]] };
	};
	returns = {
		{ type="function",	desc=[[Call this function with the object to document.]],
			["function"]={	desc = [[Call with your object to document it.]];
				params = {{ [[object]] }};
				returns = {{ param=1 }};
			};
		};
	};
}(doc)

getdt = doc{
	desc = [[Retrives the documentation table(s) for the given object (if possible)]];
	params = {
		{ desc=[[Object to grab documentation for]]; };
	};
	returns = {
		multi = 1;
		{ desc=[[Documentation table(s)]]; };
	};
} ( function ( v ) return unpack( dt[v] ) end )

return {
	doc = doc ;
	getdt = getdt;
}
