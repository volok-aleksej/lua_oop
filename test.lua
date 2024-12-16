local class = require "class"
local count = 1

function new_test(name)
    print("\n"..count.."."..name)
    count = count + 1
end

local a = class.new("a")
function a:__init(data)
    print("a("..tostring(self)..","..data.name..")")
end
function a:__destroy()
    print("~a("..tostring(self)..")")
end

a.data = 5
function a:start()
  print("a.start("..tostring(self)..")")
  self.__private.attr1 = 8
  self.__protected.attr2 = 9
  self:private()
  print(self.attr1)
  self.__protected.start_func = self.private
end
a.start.virtual = true

function a:private()
  print("a.private("..tostring(self)..")")
end
a.private.access = class.PRIVATE

function a:finish()
  print("a.finish("..tostring(self)..")")
  self:start()
end
a.finish.access = class.PROTECTED

new_test("call a:start()")    --1
a:start()
new_test("call a:finish()")    --2
print("call", pcall(a.finish, a))

local b = class.new("b")
function b:__init(data)
    print("b("..tostring(self)..","..data.name..")")
end
function b:__destroy()
    print("~b("..tostring(self)..")")
end

b.data = 5
function b:start()
  print("b.start("..tostring(self)..")")
  self:finish()
end
function b:finish()
  print("b.finish("..tostring(self)..")")
end
b.finish.virtual = true

local c = class.inherit("c", a, b)
function c:__init(data)
    print("c("..tostring(self)..","..data.name..")")
end
function c:__destroy(data)
    print("~c("..tostring(self)..")")
end

c.test = 6
function c:start()
  print("c.start("..tostring(self)..")")
  self.super:start()
end

function c:finish()
  print("c.finish("..tostring(self)..")")
  self.super("a").finish(self)
  self.super("b").finish(self)
end

function c:print_obj_attr()
  self.__private.attr3 = 15
  for name, value in pairs(self.__private) do
    print("private ", name, value)
  end
  for name, value in pairs(self.super.__protected) do
    print("protected ", name, value)
  end
  print(self.super.__private)
  print(self.super.attr1)
  print(self.attr1)
  print(self.attr2)
  print(self.attr3)
end

function c:call_private()
    self:start_func()
end

new_test("print objects \nc: {\n\ta:{\n\t\tvirtual start(),\n\t\tfinish(), \n\t\tdata: 5\n\t},\n\tb:{\n\t\tstart(), \n\t\tvirtual finish()\n\t},\n\ttest:6\n}")      --3
print(a)
print(b)
print(c)
new_test("call c:start()")      --4
c:start()
new_test("call c:finish()")      --5
c:finish()
new_test("print c.data")      --6
print(c.data)
new_test("call a:start()")      --7
a:start()
new_test("call b:finish()")      --8
b:finish()
new_test("get object from a")      --9
print(class.self(a))
new_test("inherit from not class - is created new class but not inherited from anything")      --10
local d = class.inherit("d", {data = 5})
print(d)
print(class.self(d))
new_test("call inherit with incorrect argument - error")      --11
print("call", pcall(class.inherit, {data = 5}))
new_test("call constructors")      --12
c({name = "class c"})
new_test("call super")      --13
c.super:finish()
print("call", pcall(c.super.private, c.super))
print(c.super.data)
new_test("private and protected object attributes")  --14
print(c.__private)
print(c.__protected)
c:print_obj_attr()
print(a.attr2)
new_test("json convertor")      --15
print(class.json(c))
new_test("call private function") --16
c:call_private()

new_test("destructors") --17
