# config/initializers/bullet.rb
if defined?(Bullet)
  Rails.application.config.after_initialize do
    Bullet.enable = true
    Bullet.alert = true
    Bullet.bullet_logger = true
    Bullet.console = true
    Bullet.rails_logger = true
    Bullet.add_footer = true

    # 특정 모델의 특정 관계에 대한 N+1 쿼리 감지를 제외하려면 설정 추가
    # Bullet.add_safelist(:type => :n_plus_one_query, :class_name => "Message", :association => :broadcast)

    # 개발 및 테스트 환경에서만 활성화
    Bullet.raise = Rails.env.test?
  end
end
