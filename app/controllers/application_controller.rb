class ApplicationController < ActionController::API
  protect_from_forgery prepend: true
  before_action :authenticate_user!
  before_filter :user_quota

  def user_quota
    render json: { error: 'over quota' } if current_user.count_hits >= 10000
  end
end
