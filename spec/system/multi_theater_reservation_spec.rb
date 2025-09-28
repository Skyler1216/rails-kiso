require 'rails_helper'

RSpec.describe 'Multi theater reservation flow', type: :system do
  before do
    driven_by(:rack_test)
  end

  it 'allows a user to pick a theater and complete a reservation' do
    user = create(:user)
    movie = create(:movie)

    theater_a = create(:theater, name: 'A-シネマ', address: '東京都千代田区1-1-1')
    screen_a = create(:screen, theater: theater_a, name: 'スクリーンA')
    create(:sheet, screen: screen_a, row: 'a', column: 1)

    theater_b = create(:theater, name: 'B-シネマ', address: '大阪府大阪市2-2-2')
    screen_b = create(:screen, theater: theater_b, name: 'スクリーンB')
    seat_b = create(:sheet, screen: screen_b, row: 'b', column: 2)

    base_date = Time.zone.today + 1
    start_time_a = Time.zone.local(base_date.year, base_date.month, base_date.day, 10, 0, 0)
    start_time_b = Time.zone.local(base_date.year, base_date.month, base_date.day, 14, 0, 0)

    create(:schedule, movie: movie, screen: screen_a, start_time: start_time_a)
    schedule_b = create(:schedule, movie: movie, screen: screen_b, start_time: start_time_b)

    visit new_user_session_path
    fill_in 'メールアドレス', with: user.email
    fill_in 'パスワード', with: 'testuser'
    click_button 'ログインする'

    visit movie_path(movie)

    select 'B-シネマ', from: '劇場を選択'
    date_label = start_time_b.to_date.strftime('%Y年%m月%d日')
    select date_label, from: '日付を選択'
    click_button '上映スケジュールを表示'

    expect(page).to have_content('選択中の劇場')
    expect(page).to have_content('B-シネマ')
    expect(page).not_to have_content('スクリーンA')

    schedule_label = "#{start_time_b.strftime('%H:%M')}～#{(start_time_b + 2.hours).strftime('%H:%M')} / #{screen_b.name}"
    select schedule_label, from: 'スケジュールを選択'
    click_button '座席を選ぶ'

    expect(page).to have_content('B-シネマ')
    expect(page).to have_link('B-2')

    click_link 'B-2'

    expect(page).to have_content('Confirm Reservation')
    expect(page).to have_content('B-シネマ')
    expect(page).to have_content('スクリーンB')

    expect do
      click_button '予約を確定する'
    end.to change(Reservation, :count).by(1)

    expect(page).to have_content('予約が完了しました')

    latest_reservation = Reservation.order(:created_at).last
    expect(latest_reservation.screen).to eq(screen_b)
    expect(latest_reservation.sheet).to eq(seat_b)
    expect(latest_reservation.date.to_s).to eq(schedule_b.start_time.to_date.to_s)
  end
end
