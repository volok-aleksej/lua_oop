local PUBLIC = "public"
local PROTECTED = "protected"
local PRIVATE = "private"

local metatable = {}
metatable.get = getmetatable
metatable.set = setmetatable
metatable.tables = {}

local function delmetatable(obj)
  for i = 1, #metatable.tables do
    local tbl = metatable.tables[i]
    if tbl.__owner == obj then
      table.remove(metatable.tables, i)
    end
  end
end

local function getmetatable(obj)
  local meta = metatable.get(obj)
  local mtable
  for _, tbl in ipairs(metatable.tables) do
    if tbl.__owner == obj then
      return tbl
    end
  end
  return nil
end

local function setmetatable(obj, tbl)
  local meta = {}
  local mtable = {}
  for name, value in pairs(tbl) do
    if name == "__name"
    or name == "__index"
    or name == "__newindex"
    or name == "__call"
    or name == "__gc"
    then
      meta[name] = value
    else
      mtable[name] = value
    end
  end
  if not meta.__gc then 
    meta.__gc = function(obj)
      delmetatable(obj)
    end
  end
  mtable.__owner = obj
  table.insert(metatable.tables, mtable)
  metatable.set(obj, meta)
  return obj
end

local function create_function(obj, name, func)
  local function fcall(obj, self, ...)
    local objmt = getmetatable(obj)
    local cmeta = getmetatable(objmt.__class)
    local cselfmeta = getmetatable(cmeta.__self)
    cselfmeta.__incall = cselfmeta.__incall + 1
    cmeta.__incall = cselfmeta.__incall + 1
    if objmt.__virtual and objmt.__self then
      obj = cselfmeta[name]
      objmt = getmetatable(obj)
    end
    local ret = objmt.__func(objmt.__class, ...)
    cmeta.__incall = cmeta.__incall - 1
    cselfmeta.__incall = cselfmeta.__incall - 1
    return ret
  end
  
  local function findex(func, name)
      local meta = getmetatable(func)
      if name == "virtual" then
        return meta.__virtual
      elseif name == "self" then
        return meta.__self
      else
        return nil
      end
  end
  
  local function fnewindex(func, name, value)
      local meta = getmetatable(func)
      if name == "virtual" then
        meta.__virtual = value
      elseif name == "self" then
        meta.__self = value
      elseif name == "access" then
        if value == PRIVATE
        or value == PROTECTED
        or value == PRIVATE then meta.__access = value end
      end
  end
  local meta = getmetatable(obj)
  meta[name] = setmetatable({}, {__newindex = fnewindex,
                                 __index = findex,
                                 __call = fcall,
                                 __name = name,
                                 __access = PUBLIC,
                                 __class = obj,
                                 __func = func,
                                 __virtual = false,
                                 __self = obj})
  return meta[name]
end

local new
local function inherit(name, ...)
  if type(name) ~= "string" then error("incorrect first argument: use inherite(name:string, args..)") end
  local child = new(name)
  local meta = getmetatable(child)
  meta.__super = {}
  for _, arg in ipairs({...}) do
    local ameta = getmetatable(arg)
    if ameta and ameta.__self then
        ameta.__self = child
        table.insert(meta.__super, arg)
    end
  end
  return child
end

local function check_access(obj, super)
    local meta = getmetatable(obj)
    if not meta then return obj end
    local cmeta = getmetatable(meta.__class)
    cmeta = getmetatable(cmeta.__self)
    if cmeta.__incall > 0 then
        if not super or meta.__access ~= PRIVATE then return obj end
    else
        if meta.__access == PUBLIC then return obj end
    end
    return nil
end

local function super(obj)
  local function sindex(s, name)
    local function get_index(obj, name)
      local sobj = metatable.get(obj).__index(obj, name, nil, true)
      if type(sobj) == "table" then
        local sobjmt = getmetatable(sobj)
        if sobjmt and sobjmt.__func then
          return function(self, ...)
            sobjmt.__func(obj, ...)
          end
        end
      end
      return sobj
    end

    local meta = getmetatable(s)
    if meta.__class then
      return get_index(meta.__class, name)
    else
      local sobjects = getmetatable(meta.__self).__super
      for i = 1, #sobjects do
        local data = get_index(sobjects[i], name)
        if data then return data end
      end
    end
    return nil
  end

  local function scall(s, name)
      local meta = getmetatable(s)
      if meta.__singles[name] then return meta.__singles[name] end

      local pmt = getmetatable(meta.__self)
      if not pmt.__super then return nil end
      local sobj
      for _, val in pairs(pmt.__super) do
        if metatable.get(val).__name == name then
          sobj = val
          break
        end
      end

      local ssingle = setmetatable({}, {__name = "super("..name..")",
                                      __index = sindex,
                                      __self = meta.__self,
                                      __class = val})
      meta.__singles[name] = ssingle
      return ssingle
  end
  local pmt = getmetatable(obj)
  if not pmt or not pmt.__super then return nil end
  local super
  if pmt.__sobj then
    super = pmt.__sobj
  else
    local smeta = {__name = "super",
                   __index = sindex,
                   __call = scall,
                   __self = obj,
                   __singles = {}}
    super = setmetatable({}, smeta)
    pmt.__sobj = super
  end
  return super
