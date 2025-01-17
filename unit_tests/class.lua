local lunit = require "lunit"

_ENV = lunit.module('class','seeall')

local class = require "class"

function test_simple()
    local a = class.new("a")
    function a:__init()
        assert_equal(a, self)
        a.data = 5
    end
    a()
    assert_equal(5, a.data)
end

function test_private()
    local a = class.new("a")
    function a:__init()
        self.__private.attr1 = "attr1"
        self.__protected.attr2 = "attr2"
        assert_equal("attr1", self.attr1)
        assert_equal("attr2", self.attr2)
    end
    a()
    assert_equal(nil, a.attr1)
    assert_equal(nil, a.attr2)

    function a:check_private()
        assert_equal("attr1", self.attr1)
        assert_equal("attr2", self.attr2)
    end

    a:check_private()

    a.check_private.access = class.PRIVATE
    assert_error("call private", function() a:check_private() end)
end

function test_inherit()
    local a = class.new("a")
    function a:__init()
        assert_equal(a, self)
        self.attr1 = "attr1"
        self.__protected.attr3 = "attr3"
    end

    local b = class.inherit("b", a)
    function b:__init()
        assert_equal(b, self)
        self.attr2 = "attr2"
        assert_equal("attr3", self.attr3)
    end

    b()

    assert_equal("attr1", b.attr1)
    assert_equal("attr2", b.attr2)
    assert_equal(nil, b.attr3)

    function a:func1()
        return true
    end

    assert_equal(true, b:func1())
end


function test_virtual()
    local a = class.new("a")
    local b = class.inherit("b", a)

    function a:virtual_func()
        self.attr1 = "attr1"
    end
    a.virtual_func.virtual = true

    function a:virtual_func_one()
        self.attr5 = "attr5"
    end
    a.virtual_func_one.virtual = true

    function b:virtual_func()
        self.attr2 = "attr2"
        assert_equal(nil, self.attr1)
        self.super:virtual_func()
        assert_equal("attr1", self.attr1)
    end

    a:virtual_func()
    assert_equal("attr1", b.attr1)
    assert_equal("attr2", b.attr2)

    function a:non_virt_func()
        self.attr3 = "attr3"
    end

    function b:non_virt_func()
        self.attr4 = "attr4"
    end

    a:non_virt_func()
    assert_equal("attr3", b.attr3)
    assert_equal(nil, b.attr4)
    b:non_virt_func()
    assert_equal("attr4", b.attr4)
    b:virtual_func_one()
    assert_equal("attr5", b.attr5)
end

function test_super()
    local a = class.new("a")
    local c = class.new("c")
    local b = class.inherit("b", a, c)
    function a:__init()
        self.attr2 = "a_attr2"
        self.__protected.attr1 = "a_attr1"
    end

    function b:__init()
        self.attr2 = "b_attr2"
        self.__private.attr1 = "b_attr1"
    end

    function c:__init()
        self.attr3 = "attr3"
    end

    b()
    assert_equal("b_attr2", b.attr2)
    assert_equal("a_attr2", b.super.attr2)
    assert_equal("a_attr2", b.super("a").attr2)
    assert_equal(nil, b.super.attr1)
    assert_equal("attr3", b.super.attr3)

    function b:test_super()
        assert_equal("b_attr1", self.attr1)
        assert_equal("a_attr1", self.super.attr1)
    end

    b:test_super()
end

function test_getmetatable()
    local a = class.new("a")
    function a:data()
    end
    local meta = getmetatable(a)
    assert_equal(nil, meta.data)
end

function test_access_functions()
    local a = class.new("a")
    function a:__init()
        function self.__protected.test(self)
            assert_equal(self, a)
        end
    end
    function a:data()
        self:test()
    end
    a()
    a:data()
end

function test_destroy()
    local test = 5
    local test_1 = 8
    local a = class.new("a")
    local b = class.inherit("b", a)
    function b:__destroy()
        test_1 = 9
        assert_equal(5, test)
        test = 6
    end

    function a:__destroy()
        assert_equal(6, test)
        test = 7
    end
    a.__destroy.virtual = true

    class.delete(a)

    assert_equal(7, test)
    assert_equal(9, test_1)
end


function test_multi_inherit()
    local a = class.new("a")
    local b = class.inherit("b", a)
    local d = class.new("d")
    local c = class.inherit("c", b, d)

    local test = 5
    function d:data()
        test = 6
    end
    function c:data()
        test = 7
    end
    function b:data()
        test = 8
    end
    function a:data()
        test = 9
    end
    a.data.virtual = true

    b:data()
    assert_equal(7, test)

    test = 5
    a:data()
    assert_equal(7, test)

    test = 5
    d:data()
    assert_equal(6, test)
end

function test_super_set()
    local a = class.new("a")
    local b = class.inherit("b", a)
    
    function a:data()
        self.attr2 = 5
    end

    function b:data()
        self.super:data()
        self.super.attr2 = 6
    end

    b.data()
    assert_equal(6, b.attr2)
end

function test_type()
    local a = class.new("a")
    local b = class.inherit("b", a)

    function a:data()
    end
    a.test = 5

    function b:data()
    end
    b.test = 6

    assert_equal(class.CLASS, class.type(a))
    assert_equal(class.CLASS, class.type(b))
    assert_equal(class.METHOD, class.type(a.data))
    assert_equal(class.METHOD, class.type(b.data))
    assert_equal(class.SUPER, class.type(b.super))
    assert_equal(class.SUPER, class.type(b.super(a)))
    assert_equal("number", class.type(a.test))
    assert_equal("number", class.type(b.test))
end

function test_iteration()
    local a = class.new("a")
    local b = class.inherit("b", a)

    local function iter(obj, mass)
        for name, value in pairs(obj) do
            table.insert(mass, {name=name, type=class.type(value)})
        end
    end

    function a:data()
        local mass = {}
        iter(self, mass)
        assert_equal(2, #mass)
        assert_equal("test", mass[1].name)
        assert_equal("number", mass[1].type)
        assert_equal("data", mass[2].name)
        assert_equal(class.METHOD, mass[2].type)
    end
    a.test = 5

    function b:data()
        self.__protected.arg = "arg"
        local mass = {}
        iter(self, mass)
        assert_equal(6, #mass)
        assert_equal("test", mass[1].name)
        assert_equal("number", mass[1].type)
        assert_equal("arg", mass[2].name)
        assert_equal("string", mass[2].type)
        assert_equal(class.METHOD, mass[3].type)
        assert_equal(class.METHOD, mass[4].type)
        assert_equal("test", mass[5].name)
        assert_equal("number", mass[5].type)
        assert_equal("data", mass[6].name)
        assert_equal(class.METHOD, mass[6].type)
        self.super:data()
    end

    function b:func()
        self.__protected.arg = "arg"
    end
    b.func.access = class.PRIVATE
    b.test = 6

    b:data()

    local mass = {}
    iter(b, mass)
    assert_equal(4, #mass)
    assert_equal("test", mass[1].name)
    assert_equal("number", mass[1].type)
    assert_equal("data", mass[2].name)
    assert_equal(class.METHOD, mass[2].type)
    assert_equal("test", mass[3].name)
    assert_equal("number", mass[3].type)
    assert_equal("data", mass[4].name)
    assert_equal(class.METHOD, mass[4].type)
end
