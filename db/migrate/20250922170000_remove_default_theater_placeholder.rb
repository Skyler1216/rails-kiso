class RemoveDefaultTheaterPlaceholder < ActiveRecord::Migration[7.1]
  def up
    default_theater_id = select_value(<<~SQL)
      SELECT id
      FROM theaters
      WHERE name = 'デフォルト劇場'
        AND address = '未設定'
      ORDER BY id
      LIMIT 1
    SQL

    return if default_theater_id.blank?

    default_theater_id = default_theater_id.to_i

    screens_linked = select_value(<<~SQL)
      SELECT COUNT(*)
      FROM screens
      WHERE theater_id = #{default_theater_id}
    SQL

    if screens_linked.to_i.positive?
      raise ActiveRecord::IrreversibleMigration,
            'デフォルト劇場に紐づいたスクリーンが残っています。削除前に theater_id を更新してください。'
    end

    execute(<<~SQL)
      DELETE FROM theaters
      WHERE id = #{default_theater_id}
    SQL
  end

  def down
    existing = select_value(<<~SQL)
      SELECT COUNT(*)
      FROM theaters
      WHERE name = 'デフォルト劇場'
        AND address = '未設定'
    SQL

    return unless existing.to_i.zero?

    execute(<<~SQL)
      INSERT INTO theaters (name, address, is_active, created_at, updated_at)
      VALUES ('デフォルト劇場', '未設定', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end
end
