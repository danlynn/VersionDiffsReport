require "test/unit"
require "lib/app_config"

class AppConfigTest < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.
  def teardown
    # Do nothing
  end

  def test_00_path_nil_until_yaml_loaded
    Object.send(:remove_const, :AppConfig)
    load 'lib/app_config.rb'
    assert_equal(nil, AppConfig.path)
  end
  
  # Unload User class before loading AppConfig instance thus causing error
  # complaining about missing User class which is used within the yaml of the
  # config file.
  def test_05_missing_classes_raises_error
    Object.send(:remove_const, :User) rescue nil # ignore error if NOT already loaded
    e = assert_raise RuntimeError do
      AppConfig.load_yaml('config/config_test.yml')
      p AppConfig['environments']['svn_mock']['users'] # requires 'lib/user' to have been loaded
    end
    assert_match(/WARNING: AppConfig loaded YAML containing classes which havn't been loaded yet:/, e.message)
  end

  # Reload the AppConfig after first loading the User class
  def test_10_lazy_load_default
    load 'lib/user.rb'
    AppConfig.load_yaml('config/config_test.yml')
    #assert(require('lib/user'), "Unable to load 'lib/user'")
    user = AppConfig['environments']['svn_mock']['users']['aaaaa1']
    p user
    assert_equal("Test User1", user.name)
    p user
  end
  
  def test_20_get_by_symbol
    AppConfig.load_yaml('config/config_test.yml')
    assert_equal("EARs", AppConfig[:report_groups]['ears']['name'])
  end

  def test_30_get_by_string
    AppConfig.load_yaml('config/config_test.yml')
    assert_equal("EARs", AppConfig['report_groups']['ears']['name'])
  end

  def test_40_set_by_symbol
    AppConfig.load_yaml('config/config_test.yml')
    assert_equal("EARs", AppConfig[:report_groups]['ears']['name'])
    AppConfig[:report_groups]['ears']['name'] = "changed"
    assert_equal("changed", AppConfig[:report_groups]['ears']['name'])
  end

  def test_50_get_list
#    require "lib/report_params"
    AppConfig.load_yaml('config/config_test.yml')
    groups = AppConfig[:report_groups]['ears']['groups']
    assert_equal(3, groups.size)
  end
end