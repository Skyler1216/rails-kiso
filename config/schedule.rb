# station3,4で説明
# whenever用のスケジュール定義ファイル
# cronは、UNIX/Linuxで使われる「定時実行（スケジューラ）」の仕組みです。
# Railsでは: wheneverがcronエントリを自動生成し、Rakeタスクなどを定期実行できるようにしてくれます。

# wheneverの実行ログ出力先（cron実行時の標準出力/標準エラーをここへ書き出す）
set :output, 'log/whenever.log'

# タスクをどのRails環境で実行するか
# 現状開発検証用に固定（cron登録時に毎回developmentで動作）
set :environment, 'development'

# cronの基準タイムゾーン（ここではJST指定。'7:00 pm'はJSTの19時を意味する）
set :cron_timezone, 'Asia/Tokyo'

# 毎日19:00(JST)に、翌日上映の予約へリマインドメールを送るRakeタスクを実行
every 1.day, at: '7:00 pm' do
  rake 'reservation:send_reminders'
end
