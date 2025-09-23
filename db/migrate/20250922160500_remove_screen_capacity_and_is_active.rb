class RemoveScreenCapacityAndIsActive < ActiveRecord::Migration[7.1]
  def up
    remove_column :screens, :capacity if column_exists?(:screens, :capacity)
    remove_column :screens, :is_active if column_exists?(:screens, :is_active)
  end

  def down
    unless column_exists?(:screens, :capacity)
      add_column :screens, :capacity, :integer, null: false, default: 15, comment: '座席数 (3x5)'
    end

    unless column_exists?(:screens, :is_active)
      add_column :screens, :is_active, :boolean, null: false, default: true, comment: '使用フラグ'
    end
  end
end
