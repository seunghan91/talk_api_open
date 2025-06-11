# 민감한 파라미터 필터링 설정
Rails.application.config.filter_parameters += [ :password, :token, :auth_token, :code, :phone_number, :verification_id, :jwt ]
