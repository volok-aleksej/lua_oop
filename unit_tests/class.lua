local lunit = require "lunit"

_ENV = lunit.module('class','seeall')

local class = require "class"

function test_simple()
    local a = class.new("a")
    function a:__init()
        assert_equal(a, self)
    end
    a()
end

