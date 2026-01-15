# frozen_string_literal: true

require "cases/helper"
require "active_job"

class DummyDestroyAsyncJob < ActiveJob::Base
  self.queue_adapter = :test

  def perform(*); end
end

class DestroyAsyncWithoutPkTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  teardown do
    with_lease_connection do |connection|
      connection.drop_table(:owners_without_pk_assocs, if_exists: true)
      connection.drop_table(:dependents_without_pk, if_exists: true)
      connection.drop_table(:profiles_without_pk, if_exists: true)
      connection.drop_table(:posts_without_pk, if_exists: true)
      connection.drop_table(:comments_destroy_async, if_exists: true)
    end
  end

  def test_has_many_destroy_async_raises_when_target_has_no_primary_key
    previous_job = ActiveRecord::Base._destroy_association_async_job
    ActiveRecord::Base._destroy_association_async_job = DummyDestroyAsyncJob

    with_lease_connection do |connection|
      connection.create_table(:owners_without_pk_assocs, force: true) do |t|
        t.string :name
      end

      connection.create_table(:dependents_without_pk, id: false, force: true) do |t|
        t.integer :owner_id
        t.string :name
      end
    end

    owner_class = Class.new(ActiveRecord::Base) do
      self.table_name = "owners_without_pk_assocs"

      has_many :dependents_without_pk,
        class_name: "DestroyAsyncDependentWithoutPk",
        foreign_key: :owner_id,
        dependent: :destroy_async

      def self.name
        "DestroyAsyncOwnerWithoutPkAssoc"
      end
    end

    dependent_class = Class.new(ActiveRecord::Base) do
      self.table_name = "dependents_without_pk"
      self.primary_key = nil

      belongs_to :owner_without_pk_assoc,
        class_name: "DestroyAsyncOwnerWithoutPkAssoc",
        foreign_key: :owner_id

      def self.name
        "DestroyAsyncDependentWithoutPk"
      end
    end

    Object.const_set(owner_class.name, owner_class)
    Object.const_set(dependent_class.name, dependent_class)

    owner = owner_class.create!(name: "owner")
    dependent_class.create!(owner_without_pk_assoc: owner, name: "dep")

    error = assert_raises(ActiveRecord::UnknownPrimaryKey) { owner.destroy }
    assert_includes error.message, "cannot destroy associated records asynchronously without a primary key"
  ensure
    ActiveRecord::Base._destroy_association_async_job = previous_job
    Object.send(:remove_const, owner_class.name) if owner_class && Object.const_defined?(owner_class.name)
    Object.send(:remove_const, dependent_class.name) if dependent_class && Object.const_defined?(dependent_class.name)
  end

  def test_has_one_destroy_async_raises_when_target_has_no_primary_key
    previous_job = ActiveRecord::Base._destroy_association_async_job
    ActiveRecord::Base._destroy_association_async_job = DummyDestroyAsyncJob

    with_lease_connection do |connection|
      connection.create_table(:owners_without_pk_assocs, force: true) do |t|
        t.string :name
      end

      connection.create_table(:profiles_without_pk, id: false, force: true) do |t|
        t.integer :owner_id
        t.string :bio
      end
    end

    owner_class = Class.new(ActiveRecord::Base) do
      self.table_name = "owners_without_pk_assocs"

      has_one :profile_without_pk,
        class_name: "DestroyAsyncProfileWithoutPk",
        foreign_key: :owner_id,
        dependent: :destroy_async

      def self.name
        "DestroyAsyncOwnerWithoutPkAssoc"
      end
    end

    profile_class = Class.new(ActiveRecord::Base) do
      self.table_name = "profiles_without_pk"
      self.primary_key = nil

      belongs_to :owner_without_pk_assoc,
        class_name: "DestroyAsyncOwnerWithoutPkAssoc",
        foreign_key: :owner_id

      def self.name
        "DestroyAsyncProfileWithoutPk"
      end
    end

    Object.const_set(owner_class.name, owner_class)
    Object.const_set(profile_class.name, profile_class)

    owner = owner_class.create!(name: "owner")
    profile_class.create!(owner_without_pk_assoc: owner, bio: "text")

    error = assert_raises(ActiveRecord::UnknownPrimaryKey) { owner.destroy }
    assert_includes error.message, "cannot destroy associated records asynchronously without a primary key"
  ensure
    ActiveRecord::Base._destroy_association_async_job = previous_job
    Object.send(:remove_const, owner_class.name) if owner_class && Object.const_defined?(owner_class.name)
    Object.send(:remove_const, profile_class.name) if profile_class && Object.const_defined?(profile_class.name)
  end

  private
    def with_lease_connection
      connection = ActiveRecord::Base.lease_connection
      yield connection
    ensure
      ActiveRecord::Base.connection_pool.release_connection(connection) if connection
    end
end
