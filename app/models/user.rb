class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :hits

  #before_save :before_time_zone_change, if: :will_save_change_to_time_zone?
  after_save :time_zone_changed_callback, if: :saved_change_to_time_zone?

  private

  # NOTE: its possible that users could receive quota limit errors in the short window of time between database save and keys flush
  # its a very small window that isn't worth addressing at this time.
  # def before_time_zone_change
  #   ApiQuotaService.new(self, time_zone_was).persist_logs!
  # end

  def time_zone_changed_callback
    old_time_zone = previous_changes['time_zone'].first

    ApiQuotaService.new(self).flush_keys_to_new_timezone(old_time_zone)
  end
end
