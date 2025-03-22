# app/controllers/users_controller.rb
class UsersController < ApplicationController
    # Devise를 사용한다면 로그인 확인 (create는 제외)
    before_action :authenticate_user!, except: [ :create ]

    # 모든 사용자 조회
    def index
      @users = User.all
      render json: @users
    end

    # 사용자 생성
    def create
      user = User.new(user_params)

      if user.save
        render json: { user: user }, status: :created
      else
        render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # 특정 사용자 조회
    def show
      user = User.find_by(phone_number: params[:id]) # phone_number가 PK이므로
      if user
        render json: { user: user }
      else
        render json: { error: "User not found" }, status: :not_found
      end
    end

    # 사용자 정보 업데이트
    def update
      user = User.find_by(phone_number: params[:id])
      if user.update(user_params)
        render json: { user: user }
      else
        render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # 사용자 신고
    def report
      user_to_report = User.find_by(phone_number: params[:id])
      return render json: { error: "User not found" }, status: :not_found unless user_to_report

      report = Report.new(
        reporter: current_user, # Devise 사용 시
        reported: user_to_report,
        reason: params[:reason]
      )

      if report.save
        render json: { message: "신고 완료", report: report }, status: :ok
      else
        render json: { errors: report.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # 사용자 차단
    def block
      user_to_block = User.find_by(phone_number: params[:id])
      return render json: { error: "User not found" }, status: :not_found unless user_to_block

      block = Block.new(
        blocker: current_user, # Devise 사용 시
        blocked: user_to_block
      )

      if block.save
        render json: { message: "차단 완료", block: block }, status: :ok
      else
        render json: { errors: block.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # 사용자 차단 해제
    def unblock
      user_to_unblock = User.find_by(phone_number: params[:id])
      return render json: { error: "User not found" }, status: :not_found unless user_to_unblock

      block_record = Block.find_by(blocker: current_user, blocked: user_to_unblock)
      if block_record
        block_record.destroy
        render json: { message: "차단 해제 완료" }, status: :ok
      else
        render json: { message: "차단 내역 없음" }, status: :not_found
      end
    end

    private

    # Strong Parameters
    def user_params
      params.permit(:phone_number, :nickname, :gender, :unique_code, :is_verified, :terms_agreed, :blocked)
    end
end
