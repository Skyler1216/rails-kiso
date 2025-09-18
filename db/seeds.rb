# === 初期化（外部キー制約の順序に注意） ===
Reservation.destroy_all
Schedule.destroy_all
Sheet.destroy_all
Screen.destroy_all

# === 映画データ ===
inception = Movie.find_or_create_by!(name: 'インセプション') do |movie|
  movie.year = '2010'
  movie.description = '夢の中で夢を見るという斬新なSFアクション'
  movie.image_url = 'https://picsum.photos/200/300?random=1'
  movie.is_showing = true
end

matrix = Movie.find_or_create_by!(name: 'マトリックス') do |movie|
  movie.year = '1999'
  movie.description = '現実と思っていた世界が仮想だった…衝撃の名作'
  movie.image_url = 'https://picsum.photos/200/300?random=2'
  movie.is_showing = true
end

interstellar = Movie.find_or_create_by!(name: 'インターステラー') do |movie|
  movie.year = '2014'
  movie.description = '時空を超える父と娘の絆を描くSF大作'
  movie.image_url = 'https://picsum.photos/200/300?random=3'
  movie.is_showing = true
end

movies = [inception, matrix, interstellar]

# === スクリーン作成 ===
screens = ['Screen 1', 'Screen 2', 'Screen 3'].map do |name|
  Screen.create!(name: name)
end

# === 各スクリーンに座席を作成（A-1～C-5） ===
screens.each do |screen|
  ('a'..'c').each do |row|
    (1..5).each do |column|
      Sheet.create!(screen: screen, row: row, column: column)
    end
  end
end

# === 各スクリーンに同じ時間帯のスケジュールを設定 ===
Schedule.destroy_all # 念のため再度クリア

(0..6).each do |i| # 1週間分
  date = Date.today + i

  [
    [10, 0, 12, 30],
    [14, 0, 16, 30],
    [18, 0, 20, 30]
  ].each do |start_hour, start_min, end_hour, end_min|
    screens.each_with_index do |screen, idx|
      Schedule.create!(
        movie: movies[idx],
        screen: screen,
        start_time: date.to_datetime.change(hour: start_hour, min: start_min),
        end_time: date.to_datetime.change(hour: end_hour, min: end_min)
      )
    end
  end
end
