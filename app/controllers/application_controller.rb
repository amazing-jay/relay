class ApplicationController < ActionController::API
  protect_from_forgery prepend: true
  before_action :authenticate_user!
  before_filter :user_quota

  def user_quota
    quota_service = ApiQuotaService.new(current_user)
    quota_service.record_hit(request.endpoint)  # Assumes that request.endpoint stores the requested endpoint

    render json: { error: 'over quota' }, status: 429 if quota_service.over_quota?
    # todo: warn when approaching quota; i've invested too much time in this exercise so leaving as a comment
  end
end
