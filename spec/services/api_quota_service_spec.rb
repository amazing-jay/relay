# spec/services/api_quota_service_spec.rb
require 'rails_helper'

RSpec.describe ApiQuotaService do
  let(:user) { create(:user) }
  let(:api_quota_service) { described_class.new(user) }

  before do
    # Stubbing Redis calls
    allow($redis).to receive(:get).and_return(nil)
    allow($redis).to receive(:set)
    allow($redis).to receive(:multi).and_yield
    allow($redis).to receive(:incr)
    allow($redis).to receive(:rpush)
    allow($redis).to receive(:expire)
    allow($redis).to receive(:setnx).and_return(true)
    allow($redis).to receive(:lrange).and_return([])
    allow($redis).to receive(:del)
    allow($redis).to receive(:llen).and_return(0)
  end

  describe '#over_quota?' do
    context 'when under quota' do
      it 'returns false' do
        allow($redis).to receive(:get).and_return('1000')
        expect(api_quota_service.over_quota?).to be_falsey
      end
    end

    context 'when over quota' do
      it 'returns true' do
        allow($redis).to receive(:get).and_return('10001')
        expect(api_quota_service.over_quota?).to be_truthy
      end
    end
  end

  describe '#record_hit' do
    context 'when under quota' do
      it 'increments hit count' do
        expect($redis).to receive(:incr)
        api_quota_service.record_hit('/test')
      end
    end

    context 'when over quota' do
      it 'does not increment hit count' do
        allow(api_quota_service).to receive(:over_quota?).and_return(true)
        expect($redis).not_to receive(:incr)
        api_quota_service.record_hit('/test')
      end
    end
  end

  describe '#persist_logs!' do
    it 'persists logs to database' do
      logs = [{ 'endpoint' => '/test', 'created_at' => Time.now.to_s }]
      allow($redis).to receive(:lrange).and_return(logs.map(&:to_json))
      expect {
        api_quota_service.persist_logs!
      }.to change { Hit.count }.by(1)
    end
  end

  describe '#flush_keys_to_new_timezone' do
    it 'changes keys according to new timezone' do
      expect($redis).to receive(:del).twice
      expect(api_quota_service).to receive(:reset_hit_count_from_db)
      api_quota_service.flush_keys_to_new_timezone('America/New_York')
    end
  end

  describe '.schedule_persist_jobs_for_all_time_zones' do
    it 'schedules PersistHitLogsJob for each time zone' do
      expect(PersistHitLogsJob).to receive(:perform_in).at_least(:once)
      described_class.schedule_persist_jobs_for_all_time_zones
    end
  end

  describe '.persist_remaining_logs_for_time_zone' do
    it 'calls #persist_logs! for each user in the given time zone' do
      users = [create(:user, time_zone: 'UTC'), create(:user, time_zone: 'UTC')]
      expect_any_instance_of(described_class).to receive(:persist_logs!).exactly(users.size).times
      described_class.persist_remaining_logs_for_time_zone('UTC')
    end
  end
end
