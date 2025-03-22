# 알림 설정 조회 메서드
def notification_settings
  user = params[:id] == 'me' ? current_user : User.find(params[:id])
  
  # 현재 사용자와 요청된 사용자가 다른 경우 권한 확인
  unless user == current_user || current_user.admin?
    return render json: { error: '권한이 없습니다' }, status: :forbidden
  end
  
  render json: user.notification_settings || {}
rescue ActiveRecord::RecordNotFound
  render json: { error: '사용자를 찾을 수 없습니다' }, status: :not_found
end

# 알림 설정 업데이트 메서드
def update_notification_settings
  user = params[:id] == 'me' ? current_user : User.find(params[:id])
  
  # 현재 사용자와 요청된 사용자가 다른 경우 권한 확인
  unless user == current_user || current_user.admin?
    return render json: { error: '권한이 없습니다' }, status: :forbidden
  end
  
  if user.update_notification_settings(notification_settings_params)
    render json: user.notification_settings
  else
    render json: { error: '알림 설정 업데이트 실패' }, status: :unprocessable_entity
  end
rescue ActiveRecord::RecordNotFound
  render json: { error: '사용자를 찾을 수 없습니다' }, status: :not_found
end

private

def notification_settings_params
  params.require(:notification_settings).permit(
    :receive_new_messages, 
    :receive_broadcast_alerts,
    :receive_marketing_emails,
    :push_enabled,
    :sound_enabled,
    :vibration_enabled
  )
end 