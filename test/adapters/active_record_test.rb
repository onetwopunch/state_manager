require 'helper'

class ActiveRecordTest < Test::Unit::TestCase

  class PostStates < StateManager::Base
    state :unsubmitted do
      event :submit, :transitions_to => 'submitted.awaiting_review'
    end
    state :submitted do
      state :awaiting_review do
        event :review, :transitions_to => 'submitted.reviewing'
      end
      state :reviewing do
        event :accept, :transitions_to => 'active'
        event :clarify, :transitions_to => 'submitted.clarifying'
      end
      state :clarifying do
        event :review, :transitions_to => 'submitted.reviewing'
      end
    end
    state :active
    state :rejected
  end

  class Post < ActiveRecord::Base
    extend StateManager::Resource
    state_manager
  end

  def exec(sql)
    ActiveRecord::Base.connection.execute sql
  end

  def setup
    ActiveRecord::Base.establish_connection(
      :adapter => "sqlite3",
      :database  => ":memory:" #"tmp/test"
    )

    ActiveRecord::Schema.define do
      create_table :posts do |t|
        t.integer :id
        t.string :title
        t.string :body
        t.string :state
      end
    end

    exec "INSERT INTO posts VALUES(1, NULL, NULL, NULL)"
    exec "INSERT INTO posts VALUES(2, NULL, NULL, 'unsubmitted')"
    exec "INSERT INTO posts VALUES(3, NULL, NULL, 'submitted.reviewing')"
    exec "INSERT INTO posts VALUES(4, NULL, NULL, 'submitted.bad_state')"

    @resource = nil
  end

  def teardown
    ActiveRecord::Base.connection.disconnect!
  end

  def test_adapter_included
    @resource = Post.find(1)
    assert @resource.is_a?(StateManager::Adapters::ActiveRecord::ResourceMethods)
    assert @resource.state_manager.is_a?(StateManager::Adapters::ActiveRecord::ManagerMethods)
  end

  def test_persist_initial_state
    @resource = Post.find(1)
    assert_state 'unsubmitted'
    assert !@resource.changed?, "state should have been persisted"
  end

  def test_initial_state_value
    @resource = Post.find(3)
    assert_state 'submitted.reviewing'
  end

  def test_validate_nil_state
    @resource = Post.find(1)
    assert !@resource.state
    @resource.save
    assert_state 'unsubmitted'
  end

  def test_validate_invalid_state
    @resource = Post.find(4)
    assert_equal 'submitted.bad_state', @resource.state
    @resource.save
    assert_state 'unsubmitted'
  end
end