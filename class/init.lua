local PUBLIC = "public"
local PROTECTED = "protected"
local PRIVATE = "private"

local SUPER = "super"
local METHOD = "method"
local CLASS = "class"

local class = {}
local method = {}
local metatable = {}
metatable.tables = {}

-------------------------------------------------------------------------
--                              metatables                             --
-------------------------------------------------------------------------
function metatable.get(obj)
  local meta, mtable
  if obj then
     meta = getmetatable(obj)
     if meta then mtable = metatable.tables[meta.__addr] end
  end
  return mtable
end

function metatable.set(obj, meta, tbl)
  meta.__addr = tostring(obj):gsub("table: ", "")
  metatable.tables[meta.__addr] = tbl
  return setmetatable(obj, meta)
end

function metatable.name(obj)
  local name
  if obj then
     meta = getmetatable(obj)
     if meta then name = meta.__name end
  end
  return name
end

function metatable.index(obj, ...)
  if obj then
     meta = getmetatable(obj)
     if meta then return meta.__index(obj, ...) end
  end
  return nil
end

-------------------------------------------------------------------------
--                                method                               --
-------------------------------------------------------------------------
function method.create(obj, name, func)
  local function fcall(obj, self, ...)
    local objmt = metatable.get(obj)
    local cmeta = metatable.get(objmt.__class)
    local cselfmeta = metatable.get(cmeta.__self)
    local meta = cselfmeta or cmeta

    if objmt.__virtual and cselfmeta and cselfmeta[name] then
      obj = cselfmeta[name]
      objmt = metatable.get(obj)
    end

    meta.__incall = meta.__incall + 1
    local ret
    if objmt.__super_call then
        local funcs = {}
        metatable.index(objmt.__class, name, function(pfunc)
            table.insert(funcs, pfunc)
        end)
        if #funcs > 0 then ret = {} end
        for _, pfunc in ipairs(funcs) do
          local fmeta = metatable.get(pfunc)
          local res = fmeta.__func(fmeta.__class, ...)
          if res then
            if not ret then ret = {} end
            ret[metatable.name(fmeta.__class)] = res
          end
        end
    else
      ret = objmt.__func(objmt.__class, ...)
    end
    meta.__incall = meta.__incall - 1
    return ret
  end
  
  local function findex(func, name)
      local meta = metatable.get(func)
      if name == "virtual" then
        return meta.__virtual
      elseif name == "self" then
        return meta.__self
      else
        return nil
      end
  end
  
  local function set_virtual(obj, value)
      local meta = metatable.get(obj)
      local cmeta = metatable.get(meta.__class)
      metatable.index(cmeta.__self, metatable.name(obj), function(pfunc)
          local meta = metatable.get(pfunc)
          meta.__virtual = value
          return pfunc == obj
      end)
  end
  
  local function fnewindex(func, name, value)
      local meta = metatable.get(func)
      if name == "virtual" then
        set_virtual(func, value)
      elseif name == "access" then
        if value == PRIVATE
        or value == PROTECTED
        or value == PRIVATE then meta.__access = value end
      end
  end
  local meta = metatable.get(obj)
  meta[name] = metatable.set({}, {__newindex = fnewindex,
                                 __index = findex,
                                 __call = fcall,
                                 __name = name},
                                {__access = PUBLIC,
                                 __type = METHOD,
                                 __class = obj,
                                 __func = func,
                                 __virtual = false,
                                 __super_call = false})
  return meta[name]
end

function method.is_method(obj)
  local meta = metatable.get(obj)
  if meta and meta.__type == METHOD then return true end
  return false
end

