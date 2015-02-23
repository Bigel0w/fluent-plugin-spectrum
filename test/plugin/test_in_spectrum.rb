require 'helper'

class SpectrumInputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    host 0
    port 1062
    tag alert.spectrum
  ]

  def create_driver(conf=CONFIG)
    Fluent::Test::InputTestDriver.new(Fluent::SpectrumInput).configure(conf)
  end

  def test_configure
    d = create_driver('')
    assert_equal "0".to_i, d.instance.host
    assert_equal "1062".to_i, d.instance.port
    assert_equal 'alert.spectrum', d.instance.tag
  end
end