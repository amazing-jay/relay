class ApiQuotaService

  class << self

    # Class method to schedule persistence jobs for each time zone
    # This should be scheduled to run once, just after midnight UTC on the 1st of every month
    def schedule_persist_jobs_for_all_time_zones
      time_zones = ActiveSupport::TimeZone.all.map(&:name)

      time_zones.each do |time_zone|
        utc_offset_minutes = ActiveSupport::TimeZone[time_zone].utc_offset / 60
        minutes_from_now = utc_offset_minutes - Time.now.utc.min
        minutes_from_now += 24 * 60 if minutes_from_now < 0  # Add 24 hours if past midnight

        # Schedule the job to run 'minutes_from_now' minutes from now
        PersistHitLogsJob.perform_in(minutes_from_now.minutes, time_zone)
      end
    end

    # Class method to persist remaining logs for all users in a particular time zone
    def persist_remaining_logs_for_time_zone(time_zone)
      # Assumes there aren't a lot of API users.
      # If there are, this needs to refactored to background job and performed in batches
      users = User.where(time_zone: time_zone).all
      users.each do |user|
        ApiQuotaService.new(user).persist_logs!
      end
    end
  end

  QUOTA_LIMIT = 10_000

  # represents the maximum number of logs that can be cached in membory before persitance; increase in higher bandwidth systems
  LOG_BATCH_SIZE = 100

  def initialize(user, time_zone = nil)
    @user = user
    @time_zone = time_zone || @user.time_zone || 'UTC'
    @current_month = Time.now.in_time_zone(@time_zone).strftime('%Y%m')
    @lock_key = "user:#{@user.id}:lock"

    reset_hit_count_from_db if $redis.get(hit_count_key).nil?
  end

  def over_quota?
    $redis.get(hit_count_key).to_i >= QUOTA_LIMIT
  end

  def record_hit(endpoint)
    return if over_quota?

    log_entry = { endpoint: endpoint, created_at: Time.now.in_time_zone(@time_zone) }.to_json

    $redis.multi do
      $redis.incr(hit_count_key)
      $redis.rpush(hit_log_key, log_entry)
      $redis.expire(hit_count_key, calculate_ttl)
      $redis.expire(hit_log_key, calculate_ttl)
    end

    persist_logs! if reached_batch_size?
  end

  def hit_count_key
    "user:#{@user.id}:hit_count:#{@time_zone}:#{@current_month}"
  end

  def hit_log_key
    "user:#{@user.id}:hit_log:#{@time_zone}:#{@current_month}"
  end

  def persist_logs!
    lock! do

      hit_logs = $redis.lrange(hit_log_key, 0, -1).map { |log| JSON.parse(log) } # Fetch all logs
      hit_objects = hit_logs.map do |log|
        {
          user_id: @user.id,
          endpoint: log['endpoint'],
          created_at: Time.parse(log['created_at']).in_time_zone(@time_zone)
        }
      end

      ActiveRecord::Base.transaction do
        Hit.insert_all(hit_objects)
        $redis.del(hit_log_key)
      end
    end
  end

  def flush_keys_to_new_timezone(old_time_zone)
    lock! do
      new_time_zone = @time_zone
      @time_zone = old_time_zone
      persist_logs!
      $redis.del(hit_log_key)
      $redis.del(hit_count_key)

      @time_zone = new_time_zone

      reset_hit_count_from_db
    end
  end

  private

  def reset_hit_count_from_db
    start_of_month = Time.now.in_time_zone(@time_zone).beginning_of_month
    db_count =  @user.hits.where('created_at > ?', start_of_month).count

    # Fetch the number of unpersisted log records from Redis
    redis_count = $redis.get(hit_count_key).to_i

    # Sum the database and Redis counts
    total_count = db_count + redis_count

    # Set the hit_count in Redis
    $redis.set(hit_count_key, total_count)
  end

  def lock!
    # Acquire lock
    if $redis.setnx(@lock_key, 1)
      # Expire lock after 10 seconds as a failsafe
      $redis.expire(@lock_key, 10)

      yield

      $redis.del(@lock_key)
    end
  end

  def reached_batch_size?
    $redis.llen(hit_log_key) >= LOG_BATCH_SIZE
  end

  def calculate_ttl
    end_of_month_in_tz = Time.now.in_time_zone(@time_zone).end_of_month
    ttl = (end_of_month_in_tz + 1.week) - Time.now
    ttl.to_i
  end
end
