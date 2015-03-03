require 'helper'

class SpectrumInputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
  ]

  def create_driver(conf=CONFIG)
    Fluent::Test::InputTestDriver.new(Fluent::SpectrumInput).configure(conf)
  end

  def test_configure
    d = create_driver('')
    assert_equal "pleasechangeme.com", d.instance.endpoint
    assert_equal "username", d.instance.user
    assert_equal "password", d.instance.pass
    assert_equal "300".to_i, d.instance.interval
    assert_equal "false", d.instance.include_raw
    assert_equal 'alert.spectrum', d.instance.tag
  end
end