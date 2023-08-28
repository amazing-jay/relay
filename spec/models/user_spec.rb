require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'Associations' do
    it { should have_many(:hits) }
  end

  describe 'Callbacks' do
    let(:user) { create(:user, time_zone: 'UTC') }

    context 'when time zone is changed' do
      it 'should flush keys to new timezone' do
        expect_any_instance_of(ApiQuotaService).to receive(:flush_keys_to_new_timezone)
        user.update(time_zone: 'Pacific Time (US & Canada)')
      end
    end
  end
end