-------------------------------------------------------------------------
--                                 super                               --
-------------------------------------------------------------------------
local function super(obj)
  local function sindex(s, name)
    local function get_index(obj, name)
      local sobj = metatable.index(obj, name, nil, true)
      if method.is_method(sobj) then 
          return function(self, ...)
              return metatable.get(sobj).__func(obj, ...)
          end
      else 
        return sobj
      end
    end

    local meta = metatable.get(s)
    if meta.__class then
      return get_index(meta.__class, name)
    else
      local sobjects = metatable.get(meta.__self).__super
      for i = 1, #sobjects do
        local data = get_index(sobjects[i], name)
        if data then return data end
      end
    end
    return nil
  end

  local function snewindex(s, name, value)
    local meta = metatable.get(s)
    if meta.__class then
      meta.__class[name] = value
    else
      meta.__self[name] = value
    end
  end

  local function scall(s, name)
      local meta = metatable.get(s)
      if class.type(name) == CLASS then name = class.name(name) end
      if meta.__singles[name] then return meta.__singles[name] end

      local pmt = metatable.get(meta.__self)
      if not pmt.__super then return nil end
      local sobj
      for _, val in pairs(pmt.__super) do
        if metatable.name(val) == name then
          sobj = val
          break
        end
      end

      local ssingle = metatable.set({}, {__name = SUPER.."("..name..")",
                                         __index = sindex,
                                         __newindex = snewindex},
                                        {__self = meta.__self,
                                         __type = SUPER,
                                         __class = sobj})
      meta.__singles[name] = ssingle
      return ssingle
  end
  local pmt = metatable.get(obj)
  if not pmt or not pmt.__super then return nil end
  if not pmt.__sobj then 
    pmt.__sobj = metatable.set({}, {__name = SUPER,
                                   __index = sindex,
                                   __newindex = snewindex,
                                   __call = scall},
                                  {__self = obj,
                                   __type = SUPER,
                                   __singles = {}})
  end
  return pmt.__sobj
end

-------------------------------------------------------------------------
--                                 class                               --
-------------------------------------------------------------------------
function class.inherit(name, ...)
  if type(name) ~= "string" then error("incorrect first argument: use inherite(name:string, args..)") end

  local function set_self(meta, obj)
    meta.__self = obj
    if not meta.__super then return end
    for _, parent in ipairs(meta.__super) do 
      local ameta = metatable.get(parent)
      set_self(ameta, obj)
    end
  end

  local child = class.new(name)
  local meta = metatable.get(child)
  meta.__super = {}
  for _, arg in ipairs({...}) do
    local ameta = metatable.get(arg)
    if ameta and ameta.__self then
        set_self(ameta, child)
        table.insert(meta.__super, arg)
    end
  end
  return child
end

function class.self(obj)
  local meta = metatable.get(obj)
  if meta then return meta.__self end
  return nil
end

