# 映画データ（重複防止のため find_or_create_by! を使用）
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
  movie.is_showing = false
end

interstellar = Movie.find_or_create_by!(name: 'インターステラー') do |movie|
  movie.year = '2014'
  movie.description = '時空を超える父と娘の絆を描くSF大作'
  movie.image_url = 'https://picsum.photos/200/300?random=3'
  movie.is_showing = true
end

# 座席マスターデータ（重複チェック省略して強制挿入）
Sheet.destroy_all
Sheet.create!([
  { id: 1, column: 1, row: 'a' },
  { id: 2, column: 2, row: 'a' },
  { id: 3, column: 3, row: 'a' },
  { id: 4, column: 4, row: 'a' },
  { id: 5, column: 5, row: 'a' },
  { id: 6, column: 1, row: 'b' },
  { id: 7, column: 2, row: 'b' },
  { id: 8, column: 3, row: 'b' },
  { id: 9, column: 4, row: 'b' },
  { id: 10, column: 5, row: 'b' },
  { id: 11, column: 1, row: 'c' },
  { id: 12, column: 2, row: 'c' },
  { id: 13, column: 3, row: 'c' },
  { id: 14, column: 4, row: 'c' },
  { id: 15, column: 5, row: 'c' }
])

# インセプションに紐づく上映スケジュール5件
Schedule.where(movie: inception).destroy_all

(0..13).each do |i|
  date = Date.today + i

  [
    [10, 0, 12, 30],
    [14, 0, 16, 30],
    [18, 0, 20, 30]
  ].each do |start_hour, start_min, end_hour, end_min|
    Schedule.create!(
      movie: inception,
      start_time: date.to_datetime.change({ hour: start_hour, min: start_min }),
      end_time:   date.to_datetime.change({ hour: end_hour,   min: end_min })
    )
  end
end

# マトリックスのスケジュール30日分
Schedule.where(movie: matrix).destroy_all

(0..29).each do |i|
  date = Date.today + i
  Schedule.create!(
    movie: matrix,
    start_time: date.to_datetime.change({ hour: 14, min: 0 }),
    end_time: date.to_datetime.change({ hour: 16, min: 30 })
  )
end