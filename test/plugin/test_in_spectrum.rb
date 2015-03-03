require 'helper'

class SpectrumInputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    endpoint spectrumapi.test.com
    user username
    pass password
    interval 60
    include_raw true
    tag alert.spectrum
  ]

  def create_driver(conf=CONFIG)
    Fluent::Test::InputTestDriver.new(Fluent::SpectrumInput).configure(conf)
  end

  def test_configure
    d = create_driver('')
    assert_equal "spectrumapi.test.com", d.instance.endpoint
    assert_equal "username", d.instance.user
    assert_equal "password", d.instance.pass
    assert_equal "60".to_i, d.instance.interval
    assert_equal "true", d.instance.include_raw
    assert_equal 'alert.spectrum', d.instance.tag
  end
end