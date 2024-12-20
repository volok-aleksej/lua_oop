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
    local a = class.new("a")
    local b = class.inherit("b", a)
    function b:__destroy()
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
end
