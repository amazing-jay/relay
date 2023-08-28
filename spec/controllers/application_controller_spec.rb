require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe 'user_quota' do
    before do
      allow(controller).to receive(:current_user).and_return(user)
      allow(controller).to receive(:request).and_return(instance_double('Request', endpoint: '/some_endpoint'))
    end

    context 'when user is under quota' do
      before do
        allow($redis).to receive(:get).and_return('1000') # Mocking user's current hit_count from Redis
      end

      it 'does not return a 429 status' do
        get :some_action
        expect(response.status).not_to eq(429)
      end
    end

    context 'when user is over quota' do
      before do
        allow($redis).to receive(:get).and_return('10001') # Mocking user's current hit_count from Redis
      end

      it 'returns a 429 status' do
        get :some_action
        expect(response.status).to eq(429)
      end
    end

    context 'when user is exactly at the quota limit' do
      before do
        allow($redis).to receive(:get).and_return('10000') # Mocking user's current hit_count from Redis
      end

      it 'does not return a 429 status' do
        get :some_action
        expect(response.status).not_to eq(429)
      end
    end
  end
end
