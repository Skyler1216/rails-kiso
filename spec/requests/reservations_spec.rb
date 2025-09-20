require 'rails_helper'

RSpec.describe 'Reservations', type: :request do
  describe 'POST /reservations' do
    context 'when unauthenticated' do
      it 'redirects to the login page' do
        post reservations_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when authenticated' do
      it 'processes the reservation request' do
        user = create(:user)
        sign_in(user)

        movie = create(:movie)
        screen = create(:screen)
        sheet = create(:sheet, screen: screen)
        schedule = create(:schedule, movie: movie, screen: screen)

        post reservations_path, params: {
          reservation: {
            name: user.name,
            email: user.email,
            schedule_id: schedule.id,
            sheet_id: sheet.id,
            screen_id: screen.id,
            date: Date.today
          }
        }

        expect(response).to redirect_to(movie_path(movie))
      end
    end
  end
end
