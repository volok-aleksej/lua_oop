# lua_oop
implementation lua oop like in cpp

## lua oop api
**create class object**\
class.new(*name*)
* *name* : class name
``` 
local a = class.new("a")
```

**create contructor of class**\
function *obj*:__init(...)
* *obj* : object of class
* *...* : parameters of object contructor
```
function a:__init(...)
end
```

**create dectructor of class**\
function *obj*:__destroy()
* *obj*: object of class
* no parameters
```
function a:__destroy()
end
```

**create function of class**\
function *obj*:*func*(...)
* function created as public function
* *obj* : object of class
* *func* : name of function
* *...* : parameters of object function
```
function a:start(...)
end

function a:next(...)
end
```

**set function attributes**
* available attributes:
* * virtual = true

    function is *virtual*
  * access = class.PUBLIC

    function access, may be *class.PUBLIC*, *class.PROTECTED*, *class.PRIVATE*\
    after setting function access\
    function can be not available from global area(for access type *PROTECTED* and *PRIVATE*)
```
a.start.virtual = true
a.start.access = class.PROTECTED
```

**create public attribute of object**
```
a.data = 5
```

**create protected or private attribute of object**
* available only in class function, contructor or destructor 
```
function a:__init(...)
  self.__private.pv_data = 6
  self.__protected.pt_data = 7
end
```

**access to object attributes and functions**
* public attributes and functions available from anywhere
* private attributes and functions available from owner class
* protected attributes and functions available from owner and inheritence class
```
print(a.data)      -- 5
print(a.pv_data)   -- nil
print(a.pt_data)   -- nil
function a:start()
  print(a.data)    -- 5
  print(a.pv_data) -- 6
  print(a.pt_data) -- 7
end
a:next()           -- not error: call successful
a:start()          -- error: attempts call nil value
```
**inheriting classes**
class.inherit(*name*, *obj*[, *obj*...])
* *name* : name of new class
* *obj* : parent class object
```
local b = class.new("b")
local c = class.inherit("c", a, b)
```
**call function from parent class\
*super* keyword**\
self.super:*func*(...)\
self.super(*name*):*func*(...)\
self.super.*attr*\
self.super(name).*attr*
* *super* keyword return access to parent attributes and functions
* * *func* : function name
  * *name* : name of parent object
  * *attr* : name of parent object attribute
```
function c:start(...)
  self.data = 8              -- created data attribute of `c`
  print(self.data)  -- 8
  print(self.super(a).data)  -- 5
  print(self.super.pt_data)  -- 7
  print(self.super.pv_data)  -- nil
  return self.super:start()  -- not error: call successful
end
```

**call virtual function**
```
function a:virt()
  print("a:virt")
end
a.virt.virtual = true

function  c:virt()
  print("c:virt")
  self.super:virt()
end
a:virt()            -- c:virt
                    -- a:virt
```

**call constructors**
```
c({data=6})          -- calls a:__init(), b:__init() and c:__init()
a({data=6})          -- call only a:__init()
b({data=6})          -- call only b:__init()
```