function class.new(name)
  if type(name) ~= "string" then error("incorrect 1 argument: use new(name:string[, init:function, gc:function])") end
  if init and type(init) ~= "function" then error("incorrect 2 argument: use new(name:string[, init:function, gc:function])") end
  if gc and type(gc) ~= "function" then error("incorrect 3 argument: use new(name:string[, init:function, gc:function])") end
  
  local function check_access(obj, super)
      local meta = metatable.get(obj)
      if not meta then return obj end
      local cmeta = metatable.get(meta.__class)
      cmeta = metatable.get(cmeta.__self)
      if cmeta.__incall > 0 then
          if not super or meta.__access ~= PRIVATE then return obj end
      else
          if meta.__access == PUBLIC then return obj end
      end
      return nil
  end

  local function index(obj, name, callback, issuper)
    if name == SUPER then return super(obj) end

    if rawget(obj, name) then return rawget(obj, name) end
    local pmt = metatable.get(obj)
    local attr = check_access(pmt.__private, issuper)
    if attr and attr[name] then return attr[name] end
    attr = check_access(pmt.__protected, issuper)
    if attr and attr[name] then return attr[name] end

    local function check_callback(data)
      if not callback then return true end
      return callback(data)
    end

    if pmt[name]
    and check_callback(pmt[name]) then return check_access(pmt[name], issuper) end
    if pmt.__super then
      for _, obj in pairs(pmt.__super) do
        local sobj = nil
        if callback then
            sobj = index(obj, name, function(pfunc) return callback(pfunc) end)
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
      local meta = metatable.get(obj)
      if name:sub(1, 2) == "__"
      and name ~= "__destroy" then
        meta[name] = value
      else
        local func = method.create(obj, name, value)
        if name == "__destroy" then
            metatable.get(func).__super_call = true 
        end
        index(obj, name, function(pfunc)
            if pfunc.virtual then
                func.virtual = pfunc.virtual
            end
            return false
        end)
      end
    elseif name:sub(1, 2) ~= "__" then
      rawset(obj, name, value)
    end
  end

  local function call(obj, ...)
    local meta = metatable.get(obj)
    local selfmeta = metatable.get(meta.__self)
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

  local function cpairs(obj)
    local objects = {}
    local function iterate_object(obj, super)
      table.insert(objects, obj)
      local meta = metatable.get(obj)
      if check_access(meta.__protected, super) then 
        table.insert(objects, meta.__protected)
      end
      if check_access(meta.__private, super) then 
        table.insert(objects, meta.__private)
      end
      local methods = {}
      for name, value in pairs(meta) do
        if name:sub(1, 2) ~= "__" and check_access(value, super) then
          methods[name] = value
        end
      end
      table.insert(objects, methods)
    end
    local meta = metatable.get(obj)
    iterate_object(obj, false)
    if meta and meta.__super then
      for _, parent in ipairs(meta.__super) do
        iterate_object(parent, false)
      end
    end
    local i = 1
    local in_obj = objects[i]
    return function(_, k)
      repeat
        k, v = next(in_obj, k)
        if k ~= nil then return k, v
        else i = i + 1
        end
        if i <= #objects then in_obj = objects[i]
        else in_obj = nil
        end
      until not in_obj
      return nil, nil
    end, in_obj, nil
  end

  local obj = {}
  local private = {}
  metatable.set(private, {__name = "private"},
                         {__class = obj,
                          __access = PRIVATE})
  local protected = {}
  metatable.set(protected, {__name = "protected"},
                           {__class = obj,
                            __access = PROTECTED})
  return metatable.set(obj, {__index = index,
                             __newindex = newindex,
                             __call = call,
                             __name = name,
                             __pairs = cpairs},
                            {__incall = 0,
                             __self = obj,
                             __type = CLASS,
                             __private = private,
                             __protected = protected})
end

function class.delete(obj)
    local function del_mtable(obj)
        if not obj then return end
        local meta = getmetatable(obj)
        if not meta then return end
        metatable.tables[meta.__addr] = nil
    end

    local function del_obj(obj)
        local mtable = metatable.get(obj)
        del_mtable(obj)

        --clear all inner data
        mtable.__destroy = nil
        mtable.__init = nil
        mtable.__incall = nil
        mtable.__self = nil
        mtable.__type = nil

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
    local mtable = metatable.get(obj)
    if mtable and mtable.__destroy then
        mtable.__destroy(obj)
    end

    --get full object
    local mtable = metatable.get(obj)
    if mtable and mtable.__self ~= obj then
        obj = mtable.__self
    end

    del_obj(obj)
end

function class.json(obj)
    local function iterate(obj)
        local json = ""
        for name, value in pairs(obj) do
            if name:sub(1, 2) ~= "__" then
                if type(value) == "function" then
                    json = json.."\""..name.."\":\"function\","
                elseif type(value) == "table" then
                    local meta = metatable.get(value)
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
        local meta = metatable.get(obj)
        s = iterate(meta)
        if string.len(s) ~= 0 then json = json..s.."," end
        s = iterate(meta.__private)
        if string.len(s) ~= 0 then json = json.."private:{"..s.."}," end
        s = iterate(meta.__protected)
        if string.len(s) ~= 0 then json = json.."protected:{"..s.."}," end
        if meta.__super then
            for _, child in ipairs(meta.__super) do
                json = json.."\""..metatable.name(child).."\":{" ..iterate_object(child).."},"
            end
        end
        return json:sub(1, -2)
    end
    return "{"..iterate_object(obj).."}"
end

class.PUBLIC = PUBLIC
class.PROTECTED = PROTECTED
class.PRIVATE = PRIVATE

class.SUPER = SUPER
class.METHOD = METHOD
class.CLASS = CLASS

function class.name(obj)
  return metatable.name(obj)
end

function class.type(obj)
  local meta = metatable.get(obj)
  if meta and meta.__type then return meta.__type
  else return type(obj) end
end

return class
