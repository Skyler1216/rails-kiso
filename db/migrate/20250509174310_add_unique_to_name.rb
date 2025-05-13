class AddUniqueToName < ActiveRecord::Migration[7.1]
  def change
    # 既存の index を削除
    remove_index :movies, :name if index_exists?(:movies, :name)

    # 新しくユニークな index を追加
    add_index :movies, :name, unique: true
  end
end
