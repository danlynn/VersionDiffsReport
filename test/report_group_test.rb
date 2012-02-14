require 'rubygems'
unless require 'active_support/core_ext' # for inflections
  raise "Config error: active_support not found! Try installing activesupport gem or rails gem."
end

require 'test/unit'
require 'pp'

require 'lib/report_group'
require 'lib/utils'


class ReportGroupTest < Test::Unit::TestCase

  AppConfig.load_yaml("config/config_test.yml")  
  
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

  # Test ReportGroup#commits on a group with a non-existent group reference for 
  # the find_by attribute.
  def test_010_commits_bad_find_by_group_reference
    root_report_group = ReportGroup.root_report_group(["test_bad_sort_group"], {}, [])
    report_group = root_report_group.groups[0]
    e = assert_raise RuntimeError do
      report_group.commits
    end
    assert_match(/find_by which forwards to a non-existent group/, e.message, "Failed to raise expected config error.  Raised: #{e.message}")
  end

  # Test ReportGroup#commits on a group with a nested find_by group reference 
  # with a non-existent group reference for the find_by attribute.
  def test_020_commits_bad_nested_find_by_group_reference
    root_report_group = ReportGroup.root_report_group(["test_bad_sort_group_parent"], {}, [])
    report_group = root_report_group.groups[0]
    e = assert_raise RuntimeError do
      report_group.commits
    end
    assert_match(/find_by which forwards to a non-existent group/, e.message, "Failed to raise expected config error.  Raised: #{e.message}")
  end

  # Test ReportGroup.initialize on a bad group name
  def test_030_initialize_bad_group_name
    e = assert_raise RuntimeError do
      ReportGroup.root_report_group(["non_existant_group_name"], {}, [])
    end
    assert_match(/group '.*?' that has not been defined/, e.message, "Failed to raise expected config error.  Raised: #{e.message}")
  end

  # Test ReportGroup.initialize on a sub-groups that create a cyclical graph by
  # referring back to a group in the parent hierarchy
  def test_040_initialize_cyclical_group_hierarchy
    e = assert_raise RuntimeError do
      ReportGroup.root_report_group(["test_loop_1"], {}, [])
    end
    assert_match(/attempts to loop back on itself/, e.message, "Failed to raise expected config error.  Raised: #{e.message}")
  end

  # Test ReportGroup#find_by_vcs
  def test_050_find_by_vcs
    root_report_group = ReportGroup.root_report_group(
        ["module3_by_tier"], 
        {"env_name" => "svn_mock", "first_commit_id" => "2520", "last_commit_id" => "2537"}
    )
    puts root_report_group.groups[0].groups[0].commit_paths.to_yaml
    assert_equal(
        IO.read("test_data/expected_results/test_050_find_by_vcs.yml"),
        root_report_group.groups[0].groups[0].commit_paths.to_yaml
    )
  end
  
  # Test that ReportGroup#find_by_vcs raises config error when no commit ID 
  # range has been provided.
  def test_060_find_by_vcs_with_no_commit_id_range
    root_report_group = ReportGroup.root_report_group(
        ["module3_by_tier"], 
        {"env_name" => "svn_mock"}
    )
    e = assert_raise RuntimeError do
      root_report_group.groups[0].groups[0].commit_paths
    end
    assert_match(/'find_by' 'vcs' without any 'first_commit_id' or 'last_commit_id'/, e.message, "Failed to raise expected config error.  Raised: #{e.message}")
  end

  # Test that ReportGroup#find_by_vcs will work correctly in nested groups by 
  # over-riding env_name in the report group options config
  def test_065_find_by_vcs_with_nested_find_by_vcs_with_options_override
    root_report_group = ReportGroup.root_report_group(
        ["test_commits_in_3_env"], 
        {"env_name" => "trunk", "first_commit_id" => "2520", "last_commit_id" => "2537"},
        []
    )
    #puts "\n\n=====\n#{root_report_group.groups[0].groups[0].commits.to_yaml}\n=====\n\n"
    assert_equal(
        IO.read("test_data/expected_results/test_065_find_by_vcs_with_nested_find_by_vcs_with_options_override.yml"),
        root_report_group.groups[0].groups[0].commits.to_yaml
    )
  end

  # Test that ReportGroup#find_by_vcs will work correctly in nested groups by 
  # over-riding env_name in the report group find_by:vcs:env_name config
  def test_066_find_by_vcs_with_nested_find_by_vcs_with_args_override
    root_report_group = ReportGroup.root_report_group(
        ["test_commits_in_3_env"], 
        {"env_name" => "trunk", "first_commit_id" => "2520", "last_commit_id" => "2537"},
        []
    )
    assert_equal(
        IO.read("test_data/expected_results/test_065_find_by_vcs_with_nested_find_by_vcs_with_options_override.yml"),
        root_report_group.groups[0].groups[1].commits.to_yaml
    )
  end

  # Test that ReportGroup#find_by_vcs raises a Configuration Error if a
  # non-existent env_name is specified in the report group options over-ride
  def test_067_find_by_vcs_with_bad_env_name_override
    root_report_group = ReportGroup.root_report_group(
        ["test_commits_in_3_env"], 
        {"env_name" => "trunk", "first_commit_id" => "2520", "last_commit_id" => "2537"},
        []
    )
    e = assert_raise RuntimeError do
      root_report_group.groups[0].groups[2].commits
    end
    assert_match(/Specified env_name 'svn_mock3' not found in environments config./, e.message, "Failed to raise expected config error.  Raised: #{e.message}")
  end  
  
  # Test ReportGroup#commit_paths on a group a nested group where both the group
  # and its parent group have commit_path find_by filters.  This also tests the 
  # find_by_vcs filter.
  def test_070_commit_paths_multiple_parent_filters
    root_report_group = ReportGroup.root_report_group(
        ["module3_by_tier"], 
        {"env_name" => "svn_mock", "first_commit_id" => "2520", "last_commit_id" => "2537"}
    )
    #puts "\n\n==0,0==\n#{root_report_group.groups[0].groups[0].commit_paths.to_yaml}\n==0,0==\n\n"
    assert_equal(
        IO.read("test_data/expected_results/test_070_commit_paths_multiple_parent_filters_0.yml"),
        root_report_group.groups[0].groups[0].commit_paths.to_yaml
    )
    #puts "\n\n==0,1==\n#{root_report_group.groups[0].groups[1].commit_paths.to_yaml}\n==0,1==\n\n"
    assert_equal(
        IO.read("test_data/expected_results/test_070_commit_paths_multiple_parent_filters_1.yml"),
        root_report_group.groups[0].groups[1].commit_paths.to_yaml
    )
  end

  def test_075_find_by_user
    options = {"env_name" => "svn_mock", "first_commit_id" => "2520", "last_commit_id" => "2537"}
    Utils.populate_users(options)
    root_report_group = ReportGroup.root_report_group(
        ["test_no_commit_path_queries_2"], 
        options
    )
    #puts "\n\n=====\n#{root_report_group.groups[0].commits.to_yaml}\n=====\n\n"
    assert_equal(
        IO.read("test_data/expected_results/test_075_find_by_user.yml"),
        root_report_group.groups[0].commits.to_yaml
    )
  end

  # Test ReportGroup#commit_paths on a nested group where none of the groups in
  # the hierarchy have find_by commit_path filters.  Note that this also tests
  # that the ReportGroup#find_by_user works.
  def test_080_commit_paths_with_no_find_by_commit_path_filters
    options = {"env_name" => "svn_mock", "first_commit_id" => "2520", "last_commit_id" => "2537"}
    Utils.populate_users(options)
    root_report_group = ReportGroup.root_report_group(
        ["test_no_commit_path_queries_1"], 
        options
    )
    puts "\n\n=====\n#{root_report_group.groups[0].groups[0].commit_paths.to_yaml}\n=====\n\n"
    assert_equal(
        IO.read("test_data/expected_results/test_080_commit_paths_with_no_find_by_commit_path_filters.yml"),
        root_report_group.groups[0].groups[0].commit_paths.to_yaml
    )
  end

end