end

local function get_self(obj)
  local meta = getmetatable(obj)
  if meta then return meta.__self end
  return nil
end

function new(name)
  if type(name) ~= "string" then error("incorrect 1 argument: use new(name:string[, init:function, gc:function])") end
  if init and type(init) ~= "function" then error("incorrect 2 argument: use new(name:string[, init:function, gc:function])") end
  if gc and type(gc) ~= "function" then error("incorrect 3 argument: use new(name:string[, init:function, gc:function])") end
  
  local function index(obj, name, callback, issuper)
    if name == "super" then return super(obj) end
    if name == "inherit" then return inherit end

    local pmt = getmetatable(obj)
    local attr = check_access(pmt.__private, issuper)
    if attr and attr[name] then return attr[name] end
    attr = check_access(pmt.__protected, issuper)
    if attr and attr[name] then return attr[name] end

    local function check_callback(data)
      if not callback then return true end
      return callback(data)
    end

    if rawget(obj, name) then return rawget(obj, name) end
    if pmt[name]
    and check_callback(pmt[name]) then return check_access(pmt[name], issuper) end
    if pmt.__super then
      for _, obj in pairs(pmt.__super) do
        local sobj = nil
        if callback then 
            index(obj, name, function(pfunc)
                    return callback(pfunc)
                end)
        else
            sobj = index(obj, name, nil, true)
        end
        if sobj then return sobj end
      end
    end
    return nil
  end

  local function newindex(obj, name, value)
    if type(value) == "function" then
      local meta = getmetatable(obj)
      if string.sub(name, 1, 2) == "__" then
        meta[name] = value
      else
        local func = create_function(obj, name, value)

        index(obj, name, function(pfunc)
            pfunc.self = obj
            if pfunc.virtual then
                func.virtual = pfunc.virtual
            end
            return false
        end)
      end
    else
      rawset(obj, name, value)
    end
  end

  local function call(obj, ...)
    local meta = getmetatable(obj)
    local selfmeta = getmetatable(meta.__self)
    selfmeta.__incall = selfmeta.__incall + 1
    meta.__incall = selfmeta.__incall + 1
    if meta.__super then 
        for _,child in ipairs(meta.__super) do
            child(...)
        end
    end
    if meta.__init then meta.__init(obj, ...) end
    selfmeta.__incall = selfmeta.__incall - 1
    meta.__incall = selfmeta.__incall - 1
  end

  local function __gc(obj)
    local meta = getmetatable(obj)
    local selfmeta = getmetatable(meta.__self)
    delmetatable(obj)
    selfmeta.__incall = selfmeta.__incall + 1
    meta.__incall = selfmeta.__incall + 1
    if meta.__destroy then meta.__destroy(obj) end
    if meta.__super then 
        for i = 1, #meta.__super do
            table.remove(meta.__super, 1)
        end
    end
    selfmeta.__incall = selfmeta.__incall - 1
    meta.__incall = selfmeta.__incall - 1
  end

  local obj = {}
  local private = {}
  setmetatable(private, {__name = "private",
                         __class = obj,
                         __access = PRIVATE})
  local protected = {}
  setmetatable(protected, {__name = "protected",
                           __class = obj,
                           __access = PROTECTED})
  return setmetatable(obj, {__index = index,
                           __newindex = newindex,
                           __call = call,
                           __name = name,
                           __gc = __gc,
                           __incall = 0,
                           __self = obj,
                           __private = private,
                           __protected = protected,
                           __init = nil,
                           __destroy = nil,
                           __super = nil})
end

local function to_json(obj)
    local function iterate(obj)
        local json = ""
        for name, value in pairs(obj) do
            if string.sub(name, 1, 2) ~= "__" then
                if type(value) == "function" then
                    json = json.."\""..name.."\":\"function\","
                elseif type(value) == "table" then
                    local meta = getmetatable(value)
                    if meta and meta.__func then
                        local virtual = meta.__virtual and "virtual " or ""
                        json = json.."\""..name.."\":\""..virtual.."function\","
                    else
                        json = json.."\""..name.."\":{"
                        json = json..iterate(value).."},"
                    end
                else
                    json = json.."\""..name.."\":"..tostring(value)..","
                end
            end
        end
        return json:sub(1, -2)
    end
    local function iterate_object(obj)
        local json = iterate(obj)..","
        local meta = getmetatable(obj)
        local s = iterate(meta)
        if string.len(s) ~= 0 then json = json..s.."," end
        s = iterate(meta.__private)
        if string.len(s) ~= 0 then json = json..s.."," end
        s = iterate(meta.__protected)
        if string.len(s) ~= 0 then json = json..s.."," end
        if meta.__super then
            for _, child in ipairs(meta.__super) do
                local cmeta = getmetatable(child)
                json = json.."\""..cmeta.__name.."\":{" ..iterate_object(child).."},"
            end
        end
        return json:sub(1, -2)
    end
    return "{"..iterate_object(obj).."}"
end

return {new = new,
        inherit = inherit,
        self = get_self,
        json = to_json,
        PUBLIC = PUBLIC,
        PROTECTED = PROTECTED,
        PRIVATE = PRIVATE}
