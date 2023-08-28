class PersistHitLogsJob < ApplicationJob
  include Sidekiq::Worker

  def perform(time_zone)
    ApiQuotaService.persist_remaining_logs_for_time_zone(time_zone)
  end
end
