class CreateTheatersAndExtendScreens < ActiveRecord::Migration[7.1]
  # 複数の劇場を扱えるようにするための変更です。
  # 「up」は変更を適用するとき、「down」は元に戻すときに使います。
  def up
    # 1) 劇場テーブルを新しく作成
    # - 劇場の名前、住所、電話番号、営業中かどうかを保存できるようにします
    # - 作成日時と更新日時も自動で記録されます
    create_table :theaters do |t|
      t.string  :name,    null: false, comment: '劇場名'
      t.string  :address, null: false, comment: '所在地'
      t.string  :phone,                comment: '電話番号'
      t.boolean :is_active, default: true, null: false, comment: '営業フラグ'
      t.timestamps
    end

    # 2) 既存の「スクリーン」テーブルに「どの劇場のスクリーンか」を示す欄を追加
    # - これで「A館のスクリーン1」「B館のスクリーン2」といった区別ができます
    # - データベースに「必ず実在する劇場にだけ紐づく」というルールを追加します
    add_reference :screens, :theater, foreign_key: true, comment: '劇場ID'

    # 3) すでにあるスクリーンのデータを整理
    # - 今あるスクリーンには「どの劇場か」がまだ入っていない（空欄）
    # - 空欄のまま「必須ルール」を付けるとエラーになるため、
    #   まず「デフォルト劇場」を1つ登録しておきます
    default_theater_id = insert <<~SQL
      INSERT INTO theaters (name, address, is_active, created_at, updated_at)
      VALUES ('デフォルト劇場', '未設定', TRUE, NOW(), NOW())
    SQL

    # - すべての既存スクリーンを「デフォルト劇場」に紐づけます
    execute <<~SQL
      UPDATE screens SET theater_id = #{default_theater_id}
    SQL

    # - 全部のスクリーンに「劇場」が設定できたので、
    #   これ以降は「必ず劇場が入っていないとダメ」というルールを有効にします
    # 【「screens テーブルの theater_id 列は NULL（空欄）を禁止】にする
    change_column_null :screens, :theater_id, false
  end

  def down
    # 変更を取り消すときの処理（bundle exec rails db:rollback で元に戻す）
    # - スクリーンから「劇場」の欄を消す
    # - 劇場テーブル自体も削除する
    remove_reference :screens, :theater, foreign_key: true
    drop_table :theaters
  end
end
