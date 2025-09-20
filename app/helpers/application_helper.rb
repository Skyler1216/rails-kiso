module ApplicationHelper
  # ================================
  # ヘッダーナビ専用のユーティリティ
  # ================================
  # 右肩上がりで同じクラス指定が散らからないよう、ここでまとめて管理する。
  # ビュー側では helper 経由で呼び出すだけにして、レイアウトを読みやすくする狙い。
  def header_nav_link_class(path)
    classes = ['nav-link']
    classes << 'nav-link--active' if current_page?(path)
    classes.join(' ')
  end

  # ヘッダー内のプライマリボタン（例: 新規登録）で使うクラスを返す。
  # レスポンシブ向けのテキストサイズ指定も含め、呼び出し側で考えることを減らす。
  def header_primary_button_class
    'btn-primary text-xs sm:text-sm'
  end

  # ヘッダー内のセカンダリボタン（例: ログイン/ログアウト）で使うクラスを返す。
  # 必要に応じてここを変更すれば、全ページへ一括反映できる。
  def header_secondary_button_class
    'btn-secondary text-xs sm:text-sm'
  end

  def admin_nav_link_class(path)
    classes = ['admin-link']
    classes << 'admin-link--active' if current_page?(path)
    classes.join(' ')
  end

  # フラッシュメッセージ種別に紐づく Tailwind ユーティリティクラスを返す。
  # notice -> 成功体裁 / それ以外 -> 警告体裁 として扱い、判定ロジックをレイアウトから切り離す。
  def flash_banner_class(type)
    type.to_sym == :notice ? 'flash-success' : 'flash-alert'
  end
end
