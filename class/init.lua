local PUBLIC = "public"
local PROTECTED = "protected"
local PRIVATE = "private"

local metatable = {}
metatable.get = getmetatable
metatable.set = setmetatable
metatable.tables = {}

local function getmetatable(obj)
  if not obj then return nil end
  local meta = metatable.get(obj)
  return metatable.tables[meta.__addr]
end

local function setmetatable(obj, tbl)
  local meta = {__addr = tostring(obj):gsub("table: ", "")}
  local mtable = {}
  for name, value in pairs(tbl) do
    if name == "__name"
    or name == "__index"
    or name == "__newindex"
    or name == "__call"
    then
      meta[name] = value
    else
      mtable[name] = value
    end
  end
  metatable.tables[meta.__addr] = mtable
  metatable.set(obj, meta)
  return obj
end

local function create_function(obj, name, func)
  local function fcall(obj, self, ...)
    local objmt = getmetatable(obj)
    local cmeta = getmetatable(objmt.__class)
    local cselfmeta = getmetatable(cmeta.__self)
    local super = cmeta.__super
    if cselfmeta then cselfmeta.__incall = cselfmeta.__incall + 1 end
    cmeta.__incall = cmeta.__incall + 1
    if objmt.__virtual and cselfmeta then
      obj = cselfmeta[name]
      objmt = getmetatable(obj)
      super = cselfmeta.__super
    end
    local ret = objmt.__func(objmt.__class, ...)
    if objmt.__super_call and super then 
        for _, sf in ipairs(super) do
            (function(obj, name, ...)
                local func = sf[name]
                if not func then return end
                local fmeta = getmetatable(func)
                if not fmeta then return end
                if not fmeta.__func then return end
                fmeta.__func(sf, ...)
            end)(sf, name, ...)
        end
    end
    cmeta.__incall = cmeta.__incall - 1
    if cselfmeta then cselfmeta.__incall = cselfmeta.__incall - 1 end
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
                                 __super_call = false,
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
      if string.sub(name, 1, 2) == "__" and name ~= "__destroy" then
        meta[name] = value
      else
        local func = create_function(obj, name, value)
        if name == "__destroy" then
            getmetatable(func).__super_call = true 
        end

        index(obj, name, function(pfunc)
            pfunc.self = obj
            if pfunc.virtual then
                func.virtual = pfunc.virtual
            end
            return false
        end)
      end
    elseif string.sub(name, 1, 2) ~= "__" then
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
                           __incall = 0,
                           __self = obj,
                           __private = private,
                           __protected = protected,
                           __init = nil,
                           __destroy = nil,
                           __super = nil})
end

local function delete(obj)
    local function del_mtable(obj)
        if not obj then return end
        local meta = metatable.get(obj)
        metatable.tables[meta.__addr] = nil
    end

    local function del_obj(obj)
        local meta = metatable.get(obj)
        local mtable = metatable.tables[meta.__addr]
        metatable.tables[meta.__addr] = nil

        --clear all inner data
        mtable.__init = nil
        mtable.__incall = nil
        mtable.__self = nil

        del_mtable(mtable.__protected)
        mtable.__protected = nil
        del_mtable(mtable.__private)
        mtable.__private = nil
        if mtable.__sobj then del_mtable(mtable.__sobj) end
        mtable.__sobj = nil
        local super = mtable.__super
        mtable.__super = nil
        for name, value in pairs(mtable) do
            del_mtable(value)
        end
        if super then
            for i =1, #super do
                del_obj(super[i])
            end
        end
    end
    
    -- call destructor
    local meta = metatable.get(obj)
    local mtable = metatable.tables[meta.__addr]
    if mtable.__destroy then
        mtable.__destroy(obj)
    end

    --get full object
    local meta = metatable.get(obj)
    local mtable = metatable.tables[meta.__addr]
    if mtable.__self ~= obj then
        obj = mtable.__self
    end

    del_obj(obj)
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
                  if type(name) == "string" then
                    json = json.."\""..name.."\":"
                  end
                  if type(value) == "string" then
                    json = json.."\""..tostring(value).."\","
                  else
                    json = json..tostring(value)..","
                  end
                end
            end
        end
        return json:sub(1, -2)
    end
    local function iterate_object(obj)
        local json = ""
        local s = iterate(obj)
        if string.len(s) ~= 0 then json = "public:{"..s.."}," end
        local meta = getmetatable(obj)
        s = iterate(meta)
        if string.len(s) ~= 0 then json = json..s.."," end
        s = iterate(meta.__private)
        if string.len(s) ~= 0 then json = json.."private:{"..s.."}," end
        s = iterate(meta.__protected)
        if string.len(s) ~= 0 then json = json.."protected:{"..s.."}," end
        if meta.__super then
            for _, child in ipairs(meta.__super) do
                json = json.."\""..metatable.get(child).__name.."\":{" ..iterate_object(child).."},"
            end
        end
        return json:sub(1, -2)
    end
    return "{"..iterate_object(obj).."}"
end

return {new = new,
        delete = delete,
        inherit = inherit,
        self = get_self,
        json = to_json,
        PUBLIC = PUBLIC,
        PROTECTED = PROTECTED,
        PRIVATE = PRIVATE}
