require 'rails_helper'

RSpec.describe PersistHitLogsJob, type: :job do
  describe '#perform' do
    it 'calls the class method to persist logs with the correct time zone' do
      time_zone = 'UTC'
      expect(ApiQuotaService).to receive(:persist_remaining_logs_for_time_zone).with(time_zone)
      described_class.perform_now(time_zone)
    end

    it 'calls the class method to persist logs with a different time zone' do
      time_zone = 'Pacific Time (US & Canada)'
      expect(ApiQuotaService).to receive(:persist_remaining_logs_for_time_zone).with(time_zone)
      described_class.perform_now(time_zone)
    end
  end
end
