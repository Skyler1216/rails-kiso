class ApplicationMailer < ActionMailer::Base
  # すべてのメールに共通する基本設定を集約するベースクラス

  # デフォルトの送信元アドレスを設定（各Mailerで明示しない限りこのFromが使われる）
  # 本番では環境変数やCredentialsから安全に読み込む運用を推奨
  default from: 'no-reply@example.com'

  # メールの共通レイアウトを指定
  # HTMLメールには app/views/layouts/mailer.html.erb
  # テキストメールには app/views/layouts/mailer.text.erb が適用され、
  # 各メール本文テンプレートがレイアウトの <%= yield %> に差し込まれる
  layout 'mailer'
end
