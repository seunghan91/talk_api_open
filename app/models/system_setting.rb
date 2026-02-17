# frozen_string_literal: true

class SystemSetting < ApplicationRecord
  validates :setting_key, presence: true, uniqueness: true
  validates :setting_value, presence: true

  belongs_to :updated_by, class_name: "User", optional: true

  scope :active, -> { where(is_active: true) }

  # ─── 브로드캐스트 제한 설정 ───

  BROADCAST_LIMITS_KEY = "broadcast_limits"

  BROADCAST_LIMITS_DEFAULTS = {
    "daily_limit" => 20,
    "hourly_limit" => 5,
    "cooldown_minutes" => 10,
    "bypass_roles" => ["admin"]
  }.freeze

  # 브로드캐스트 제한 설정을 조회 (캐싱 포함)
  def self.broadcast_limits
    setting = active.find_by(setting_key: BROADCAST_LIMITS_KEY)
    return BROADCAST_LIMITS_DEFAULTS unless setting

    BROADCAST_LIMITS_DEFAULTS.merge(setting.setting_value)
  end

  # 브로드캐스트 제한 설정 업데이트
  def self.update_broadcast_limits!(values, updated_by: nil)
    setting = find_or_initialize_by(setting_key: BROADCAST_LIMITS_KEY)

    # 기존 값과 병합 (partial update 지원)
    current = setting.persisted? ? setting.setting_value : BROADCAST_LIMITS_DEFAULTS.dup
    merged = current.merge(values.stringify_keys)

    # 유효성 검사
    validate_broadcast_limits!(merged)

    setting.update!(
      setting_value: merged,
      updated_by: updated_by,
      is_active: true,
      description: "Broadcast rate limiting configuration"
    )

    setting
  end

  # ─── 범용 설정 접근 ───

  def self.get(key, default: nil)
    setting = active.find_by(setting_key: key)
    setting&.setting_value || default
  end

  def self.set!(key, value, description: nil, updated_by: nil)
    setting = find_or_initialize_by(setting_key: key)
    setting.update!(
      setting_value: value,
      description: description || setting.description,
      updated_by: updated_by,
      is_active: true
    )
    setting
  end

  private_class_method def self.validate_broadcast_limits!(values)
    daily = values["daily_limit"]
    hourly = values["hourly_limit"]
    cooldown = values["cooldown_minutes"]

    raise ArgumentError, "daily_limit must be a positive integer" unless daily.is_a?(Integer) && daily > 0
    raise ArgumentError, "hourly_limit must be a positive integer" unless hourly.is_a?(Integer) && hourly > 0
    raise ArgumentError, "cooldown_minutes must be a non-negative integer" unless cooldown.is_a?(Integer) && cooldown >= 0
    raise ArgumentError, "hourly_limit cannot exceed daily_limit" if hourly > daily
    raise ArgumentError, "bypass_roles must be an array" unless values["bypass_roles"].is_a?(Array)
  end
end
