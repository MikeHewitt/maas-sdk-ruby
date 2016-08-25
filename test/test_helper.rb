require 'coveralls'
Coveralls.wear!

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'miracl_api'

require 'minitest/autorun'
require "mocha/mini_test"
