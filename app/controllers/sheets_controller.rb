class SheetsController < ApplicationController
  skip_before_action :authenticate_user!, only: :index
  def index
    @sheets = Sheet.all.group_by(&:row)
  end
end
