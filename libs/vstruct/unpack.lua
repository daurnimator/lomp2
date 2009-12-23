local io = require ((...):gsub("unpack$", "io"))

return function(refs)
    local env = {}
    
    local fd,buffer,bufsize,bufpos,data,stack,key
    local bitpack,nextbit
    
    local function store(value)
        if not key then
            data[#data+1] = value
        else
            local data = data
            for name in key:gmatch("([^%.]+)%.") do
                if data[name] == nil then
                    data[name] = {}
                end
                data = data[name]
            end
            data[key:match("[^%.]+$")] = value
            key = nil
        end
    end
    
    function env.ref(id)
        return unpack(refs[id])
    end
    
    function env.initialize(_fd, _data)
        fd = _fd
        
        buffer,bufsize,bufpos = nil,0,0
        
        data = _data
        stack = {}
        
        key = nil
    end
    
    function env.readahead(n)
        assert(bufpos == bufsize, "internal consistency failure: overlapping readahead")
        
        buffer = fd:read(n)
        bufsize = n
        bufpos = 0
    end
    
    function env.name(name)
        key = name
    end
    
    function env.push()
        local t = {}
        store(t)
        stack[#stack+1] = data
        data = t
    end
    
    function env.pop()
        data = stack[#stack]
        stack[#stack] = nil
    end
    
    function env.io(name, hasvalue, width, ...)
        local buf
        if bufpos < bufsize and width then
            buf = buffer:sub(bufpos+1, bufpos+width)
            bufpos = bufpos + width
        end
        
        local v = io(name, "unpack", fd, buf, ...)
        if v ~= nil then
            store(v)
        end
    end
    
    function env.bitpack(width)
        if width then
            assert(bufpos + width <= bufsize, "not enough bytes in buffer to expand bitpack")
            bitpack = { string.byte(buffer, bufpos+1, bufpos+width) }

            local e = io("endianness", "get")
            
            local bbit = 0
            local bbyte = e == "big" and #bitpack or 1
            local bdelta = e == "big" and -1 or 1
            
            function nextbit()    
                local v
                v = math.floor(bitpack[bbyte]/(2^bbit)) % 2
                if bbit < 7 then
                    bbit = bbit+1
                else
                    bbit = 0
                    bbyte = bbyte+bdelta
                end
                return v
            end
        else
            bufpos = bufpos + #bitpack
            bitpack = nil
        end
    end
    
    function env.bpio(name, hasvalue, width, ...)
        local v = io(name, "unpackbits", nextbit, ...)
        if v ~= nil then
            store(v)
        end
    end
    
    function env.finalize()
        assert(#stack == 0, "mismatched push/pop in execution")
        return data
    end
    
    do return env end
    
    return setmetatable({}, {
        __index = function(_, key)
            return function(...)
                print("unpack", key, ...)
                return env[key](...)
            end
        end;
    })
end